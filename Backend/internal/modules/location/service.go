package location

import (
	"encoding/csv"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const (
	ProvincesCSVURL = "https://raw.githubusercontent.com/zuydd/vn-geo/main/csv/provinces.csv"
	WardsCSVURL     = "https://raw.githubusercontent.com/zuydd/vn-geo/main/csv/wards.csv"
)

type Service interface {
	GetProvinces() ([]Province, error)
	GetWardsByProvince(provinceCode string) ([]Ward, error)
	SeedLocationsIfEmpty() error
}

type service struct {
	repo Repository
}

func NewService(repo Repository) Service {
	return &service{repo: repo}
}

func (s *service) GetProvinces() ([]Province, error) {
	return s.repo.GetProvinces()
}

func (s *service) GetWardsByProvince(provinceCode string) ([]Ward, error) {
	return s.repo.GetWardsByProvinceCode(provinceCode)
}

func (s *service) SeedLocationsIfEmpty() error {
	pCount, err := s.repo.CountProvinces()
	if err != nil {
		return fmt.Errorf("không thể đếm số tỉnh/thành: %w", err)
	}

	wCount, err := s.repo.CountWards()
	if err != nil {
		return fmt.Errorf("không thể đếm số phường/xã: %w", err)
	}

	if pCount >= 63 && wCount >= 3000 {
		log.Printf("Địa giới hành chính đã có đầy đủ dữ liệu (%d tỉnh/thành, %d phường/xã). Bỏ qua seeding.", pCount, wCount)
		return nil
	}

	log.Println("Bắt đầu nạp dữ liệu Tỉnh/Thành và Phường/Xã từ vn-geo CSV...")

	provinces, err := s.fetchAndParseProvinces()
	if err != nil {
		log.Printf("Lỗi khi tải hoặc đọc provinces.csv: %v", err)
	} else if len(provinces) > 0 {
		if err := s.repo.SaveProvincesBatch(provinces); err != nil {
			return fmt.Errorf("lỗi lưu danh sách tỉnh thành: %w", err)
		}
		log.Printf("Đã lưu thành công %d Tỉnh/Thành phố vào database!", len(provinces))
	}

	pMap := make(map[string]Province)
	for _, p := range provinces {
		pMap[p.Code] = p
	}

	if len(pMap) == 0 {
		dbProvinces, _ := s.repo.GetProvinces()
		for _, p := range dbProvinces {
			pMap[p.Code] = p
		}
	}

	wards, err := s.fetchAndParseWards(pMap)
	if err != nil {
		log.Printf("Lỗi khi tải hoặc đọc wards.csv: %v", err)
	} else if len(wards) > 0 {
		if err := s.repo.SaveWardsBatch(wards); err != nil {
			return fmt.Errorf("lỗi lưu danh sách phường xã: %w", err)
		}
		log.Printf("Đã lưu thành công %d Phường/Xã/Đặc khu vào database!", len(wards))
	}

	return nil
}

func (s *service) fetchAndParseProvinces() ([]Province, error) {
	client := http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(ProvincesCSVURL)
	if err != nil {
		return nil, fmt.Errorf("HTTP GET provinces.csv thất bại: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP status %d khi tải provinces.csv", resp.StatusCode)
	}

	r := csv.NewReader(resp.Body)
	r.FieldsPerRecord = -1

	header, err := r.Read()
	if err != nil {
		return nil, fmt.Errorf("không thể đọc header provinces.csv: %w", err)
	}

	colIdx := map[string]int{}
	for i, h := range header {
		colIdx[strings.TrimSpace(h)] = i
	}

	var provinces []Province
	for {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		code := getRecordValue(record, colIdx, "code")
		if code == "" {
			continue
		}

		isCentral, _ := strconv.ParseBool(getRecordValue(record, colIdx, "isCentral"))

		provinces = append(provinces, Province{
			Code:      code,
			Name:      getRecordValue(record, colIdx, "name"),
			Type:      getRecordValue(record, colIdx, "type"),
			IsCentral: isCentral,
		})
	}

	return provinces, nil
}

func (s *service) fetchAndParseWards(pMap map[string]Province) ([]Ward, error) {
	client := http.Client{Timeout: 60 * time.Second}
	resp, err := client.Get(WardsCSVURL)
	if err != nil {
		return nil, fmt.Errorf("HTTP GET wards.csv thất bại: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP status %d khi tải wards.csv", resp.StatusCode)
	}

	r := csv.NewReader(resp.Body)
	r.FieldsPerRecord = -1

	header, err := r.Read()
	if err != nil {
		return nil, fmt.Errorf("không thể đọc header wards.csv: %w", err)
	}

	colIdx := map[string]int{}
	for i, h := range header {
		colIdx[strings.TrimSpace(h)] = i
	}

	var wards []Ward
	for {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		code := getRecordValue(record, colIdx, "code")
		if code == "" {
			continue
		}

		pCode := getRecordValue(record, colIdx, "provinceCode")
		provName := ""
		if p, ok := pMap[pCode]; ok {
			provName = p.Name
		}

		wards = append(wards, Ward{
			Code:         code,
			Name:         getRecordValue(record, colIdx, "name"),
			Type:         getRecordValue(record, colIdx, "type"),
			ProvinceCode: pCode,
			ProvinceName: provName,
		})
	}

	return wards, nil
}

func getRecordValue(record []string, colIdx map[string]int, key string) string {
	idx, ok := colIdx[key]
	if !ok || idx >= len(record) {
		return ""
	}
	return strings.TrimSpace(record[idx])
}

package user

import (
	"context"
	"errors"
	"io"
	"regexp"
	"strings"
	"time"

	"gorm.io/gorm"
)

type AvatarUploader interface {
	UploadAvatar(
		ctx context.Context,
		userID uint,
		file io.Reader,
		filename string,
		contentType string,
	) (string, error)
}

type Service struct {
	repo           *Repository
	avatarUploader AvatarUploader
}

func NewService(repo *Repository, avatarUploader AvatarUploader) *Service {
	return &Service{
		repo:           repo,
		avatarUploader: avatarUploader,
	}
}

func (s *Service) WithTransaction(tx *gorm.DB) *Service {
	return NewService(s.repo.withDB(tx), s.avatarUploader)
}

func (s *Service) CreateEmptyProfile(userID uint) error {
	return s.CreateInitialProfile(userID, nil, "", "")
}

func (s *Service) CreateInitialProfile(userID uint, dob *time.Time, gender string, address string) error {
	existingProfile, err := s.repo.FindByUserID(userID)
	if err != nil {
		return err
	}

	if existingProfile != nil {
		return nil
	}

	profile := &UserProfile{
		UserID:             userID,
		DateOfBirth:        dob,
		Gender:             gender,
		Address:            address,
		DailyTransferLimit: 50000000,
	}

	return s.repo.CreateProfile(profile)
}

func (s *Service) GetMyProfile(userID uint) (*UserProfileResponse, error) {
	basicUser, err := s.repo.FindBasicUserInfo(userID)
	if err != nil {
		return nil, err
	}

	profile, err := s.repo.FindByUserID(userID)
	if err != nil {
		return nil, err
	}

	if profile == nil {
		profile = &UserProfile{
			UserID:             userID,
			DailyTransferLimit: 50000000,
		}
	}

	limit := profile.DailyTransferLimit
	if limit == 0 {
		limit = 50000000
	}

	return &UserProfileResponse{
		FullName:           basicUser.FullName,
		Phone:              basicUser.Phone,
		Role:               basicUser.Role,
		Address:            profile.Address,
		AvatarURL:          profile.AvatarURL,
		Gender:             profile.Gender,
		DateOfBirth:        profile.DateOfBirth,
		DailyTransferLimit: limit,
		HasIdentityCard:    profile.IdentityCardLast4 != "",
	}, nil
}

func (s *Service) UpdateMyProfile(
	userID uint,
	req UpdateUserProfileRequest,
) error {
	req.Address = strings.TrimSpace(req.Address)
	req.Gender = strings.ToLower(strings.TrimSpace(req.Gender))
	if len([]rune(req.Address)) > 500 {
		return errors.New("Địa chỉ tối đa 500 ký tự")
	}
	if req.Gender != "" &&
		req.Gender != "male" &&
		req.Gender != "female" &&
		req.Gender != "other" {
		return errors.New("Giới tính không hợp lệ")
	}
	if req.DateOfBirth != nil {
		birthDate := *req.DateOfBirth
		today := time.Now()
		if birthDate.Before(time.Date(1900, 1, 1, 0, 0, 0, 0, time.UTC)) ||
			birthDate.After(today) {
			return errors.New("Ngày sinh không hợp lệ")
		}
	}

	profile := &UserProfile{
		UserID:      userID,
		Address:     req.Address,
		Gender:      req.Gender,
		DateOfBirth: req.DateOfBirth,
	}

	existingProfile, err := s.repo.FindByUserID(userID)
	if err != nil {
		return err
	}

	if existingProfile == nil {
		return s.repo.CreateProfile(profile)
	}

	profile.AvatarURL = existingProfile.AvatarURL
	return s.repo.UpdateProfile(userID, profile)
}

func (s *Service) UploadMyAvatar(
	ctx context.Context,
	userID uint,
	file io.Reader,
	filename string,
	contentType string,
) (string, error) {
	avatarURL, err := s.avatarUploader.UploadAvatar(
		ctx,
		userID,
		file,
		filename,
		contentType,
	)
	if err != nil {
		return "", err
	}

	existingProfile, err := s.repo.FindByUserID(userID)
	if err != nil {
		return "", err
	}
	if existingProfile == nil {
		err = s.repo.CreateProfile(&UserProfile{
			UserID:    userID,
			AvatarURL: avatarURL,
		})
	} else {
		err = s.repo.UpdateAvatarURL(userID, avatarURL)
	}
	if err != nil {
		return "", err
	}
	return avatarURL, nil
}

func (s *Service) UpdateDailyTransferLimit(userID uint, limit int64) error {
	if limit < 10000000 || limit > 100000000 {
		return errors.New("Hạn mức chuyển khoản phải từ 10.000.000 VND đến 100.000.000 VND")
	}

	existingProfile, err := s.repo.FindByUserID(userID)
	if err != nil {
		return err
	}

	if existingProfile == nil {
		return s.repo.CreateProfile(&UserProfile{
			UserID:             userID,
			DailyTransferLimit: limit,
		})
	}

	return s.repo.UpdateDailyTransferLimit(userID, limit)
}

// UpdateIdentityCard cho phép user cập nhật 4 số cuối CCCD/CMND để xác thực khi rút tiền.
// Hàm này chỉ lưu 4 số cuối, không bao giờ trả về qua API.
func (s *Service) UpdateIdentityCard(userID uint, req UpdateIdentityCardRequest) error {
	last4 := strings.TrimSpace(req.IdentityCardLast4)
	if !regexp.MustCompile(`^[0-9]{4}$`).MatchString(last4) {
		return errors.New("4 số cuối CCCD/CMND phải gồm đúng 4 chữ số")
	}

	existingProfile, err := s.repo.FindByUserID(userID)
	if err != nil {
		return err
	}

	if existingProfile == nil {
		return s.repo.CreateProfile(&UserProfile{
			UserID:            userID,
			IdentityCardLast4: last4,
		})
	}

	return s.repo.UpdateIdentityCardLast4(userID, last4)
}

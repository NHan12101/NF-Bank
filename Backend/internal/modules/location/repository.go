package location

import (
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type Repository interface {
	GetProvinces() ([]Province, error)
	GetWardsByProvinceCode(provinceCode string) ([]Ward, error)
	CountProvinces() (int64, error)
	CountWards() (int64, error)
	SaveProvincesBatch(provinces []Province) error
	SaveWardsBatch(wards []Ward) error
}

type repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) Repository {
	return &repository{db: db}
}

func (r *repository) GetProvinces() ([]Province, error) {
	var provinces []Province
	err := r.db.Order("name ASC").Find(&provinces).Error
	return provinces, err
}

func (r *repository) GetWardsByProvinceCode(provinceCode string) ([]Ward, error) {
	var wards []Ward
	query := r.db.Order("name ASC")
	if provinceCode != "" {
		query = query.Where("province_code = ?", provinceCode)
	}
	err := query.Find(&wards).Error
	return wards, err
}

func (r *repository) CountProvinces() (int64, error) {
	var count int64
	err := r.db.Model(&Province{}).Count(&count).Error
	return count, err
}

func (r *repository) CountWards() (int64, error) {
	var count int64
	err := r.db.Model(&Ward{}).Count(&count).Error
	return count, err
}

func (r *repository) SaveProvincesBatch(provinces []Province) error {
	if len(provinces) == 0 {
		return nil
	}
	return r.db.Clauses(clause.OnConflict{UpdateAll: true}).CreateInBatches(provinces, 100).Error
}

func (r *repository) SaveWardsBatch(wards []Ward) error {
	if len(wards) == 0 {
		return nil
	}
	return r.db.Clauses(clause.OnConflict{UpdateAll: true}).CreateInBatches(wards, 500).Error
}

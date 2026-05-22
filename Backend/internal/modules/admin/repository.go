package admin

import (
	"bank-service/internal/modules/auth"

	"gorm.io/gorm"
)

type Repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) *Repository {
	return &Repository{
		db: db,
	}
}

func (r *Repository) FindAllUsers() ([]auth.User, error) {
	var users []auth.User

	err := r.db.Find(&users).Error
	if err != nil {
		return nil, err
	}

	return users, nil
}

func (r *Repository) FindUserByID(
	userID uint,
) (*auth.User, error) {

	var user auth.User

	err := r.db.First(&user, userID).Error
	if err != nil {
		return nil, err
	}

	return &user, nil
}

func (r *Repository) LockUser(userID uint) error {
	return r.db.
		Model(&auth.User{}).
		Where("id = ?", userID).
		Update("is_locked", true).Error
}

func (r *Repository) UnlockUser(userID uint) error {
	return r.db.
		Model(&auth.User{}).
		Where("id = ?", userID).
		Update("is_locked", false).Error
}

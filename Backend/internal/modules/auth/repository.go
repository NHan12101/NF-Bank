package auth

import (
	"errors"
	"time"

	"gorm.io/gorm"
)

// Repository chịu trách nhiệm thao tác database cho auth
type Repository struct {
	db *gorm.DB
}

// NewRepository tạo auth repository
func NewRepository(db *gorm.DB) *Repository {
	return &Repository{
		db: db,
	}
}

// CreateUser tạo user mới trong database
func (r *Repository) CreateUser(user *User) error {
	return r.db.Create(user).Error
}

// FindUserByEmail tìm user theo email
func (r *Repository) FindUserByEmail(email string) (*User, error) {
	var user User

	err := r.db.Where("email = ?", email).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}

		return nil, err
	}

	return &user, nil
}

// FindUserByID tìm user theo ID
func (r *Repository) FindUserByID(id uint) (*User, error) {
	var user User

	err := r.db.First(&user, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}

		return nil, err
	}

	return &user, nil
}

// UpdatePassword cập nhật mật khẩu mới cho user
func (r *Repository) UpdatePassword(userID uint, passwordHash string) error {
	return r.db.Model(&User{}).
		Where("id = ?", userID).
		Update("password_hash", passwordHash).Error
}

func (r *Repository) FindUserByPhone(phone string) (*User, error) {
	var user User

	err := r.db.Where("phone = ?", phone).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}

		return nil, err
	}

	return &user, nil
}

func (r *Repository) IncreaseSessionVersion(userID uint) error {
	return r.db.Model(&User{}).
		Where("id = ?", userID).
		Update("session_version", gorm.Expr("session_version + ?", 1)).
		Error
}

func (r *Repository) FindSessionVersionByUserID(
	userID uint,
) (int, error) {

	var user User

	err := r.db.
		Select("session_version").
		First(&user, userID).Error

	if err != nil {
		return 0, err
	}

	return user.SessionVersion, nil
}

func (r *Repository) CreateRefreshToken(
	refreshToken *RefreshToken,
) error {
	return r.db.Create(refreshToken).Error
}

func (r *Repository) HasActiveSession(
	userID uint,
) (bool, error) {

	var count int64

	err := r.db.
		Model(&RefreshToken{}).
		Where(
			"user_id = ? AND is_revoked = ? AND expires_at > ?",
			userID,
			false,
			time.Now(),
		).
		Count(&count).Error

	if err != nil {
		return false, err
	}

	return count > 0, nil
}

func (r *Repository) RevokeAllUserRefreshTokens(
	userID uint,
) error {

	return r.db.
		Model(&RefreshToken{}).
		Where("user_id = ? AND is_revoked = ?", userID, false).
		Update("is_revoked", true).Error
}

func (r *Repository) RevokeRefreshToken(
	tokenHash string,
) error {

	return r.db.
		Model(&RefreshToken{}).
		Where("token_hash = ?", tokenHash).
		Update("is_revoked", true).Error
}
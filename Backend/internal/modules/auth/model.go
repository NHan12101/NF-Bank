package auth

import "time"

type User struct {
	ID             uint      `gorm:"primaryKey" json:"id"`
	FullName       string    `gorm:"type:varchar(255);not null" json:"full_name"`
	Email          string    `gorm:"type:varchar(255);uniqueIndex;not null" json:"email"`
	PasswordHash   string    `gorm:"type:varchar(255);not null" json:"-"`
	Phone          string    `gorm:"type:varchar(20);uniqueIndex;not null" json:"phone"`
	Role           string    `gorm:"type:varchar(50);default:user" json:"role"`
	IsVerified     bool      `gorm:"default:false" json:"is_verified"`
	IsLocked       bool      `gorm:"default:false" json:"is_locked"`
	SessionVersion int       `gorm:"not null;default:1" json:"-"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type RefreshToken struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	UserID    uint      `gorm:"not null;index" json:"user_id"`
	TokenHash string    `gorm:"type:varchar(255);not null;uniqueIndex" json:"-"`
	IsRevoked bool      `gorm:"default:false" json:"is_revoked"`
	ExpiresAt time.Time `gorm:"not null" json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
}

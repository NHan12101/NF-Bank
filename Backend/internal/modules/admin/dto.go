package admin

import "time"

type AdminUserResponse struct {
	ID             uint      `json:"id"`
	FullName       string    `json:"full_name"`
	Email          string    `json:"email"`
	Phone          string    `json:"phone"`
	Role           string    `json:"role"`
	IsVerified     bool      `json:"is_verified"`
	IsLocked       bool      `json:"is_locked"`
	SessionVersion int       `json:"session_version"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

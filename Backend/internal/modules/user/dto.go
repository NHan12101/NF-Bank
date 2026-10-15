package user

import "time"

type UserProfileResponse struct {
	FullName           string     `json:"full_name"`
	Phone              string     `json:"phone"`
	Role               string     `json:"role"`
	Address            string     `json:"address"`
	AvatarURL          string     `json:"avatar_url"`
	Gender             string     `json:"gender"`
	DateOfBirth        *time.Time `json:"date_of_birth"`
	DailyTransferLimit int64      `json:"daily_transfer_limit"`
	HasIdentityCard    bool       `json:"has_identity_card"` // true nếu đã cập nhật CCCD/CMND
}

type UpdateUserProfileRequest struct {
	Address     string     `json:"address"`
	Gender      string     `json:"gender"`
	DateOfBirth *time.Time `json:"date_of_birth"`
}

type UpdateTransferLimitRequest struct {
	Limit int64 `json:"limit" binding:"required"`
}

// UpdateIdentityCardRequest cho phép user cập nhật 4 số cuối CCCD/CMND.
// Dùng để xác thực khi rút tiền về tài khoản ngân hàng ngoài.
type UpdateIdentityCardRequest struct {
	IdentityCardLast4 string `json:"identity_card_last4" binding:"required"`
}


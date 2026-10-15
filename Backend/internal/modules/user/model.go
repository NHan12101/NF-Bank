package user

import "time"

type UserProfile struct {
	UserID             uint       `gorm:"primaryKey" json:"user_id"`
	Address            string     `gorm:"type:varchar(500)" json:"address"`
	AvatarURL          string     `gorm:"type:varchar(500)" json:"avatar_url"`
	Gender             string     `gorm:"type:varchar(20)" json:"gender"`
	DateOfBirth        *time.Time `json:"date_of_birth"`
	IdentityCardLast4  string     `gorm:"type:varchar(4)" json:"-"` // 4 số cuối CCCD/CMND, không bao giờ expose ra API
	DailyTransferLimit int64      `gorm:"default:50000000" json:"daily_transfer_limit"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

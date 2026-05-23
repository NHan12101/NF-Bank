package transaction

import "time"

type Transaction struct {
	ID                uint      `gorm:"primaryKey" json:"id"`
	ReferenceCode     string    `gorm:"type:varchar(50);uniqueIndex;not null" json:"reference_code"`
	SenderAccountID   uint      `gorm:"not null;index" json:"sender_account_id"`
	ReceiverAccountID uint      `gorm:"not null;index" json:"receiver_account_id"`
	Amount            int64     `gorm:"not null" json:"amount"`
	Currency          string    `gorm:"type:varchar(10);not null" json:"currency"`
	Type              string    `gorm:"type:varchar(50);not null" json:"type"`
	Status            string    `gorm:"type:varchar(50);not null" json:"status"`
	Description       string    `gorm:"type:varchar(255)" json:"description"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

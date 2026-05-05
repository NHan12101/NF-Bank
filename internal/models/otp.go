package models

import (
	"time"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type OTPVerification struct {
	ID           primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	EmailOrPhone string             `bson:"email_or_phone" json:"email_or_phone"` // Đích đến của OTP (SĐT hoặc Email)
	OTP          string             `bson:"otp" json:"otp"`
	Type         string             `bson:"type" json:"type"` // VD: "register" hoặc "login"
	CreatedAt    time.Time          `bson:"created_at" json:"created_at"`

	// Dữ liệu tạm thời chờ xác thực để tạo User mới
	TempUsername string `bson:"temp_username,omitempty" json:"temp_username"`
	TempPassword string `bson:"temp_password,omitempty" json:"temp_password"` // Mật khẩu đã được mã hóa (Hash)
	TempEmail    string `bson:"temp_email,omitempty" json:"temp_email"`
	TempPhone    string `bson:"temp_phone,omitempty" json:"temp_phone"`
}
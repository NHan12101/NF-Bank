package utils

import (
	"crypto/rand"
	"fmt"
	"math/big"
)

// GenerateOTP tạo ra một chuỗi 6 số ngẫu nhiên
func GenerateOTP() string {
	// Lấy một số ngẫu nhiên từ 0 đến 999999
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "123456" // Fallback nếu có lỗi (hiếm khi xảy ra)
	}
	// Format để luôn đảm bảo có đủ 6 chữ số (ví dụ: số 42 sẽ thành "000042")
	return fmt.Sprintf("%06d", n)
}
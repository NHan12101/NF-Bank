package auth

import "golang.org/x/crypto/bcrypt"

// HashPassword mã hóa mật khẩu gốc thành chuỗi hash an toàn
func HashPassword(password string) (string, error) {
	// Tham số 14 là "cost" (độ khó). Số càng cao mã hóa càng lâu, càng khó bị bẻ khóa.
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	return string(bytes), err
}

// CheckPasswordHash so sánh mật khẩu người dùng nhập với chuỗi hash trong database
func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil // Nếu không có lỗi (nil) tức là mật khẩu khớp
}
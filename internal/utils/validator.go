package utils

import "regexp"

// IsValidVNPhone kiểm tra đầu số nhà mạng Việt Nam (10 số, bắt đầu bằng 0 hoặc +84)
func IsValidVNPhone(phone string) bool {
	pattern := `^(0|\+84)(3|5|7|8|9)[0-9]{8}$`
	matched, _ := regexp.MatchString(pattern, phone)
	return matched
}

// IsValidEmail kiểm tra định dạng email cơ bản
func IsValidEmail(email string) bool {
	pattern := `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
	matched, _ := regexp.MatchString(pattern, email)
	return matched
}
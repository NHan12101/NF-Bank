package utils

import (
	"fmt"
	"net/smtp"
	"os"
)

// SendEmail nhận vào email người nhận, tiêu đề và nội dung
func SendEmail(toEmail string, subject string, body string) error {
	from := os.Getenv("EMAIL_FROM")
	password := os.Getenv("EMAIL_PASSWORD")
	smtpHost := os.Getenv("SMTP_HOST")
	smtpPort := os.Getenv("SMTP_PORT")
	
	// Cấu trúc của một bức thư chuẩn SMTP
	message := []byte(fmt.Sprintf("To: %s\r\nSubject: %s\r\n\r\n%s", toEmail, subject, body))

	// Xác thực với máy chủ Gmail
	auth := smtp.PlainAuth("", from, password, smtpHost)

	// Tiến hành gửi
	err := smtp.SendMail(smtpHost+":"+smtpPort, auth, from, []string{toEmail}, message)
	if err != nil {
		fmt.Println("Lỗi gửi mail:", err)
		return err
	}

	fmt.Println("Đã gửi email thành công tới:", toEmail)
	return nil
}

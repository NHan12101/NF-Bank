package email

import (
	"fmt"
	"net/smtp"

	"bank-service/internal/config"
)

type Sender struct {
	cfg *config.Config
}

func NewSender(cfg *config.Config) *Sender {
	return &Sender{
		cfg: cfg,
	}
}

func (s *Sender) SendOTP(toEmail string, otp string) error {
	auth := smtp.PlainAuth(
		"",
		s.cfg.SMTPUsername,
		s.cfg.SMTPPassword,
		s.cfg.SMTPHost,
	)

	subject := "Subject: NF-Bank Password Reset OTP\r\n"

	body := fmt.Sprintf(
		"\r\nMã OTP đặt lại mật khẩu của bạn là: %s\nOTP có hiệu lực trong 5 phút.",
		otp,
	)

	message := []byte(subject + body)

	addr := fmt.Sprintf("%s:%s", s.cfg.SMTPHost, s.cfg.SMTPPort)

	return smtp.SendMail(
		addr,
		auth,
		s.cfg.SMTPUsername,
		[]string{toEmail},
		message,
	)
}

func (s *Sender) SendSecurityAlert(toEmail string) error {
	auth := smtp.PlainAuth(
		"",
		s.cfg.SMTPUsername,
		s.cfg.SMTPPassword,
		s.cfg.SMTPHost,
	)

	subject := "Subject: Cảnh báo bảo mật NF-Bank\r\n"

	body := `
Phát hiện đăng nhập từ thiết bị khác.

Toàn bộ phiên đăng nhập đã bị vô hiệu hóa để bảo vệ tài khoản của bạn.

Nếu đây không phải là bạn, vui lòng liên hệ quản trị viên ngay lập tức.
`

	message := []byte(subject + "\r\n" + body)

	addr := fmt.Sprintf("%s:%s", s.cfg.SMTPHost, s.cfg.SMTPPort)

	return smtp.SendMail(
		addr,
		auth,
		s.cfg.SMTPUsername,
		[]string{toEmail},
		message,
	)
}

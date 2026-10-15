package email

import (
	"bytes"
	"crypto/tls"
	"fmt"
	"html/template"
	"log"
	"net"
	"net/smtp"
	"strings"
	"time"

	"bank-service/internal/config"
)

// Client quản lý dịch vụ gửi Email thông báo và OTP
type Client struct {
	cfg *config.Config
}

// ReceiptData chứa thông tin biên lai giao dịch chuyển tiền (kiểu Vietcombank)
type ReceiptData struct {
	TransactionCode string
	SenderName      string
	SenderAccount   string
	ReceiverName    string
	ReceiverAccount string
	ReceiverBank    string
	Amount          int64
	Description     string
	Fee             int64
	TransactionTime time.Time
}

// NewClient khởi tạo Email Client
func NewClient(cfg *config.Config) *Client {
	return &Client{
		cfg: cfg,
	}
}

// SendRawEmail thực hiện gửi Email HTML qua SMTP (hoặc log MOCK khi chưa cấu hình SMTP)
func (c *Client) SendRawEmail(toEmail string, subject string, htmlBody string) error {
	toEmail = strings.TrimSpace(toEmail)
	if toEmail == "" {
		return fmt.Errorf("địa chỉ email nhận không được để trống")
	}

	host := c.cfg.SMTPHost
	port := c.cfg.SMTPPort
	username := c.cfg.SMTPUsername
	password := c.cfg.SMTPPassword
	fromName := c.cfg.SMTPFromName
	if fromName == "" {
		fromName = "NFBank - Ngân hàng số"
	}

	// Nếu chưa cấu hình SMTP Username / Password -> Chạy ở chế độ MOCK LOG (không báo lỗi server)
	if username == "" || password == "" {
		log.Printf("📧 [MOCK EMAIL SMTP] Gửi đến: %s | Tiêu đề: %s", toEmail, subject)
		return nil
	}

	fromHeader := fmt.Sprintf("%s <%s>", fromName, username)
	headers := make(map[string]string)
	headers["From"] = fromHeader
	headers["To"] = toEmail
	headers["Subject"] = subject
	headers["MIME-Version"] = "1.0"
	headers["Content-Type"] = "text/html; charset=UTF-8"

	message := ""
	for k, v := range headers {
		message += fmt.Sprintf("%s: %s\r\n", k, v)
	}
	message += "\r\n" + htmlBody

	addr := net.JoinHostPort(host, port)
	auth := smtp.PlainAuth("", username, password, host)

	// Xử lý gửi mail với SSL (cổng 465) hoặc STARTTLS (cổng 587)
	if port == "465" {
		tlsconfig := &tls.Config{
			InsecureSkipVerify: false,
			ServerName:         host,
		}
		conn, err := tls.Dial("tcp", addr, tlsconfig)
		if err != nil {
			return fmt.Errorf("kết nối SSL SMTP thất bại: %w", err)
		}
		defer conn.Close()

		client, err := smtp.NewClient(conn, host)
		if err != nil {
			return fmt.Errorf("khởi tạo client SMTP SSL thất bại: %w", err)
		}
		defer client.Quit()

		if err = client.Auth(auth); err != nil {
			return fmt.Errorf("xác thực SMTP thất bại: %w", err)
		}
		if err = client.Mail(username); err != nil {
			return err
		}
		if err = client.Rcpt(toEmail); err != nil {
			return err
		}
		w, err := client.Data()
		if err != nil {
			return err
		}
		_, err = w.Write([]byte(message))
		if err != nil {
			return err
		}
		err = w.Close()
		if err != nil {
			return err
		}
		log.Printf("✅ [SMTP SSL Email Sent] Đến: %s | Subject: %s", toEmail, subject)
		return nil
	}

	// Gửi qua SMTP chuẩn (STARTTLS)
	err := smtp.SendMail(addr, auth, username, []string{toEmail}, []byte(message))
	if err != nil {
		log.Printf("⚠️ Gửi mail qua SMTP thất bại: %v", err)
		return err
	}

	log.Printf("✅ [SMTP Email Sent] Đến: %s | Subject: %s", toEmail, subject)
	return nil
}

// SendOTPEmail gửi Email mã xác thực OTP (dùng cho Quên mật khẩu / Xác thực)
func (c *Client) SendOTPEmail(toEmail string, otp string) error {
	subject := fmt.Sprintf("[%s] Mã xác thực OTP đặt lại mật khẩu: %s", "NFBank", otp)
	html := generateOTPEmailHTML(otp, 5)
	return c.SendRawEmail(toEmail, subject, html)
}

// SendWelcomeEmail gửi Email chúc mừng khi đăng ký tài khoản thành công
func (c *Client) SendWelcomeEmail(toEmail string, fullName string, accountNumber string, phone string) error {
	subject := "🎉 Chào mừng Quý khách đến với Ngân hàng số NFBank"
	html := generateWelcomeEmailHTML(fullName, accountNumber, phone)
	return c.SendRawEmail(toEmail, subject, html)
}

// SendReceiptEmail gửi Email Biên lai chuyển tiền thành công (giao diện chuẩn Vietcombank)
func (c *Client) SendReceiptEmail(toEmail string, data ReceiptData) error {
	formattedAmount := formatMoney(data.Amount)
	subject := fmt.Sprintf("🟢 BIÊN LAI GIAO DỊCH: Chuyển thành công -%s VND", formattedAmount)
	html := generateReceiptEmailHTML(data)
	return c.SendRawEmail(toEmail, subject, html)
}

func formatMoney(amount int64) string {
	str := fmt.Sprintf("%d", amount)
	n := len(str)
	if n <= 3 {
		return str
	}
	var result []string
	remainder := n % 3
	if remainder > 0 {
		result = append(result, str[:remainder])
	}
	for i := remainder; i < n; i += 3 {
		result = append(result, str[i:i+3])
	}
	return strings.Join(result, ".")
}

func generateOTPEmailHTML(otp string, expireMinutes int) string {
	const tmpl = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>NFBank OTP Code</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f4f6f9; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f6f9; padding: 30px 0;">
        <tr>
            <td align="center">
                <table width="540" cellpadding="0" cellspacing="0" style="background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08);">
                    <!-- Header -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #562875 0%, #3B1F5E 100%); padding: 28px 32px; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 26px; font-weight: 800; letter-spacing: 1px;">NFBank</h1>
                            <p style="color: #e2d4f2; margin: 4px 0 0 0; font-size: 13px;">Ngân hàng số hiện đại & an toàn</p>
                        </td>
                    </tr>
                    <!-- Content -->
                    <tr>
                        <td style="padding: 32px;">
                            <h2 style="color: #1e293b; margin: 0 0 12px 0; font-size: 18px; font-weight: 700;">Xác thực mã OTP</h2>
                            <p style="color: #64748b; margin: 0 0 24px 0; font-size: 14px; line-height: 1.6;">
                                Quý khách đang thực hiện yêu cầu **đặt lại mật khẩu** hoặc **xác thực giao dịch** trên NFBank. Vui lòng nhập mã OTP bên dưới để hoàn tất:
                            </p>
                            <!-- OTP Box -->
                            <div style="background-color: #f8fafc; border: 2px dashed #6366f1; border-radius: 12px; padding: 20px; text-align: center; margin-bottom: 24px;">
                                <span style="font-size: 32px; font-weight: 800; color: #562875; letter-spacing: 8px; font-family: monospace;">{{.OTP}}</span>
                            </div>
                            <p style="color: #ef4444; margin: 0 0 16px 0; font-size: 13px; font-weight: 600;">
                                ⚠️ Mã OTP có hiệu lực trong {{.ExpireMinutes}} phút. Không chia sẻ mã này cho bất kỳ ai (kể cả nhân viên ngân hàng).
                            </p>
                            <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
                            <p style="color: #94a3b8; margin: 0; font-size: 12px; text-align: center;">
                                Đây là email tự động từ NFBank, vui lòng không trả lời email này.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
`
	t, _ := template.New("otp").Parse(tmpl)
	var buf bytes.Buffer
	_ = t.Execute(&buf, map[string]interface{}{
		"OTP":           otp,
		"ExpireMinutes": expireMinutes,
	})
	return buf.String()
}

func generateWelcomeEmailHTML(fullName, accountNumber, phone string) string {
	const tmpl = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>NFBank Welcome</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f4f6f9; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f6f9; padding: 30px 0;">
        <tr>
            <td align="center">
                <table width="560" cellpadding="0" cellspacing="0" style="background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #562875 0%, #3B1F5E 100%); padding: 32px; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: 800; letter-spacing: 1px;">NFBank</h1>
                            <p style="color: #34d399; margin: 8px 0 0 0; font-size: 15px; font-weight: 600;">🎉 Đăng ký tài khoản thành công</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 32px;">
                            <h3 style="color: #1e293b; margin: 0 0 12px 0;">Kính gửi Quý khách {{.FullName}},</h3>
                            <p style="color: #475569; margin: 0 0 20px 0; font-size: 14px; line-height: 1.6;">
                                Chúc mừng Quý khách đã mở thành công Tài khoản Thanh toán Ngân hàng số NFBank. Dưới đây là thông tin tài khoản của Quý khách:
                            </p>
                            
                            <table width="100%" cellpadding="12" cellspacing="0" style="background: #f8fafc; border-radius: 12px; border: 1px solid #e2e8f0; margin-bottom: 24px;">
                                <tr>
                                    <td style="color: #64748b; font-size: 13px;">Chủ tài khoản:</td>
                                    <td style="color: #1e293b; font-weight: bold; font-size: 14px;" align="right">{{.FullName}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13px;">Số tài khoản:</td>
                                    <td style="color: #562875; font-weight: bold; font-size: 16px; font-family: monospace;" align="right">{{.AccountNumber}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13px;">Số điện thoại đăng ký:</td>
                                    <td style="color: #1e293b; font-weight: bold; font-size: 14px;" align="right">{{.Phone}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13px;">Trạng thái tài khoản:</td>
                                    <td style="color: #059669; font-weight: bold; font-size: 13px;" align="right">🟢 Đã kích hoạt</td>
                                </tr>
                            </table>

                            <p style="color: #64748b; margin: 0; font-size: 13px; line-height: 1.5;">
                                Giờ đây Quý khách có thể bắt đầu trải nghiệm đầy đủ tính năng chuyển tiền 24/7, gửi tiết kiệm online và quản lý tài chính thông minh trên ứng dụng NFBank.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
`
	t, _ := template.New("welcome").Parse(tmpl)
	var buf bytes.Buffer
	_ = t.Execute(&buf, map[string]interface{}{
		"FullName":      strings.ToUpper(fullName),
		"AccountNumber": accountNumber,
		"Phone":         phone,
	})
	return buf.String()
}

func generateReceiptEmailHTML(data ReceiptData) string {
	const tmpl = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Biên lai chuyển tiền NFBank</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f1f5f9; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f1f5f9; padding: 30px 0;">
        <tr>
            <td align="center">
                <table width="560" cellpadding="0" cellspacing="0" style="background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.08);">
                    <!-- Vietcombank Style Top Badge -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #059669 0%, #047857 100%); padding: 28px 32px; text-align: center;">
                            <div style="background: rgba(255,255,255,0.2); width: 48px; height: 48px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 8px;">
                                <span style="color: #ffffff; font-size: 24px;">✓</span>
                            </div>
                            <h2 style="color: #ffffff; margin: 0; font-size: 20px; font-weight: 800; letter-spacing: 0.5px;">CHUYỂN TIỀN THÀNH CÔNG</h2>
                            <p style="color: #a7f3d0; margin: 4px 0 0 0; font-size: 13px;">Dịch vụ Ngân hàng điện tử NFBank</p>
                        </td>
                    </tr>
                    
                    <!-- Amount Section -->
                    <tr>
                        <td style="padding: 24px 32px 16px 32px; text-align: center; background: #fafafa; border-bottom: 1px dashed #cbd5e1;">
                            <span style="color: #64748b; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px;">Số tiền chuyển</span>
                            <h1 style="color: #dc2626; font-size: 32px; font-weight: 800; margin: 6px 0 0 0;">-{{.FormattedAmount}} VND</h1>
                        </td>
                    </tr>

                    <!-- Details Table -->
                    <tr>
                        <td style="padding: 24px 32px;">
                            <table width="100%" cellpadding="10" cellspacing="0">
                                <tr>
                                    <td style="color: #64748b; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;">Mã giao dịch (FT):</td>
                                    <td style="color: #1e293b; font-weight: 700; font-size: 14px; font-family: monospace; border-bottom: 1px solid #f1f5f9;" align="right">{{.TransactionCode}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;">Thời gian giao dịch:</td>
                                    <td style="color: #1e293b; font-weight: 600; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;" align="right">{{.TransactionTime}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;">Tài khoản nguồn:</td>
                                    <td style="color: #1e293b; font-weight: 600; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;" align="right">{{.SenderAccount}} ({{.SenderName}})</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;">Tài khoản thụ hưởng:</td>
                                    <td style="color: #562875; font-weight: 700; font-size: 14px; border-bottom: 1px solid #f1f5f9;" align="right">{{.ReceiverAccount}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;">Tên người thụ hưởng:</td>
                                    <td style="color: #1e293b; font-weight: 700; font-size: 14px; border-bottom: 1px solid #f1f5f9;" align="right">{{.ReceiverName}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;">Ngân hàng nhận:</td>
                                    <td style="color: #1e293b; font-weight: 600; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;" align="right">{{.ReceiverBank}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;">Nội dung chuyển tiền:</td>
                                    <td style="color: #1e293b; font-weight: 500; font-size: 13.5px; border-bottom: 1px solid #f1f5f9;" align="right">{{.Description}}</td>
                                </tr>
                                <tr>
                                    <td style="color: #64748b; font-size: 13.5px;">Phí giao dịch:</td>
                                    <td style="color: #059669; font-weight: 600; font-size: 13.5px;" align="right">{{.FormattedFee}} VND (Miễn phí)</td>
                                </tr>
                            </table>

                            <div style="margin-top: 24px; padding: 14px; background: #f8fafc; border-radius: 10px; text-align: center;">
                                <p style="color: #64748b; margin: 0; font-size: 12px; line-height: 1.5;">
                                    Cảm ơn Quý khách đã tin tưởng và sử dụng dịch vụ của <strong>NFBank</strong>.
                                </p>
                            </div>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
`
	t, _ := template.New("receipt").Parse(tmpl)
	var buf bytes.Buffer

	bankName := data.ReceiverBank
	if bankName == "" {
		bankName = "NFBank"
	}
	feeText := "0"
	if data.Fee > 0 {
		feeText = formatMoney(data.Fee)
	}

	_ = t.Execute(&buf, map[string]interface{}{
		"FormattedAmount": formatMoney(data.Amount),
		"TransactionCode": data.TransactionCode,
		"TransactionTime": data.TransactionTime.Format("02/01/2006 15:04:05"),
		"SenderName":      strings.ToUpper(data.SenderName),
		"SenderAccount":   data.SenderAccount,
		"ReceiverName":    strings.ToUpper(data.ReceiverName),
		"ReceiverAccount": data.ReceiverAccount,
		"ReceiverBank":    bankName,
		"Description":     data.Description,
		"FormattedFee":    feeText,
	})
	return buf.String()
}

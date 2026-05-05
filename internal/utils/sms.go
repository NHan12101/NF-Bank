package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// SpeedSMSRequest định nghĩa cấu trúc dữ liệu gửi lên API của nhà mạng
type SpeedSMSRequest struct {
	To       string `json:"to"`
	Content  string `json:"content"`
	SmsType  int    `json:"sms_type"`
	Sender   string `json:"sender"`
}

// SendOTP_SMS nhận vào số điện thoại và mã OTP, sau đó gọi API SpeedSMS để gửi tin nhắn
func SendOTP_SMS(phone string, otp string) error {
	// Lấy Token từ file .env
	token := os.Getenv("SPEEDSMS_TOKEN")
	if token == "" {
		return fmt.Errorf("lỗi hệ thống: chưa cấu hình SPEEDSMS_TOKEN trong file .env")
	}

	// LƯU Ý: Nội dung này PHẢI KHỚP 100% với mẫu đã đăng ký trên web SpeedSMS
	message := fmt.Sprintf("[NF-Bank] Ma xac thuc OTP cua ban la %s. Vui long khong chia se ma nay cho bat ky ai.", otp)

	reqBody := SpeedSMSRequest{
		To:      phone,
		Content: message,
		SmsType: 2,  // 2 = Loại tin nhắn CSKH/OTP
		Sender:  "", // Để trống để SpeedSMS tự dùng đầu số mặc định
	}

	// Chuyển struct thành chuỗi JSON
	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("lỗi parse JSON: %v", err)
	}

	// Tạo HTTP Request gửi sang server của SpeedSMS
	req, err := http.NewRequest("POST", "https://api.speedsms.vn/index.php/sms/send", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("lỗi tạo request: %v", err)
	}

	// Cấu hình Header và Basic Auth (Username là Token, Password là "x" theo tài liệu SpeedSMS)
	req.SetBasicAuth(token, "x")
	req.Header.Set("Content-Type", "application/json")

	// Cài đặt Timeout (tránh việc gọi API bị treo quá lâu)
	client := &http.Client{Timeout: 10 * time.Second}
	
	// Thực thi gọi API
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("lỗi kết nối đến SpeedSMS: %v", err)
	}
	defer resp.Body.Close()

	// Đọc kết quả nhà mạng trả về (dùng để log ra debug nếu bị lỗi)
	bodyBytes, _ := io.ReadAll(resp.Body)

	// Kiểm tra HTTP Status
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("nhà mạng từ chối gửi tin, HTTP Status: %d, Chi tiết: %s", resp.StatusCode, string(bodyBytes))
	}

	fmt.Println("✅ Đã bắn SMS OTP thành công tới số:", phone)
	return nil
}
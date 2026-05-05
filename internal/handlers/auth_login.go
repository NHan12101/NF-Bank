package handlers

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"bank-service/internal/auth"
	"bank-service/internal/database"
	"bank-service/internal/models"
	"bank-service/internal/utils"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// ==========================================
// BƯỚC 1: KIỂM TRA MẬT KHẨU VÀ BẮN OTP
// ==========================================
type RequestLoginPayload struct {
	Username  string `json:"username" binding:"required"`
	Password  string `json:"password" binding:"required"`
	OtpMethod string `json:"otp_method" binding:"required"` // "sms" hoặc "email"
}

func RequestLogin(c *gin.Context) {
	var req RequestLoginPayload
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dữ liệu không hợp lệ"})
		return
	}

	collection := database.DB.Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 1. Tìm user trong DB
	var user models.User
	err := collection.FindOne(ctx, bson.M{"username": req.Username}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Sai tài khoản hoặc mật khẩu"})
		return
	}

	// 2. Kiểm tra mật khẩu
	if !auth.CheckPasswordHash(req.Password, user.Password) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Sai tài khoản hoặc mật khẩu"})
		return
	}

	// 3. Sinh OTP và Gửi đi
	otpCode := utils.GenerateOTP()

	if req.OtpMethod == "sms" {
		err := utils.SendOTP_SMS(user.PhoneNumber, otpCode)
    if err != nil {
        fmt.Println("❌ LỖI BẮN SMS:", err)
    }
	} else {
		go utils.SendEmail(user.Email, "Mã OTP Đăng nhập NF-Bank", "Mã OTP của bạn là: " + otpCode)
	}

	// 4. Lưu OTP vào bảng tạm (Type: "login")
	otpRecord := models.OTPVerification{
		ID:           primitive.NewObjectID(),
		EmailOrPhone: user.Username, // Dùng username làm key để verify
		OTP:          otpCode,
		Type:         "login",
		CreatedAt:    time.Now(),
	}

	_, err = database.DB.Collection("otp_verifications").InsertOne(ctx, otpRecord)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi khi tạo phiên đăng nhập"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Sai tài khoản/mật khẩu đúng! Vui lòng nhập OTP để hoàn tất đăng nhập.",
		"phone":   user.PhoneNumber, // Trả về để client biết sĐT che giấu (vd: 090***123)
		"email":   user.Email,
	})
}

// ==========================================
// BƯỚC 2: XÁC THỰC OTP, CẤP TOKEN VÀ ĐÁ THIẾT BỊ CŨ
// ==========================================
type VerifyLoginPayload struct {
	Username string `json:"username" binding:"required"`
	OTP      string `json:"otp" binding:"required"`
}

func VerifyLogin(c *gin.Context) {
	var req VerifyLoginPayload
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dữ liệu không hợp lệ"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 1. Kiểm tra OTP
	var otpRecord models.OTPVerification
	err := database.DB.Collection("otp_verifications").FindOne(ctx, bson.M{
		"email_or_phone": req.Username,
		"otp":            req.OTP,
		"type":           "login",
	}).Decode(&otpRecord)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mã OTP không chính xác hoặc đã hết hạn!"})
		return
	}

	if time.Since(otpRecord.CreatedAt).Seconds() > 120 {
		// Tiện tay xóa luôn cái OTP rác này đi
		database.DB.Collection("otp_verifications").DeleteOne(ctx, bson.M{"_id": otpRecord.ID})
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mã OTP đã hết hạn! Vui lòng yêu cầu mã mới."})
		return
	}

	// 2. Lấy thông tin User
	var user models.User
	err = database.DB.Collection("users").FindOne(ctx, bson.M{"username": req.Username}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Không tìm thấy người dùng"})
		return
	}

	// 3. LOGIC XỬ LÝ PHIÊN ĐĂNG NHẬP (Giữ nguyên siêu phẩm của bạn)
	newSessionID := primitive.NewObjectID().Hex()
	isAnotherDevice := false
	if user.CurrentSessionID != "" && user.CurrentSessionID != newSessionID {
		isAnotherDevice = true // Phát hiện đang có người dùng ở thiết bị khác
	}

	// Cập nhật SessionID mới vào DB
	_, err = database.DB.Collection("users").UpdateOne(ctx,
		bson.M{"_id": user.ID},
		bson.M{"$set": bson.M{"current_session_id": newSessionID}},
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Không thể cập nhật phiên đăng nhập"})
		return
	}

	// 4. Tạo Token
	accessToken, refreshToken, err := auth.GenerateTokens(user.ID.Hex(), newSessionID, user.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi tạo token"})
		return
	}

	// Cài đặt Cookie
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie("refresh_token", refreshToken, 0, "/", "", false, true)

	// 5. GỬI EMAIL CẢNH BÁO (Goroutine) - CHỈ GỬI KHI BỊ ĐÁ VĂNG
	if isAnotherDevice {
		go func(userEmail string, loginTime time.Time) {
			subject := "🚨 CẢNH BÁO KHẨN CẤP: Tài khoản bị đăng nhập từ thiết bị mới!"
			timeStr := loginTime.Format("15:04:05 ngày 02/01/2006")

			body := fmt.Sprintf(`Chào bạn,
		
Hệ thống phát hiện tài khoản của bạn vừa được đăng nhập thành công từ một thiết bị khác vào lúc %s.
⚠️ Phiên đăng nhập trên thiết bị CŨ CỦA BẠN ĐÃ BỊ HỦY để đảm bảo an toàn.

Nếu hành động này KHÔNG PHẢI do bạn thực hiện, vui lòng lập tức đổi mật khẩu và liên hệ bộ phận CSKH của NF-Bank!`, timeStr)

			// Gọi hàm gửi Email thật của bạn ở đây (nếu đã setup)
			// utils.SendEmail(userEmail, subject, body)
			fmt.Println("📧 Đã gửi email cảnh báo thiết bị lạ tới:", userEmail)
			fmt.Println(subject)
			fmt.Println(body)
		}(user.Email, time.Now())
	}

	// 6. Xóa OTP sau khi hoàn tất
	database.DB.Collection("otp_verifications").DeleteOne(ctx, bson.M{"_id": otpRecord.ID})

	// 7. Trả về thành công
	c.JSON(http.StatusOK, gin.H{
		"message":      "Đăng nhập thành công!",
		"access_token": accessToken,
		"user": gin.H{
			"id":       user.ID.Hex(),
			"username": user.Username,
			"role":     user.Role,
		},
	})
}

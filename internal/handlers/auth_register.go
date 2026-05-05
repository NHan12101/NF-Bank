package handlers

import (
	"context"
	"fmt"
	"net/http"
	"regexp"
	"time"

	"bank-service/internal/auth"
	"bank-service/internal/database"
	"bank-service/internal/models"
	"bank-service/internal/utils" // Import thêm utils để gọi OTP và SMS

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// Dữ liệu người dùng gửi lên lúc bấm "Đăng ký"
type RequestRegisterPayload struct {
	Username  string `json:"username" binding:"required,alphanum,min=3,max=30"`
	Password  string `json:"password" binding:"required,min=8"`
	Email     string `json:"email" binding:"required,email"`
	Phone     string `json:"phone" binding:"required"`
	OtpMethod string `json:"otp_method" binding:"required"` // "sms" hoặc "email"
}

// BƯỚC 1: NHẬN THÔNG TIN VÀ BẮN OTP
func RequestRegister(c *gin.Context) {
	var req RequestRegisterPayload

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dữ liệu không hợp lệ! Vui lòng kiểm tra lại."})
		return
	}

	// 1. KIỂM TRA ĐẦU SỐ NHÀ MẠNG VIỆT NAM
	// Giải thích Regex:
	// - Bắt đầu bằng số 0 (`^0`)
	// - Kế tiếp là 1 trong các số 3, 5, 7, 8, 9 (Mã mạng: 03x, 05x, 07x, 08x, 09x)
	// - Theo sau là đúng 8 chữ số (`[0-9]{8}$`) -> Tổng cộng 10 số.
	phoneRegex := regexp.MustCompile(`^(0)(3|5|7|8|9)[0-9]{8}$`)
	if !phoneRegex.MatchString(req.Phone) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Số điện thoại không hợp lệ hoặc không thuộc nhà mạng Việt Nam!"})
		return
	}

	// 2. KIỂM TRA MẬT KHẨU NÂNG CAO BẰNG REGEX (Giữ nguyên logic cực xịn của bạn)
	passwordRegex := regexp.MustCompile(`[a-z]`)
	if !passwordRegex.MatchString(req.Password) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mật khẩu phải chứa ít nhất 1 chữ cái thường!"})
		return
	}
	passwordRegex = regexp.MustCompile(`[A-Z]`)
	if !passwordRegex.MatchString(req.Password) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mật khẩu phải chứa ít nhất 1 chữ cái viết hoa!"})
		return
	}
	passwordRegex = regexp.MustCompile(`[0-9]`)
	if !passwordRegex.MatchString(req.Password) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mật khẩu phải chứa ít nhất 1 chữ số!"})
		return
	}
	passwordRegex = regexp.MustCompile(`[!@#~$%^&*()+|_]{1}`)
	if !passwordRegex.MatchString(req.Password) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mật khẩu phải chứa ít nhất 1 ký tự đặc biệt (!@#$%^&*...)!"})
		return
	}

	// 3. Kiểm tra xem Username, Email hoặc SĐT đã tồn tại chưa
	collection := database.DB.Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	filter := bson.M{
		"$or": []bson.M{
			{"username": req.Username},
			{"email": req.Email},
			{"phone": req.Phone}, // Bổ sung check luôn SĐT
		},
	}
	count, err := collection.CountDocuments(ctx, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi server"})
		return
	}
	if count > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "Username, Email hoặc Số điện thoại đã được sử dụng!"})
		return
	}

	// 4. Mã hóa mật khẩu
	hashedPassword, err := auth.HashPassword(req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi hệ thống khi mã hóa"})
		return
	}

	// 5. Sinh mã OTP và Gửi đi
	otpCode := utils.GenerateOTP()

	if req.OtpMethod == "sms" {
		err := utils.SendOTP_SMS(req.Phone, otpCode)
    if err != nil {
        fmt.Println("❌ LỖI BẮN SMS:", err)
    }
	} else {
		go utils.SendEmail(req.Email, "Mã OTP Đăng ký NF-Bank", "Mã OTP của bạn là: " + otpCode)
	}

	// 6. Lưu vào bảng tạm thời `otp_verifications` chờ xác thực
	otpRecord := models.OTPVerification{
		ID:           primitive.NewObjectID(),
		EmailOrPhone: req.Phone,
		OTP:          otpCode,
		Type:         "register",
		CreatedAt:    time.Now(),
		TempUsername: req.Username,
		TempPassword: hashedPassword,
		TempEmail:    req.Email,
		TempPhone:    req.Phone,
	}

	_, err = database.DB.Collection("otp_verifications").InsertOne(ctx, otpRecord)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi khi lưu mã OTP"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Đã gửi mã xác thực. Vui lòng kiểm tra điện thoại hoặc Email của bạn.",
	})
}


// BƯỚC 2: XÁC THỰC OTP VÀ TẠO USER + TẠO VÍ
type VerifyRegisterPayload struct {
	Phone string `json:"phone" binding:"required"`
	OTP   string `json:"otp" binding:"required"`
}

func VerifyRegister(c *gin.Context) {
	var req VerifyRegisterPayload
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dữ liệu không hợp lệ"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 1. Tìm OTP trong DB
	var otpRecord models.OTPVerification
	err := database.DB.Collection("otp_verifications").FindOne(ctx, bson.M{
		"email_or_phone": req.Phone,
		"otp":            req.OTP,
		"type":           "register",
	}).Decode(&otpRecord)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mã OTP không chính xác hoặc đã hết hạn!"})
		return
	}

	// THÊM ĐOẠN NÀY VÀO: Kiểm tra hạn sử dụng (2 phút = 120 giây)
	if time.Since(otpRecord.CreatedAt).Seconds() > 120 {
		// Tiện tay xóa luôn cái OTP rác này đi
		database.DB.Collection("otp_verifications").DeleteOne(ctx, bson.M{"_id": otpRecord.ID})
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mã OTP đã hết hạn! Vui lòng yêu cầu mã mới."})
		return
	}

	// 2. Tạo User chính thức
	newUser := models.User{
		ID:               primitive.NewObjectID(),
		Username:         otpRecord.TempUsername,
		Password:         otpRecord.TempPassword,
		Email:            otpRecord.TempEmail,
		PhoneNumber:      otpRecord.TempPhone,
		Role:             "user",
		TrustedDevices:   []string{},
		IsLocked:         false,
		CurrentSessionID: "",
		CreatedAt:        time.Now(),
	}

	_, err = database.DB.Collection("users").InsertOne(ctx, newUser)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Không thể tạo tài khoản"})
		return
	}

	// 3. ĐIỂM QUAN TRỌNG: Tự động mở Ví (Account) với số dư 0 VNĐ
	newWallet := bson.M{
		"user_id":    newUser.ID,
		"balance":    0.0,
		"currency":   "VND",
		"AccountNumber": req.Phone,
		"status":     "active",
		"created_at": time.Now(),
	}
	_, err = database.DB.Collection("accounts").InsertOne(ctx, newWallet)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Tạo tài khoản thành công nhưng mở ví thất bại"})
		return
	}

	// 4. Xóa OTP sau khi dùng xong
	database.DB.Collection("otp_verifications").DeleteOne(ctx, bson.M{"_id": otpRecord.ID})

	c.JSON(http.StatusCreated, gin.H{
		"message": "Đăng ký và Mở ví thành công! Bạn có thể đăng nhập ngay.",
		"user_id": newUser.ID.Hex(),
	})
}
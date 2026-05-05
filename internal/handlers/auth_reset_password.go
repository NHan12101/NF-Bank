package handlers

import (
	"context"
	"net/http"
	"regexp"
	"time"

	"bank-service/internal/auth"
	"bank-service/internal/database"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

type ResetPasswordRequest struct {
	Email       string `json:"email" binding:"required,email"`
	OTP         string `json:"otp" binding:"required,len=6"`
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

func ResetPassword(c *gin.Context) {
	var req ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dữ liệu không hợp lệ. Vui lòng kiểm tra lại Email, mã OTP (6 số) và Mật khẩu mới!"})
		return
	}

	// 1. Kiểm tra độ mạnh mật khẩu (Regex ngân hàng)
	if !regexp.MustCompile(`[a-z]`).MatchString(req.NewPassword) ||
		!regexp.MustCompile(`[A-Z]`).MatchString(req.NewPassword) ||
		!regexp.MustCompile(`[0-9]`).MatchString(req.NewPassword) ||
		!regexp.MustCompile(`[!@#~$%^&*()+|_]{1}`).MatchString(req.NewPassword) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mật khẩu mới phải chứa ít nhất 1 chữ hoa, 1 chữ thường, 1 số và 1 ký tự đặc biệt!"})
		return
	}

	collection := database.DB.Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 2. Tìm User theo Email trước để kiểm tra trạng thái OTP
	var user bson.M
	err := collection.FindOne(ctx, bson.M{"email": req.Email}).Decode(&user)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"error": "Email không tồn tại trong hệ thống!"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi truy vấn hệ thống"})
		}
		return
	}

	// 3. KIỂM TRA SỐ LẦN NHẬP SAI (Chống Brute-force với kiểu dữ liệu an toàn)
	var otpAttempts int
	if attempts, ok := user["otp_attempts"]; ok && attempts != nil {
		// Tùy hệ điều hành, MongoDB có thể lưu số là int32 hoặc int64, ta cần bắt hết
		switch v := attempts.(type) {
		case int32:
			otpAttempts = int(v)
		case int64:
			otpAttempts = int(v)
		case float64:
			otpAttempts = int(v)
		}
	}

	if otpAttempts >= 5 {
		c.JSON(http.StatusForbidden, gin.H{"error": "Tài khoản bị khóa chức năng này do nhập sai OTP quá 5 lần. Vui lòng lấy mã mới!"})
		return
	}

	// 4. KIỂM TRA MÃ OTP VÀ THỜI HẠN (Fix lỗi Crash 500 tại đây)
	dbOTP, _ := user["reset_otp"].(string)

	// Lấy thời gian an toàn từ MongoDB (primitive.DateTime) chuyển về Go (time.Time)
	var dbExpiry time.Time
	if dt, ok := user["otp_expiry"].(primitive.DateTime); ok {
		dbExpiry = dt.Time()
	} else if t, ok := user["otp_expiry"].(time.Time); ok {
		// Fallback dự phòng
		dbExpiry = t
	}

	if dbOTP != req.OTP || time.Now().After(dbExpiry) {
		// 👉 SAI OTP: Tăng số lần thử lên 1 (Lúc này server không crash nữa nên lệnh này sẽ chạy)
		collection.UpdateOne(ctx, bson.M{"email": req.Email}, bson.M{"$inc": bson.M{"otp_attempts": 1}})

		c.JSON(http.StatusBadRequest, gin.H{"error": "Mã OTP không chính xác hoặc đã hết hạn!"})
		return
	}

	// 5. Nếu mọi thứ hợp lệ, tiến hành băm (hash) mật khẩu mới
	hashedPassword, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi hệ thống khi mã hóa mật khẩu"})
		return
	}

	// 6. CẬP NHẬT DATABASE: Thành công thì reset hết các trường bảo mật
	_, err = collection.UpdateOne(
		ctx,
		bson.M{"email": req.Email},
		bson.M{"$set": bson.M{
			"password":           hashedPassword,
			"reset_otp":          "",          // Xóa OTP
			"otp_expiry":         time.Time{}, // Reset thời gian
			"otp_attempts":       5,           // Reset số lần thử về 0
			"current_session_id": "",          // Đá văng các thiết bị cũ
		}},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Không thể cập nhật mật khẩu lúc này!"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Khôi phục mật khẩu thành công! Bạn có thể đăng nhập bằng mật khẩu mới."})
}

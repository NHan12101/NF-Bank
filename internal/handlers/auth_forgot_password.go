package handlers

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"bank-service/internal/database"
	"bank-service/internal/utils"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
)

type ForgotPasswordRequest struct {
	Email string `json:"email" binding:"required,email"`
}

func ForgotPassword(c *gin.Context) {
	var req ForgotPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email không hợp lệ!"})
		return
	}

	collection := database.DB.Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 1. Kiểm tra xem email này có tồn tại trong hệ thống không
	var user bson.M
	err := collection.FindOne(ctx, bson.M{"email": req.Email}).Decode(&user)
	if err != nil {
		// Dù không tìm thấy, chúng ta vẫn trả về thông báo chung chung để chống Hacker dò quét email
		c.JSON(http.StatusOK, gin.H{"message": "Nếu email hợp lệ, mã OTP sẽ được gửi đến hộp thư của bạn."})
		return
	}

	// 2. Tạo mã OTP và tính toán thời gian hết hạn (5 phút kể từ bây giờ)
	otp := utils.GenerateOTP()
	expiryTime := time.Now().Add(5 * time.Minute)

	// 3. Cập nhật OTP và thời hạn vào Database của User đó
	_, err = collection.UpdateOne(
		ctx,
		bson.M{"email": req.Email},
		bson.M{"$set": bson.M{
			"reset_otp":    otp,
			"otp_expiry":   expiryTime,
			"otp_attempts": 0,
		}},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi hệ thống, vui lòng thử lại sau!"})
		return
	}

	// 4. Gửi email chứa mã OTP (Chạy ngầm bằng Goroutine)
	go func() {
		subject := "Mã OTP Khôi phục mật khẩu"
		body := fmt.Sprintf("Chào bạn,\n\nMã OTP để khôi phục mật khẩu của bạn là: %s\n\nMã này có hiệu lực trong 5 phút. KHÔNG ĐƯỢC CHIA SẺ MÃ NÀY CHO BẤT KỲ AI.\n\nĐội ngũ Ngân hàng.", otp)
		utils.SendEmail(req.Email, subject, body)
	}()

	c.JSON(http.StatusOK, gin.H{"message": "Nếu email hợp lệ, mã OTP sẽ được gửi đến hộp thư của bạn."})
}
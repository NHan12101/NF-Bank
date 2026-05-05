package handlers

import (
	"context"
	"net/http"
	"regexp"
	"time"

	"bank-service/internal/auth"
	"bank-service/internal/database"
	"bank-service/internal/models"
	"bank-service/internal/utils"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

func ChangePassword(c *gin.Context) {
	var req ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dữ liệu không hợp lệ. Mật khẩu mới phải có ít nhất 8 ký tự."})
		return
	}

	// Lấy user_id từ Token (Middleware RequireAuth đã giải mã và nhét vào Context)
	userIDStr, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Không tìm thấy thông tin xác thực"})
		return
	}

	objID, _ := primitive.ObjectIDFromHex(userIDStr.(string))

	collection := database.DB.Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Tìm User trong Database
	var user models.User
	err := collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Người dùng không tồn tại"})
		return
	}

	// 1. Kiểm tra mật khẩu cũ
	if !auth.CheckPasswordHash(req.OldPassword, user.Password) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mật khẩu cũ không chính xác!"})
		return
	}

	// 2. Kiểm tra mật khẩu mới không được trùng mật khẩu cũ
	if req.OldPassword == req.NewPassword {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mật khẩu mới không được trùng với mật khẩu cũ!"})
		return
	}

	// 3. Kiểm tra độ mạnh mật khẩu mới (Regex chuẩn Ngân hàng)
	if !regexp.MustCompile(`[a-z]`).MatchString(req.NewPassword) ||
		!regexp.MustCompile(`[A-Z]`).MatchString(req.NewPassword) ||
		!regexp.MustCompile(`[0-9]`).MatchString(req.NewPassword) ||
		!regexp.MustCompile(`[!@#~$%^&*()+|_]{1}`).MatchString(req.NewPassword) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Mật khẩu mới phải chứa ít nhất 1 chữ hoa, 1 chữ thường, 1 số và 1 ký tự đặc biệt!"})
		return
	}

	// 4. Mã hóa mật khẩu mới
	hashedPassword, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi hệ thống khi mã hóa mật khẩu"})
		return
	}

	go func() {
		subject := "Cảnh báo bảo mật: Thay đổi mật khẩu thành công!"
		body := "Chào " + user.Username + ",\n\nMật khẩu tài khoản ngân hàng của bạn vừa được thay đổi thành công. Nếu không phải bạn thực hiện, vui lòng liên hệ tổng đài ngay lập tức!\n\nTrân trọng,\nĐội ngũ Ngân hàng."

		// user.Email là email mà người dùng đã đăng ký
		utils.SendEmail(user.Email, subject, body)
	}()

	c.JSON(http.StatusOK, gin.H{"message": "Đổi mật khẩu thành công! Vui lòng đăng nhập lại với mật khẩu mới."})

	// 5. Lưu vào DB và xóa SessionID để bắt đăng nhập lại
	_, err = collection.UpdateOne(
		ctx,
		bson.M{"_id": objID},
		bson.M{"$set": bson.M{
			"password":           hashedPassword,
			"current_session_id": "", // Đá văng phiên đăng nhập hiện tại
		}},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Không thể cập nhật mật khẩu"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Đổi mật khẩu thành công! Vui lòng đăng nhập lại với mật khẩu mới."})
}

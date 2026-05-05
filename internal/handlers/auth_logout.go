package handlers

import (
	"context"
	"net/http"
	"time"

	"bank-service/internal/database"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
)

// Khai báo struct nhận username để biết ai đang muốn đăng xuất
type LogoutRequest struct {
	Username string `json:"username" binding:"required"`
}

func Logout(c *gin.Context) {
	var req LogoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cần cung cấp username để đăng xuất"})
		return
	}

	collection := database.DB.Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 1. XÓA SESSION ID TRONG DATABASE
	// Chuyển current_session_id về chuỗi rỗng ""
	result, err := collection.UpdateOne(
		ctx,
		bson.M{"username": req.Username},
		bson.M{"$set": bson.M{"current_session_id": ""}},
	)
	if err != nil || result.MatchedCount == 0 {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Không thể đăng xuất hoặc không tìm thấy user"})
		return
	}

	// 2. TIÊU HỦY COOKIE TRÊN TRÌNH DUYỆT
	// Bằng cách set MaxAge = -1, trình duyệt sẽ hiểu là phải xóa Cookie này ngay lập tức
	c.SetCookie("refresh_token", "", -1, "/", "", false, true)

	c.JSON(http.StatusOK, gin.H{
		"message": "Đã đăng xuất tài khoản thành công và xóa sạch phiên đăng nhập!",
	})
}
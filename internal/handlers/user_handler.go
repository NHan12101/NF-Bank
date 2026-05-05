package handlers

import (
	"net/http"
	"github.com/gin-gonic/gin"
)

// GetProfile là API chỉ những ai có thẻ mới vào được
func GetProfile(c *gin.Context) {
	// Lấy cái nhãn mà Bác bảo vệ đã dán vào Context ở bước 4
	userID, _ := c.Get("userID")
	username, _ := c.Get("username")
	role, _ := c.Get("role")

	// Trả về dữ liệu mật
	c.JSON(http.StatusOK, gin.H{
		"message": "Chào mừng đến với khu vực tuyệt mật của ngân hàng!",
		"data": gin.H{
			"id":       userID,
			"username": username,
			"role":     role,
			"balance":  "100.000.000 VNĐ", // Tiền giả lập
		},
	})
}
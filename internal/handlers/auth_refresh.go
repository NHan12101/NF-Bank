package handlers

import (
	"context"
	"net/http"
	"os"
	"time"

	"bank-service/internal/auth"
	"bank-service/internal/database"
	"bank-service/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

func RefreshToken(c *gin.Context) {
	// 1. Tự động lấy Refresh Token từ Cookie (trình duyệt sẽ tự gửi lên)
	refreshTokenString, err := c.Cookie("refresh_token")
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Không tìm thấy Refresh Token. Vui lòng đăng nhập lại!"})
		return
	}

	// 2. Giải mã và kiểm tra hạn sử dụng của thẻ
	secretKey := []byte(os.Getenv("JWT_SECRET"))
	token, err := jwt.ParseWithClaims(refreshTokenString, &auth.RefreshClaims{}, func(t *jwt.Token) (interface{}, error) {
		return secretKey, nil
	})

	if err != nil || !token.Valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Refresh Token không hợp lệ hoặc đã hết hạn!"})
		return
	}

	claims, ok := token.Claims.(*auth.RefreshClaims)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Dữ liệu thẻ bị lỗi!"})
		return
	}

	// 3. ĐÁ VĂNG MÁY CŨ: Kiểm tra Session ID trong Database
	collection := database.DB.Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	objID, _ := primitive.ObjectIDFromHex(claims.UserID)
	var user models.User
	err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)

	// Nếu user không tồn tại hoặc Session ID đã bị thay đổi (do đăng nhập máy khác/đăng xuất)
	if err != nil || user.CurrentSessionID != claims.SessionID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Phiên đăng nhập không hợp lệ hoặc đã bị đăng xuất!"})
		return
	}

	// 4. IN THẺ MỚI (Xoay vòng thẻ)
	// Cấp lại 1 Access Token 5 phút mới và 1 Refresh Token 7 ngày mới
	newAccessToken, newRefreshToken, err := auth.GenerateTokens(user.ID.Hex(), user.CurrentSessionID, user.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi khi tạo token mới"})
		return
	}

	// 5. Cập nhật lại Cookie và trả về Access Token mới cho Frontend
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie("refresh_token", newRefreshToken, 0, "/", "", false, true)

	c.JSON(http.StatusOK, gin.H{
		"message":      "Làm mới thẻ thành công!",
		"access_token": newAccessToken,
	})
}
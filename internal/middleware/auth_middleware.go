package middleware

import (
	"context"
	"net/http"
	"os"
	"strings"
	"time"

	"bank-service/internal/auth"
	"bank-service/internal/database"
	"bank-service/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// RequireAuth chính là "Bác bảo vệ" của chúng ta
func RequireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		// BƯỚC 1: Chặn cửa và đòi thẻ (Kiểm tra Header Authorization)
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Bạn chưa cung cấp thẻ Access Token!"})
			c.Abort() // Đuổi về ngay lập tức, không cho đi tiếp
			return
		}

		// Cắt bỏ chữ "Bearer " để lấy đúng cái chuỗi token
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		// BƯỚC 2: Soi thẻ thật/giả và Hạn sử dụng
		secretKey := []byte(os.Getenv("JWT_SECRET"))
		token, err := jwt.ParseWithClaims(tokenString, &auth.AccessClaims{}, func(t *jwt.Token) (interface{}, error) {
			return secretKey, nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Thẻ (Token) không hợp lệ hoặc đã hết hạn 5 phút!"})
			c.Abort()
			return
		}

		// Trích xuất thông tin giấu trong thẻ (Claims)
		claims, ok := token.Claims.(*auth.AccessClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Dữ liệu thẻ bị lỗi!"})
			c.Abort()
			return
		}

		// BƯỚC 3: CƠ CHẾ ĐÁ VĂNG (Kiểm tra Session ID dưới Database)
		collection := database.DB.Collection("users")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		objID, _ := primitive.ObjectIDFromHex(claims.UserID)
		var user models.User
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)

		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Tài khoản không còn tồn tại trên hệ thống"})
			c.Abort()
			return
		}

		// KIỂM TRA CHỐT CHẶN BẢO MẬT: Nhỡ chủ nhà đã đăng xuất hoặc đăng nhập máy khác?
		if user.CurrentSessionID != claims.SessionID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Phiên đăng nhập đã cũ (Có người đăng nhập ở máy khác hoặc đã đăng xuất). Lập tức văng ra!"})
			c.Abort()
			return
		}

		// Nhỡ tài khoản đang bị khóa khẩn cấp?
		if user.IsLocked {
			c.JSON(http.StatusForbidden, gin.H{"error": "Tài khoản đang bị khóa khẩn cấp!"})
			c.Abort()
			return
		}

		// BƯỚC 4: Mở cổng và Dán nhãn (Lưu thông tin vào Context để các API sau xài)
		c.Set("userID", claims.UserID)
		c.Set("role", claims.Role)
		c.Set("username", user.Username)

		c.Next() // Mở cửa cho đi tiếp vào hàm API thực sự
	}
}

// RequireRole là "Cửa từ an ninh" kiểm tra cấp bậc của thẻ
func RequireRole(requiredRole string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 1. Lấy thông tin Role mà Bác bảo vệ RequireAuth đã dán vào trước đó
		userRole, exists := c.Get("role")
		if !exists {
			c.JSON(http.StatusForbidden, gin.H{"error": "Không thể xác định quyền truy cập!"})
			c.Abort() // Đuổi ra
			return
		}

		// 2. So sánh quyền: Nếu quyền của user không khớp với quyền yêu cầu
		if userRole != requiredRole {
			c.JSON(http.StatusForbidden, gin.H{"error": "Quyền lực của bạn không đủ để vào khu vực này!"})
			c.Abort() // Đuổi ra
			return
		}

		// 3. Đúng quyền thì mở cửa cho đi tiếp
		c.Next()
	}
}
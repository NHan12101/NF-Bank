package main

import (
	"log"
	"os"

	"bank-service/internal/database"
	"bank-service/internal/handlers"
	"bank-service/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// 1. Load các biến môi trường từ file .env
	err := godotenv.Load()
	if err != nil {
		log.Println("⚠️ Cảnh báo: Không tìm thấy file .env, sẽ sử dụng biến môi trường hệ thống")
	}

	// Lấy thông tin kết nối từ file .env
	mongoURI := os.Getenv("MONGO_URI")
	dbName := os.Getenv("DB_NAME")
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080" // Port mặc định nếu .env chưa có
	}

	// 2. Kết nối tới MongoDB
	database.ConnectDB(mongoURI, dbName)

	// 3. Khởi tạo router Gin
	r := gin.Default()

	// --- PHẦN THÊM MỚI: ĐỊNH NGHĨA CÁC ROUTES ---

	// Route kiểm tra hệ thống
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Bank Service đang chạy ngon lành và đã sẵn sàng!",
		})
	})

	// Nhóm các API liên quan đến xác thực (Authentication)
	authRoutes := r.Group("/auth")
	authRoutes.Use(middleware.RateLimiter())
	{
		// API Đăng ký
		authRoutes.POST("/register/request", handlers.RequestRegister)
		authRoutes.POST("/register/verify", handlers.VerifyRegister)

		// API Đăng nhập
		authRoutes.POST("/login/request", handlers.RequestLogin)
		authRoutes.POST("/login/verify", handlers.VerifyLogin)

		// API Đăng xuất
		authRoutes.POST("/logout", handlers.Logout)

		// API Quên mật khẩu (Gửi OTP)
		authRoutes.POST("/forgot-password", handlers.ForgotPassword)

		//API Xác nhận OTP & Reset mật khẩu
		authRoutes.POST("/reset-password", handlers.ResetPassword)

		authRoutes.POST("/refresh", handlers.RefreshToken)
	}

	// 🚨 KHU VỰC CÁCH LY CHUNG (Chỉ cần có thẻ là vào được)
	protectedRoutes := r.Group("/api")
	protectedRoutes.Use(middleware.RequireAuth())
	{
		// Xem thông tin cá nhân
		protectedRoutes.GET("/profile", handlers.GetProfile)

		// Thay đổi mật khẩu
		protectedRoutes.POST("/change-password", handlers.ChangePassword)
	}

	// 👑 KHU VỰC TỐI CAO (Phải có thẻ VÀ phải là Admin)
	adminRoutes := r.Group("/api/admin")
	adminRoutes.Use(middleware.RequireAuth(), middleware.RequireRole("admin"))
	{
		// Test dashboard
		adminRoutes.GET("/dashboard", func(c *gin.Context) {
			c.JSON(200, gin.H{"message": "Chào mừng Admin!"})
		})

		// API Mở khóa (POST http://localhost:8080/api/admin/unlock-user)
		adminRoutes.POST("/unlock-user", handlers.UnlockUser)

		// API Khóa (POST http://localhost:8080/api/admin/lock-user)
		adminRoutes.POST("/lock-user", handlers.LockUser)
	}

	// --- KẾT THÚC PHẦN THÊM MỚI ---

	// 4. Chạy server
	log.Printf("🚀 Server đang chạy tại port %s", port)
	r.Run(":" + port)
}

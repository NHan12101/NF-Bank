package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"bank-service/internal/config"
	"bank-service/internal/database"
	"bank-service/internal/infrastructure/email"
	"bank-service/internal/infrastructure/firebase"
	"bank-service/internal/modules/account"
	"bank-service/internal/modules/admin"
	"bank-service/internal/modules/auth"
	"bank-service/internal/modules/credit"
	"bank-service/internal/modules/notification"
	"bank-service/internal/modules/savings"
	"bank-service/internal/modules/transaction"
	"bank-service/internal/modules/user"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	fmt.Println("🚀 Đang khởi động hệ thống NF-Bank...")

	cfg := config.LoadConfig()

	database.ConnectMongoDB(cfg.MongoURI, cfg.MongoDBName)

	dsn := cfg.GetMySQLDSN()
	database.ConnectMySQL(dsn)

	if err := database.DB.AutoMigrate(
		&auth.User{},
		&auth.RefreshToken{},
		&auth.UserDevice{},
		&auth.PendingLogin{},
		&notification.Notification{},
		&account.Account{},
		&savings.SavingsDetail{},
		&credit.CreditDetail{},
		&user.UserProfile{},
		&transaction.Transaction{},
	); err != nil {
		log.Fatalf("❌ MySQL Auto Migration thất bại: %v", err)
	}
	log.Println("✅ MySQL Auto Migration hoàn tất!")

	// Seed Super Admin
	var count int64
	if err := database.DB.Model(&auth.User{}).Where("role = ?", "super_admin").Count(&count).Error; err != nil {
		log.Printf("⚠️ Lỗi kiểm tra tài khoản Super Admin: %v", err)
	} else if count == 0 {
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte("SuperAdmin123!"), bcrypt.DefaultCost)
		if err != nil {
			log.Fatalf("❌ Lỗi mã hóa mật khẩu Super Admin: %v", err)
		}
		superAdmin := auth.User{
			FullName:     "Super Admin",
			Email:        "superadmin@nfbank.com",
			PasswordHash: string(hashedPassword),
			Phone:        "0999999999",
			Role:         "super_admin",
			IsVerified:   true,
			IsLocked:     false,
			TOTPSecret:   "KGF2MOLIONATKJ5IWJW4FJYUVFS7KHPT",
		}
		if err := database.DB.Create(&superAdmin).Error; err != nil {
			log.Printf("⚠️ Lỗi tạo tài khoản Super Admin mặc định: %v", err)
		} else {
			log.Println("✅ Đã tạo tài khoản Super Admin mặc định (superadmin@nfbank.com / SuperAdmin123!)")
		}
	}

	// Khởi tạo Firebase Admin Client
	firebaseClient, err := firebase.InitFirebase(cfg.FirebaseCredentials)
	if err != nil {
		log.Fatalf("❌ Khởi tạo Firebase Admin SDK thất bại: %v", err)
	}

	if cfg.ServerMode == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.Default()

	authRepo := auth.NewRepository(database.DB)
	otpRepo := auth.NewOTPRepository(database.Mongo)

	// THÊM: repository lưu thông tin đăng ký chờ xác thực OTP trong MongoDB
	verifyRegisterRepo := auth.NewVerifyRegisterRepository(database.Mongo)

	emailSender := email.NewSender(cfg)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// SỬA: tạo TTL index cho OTP reset password thông qua repository
	if err := otpRepo.CreateTTLIndex(ctx); err != nil {
		log.Fatalf("❌ Lỗi tạo TTL Index cho OTP: %v", err)
	}
	log.Println("✅ TTL Index cho OTP MongoDB đã được cấu hình!")

	// THÊM: tạo TTL index cho verify register
	if err := verifyRegisterRepo.CreateTTLIndex(ctx); err != nil {
		log.Fatalf("❌ Lỗi tạo TTL Index cho Verify Register: %v", err)
	}
	log.Println("✅ TTL Index cho Verify Register MongoDB đã được cấu hình!")

	// SỬA: truyền thêm verifyRegisterRepo vào auth service

	accountRepo := account.NewRepository(database.DB)
	accountService := account.NewService(accountRepo)

	userRepo := user.NewRepository(database.DB)
	userService := user.NewService(userRepo)

	authService := auth.NewService(
		authRepo,
		otpRepo,
		verifyRegisterRepo,
		emailSender,
		accountService,
		userService,
		cfg,
		firebaseClient,
	)
	authHandler := auth.NewHandler(authService)

	accountHandler := account.NewHandler(accountService)
	userHandler := user.NewHandler(userService)

	adminRepo := admin.NewRepository(database.DB)
	adminService := admin.NewService(adminRepo, accountService)
	adminHandler := admin.NewHandler(adminService)

	transactionRepo := transaction.NewRepository(database.DB)
	transactionService := transaction.NewService(transactionRepo, firebaseClient)
	transactionHandler := transaction.NewHandler(transactionService)

	api := r.Group("/api/v1")
	auth.RegisterRoutes(api, authHandler)
	account.RegisterRoutes(api, accountHandler, cfg)
	user.RegisterRoutes(api, userHandler, cfg)
	transaction.RegisterRoutes(api, transactionHandler, cfg)
	admin.RegisterRoutes(api, adminHandler, cfg)

	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "NF-Bank Server is running!",
			"mode":    cfg.ServerMode,
		})
	})

	port := fmt.Sprintf(":%s", cfg.ServerPort)
	fmt.Printf("✅ Server đang chạy tại cổng %s\n", cfg.ServerPort)

	if err := r.Run(port); err != nil {
		log.Fatalf("❌ Lỗi nghiêm trọng khi khởi chạy server: %v", err)
	}
}

package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"bank-service/internal/config"
	"bank-service/internal/database"
	"bank-service/internal/infrastructure/cloudinary"
	"bank-service/internal/infrastructure/email"
	"bank-service/internal/infrastructure/firebase"
	"bank-service/internal/modules/account"
	"bank-service/internal/modules/admin"
	"bank-service/internal/modules/auth"
	"bank-service/internal/modules/location"
	"bank-service/internal/modules/notification"
	"bank-service/internal/modules/payment"
	"bank-service/internal/modules/savings"
	"bank-service/internal/modules/transaction"
	"bank-service/internal/modules/user"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	cfg := config.LoadConfig()

	dsn := cfg.GetMySQLDSN()
	database.ConnectMySQL(dsn)

	// Phiên bản cũ giới hạn một tài khoản SAVINGS cho mỗi người. Bỏ unique
	// index này trước khi migrate để hỗ trợ nhiều sổ tiết kiệm độc lập.
	if database.DB.Migrator().HasTable(&account.Account{}) &&
		database.DB.Migrator().HasIndex(&account.Account{}, "idx_user_account_type") {
		if !database.DB.Migrator().HasIndex(&account.Account{}, "idx_accounts_user_type") {
			if err := database.DB.Migrator().CreateIndex(&account.Account{}, "idx_accounts_user_type"); err != nil {
				log.Fatalf("Không thể tạo index tài khoản thay thế: %v", err)
			}
		}
		if err := database.DB.Migrator().DropIndex(&account.Account{}, "idx_user_account_type"); err != nil {
			log.Fatalf("Không thể bỏ giới hạn một sổ tiết kiệm: %v", err)
		}
	}

	if database.DB.Migrator().HasColumn(&location.Province{}, "full_name") {
		_ = database.DB.Migrator().DropColumn(&location.Province{}, "full_name")
	}
	if database.DB.Migrator().HasColumn(&location.Province{}, "slug") {
		_ = database.DB.Migrator().DropColumn(&location.Province{}, "slug")
	}
	if database.DB.Migrator().HasColumn(&location.Ward{}, "full_name") {
		_ = database.DB.Migrator().DropColumn(&location.Ward{}, "full_name")
	}
	if database.DB.Migrator().HasColumn(&location.Ward{}, "slug") {
		_ = database.DB.Migrator().DropColumn(&location.Ward{}, "slug")
	}
	if database.DB.Migrator().HasColumn(&location.Ward{}, "province_full_name") {
		_ = database.DB.Migrator().DropColumn(&location.Ward{}, "province_full_name")
	}

	if err := database.DB.AutoMigrate(
		&auth.User{},
		&auth.RefreshToken{},
		&auth.UserDevice{},
		&auth.TOTPUsage{},
		&admin.AuditLog{},
		&admin.StepUpChallenge{},
		&notification.Notification{},
		&notification.PushToken{},
		&account.Account{},
		&user.UserProfile{},
		&transaction.Transaction{},
		&transaction.LedgerEntry{},
		&transaction.TransactionPIN{},
		&savings.SavingsDetail{},
		&savings.SavingsMaturityEvent{},
		&savings.SavingsWithdrawal{},
		&payment.Merchant{},
		&payment.PaymentSession{},
		&location.Province{},
		&location.Ward{},
	); err != nil {
		log.Fatalf("MySQL Auto Migration thất bại: %v", err)
	}
	log.Println("MySQL Auto Migration hoàn tất!")

	// Khởi tạo Firebase Admin Client
	firebaseClient, err := firebase.InitFirebase(cfg.FirebaseCredentials)
	if err != nil {
		log.Fatalf("Khởi tạo Firebase Admin SDK thất bại: %v", err)
	}

	if cfg.ServerMode == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.Default()
	r.Use(corsMiddleware(cfg))

	authRepo := auth.NewRepository(database.DB)
	accountRepo := account.NewRepository(database.DB)
	accountService := account.NewService(accountRepo)

	if cfg.EnableDevSeed {
		log.Println("Development seed đang được bật")

		var count int64
		if err := database.DB.Model(&auth.User{}).Where("role = ?", "super_admin").Count(&count).Error; err != nil {
			log.Printf("Lỗi kiểm tra tài khoản Super Admin: %v", err)
		} else if count == 0 {
			hashedPassword, err := bcrypt.GenerateFromPassword([]byte("SuperAdmin123!"), bcrypt.DefaultCost)
			if err != nil {
				log.Fatalf("Lỗi mã hóa mật khẩu Super Admin: %v", err)
			}
			superAdmin := auth.User{
				FullName:     "SUPER ADMIN",
				PasswordHash: string(hashedPassword),
				Phone:        "+84999999999",
				Role:         "super_admin",
				IsVerified:   true,
				IsLocked:     false,
				TOTPSecret:   "KGF2MOLIONATKJ5IWJW4FJYUVFS7KHPT",
			}
			if err := database.DB.Create(&superAdmin).Error; err != nil {
				log.Printf("Lỗi tạo tài khoản Super Admin phát triển: %v", err)
			} else {
				_ = accountService.CreateDefaultPaymentAccount(superAdmin.ID)
			}
		}

		// 1. Kiểm tra hoặc tạo TEST_MERCHANT (NF-Mart)
		var nfMartCount int64
		if err := database.DB.Model(&payment.Merchant{}).Where("partner_code = ?", "TEST_MERCHANT").Count(&nfMartCount).Error; err == nil && nfMartCount == 0 {
			var adminUser auth.User
			if err := database.DB.Where("role = ?", "super_admin").First(&adminUser).Error; err == nil {
				var adminAccount account.Account
				err := database.DB.Where("user_id = ? AND account_type = ?", adminUser.ID, "PAYMENT").First(&adminAccount).Error
				if err != nil {
					_ = accountService.CreateDefaultPaymentAccount(adminUser.ID)
					_ = database.DB.Where("user_id = ? AND account_type = ?", adminUser.ID, "PAYMENT").First(&adminAccount).Error
				}
				if adminAccount.ID != 0 {
					newMerchant := payment.Merchant{
						PartnerCode:      "TEST_MERCHANT",
						MerchantName:     "Cửa hàng Tiện lợi NF-Mart",
						AccessKey:        "test_access_key",
						SecretKey:        "test_secret_key",
						PaymentAccountID: adminAccount.ID,
					}
					if err := database.DB.Create(&newMerchant).Error; err == nil {
						log.Println("Đã tạo Merchant TEST_MERCHANT thành công!")
					}
				}
			}
		}

		// 2. Kiểm tra hoặc tạo CHILLFY (Chillfy)
		var chillfyCount int64
		if err := database.DB.Model(&payment.Merchant{}).Where("partner_code = ?", "CHILLFY").Count(&chillfyCount).Error; err == nil && chillfyCount == 0 {
			var adminUser auth.User
			if err := database.DB.Where("role = ?", "super_admin").First(&adminUser).Error; err == nil {
				var adminAccount account.Account
				err := database.DB.Where("user_id = ? AND account_type = ?", adminUser.ID, "PAYMENT").First(&adminAccount).Error
				if err != nil {
					_ = accountService.CreateDefaultPaymentAccount(adminUser.ID)
					_ = database.DB.Where("user_id = ? AND account_type = ?", adminUser.ID, "PAYMENT").First(&adminAccount).Error
				}
				if adminAccount.ID != 0 {
					newMerchant := payment.Merchant{
						PartnerCode:      "CHILLFY",
						MerchantName:     "Chillfy",
						AccessKey:        "kCF5vDzO+q8N4qWCCcKgbGb6nRDNipifxZmvcqP31iA=",
						SecretKey:        "uxzT7tKY9DHw7bMpKb3DISYmiJ/n2QCPGhcW5N8VU18xs9gSAb5qZiehH9YzN+J1EH2ScX5a3uMvIvu2RjaWhg==",
						PaymentAccountID: adminAccount.ID,
					}
					if err := database.DB.Create(&newMerchant).Error; err == nil {
						log.Println("Đã tạo Merchant CHILLFY thành công!")
					}
				}
			}
		}
	}

	userRepo := user.NewRepository(database.DB)
	cloudinaryClient := cloudinary.NewClient(
		cfg.CloudinaryCloudName,
		cfg.CloudinaryAPIKey,
		cfg.CloudinaryAPISecret,
	)
	emailClient := email.NewClient(cfg)
	userService := user.NewService(userRepo, cloudinaryClient)

	authService := auth.NewService(
		authRepo,
		accountService,
		userService,
		cfg,
		firebaseClient,
		emailClient,
	)
	authHandler := auth.NewHandler(authService)

	accountHandler := account.NewHandler(accountService)
	userHandler := user.NewHandler(userService)

	// Khởi tạo notification module
	notificationRepo := notification.NewRepository(database.DB)
	notificationService := notification.NewService(notificationRepo, firebaseClient)
	notificationHandler := notification.NewHandler(notificationService)

	transactionRepo := transaction.NewRepository(database.DB)
	transactionService := transaction.NewService(transactionRepo, notificationService, cfg, emailClient)
	if err := transactionService.EnsureOperationsInfrastructure(); err != nil {
		log.Fatalf("Khởi tạo hạ tầng vận hành thất bại: %v", err)
	}
	transactionHandler := transaction.NewHandler(transactionService)

	adminRepo := admin.NewRepository(database.DB)
	adminService := admin.NewService(
		adminRepo,
		accountService,
		transactionService,
		notificationService,
	)
	adminHandler := admin.NewHandler(adminService)

	// Khởi tạo payment module
	paymentRepo := payment.NewRepository(database.DB)
	paymentService := payment.NewService(paymentRepo, firebaseClient, cfg, notificationService)
	paymentHandler := payment.NewHandler(paymentService)

	// Khởi tạo savings module
	savingsRepo := savings.NewRepository(database.DB)
	savingsService := savings.NewService(savingsRepo, notificationService, transactionService)
	if err := savingsService.EnsureSystemInfrastructure(); err != nil {
		log.Fatalf("Khởi tạo hạ tầng chi lãi tiết kiệm thất bại: %v", err)
	}
	savingsService.StartMaturityWorker(
		context.Background(),
		time.Duration(cfg.SavingsMaturityIntervalSeconds)*time.Second,
	)
	savingsHandler := savings.NewHandler(savingsService)

	// Khởi tạo location module
	locationRepo := location.NewRepository(database.DB)
	locationService := location.NewService(locationRepo)
	if err := locationService.SeedLocationsIfEmpty(); err != nil {
		log.Printf("Cảnh báo: Seed địa giới hành chính thất bại: %v", err)
	}
	locationHandler := location.NewHandler(locationService)

	api := r.Group("/api/v1")
	auth.RegisterRoutes(api, authHandler)
	account.RegisterRoutes(api, accountHandler, cfg)
	user.RegisterRoutes(api, userHandler, cfg)
	transaction.RegisterRoutes(api, transactionHandler, cfg)
	admin.RegisterRoutes(api, adminHandler, cfg)
	payment.RegisterRoutes(api, paymentHandler, cfg)
	notification.RegisterRoutes(api, notificationHandler, cfg)
	savings.RegisterRoutes(api, savingsHandler, cfg)
	location.RegisterRoutes(api, locationHandler)

	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "NF-Bank Server is running!",
			"mode":    cfg.ServerMode,
		})
	})

	port := fmt.Sprintf(":%s", cfg.ServerPort)
	fmt.Printf("Server đang chạy tại cổng %s\n", cfg.ServerPort)

	if err := r.Run(port); err != nil {
		log.Fatalf("Lỗi nghiêm trọng khi khởi chạy server: %v", err)
	}
}

func corsMiddleware(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		allowedOrigin := cfg.AppURL

		if cfg.ServerMode != "production" && origin != "" {
			allowedOrigin = origin
		}

		if origin != "" && origin == allowedOrigin {
			c.Header("Access-Control-Allow-Origin", allowedOrigin)
			c.Header("Vary", "Origin")
			c.Header("Access-Control-Allow-Credentials", "true")
			c.Header(
				"Access-Control-Allow-Headers",
				"Authorization, Content-Type, Idempotency-Key",
			)
			c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		}

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

package payment

import (
	"bank-service/internal/config"
	"bank-service/internal/middleware"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(
	r *gin.RouterGroup,
	handler *Handler,
	cfg *config.Config,
) {
	// 1. Nhóm API cho đối tác (Merchant) và trang Checkout public
	r.POST("/payments/create", handler.CreatePayment)
	r.GET("/payments/session/:token", handler.GetPaymentSession)
	r.GET("/payments/status", handler.GetPaymentStatus)
	r.POST("/payments/test-create", handler.TestCreatePayment)
	r.POST("/payments/verify-account", handler.VerifyAccount)
	r.POST("/payments/payout", handler.MerchantPayout)


	// 2. Nhóm API yêu cầu đăng nhập của User để xác nhận thanh toán
	confirmGroup := r.Group("/payments/confirm")
	confirmGroup.Use(middleware.AuthMiddleware(cfg))
	{
		confirmGroup.POST("", handler.ConfirmPayment)
	}
}

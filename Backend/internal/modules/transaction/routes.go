package transaction

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
	transactionGroup := r.Group("/transactions")

	transactionGroup.Use(middleware.AuthMiddleware(cfg))
	{
		transactionGroup.GET("", handler.GetMyTransactions)
		transactionGroup.GET("/resolve/:account_number", handler.ResolveAccount)
		transactionGroup.GET("/pin/status", handler.GetTransactionPINStatus)
		transactionGroup.POST("/pin/setup", handler.SetupTransactionPIN)
		transactionGroup.POST("/pin/verify", handler.VerifyTransactionPIN)
		transactionGroup.POST("/transfer", handler.Transfer)
		transactionGroup.POST("/withdraw", handler.Withdraw)
		transactionGroup.GET("/qr", handler.GetMyStaticQR)
		transactionGroup.POST("/qr", handler.GenerateDynamicQR)
		transactionGroup.GET("/:reference_code", handler.GetTransactionDetail)
	}
}

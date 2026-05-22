package admin

import (
	"net/http"

	"bank-service/internal/config"
	"bank-service/internal/middleware"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(
	r *gin.RouterGroup,
	handler *Handler,
	cfg *config.Config,
) {
	adminGroup := r.Group("/admin")

	adminGroup.Use(middleware.AuthMiddleware(cfg))
	adminGroup.Use(AdminOnlyMiddleware())

	{
		adminGroup.GET("/users", handler.GetAllUsers)
		adminGroup.GET("/users/:id", handler.GetUserByID)
		adminGroup.PATCH("/users/:id/lock", handler.LockUser)
		adminGroup.PATCH("/users/:id/unlock", handler.UnlockUser)
	}
}

func AdminOnlyMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("role")

		if role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{
				"success": false,
				"message": "Bạn không có quyền truy cập chức năng admin",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

package location

import "github.com/gin-gonic/gin"

func RegisterRoutes(r *gin.RouterGroup, handler *Handler) {
	locations := r.Group("/locations")
	{
		locations.GET("/provinces", handler.GetProvinces)
		locations.GET("/wards", handler.GetWards)
	}
}

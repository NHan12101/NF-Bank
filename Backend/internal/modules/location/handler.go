package location

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

// GetProvinces trả về danh sách các tỉnh/thành phố
func (h *Handler) GetProvinces(c *gin.Context) {
	provinces, err := h.service.GetProvinces()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"message": "Không thể lấy danh sách Tỉnh/Thành phố",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   provinces,
	})
}

// GetWards trả về danh sách xã/phường theo mã tỉnh/thành (province_code)
func (h *Handler) GetWards(c *gin.Context) {
	provinceCode := c.Query("province_code")
	if provinceCode == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"message": "Vui lòng cung cấp province_code",
		})
		return
	}

	wards, err := h.service.GetWardsByProvince(provinceCode)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"message": "Không thể lấy danh sách Phường/Xã",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   wards,
	})
}

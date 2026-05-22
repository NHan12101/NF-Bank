package admin

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{
		service: service,
	}
}

func (h *Handler) GetAllUsers(c *gin.Context) {
	users, err := h.service.GetAllUsers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Không thể lấy danh sách người dùng",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Lấy danh sách người dùng thành công",
		"data":    users,
	})
}

func (h *Handler) GetUserByID(c *gin.Context) {
	userIDParam := c.Param("id")

	userID64, err := strconv.ParseUint(userIDParam, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "ID người dùng không hợp lệ",
		})
		return
	}

	user, err := h.service.GetUserByID(uint(userID64))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Không tìm thấy người dùng",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Lấy thông tin người dùng thành công",
		"data":    user,
	})
}

func (h *Handler) LockUser(c *gin.Context) {
	userIDParam := c.Param("id")

	userID64, err := strconv.ParseUint(userIDParam, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "ID người dùng không hợp lệ",
		})
		return
	}

	if err := h.service.LockUser(uint(userID64)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Khóa tài khoản người dùng thành công",
	})
}

func (h *Handler) UnlockUser(c *gin.Context) {
	userIDParam := c.Param("id")

	userID64, err := strconv.ParseUint(userIDParam, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "ID người dùng không hợp lệ",
		})
		return
	}

	if err := h.service.UnlockUser(uint(userID64)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Mở khóa tài khoản người dùng thành công",
	})
}

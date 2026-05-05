package handlers

import (
	"context"
	"net/http"
	"time"

	"bank-service/internal/database"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
)

type UnlockUserRequest struct {
	Username string `json:"username" binding:"required"`
}

func UnlockUser(c *gin.Context) {
	var req UnlockUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Vui lòng cung cấp username cần mở khóa!"})
		return
	}

	collection := database.DB.Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	updateResult, err := collection.UpdateOne(
		ctx,
		bson.M{"username": req.Username},
		bson.M{"$set": bson.M{
			"is_locked":       false,
			"failed_attempts": 0,
		}},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Lỗi hệ thống khi mở khóa!"})
		return
	}

	if updateResult.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Không tìm thấy tài khoản này!"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Mở khóa tài khoản thành công!"})
}
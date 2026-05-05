package middleware

import (
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

var clients = make(map[string]*rate.Limiter)
var mu sync.Mutex

func RateLimiter() gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP() // Chặn theo địa chỉ IP của người gọi
		mu.Lock()
		
		if _, found := clients[ip]; !found {
			// Cho phép 5 yêu cầu mỗi phút, tối đa tích lũy (burst) 10 yêu cầu
			clients[ip] = rate.NewLimiter(rate.Limit(5.0/60.0), 10)
		}
		
		limiter := clients[ip]
		mu.Unlock()

		if !limiter.Allow() {
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "Bạn đang thao tác quá nhanh. Vui lòng thử lại sau 1 phút!"})
			c.Abort()
			return
		}
		c.Next()
	}
}
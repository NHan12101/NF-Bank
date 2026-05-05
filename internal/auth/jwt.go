package auth

import (
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// AccessClaims là thông tin giấu trong Access Token
type AccessClaims struct {
	UserID    string `json:"user_id"`
	SessionID string `json:"session_id"` // Thêm SessionID để xử lý đá văng máy cũ
	Role      string `json:"role"`
	jwt.RegisteredClaims
}

// RefreshClaims là thông tin giấu trong Refresh Token
type RefreshClaims struct {
	UserID    string `json:"user_id"`
	SessionID string `json:"session_id"` // Thêm SessionID
	jwt.RegisteredClaims
}

// GenerateTokens giờ đã nhận 3 tham số: userID, sessionID, role
func GenerateTokens(userID, sessionID, role string) (string, string, error) {
	secretKey := []byte(os.Getenv("JWT_SECRET"))

	// 1. TẠO ACCESS TOKEN (5 phút)
	accessClaims := AccessClaims{
		UserID:    userID,
		SessionID: sessionID,
		Role:      role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(5 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	accessTokenObj := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessToken, err := accessTokenObj.SignedString(secretKey)
	if err != nil {
		return "", "", err
	}

	// 2. TẠO REFRESH TOKEN (7 ngày)
	refreshClaims := RefreshClaims{
		UserID:    userID,
		SessionID: sessionID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	refreshTokenObj := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshToken, err := refreshTokenObj.SignedString(secretKey)
	if err != nil {
		return "", "", err
	}

	return accessToken, refreshToken, nil
}
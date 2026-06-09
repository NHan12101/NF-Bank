package auth

import (
	"bank-service/internal/shared/response"
	"net/http"

	"github.com/gin-gonic/gin"
)

// Handler chịu trách nhiệm xử lý HTTP request
type Handler struct {
	service *Service
}

// NewHandler tạo auth handler
func NewHandler(service *Service) *Handler {
	return &Handler{
		service: service,
	}
}

// Register xử lý API đăng ký
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest

	// Bind JSON request vào struct
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	if err := h.service.Register(req); err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusCreated, "OTP xác thực đăng ký đã được gửi đến email", nil)
}

// Login xử lý API đăng nhập
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	if err := h.service.Login(req); err != nil {
		response.Error(c, http.StatusUnauthorized, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "OTP đăng nhập đã được gửi đến email", nil)
}

// setRefreshTokenCookie thiết lập refresh token trong cookie
func setRefreshTokenCookie(c *gin.Context, refreshToken string) {
	c.SetCookie(
		"refresh_token",
		refreshToken,
		7*24*60*60, // 7 ngày
		"/api/v1/auth",
		"",
		false, // local dev dùng false, production HTTPS đổi thành true
		true,  // HttpOnly
	)
}

// Logout xử lý API logout
func (h *Handler) Logout(c *gin.Context) {

	refreshToken, err := c.Cookie("refresh_token")
	if err != nil {
		response.Error(c, http.StatusUnauthorized, "Không tìm thấy refresh token", nil)
		return
	}

	err = h.service.Logout(refreshToken)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Đăng xuất thất bại", err)
		return
	}

	// Xóa refresh token cookie
	c.SetCookie(
		"refresh_token",
		"",
		-1,
		"/api/v1/auth",
		"",
		false,
		true,
	)

	response.Success(c, http.StatusOK, "Đăng xuất thành công", nil)
}

// Refresh xử lý cấp access token mới từ refresh token cookie
func (h *Handler) Refresh(c *gin.Context) {
	refreshToken, err := c.Cookie("refresh_token")
	if err != nil {
		response.Error(c, http.StatusUnauthorized, "Không tìm thấy refresh token", nil)
		return
	}

	res, err := h.service.RefreshAccessToken(refreshToken)
	if err != nil {
		response.Error(c, http.StatusUnauthorized, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Refresh token thành công", res)
}

// ChangePassword xử lý đổi mật khẩu
func (h *Handler) ChangePassword(c *gin.Context) {
	var req ChangePasswordRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	if err := h.service.ChangePassword(userID, req); err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Đổi mật khẩu thành công", nil)
}

// ForgotPassword xử lý yêu cầu quên mật khẩu
func (h *Handler) ForgotPassword(c *gin.Context) {
	var req ForgotPasswordRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	if err := h.service.ForgotPassword(req); err != nil {
		response.Error(c, http.StatusInternalServerError, "Không thể gửi OTP", err)
		return
	}

	response.Success(c, http.StatusOK, "Nếu email tồn tại, OTP đã được gửi", nil)
}

// ResetPassword xử lý yêu cầu reset mật khẩu
func (h *Handler) ResetPassword(c *gin.Context) {
	var req ResetPasswordRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	if err := h.service.ResetPassword(req); err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Đặt lại mật khẩu thành công", nil)
}

// ConfirmRegister xác thực OTP đăng ký
func (h *Handler) ConfirmRegister(c *gin.Context) {
	var req ConfirmRegisterRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	if err := h.service.ConfirmRegister(req); err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Xác thực đăng ký thành công, vui lòng đăng nhập", nil)
}

// ConfirmLogin xác thực OTP đăng nhập
func (h *Handler) ConfirmLogin(c *gin.Context) {
	var req ConfirmLoginRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	res, err := h.service.ConfirmLogin(req)
	if err != nil {
		response.Error(c, http.StatusUnauthorized, err.Error(), nil)
		return
	}

	setRefreshTokenCookie(c, res.RefreshToken)

	response.Success(c, http.StatusOK, "Đăng nhập thành công", res)
}


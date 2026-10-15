package transaction

import (
	"bank-service/internal/shared/response"
	"net/http"

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

func (h *Handler) Transfer(c *gin.Context) {
	var req TransferRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}
	req.IdempotencyKey = c.GetHeader("Idempotency-Key")

	transaction, err := h.service.Transfer(userID, req)
	if err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Chuyển tiền thành công", transaction)
}

func (h *Handler) ResolveAccount(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	result, err := h.service.ResolveAccount(userID, c.Param("account_number"))
	if err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}
	response.Success(c, http.StatusOK, "Xác minh tài khoản thành công", result)
}

func (h *Handler) GetTransactionPINStatus(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	result, err := h.service.GetTransactionPINStatus(userID)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Không thể kiểm tra mã PIN giao dịch", err)
		return
	}
	response.Success(c, http.StatusOK, "Lấy trạng thái PIN giao dịch thành công", result)
}

func (h *Handler) SetupTransactionPIN(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	var req SetupTransactionPINRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "PIN phải gồm từ 4 đến 6 chữ số", nil)
		return
	}
	if err := h.service.SetupTransactionPIN(userID, req); err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}
	response.Success(c, http.StatusCreated, "Tạo mã PIN giao dịch thành công", nil)
}

func (h *Handler) VerifyTransactionPIN(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	var req struct {
		PIN         string `json:"pin"`
		IsNewDevice bool   `json:"is_new_device"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Mã PIN không hợp lệ", nil)
		return
	}

	if err := h.service.VerifyTransactionPIN(userID, req.PIN, req.IsNewDevice); err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}
	response.Success(c, http.StatusOK, "Xác minh mã PIN Smart OTP thành công", nil)
}

func (h *Handler) GetMyTransactions(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	transactions, err := h.service.GetMyTransactions(userID)
	if err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Lấy lịch sử giao dịch thành công", transactions)
}

func (h *Handler) GetTransactionDetail(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	referenceCode := c.Param("reference_code")

	transaction, err := h.service.GetTransactionDetail(
		userID,
		referenceCode,
	)
	if err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Lấy chi tiết giao dịch thành công", transaction)
}

func (h *Handler) GetMyStaticQR(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	result, err := h.service.GetMyStaticQR(userID)
	if err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Lấy mã QR tài khoản thành công", result)
}

func (h *Handler) GenerateDynamicQR(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	var req GenerateQRRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}

	result, err := h.service.GenerateDynamicQR(userID, req)
	if err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Tạo mã QR động thành công", result)
}

// Withdraw xử lý yêu cầu rút tiền về tài khoản ngân hàng ngoài.
// Yêu cầu Idempotency-Key header để chống duplicate request.
func (h *Handler) Withdraw(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		response.Error(c, http.StatusUnauthorized, "Không xác định được người dùng", nil)
		return
	}

	var req WithdrawRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Dữ liệu không hợp lệ", err)
		return
	}
	req.IdempotencyKey = c.GetHeader("Idempotency-Key")

	result, err := h.service.Withdraw(userID, req)
	if err != nil {
		response.Error(c, http.StatusBadRequest, err.Error(), nil)
		return
	}

	response.Success(c, http.StatusOK, "Yêu cầu rút tiền đã được ghi nhận thành công", result)
}


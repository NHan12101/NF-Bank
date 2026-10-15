package transaction

import "time"

type TransferRequest struct {
	ReceiverAccountNumber string `json:"receiver_account_number" binding:"required"`
	Amount                int64  `json:"amount" binding:"required,gt=0"`
	Description           string `json:"description"`
	TransactionPIN        string `json:"transaction_pin" binding:"required"`
	IdempotencyKey        string `json:"-"`
}

type TransactionResponse struct {
	ID                        uint      `json:"id"`
	ReferenceCode             string    `json:"reference_code"`
	SenderAccountID           *uint     `json:"sender_account_id,omitempty"`
	ReceiverAccountID         uint      `json:"receiver_account_id"`
	Amount                    int64     `json:"amount"`
	Currency                  string    `json:"currency"`
	Type                      string    `json:"type"`
	Status                    string    `json:"status"`
	Description               string    `json:"description"`
	Direction                 string    `json:"direction,omitempty"`
	CounterpartyName          string    `json:"counterparty_name,omitempty"`
	CounterpartyAccountNumber string    `json:"counterparty_account_number,omitempty"`
	BalanceAfter              *int64    `json:"balance_after,omitempty"`
	CreatedAt                 time.Time `json:"created_at"`
}

type AccountResolutionResponse struct {
	AccountNumber string `json:"account_number"`
	AccountName   string `json:"account_name"`
	AvatarURL     string `json:"avatar_url"`
	BankName      string `json:"bank_name"`
	Currency      string `json:"currency"`
}

type DepositRequest struct {
	ReceiverAccountNumber string `json:"receiver_account_number" binding:"required"`
	Amount                int64  `json:"amount" binding:"required,gt=0"`
	Description           string `json:"description"`
	IdempotencyKey        string `json:"-"`
}

type TransactionPINStatusResponse struct {
	HasPIN bool `json:"has_pin"`
}

type SetupTransactionPINRequest struct {
	PIN        string `json:"pin" binding:"required"`
	ConfirmPIN string `json:"confirm_pin" binding:"required"`
}

// WithdrawRequest là yêu cầu rút tiền về tài khoản ngân hàng ngoài.
// Để bảo mật, không dùng mật khẩu đăng nhập - chỉ dùng PIN giao dịch và thông tin định danh.
type WithdrawRequest struct {
	BankAccountNumber string `json:"bank_account_number" binding:"required"`
	AccountHolderName string `json:"account_holder_name" binding:"required"`
	BankName          string `json:"bank_name" binding:"required"`
	Amount            int64  `json:"amount" binding:"required,gt=0"`
	TransactionPIN    string `json:"transaction_pin" binding:"required"`
	IdentityCardLast4 string `json:"identity_card_last4" binding:"required"`
	Description       string `json:"description"`
	IdempotencyKey    string `json:"-"`
}


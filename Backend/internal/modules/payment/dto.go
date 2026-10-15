package payment

type CreatePaymentRequest struct {
	PartnerCode string `json:"partnerCode" binding:"required"`
	AccessKey   string `json:"accessKey" binding:"required"`
	RequestID   string `json:"requestId" binding:"required"`
	Amount      int64  `json:"amount" binding:"required,gt=0"`
	OrderID     string `json:"orderId" binding:"required"`
	OrderInfo   string `json:"orderInfo" binding:"required"`
	RedirectURL string `json:"redirectUrl" binding:"required,url"`
	IpnURL      string `json:"ipnUrl" binding:"required,url"`
	ExtraData   string `json:"extraData"`
	Signature   string `json:"signature" binding:"required"`
}

type CreatePaymentResponse struct {
	PartnerCode string `json:"partnerCode"`
	OrderID     string `json:"orderId"`
	RequestID   string `json:"requestId"`
	Amount      int64  `json:"amount"`
	PayURL      string `json:"payUrl,omitempty"`
	ResultCode  int    `json:"resultCode"`
	Message     string `json:"message"`
	Signature   string `json:"signature"`
}

type ConfirmPaymentRequest struct {
	PaymentToken     string `json:"payment_token" binding:"required"`
	PaymentAccountID uint   `json:"payment_account_id" binding:"required"`
	IDToken          string `json:"id_token"`
	OTP              string `json:"otp"`
}

type PaymentSessionResponse struct {
	PaymentToken string `json:"payment_token"`
	Amount       int64  `json:"amount"`
	OrderID      string `json:"order_id"`
	OrderInfo    string `json:"order_info"`
	MerchantName string `json:"merchant_name"`
	RedirectURL  string `json:"redirect_url"`
	Status       string `json:"status"`
}

type IpnPayload struct {
	PartnerCode  string `json:"partnerCode"`
	OrderID      string `json:"orderId"`
	RequestID    string `json:"requestId"`
	Amount       int64  `json:"amount"`
	OrderInfo    string `json:"orderInfo"`
	OrderType    string `json:"orderType"` // nfbank_gateway
	TransID      uint   `json:"transId"`
	ResultCode   int    `json:"resultCode"`
	Message      string `json:"message"`
	PayType      string `json:"payType"` // payment
	ResponseTime int64  `json:"responseTime"`
	ExtraData    string `json:"extraData"`
	Signature    string `json:"signature"`
}

type VerifyAccountRequest struct {
	PartnerCode   string `json:"partnerCode" binding:"required"`
	AccessKey     string `json:"accessKey" binding:"required"`
	RequestID     string `json:"requestId" binding:"required"`
	AccountNumber string `json:"accountNumber" binding:"required"`
	Signature     string `json:"signature" binding:"required"`
}

type VerifyAccountResponse struct {
	PartnerCode   string `json:"partnerCode"`
	RequestID     string `json:"requestId"`
	AccountNumber string `json:"accountNumber"`
	AccountName   string `json:"accountName"`
	AccountStatus string `json:"accountStatus"`
	ResultCode    int    `json:"resultCode"`
	Message       string `json:"message"`
	Signature     string `json:"signature"`
}

type MerchantPayoutRequest struct {
	PartnerCode   string `json:"partnerCode" binding:"required"`
	AccessKey     string `json:"accessKey" binding:"required"`
	RequestID     string `json:"requestId" binding:"required"`
	OrderID       string `json:"orderId" binding:"required"`
	Amount        int64  `json:"amount" binding:"required,gt=0"`
	AccountNumber string `json:"accountNumber" binding:"required"`
	OrderInfo     string `json:"orderInfo" binding:"required"`
	ExtraData     string `json:"extraData"`
	Signature     string `json:"signature" binding:"required"`
}

type MerchantPayoutResponse struct {
	PartnerCode string `json:"partnerCode"`
	OrderID     string `json:"orderId"`
	RequestID   string `json:"requestId"`
	Amount      int64  `json:"amount"`
	TransID     string `json:"transId,omitempty"`
	ResultCode  int    `json:"resultCode"`
	Message     string `json:"message"`
	Signature   string `json:"signature"`
}


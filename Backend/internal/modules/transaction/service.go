package transaction

import (
	"bank-service/internal/config"
	"bank-service/internal/infrastructure/email"
	"bank-service/internal/modules/account"
	"bank-service/internal/modules/notification"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"gorm.io/gorm"
)

type Service struct {
	repo        *Repository
	notiService *notification.Service
	cfg         *config.Config
	emailClient *email.Client
}

func NewService(
	repo *Repository,
	notiService *notification.Service,
	cfg *config.Config,
	emailClient *email.Client,
) *Service {
	return &Service{
		repo:        repo,
		notiService: notiService,
		cfg:         cfg,
		emailClient: emailClient,
	}
}

func (s *Service) Transfer(
	userID uint,
	req TransferRequest,
) (*TransactionResponse, error) {
	req.ReceiverAccountNumber = strings.TrimSpace(req.ReceiverAccountNumber)
	req.Description = strings.TrimSpace(req.Description)
	req.IdempotencyKey = strings.TrimSpace(req.IdempotencyKey)

	if req.Description == "" {
		senderName, err := s.repo.GetUserFullName(userID)
		if err != nil {
			return nil, errors.New("Không thể lấy tên người chuyển khoản")
		}
		req.Description = defaultTransferDescription(senderName)
	}
	if !regexp.MustCompile(`^[A-Za-z0-9._:-]{16,64}$`).MatchString(req.IdempotencyKey) {
		return nil, errors.New("Thiếu hoặc sai định dạng Idempotency-Key")
	}
	if len([]rune(req.Description)) > 140 {
		return nil, errors.New("Nội dung chuyển tiền tối đa 140 ký tự")
	}
	if req.Amount < s.cfg.TransferMinAmount {
		return nil, fmt.Errorf("Số tiền chuyển tối thiểu là %d VND", s.cfg.TransferMinAmount)
	}
	if req.Amount > s.cfg.TransferMaxAmount {
		return nil, fmt.Errorf("Số tiền vượt hạn mức mỗi giao dịch %d VND", s.cfg.TransferMaxAmount)
	}

	existing, err := s.repo.FindTransactionByIdempotencyKey(userID, req.IdempotencyKey)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return mapTransactionResponse(existing), nil
	}

	if err := s.VerifyTransactionPIN(userID, req.TransactionPIN, false); err != nil {
		return nil, err
	}

	var transactionResult *Transaction
	var senderUserID, receiverUserID uint
	var senderPushMessage, receiverPushMessage string

	err = s.repo.WithTx(func(tx *gorm.DB) error {
		// 1. Tìm sender account (chưa lock) để lấy ID
		senderAccount, err := s.repo.FindPaymentAccountByUserID(userID)
		if err != nil {
			return err
		}
		if senderAccount == nil {
			return errors.New("Không tìm thấy tài khoản gửi")
		}

		// 2. Tìm receiver account (chưa lock) để lấy ID
		receiverAccount, err := s.repo.FindAccountByNumber(req.ReceiverAccountNumber)
		if err != nil {
			return err
		}
		if receiverAccount == nil {
			return errors.New("Không tìm thấy tài khoản nhận")
		}

		if senderAccount.ID == receiverAccount.ID {
			return errors.New("Không thể chuyển tiền cho chính tài khoản của mình")
		}

		// 3. Thực hiện khóa theo thứ tự ID tăng dần để tránh Deadlock
		var lockedSender, lockedReceiver *account.Account
		if senderAccount.ID < receiverAccount.ID {
			// Khóa sender trước, receiver sau
			lockedSender, err = s.repo.FindAccountByIDForUpdate(tx, senderAccount.ID)
			if err != nil {
				return err
			}
			lockedReceiver, err = s.repo.FindAccountByIDForUpdate(tx, receiverAccount.ID)
			if err != nil {
				return err
			}
		} else {
			// Khóa receiver trước, sender sau
			lockedReceiver, err = s.repo.FindAccountByIDForUpdate(tx, receiverAccount.ID)
			if err != nil {
				return err
			}
			lockedSender, err = s.repo.FindAccountByIDForUpdate(tx, senderAccount.ID)
			if err != nil {
				return err
			}
		}

		if lockedSender == nil {
			return errors.New("Không tìm thấy tài khoản gửi")
		}
		if lockedReceiver == nil {
			return errors.New("Không tìm thấy tài khoản nhận")
		}

		if lockedSender.Status != "ACTIVE" {
			return errors.New("Tài khoản gửi không hoạt động")
		}

		if lockedReceiver.Status != "ACTIVE" {
			return errors.New("Tài khoản nhận không hoạt động")
		}

		var dailyLimit int64
		err = tx.Table("user_profiles").
			Select("daily_transfer_limit").
			Where("user_id = ?", userID).
			Scan(&dailyLimit).Error
		if err != nil {
			return err
		}
		if dailyLimit == 0 {
			dailyLimit = 50000000
		}

		now := time.Now()
		todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
		todayEnd := todayStart.Add(24 * time.Hour)

		sum, err := s.repo.SumSuccessfulOutgoingTransfers(tx, lockedSender.ID, todayStart, todayEnd)
		if err != nil {
			return err
		}

		if sum+req.Amount > dailyLimit {
			return fmt.Errorf("Giao dịch vượt quá hạn mức chuyển khoản trong ngày (Hạn mức: %d VND, Đã chuyển hôm nay: %d VND)", dailyLimit, sum)
		}

		if lockedSender.Currency != lockedReceiver.Currency {
			return errors.New("Không thể chuyển tiền khác loại tiền tệ")
		}

		if lockedSender.Balance < req.Amount {
			return errors.New("Số dư không đủ")
		}

		senderNewBalance := lockedSender.Balance - req.Amount
		receiverNewBalance := lockedReceiver.Balance + req.Amount

		if err := s.repo.UpdateAccountBalance(
			tx,
			lockedSender.ID,
			senderNewBalance,
		); err != nil {
			return err
		}

		if err := s.repo.UpdateAccountBalance(
			tx,
			lockedReceiver.ID,
			receiverNewBalance,
		); err != nil {
			return err
		}

		senderID := lockedSender.ID
		initiatorUserID := userID
		idempotencyKey := req.IdempotencyKey
		newTransaction := &Transaction{
			ReferenceCode:     generateReferenceCode(),
			InitiatorUserID:   &initiatorUserID,
			IdempotencyKey:    &idempotencyKey,
			SenderAccountID:   &senderID,
			ReceiverAccountID: lockedReceiver.ID,
			Amount:            req.Amount,
			Currency:          lockedSender.Currency,
			Type:              "TRANSFER",
			Status:            "SUCCESS",
			Description:       req.Description,
		}

		if err := s.repo.CreateTransaction(tx, newTransaction); err != nil {
			return err
		}
		if err := CreateDoubleEntry(
			tx,
			newTransaction.ID,
			lockedSender.ID,
			lockedReceiver.ID,
			req.Amount,
			lockedSender.Currency,
			senderNewBalance,
			receiverNewBalance,
		); err != nil {
			return err
		}

		// Tạo thông báo biến động số dư cho người gửi
		senderMsg := fmt.Sprintf("Tài khoản của bạn đã bị trừ -%d VND chuyển khoản đến số tài khoản %s. Số dư mới: %d VND. Nội dung: %s", req.Amount, lockedReceiver.AccountNumber, senderNewBalance, req.Description)
		if err := s.notiService.CreateNotification(tx, lockedSender.UserID, "BALANCE_FLUCTUATION", "Biến động số dư (-)", senderMsg); err != nil {
			return err
		}

		// Tạo thông báo biến động số dư cho người nhận
		receiverMsg := fmt.Sprintf("Tài khoản của bạn đã được cộng +%d VND từ số tài khoản %s. Số dư mới: %d VND. Nội dung: %s", req.Amount, lockedSender.AccountNumber, receiverNewBalance, req.Description)
		if err := s.notiService.CreateNotification(tx, lockedReceiver.UserID, "BALANCE_FLUCTUATION", "Biến động số dư (+)", receiverMsg); err != nil {
			return err
		}

		transactionResult = newTransaction
		senderUserID = lockedSender.UserID
		receiverUserID = lockedReceiver.UserID
		senderPushMessage = senderMsg
		receiverPushMessage = receiverMsg

		return nil
	})

	if err != nil {
		existing, findErr := s.repo.FindTransactionByIdempotencyKey(userID, req.IdempotencyKey)
		if findErr == nil && existing != nil {
			return mapTransactionResponse(existing), nil
		}
		return nil, err
	}

	pushData := map[string]string{
		"type":           "BALANCE_FLUCTUATION",
		"reference_code": transactionResult.ReferenceCode,
	}
	_ = s.notiService.SendPushToUser(
		senderUserID,
		"Biến động số dư (-)",
		senderPushMessage,
		pushData,
	)
	_ = s.notiService.SendPushToUser(
		receiverUserID,
		"Biến động số dư (+)",
		receiverPushMessage,
		pushData,
	)

	// Gửi Email Biên lai giao dịch chuyển tiền (chuẩn Vietcombank) cho cả người gửi và người nhận
	if s.emailClient != nil {
		go func(txRes *Transaction, sID, rID uint) {
			senderEmail, _ := s.repo.GetUserEmail(sID)
			senderName, _ := s.repo.GetUserFullName(sID)
			senderAcc, _ := s.repo.GetAccountByID(*txRes.SenderAccountID)

			receiverEmail, _ := s.repo.GetUserEmail(rID)
			receiverName, _ := s.repo.GetUserFullName(rID)
			receiverAcc, _ := s.repo.GetAccountByID(txRes.ReceiverAccountID)

			senderAccNo := ""
			if senderAcc != nil {
				senderAccNo = senderAcc.AccountNumber
			}
			receiverAccNo := ""
			if receiverAcc != nil {
				receiverAccNo = receiverAcc.AccountNumber
			}

			receiptData := email.ReceiptData{
				TransactionCode: txRes.ReferenceCode,
				SenderName:      senderName,
				SenderAccount:   senderAccNo,
				ReceiverName:    receiverName,
				ReceiverAccount: receiverAccNo,
				ReceiverBank:    "NFBank",
				Amount:          txRes.Amount,
				Description:     txRes.Description,
				Fee:             0,
				TransactionTime: txRes.CreatedAt,
			}

			if strings.TrimSpace(senderEmail) != "" {
				_ = s.emailClient.SendReceiptEmail(senderEmail, receiptData)
			}
			if strings.TrimSpace(receiverEmail) != "" {
				_ = s.emailClient.SendReceiptEmail(receiverEmail, receiptData)
			}
		}(transactionResult, senderUserID, receiverUserID)
	}

	return mapTransactionResponse(transactionResult), nil
}

func mapTransactionResponse(transactionResult *Transaction) *TransactionResponse {
	return &TransactionResponse{
		ID:                transactionResult.ID,
		ReferenceCode:     transactionResult.ReferenceCode,
		SenderAccountID:   transactionResult.SenderAccountID,
		ReceiverAccountID: transactionResult.ReceiverAccountID,
		Amount:            transactionResult.Amount,
		Currency:          transactionResult.Currency,
		Type:              transactionResult.Type,
		Status:            transactionResult.Status,
		Description:       transactionResult.Description,
		CreatedAt:         transactionResult.CreatedAt,
	}
}

func (s *Service) ResolveAccount(
	userID uint,
	accountNumber string,
) (*AccountResolutionResponse, error) {
	accountNumber = strings.TrimSpace(accountNumber)
	if !regexp.MustCompile(`^[0-9]{12}$`).MatchString(accountNumber) {
		return nil, errors.New("Số tài khoản phải gồm 12 chữ số")
	}

	ownAccount, err := s.repo.FindPaymentAccountByUserID(userID)
	if err != nil {
		return nil, err
	}
	if ownAccount != nil && ownAccount.AccountNumber == accountNumber {
		return nil, errors.New("Không thể chuyển tiền cho chính tài khoản của mình")
	}

	result, err := s.repo.ResolveActivePaymentAccount(accountNumber)
	if err != nil {
		return nil, err
	}
	if result == nil {
		return nil, errors.New("Không tìm thấy tài khoản nhận đang hoạt động")
	}
	return result, nil
}

func generateReferenceCode() string {
	return fmt.Sprintf("TRX%d", time.Now().UnixNano())
}

func (s *Service) GetMyTransactions(
	userID uint,
) ([]TransactionResponse, error) {

	paymentAccount, err := s.repo.FindPaymentAccountByUserID(userID)
	if err != nil {
		return nil, err
	}

	if paymentAccount == nil {
		return nil, errors.New("Không tìm thấy tài khoản PAYMENT")
	}

	transactions, err := s.repo.FindTransactionViewsByAccountID(paymentAccount.ID)
	if err != nil {
		return nil, err
	}

	response := make([]TransactionResponse, 0)

	for _, transaction := range transactions {
		response = append(response, mapTransactionView(transaction))
	}

	return response, nil
}

func (s *Service) GetTransactionDetail(
	userID uint,
	referenceCode string,
) (*TransactionResponse, error) {

	paymentAccount, err := s.repo.FindPaymentAccountByUserID(userID)
	if err != nil {
		return nil, err
	}

	if paymentAccount == nil {
		return nil, errors.New("Không tìm thấy tài khoản PAYMENT")
	}

	transaction, err := s.repo.FindTransactionViewByReferenceCode(paymentAccount.ID, referenceCode)
	if err != nil {
		return nil, err
	}

	if transaction == nil {
		return nil, errors.New("Không tìm thấy giao dịch")
	}

	result := mapTransactionView(*transaction)
	return &result, nil
}

func (s *Service) Deposit(adminUserID uint, req DepositRequest) (*TransactionResponse, error) {
	req.ReceiverAccountNumber = strings.TrimSpace(req.ReceiverAccountNumber)
	req.Description = strings.TrimSpace(req.Description)
	req.IdempotencyKey = strings.TrimSpace(req.IdempotencyKey)
	if !regexp.MustCompile(`^[A-Za-z0-9._:-]{16,64}$`).MatchString(req.IdempotencyKey) {
		return nil, errors.New("Thiếu hoặc sai định dạng Idempotency-Key")
	}
	if !regexp.MustCompile(`^[0-9]{12}$`).MatchString(req.ReceiverAccountNumber) {
		return nil, errors.New("Số tài khoản nhận phải gồm 12 chữ số")
	}
	if req.Amount < s.cfg.TransferMinAmount {
		return nil, fmt.Errorf(
			"Số tiền nạp tối thiểu là %d VND",
			s.cfg.TransferMinAmount,
		)
	}
	if req.Amount > s.cfg.AdminDepositMaxAmount {
		return nil, fmt.Errorf(
			"Số tiền nạp vượt hạn mức mỗi giao dịch %d VND",
			s.cfg.AdminDepositMaxAmount,
		)
	}
	if len([]rune(req.Description)) > 140 {
		return nil, errors.New("Nội dung nạp tiền tối đa 140 ký tự")
	}
	existing, err := s.repo.FindTransactionByIdempotencyKey(
		adminUserID,
		req.IdempotencyKey,
	)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return mapTransactionResponse(existing), nil
	}

	// Admin chỉ là người khởi tạo/phê duyệt nghiệp vụ. Nguồn hạch toán luôn
	// là tài khoản đối ứng hệ thống, tuyệt đối không dùng tài khoản cá nhân
	// của Admin dù dữ liệu cũ có tồn tại tài khoản PAYMENT.
	fundingAccount, err := s.repo.FindAccountByNumber(
		systemOperationsAccountNumber,
	)
	if err != nil {
		return nil, err
	}
	if fundingAccount == nil ||
		fundingAccount.AccountType != "SYSTEM_FUNDING" {
		return nil, errors.New("Nguồn cấp tiền hệ thống chưa sẵn sàng")
	}

	receiverAccount, err := s.repo.FindAccountByNumber(req.ReceiverAccountNumber)
	if err != nil {
		return nil, err
	}
	if receiverAccount == nil {
		return nil, errors.New("Không tìm thấy số tài khoản người nhận")
	}
	if receiverAccount.AccountType != "PAYMENT" {
		return nil, errors.New("Chỉ có thể nạp vào tài khoản thanh toán")
	}
	receiverRole, err := s.repo.GetUserRole(receiverAccount.UserID)
	if err != nil {
		return nil, err
	}
	if receiverRole != "user" {
		return nil, errors.New("Chỉ có thể nạp tiền cho tài khoản khách hàng")
	}

	var adminUser struct {
		FullName string
	}
	err = s.repo.db.Table("users").Where("id = ?", adminUserID).First(&adminUser).Error
	if err != nil {
		return nil, errors.New("Không thể tìm thấy thông tin định danh của admin thực hiện")
	}

	var transactionResult *Transaction
	var receiverPushMessage string

	err = s.repo.WithTx(func(tx *gorm.DB) error {
		// Khóa 2 tài khoản theo thứ tự ID để chống deadlock
		var lockedAdmin, lockedReceiver *account.Account
		if fundingAccount.ID < receiverAccount.ID {
			lockedAdmin, err = s.repo.FindAccountByIDForUpdate(tx, fundingAccount.ID)
			if err != nil {
				return err
			}
			lockedReceiver, err = s.repo.FindAccountByIDForUpdate(tx, receiverAccount.ID)
			if err != nil {
				return err
			}
		} else {
			lockedReceiver, err = s.repo.FindAccountByIDForUpdate(tx, receiverAccount.ID)
			if err != nil {
				return err
			}
			lockedAdmin, err = s.repo.FindAccountByIDForUpdate(tx, fundingAccount.ID)
			if err != nil {
				return err
			}
		}

		if lockedAdmin == nil || lockedReceiver == nil {
			return errors.New("Không tìm thấy thông tin tài khoản")
		}
		if lockedAdmin.Status != "ACTIVE" {
			return errors.New("Tài khoản nguồn hoặc nguồn cấp tiền hệ thống không hoạt động")
		}

		if lockedReceiver.Status != "ACTIVE" {
			return errors.New("Tài khoản người nhận đang bị khóa hoặc không hoạt động")
		}

		if lockedAdmin.Currency != lockedReceiver.Currency {
			return errors.New("Không thể chuyển tiền khác loại tiền tệ")
		}

		// Tài khoản funding là tài khoản đối ứng hệ thống, không phải ví cá nhân
		// của Admin. Số dư âm thể hiện nghĩa vụ cấp vốn của ngân hàng.
		adminNewBalance := lockedAdmin.Balance - req.Amount
		receiverNewBalance := lockedReceiver.Balance + req.Amount

		if err := s.repo.UpdateAccountBalance(tx, lockedAdmin.ID, adminNewBalance); err != nil {
			return err
		}

		if err := s.repo.UpdateAccountBalance(tx, lockedReceiver.ID, receiverNewBalance); err != nil {
			return err
		}

		// Định dạng Description chứa thông tin đối soát
		formattedDesc := fmt.Sprintf("Nạp tiền từ Admin: %s (STK: %s)", adminUser.FullName, lockedAdmin.AccountNumber)
		if req.Description != "" {
			formattedDesc = fmt.Sprintf("%s - %s", formattedDesc, req.Description)
		}

		newTransaction := &Transaction{
			ReferenceCode:     generateReferenceCode(),
			InitiatorUserID:   &adminUserID,
			IdempotencyKey:    &req.IdempotencyKey,
			SenderAccountID:   &lockedAdmin.ID,
			ReceiverAccountID: lockedReceiver.ID,
			Amount:            req.Amount,
			Currency:          lockedReceiver.Currency,
			Type:              "DEPOSIT",
			Status:            "SUCCESS",
			Description:       formattedDesc,
		}

		if err := s.repo.CreateTransaction(tx, newTransaction); err != nil {
			return err
		}
		if err := CreateDoubleEntry(
			tx,
			newTransaction.ID,
			lockedAdmin.ID,
			lockedReceiver.ID,
			req.Amount,
			lockedReceiver.Currency,
			adminNewBalance,
			receiverNewBalance,
		); err != nil {
			return err
		}

		// Tạo thông báo biến động số dư cho người nhận (nạp tiền)
		receiverMsg := fmt.Sprintf("Tài khoản của bạn đã được cộng +%d VND từ giao dịch nạp tiền Admin. Số dư mới: %d VND. Nội dung: %s", req.Amount, receiverNewBalance, formattedDesc)
		if err := s.notiService.CreateNotification(tx, lockedReceiver.UserID, "BALANCE_FLUCTUATION", "Biến động số dư (+)", receiverMsg); err != nil {
			return err
		}

		transactionResult = newTransaction
		receiverPushMessage = receiverMsg
		return nil
	})

	if err != nil {
		existing, findErr := s.repo.FindTransactionByIdempotencyKey(
			adminUserID,
			req.IdempotencyKey,
		)
		if findErr == nil && existing != nil {
			return mapTransactionResponse(existing), nil
		}
		return nil, err
	}

	_ = s.notiService.SendPushToUser(
		receiverAccount.UserID,
		"Biến động số dư (+)",
		receiverPushMessage,
		map[string]string{
			"type":           "BALANCE_FLUCTUATION",
			"reference_code": transactionResult.ReferenceCode,
			"transaction":    "DEPOSIT",
		},
	)
	return mapTransactionResponse(transactionResult), nil
}

func (s *Service) GetTransactionsByAccountID(accountID uint) ([]TransactionResponse, error) {
	transactions, err := s.repo.FindTransactionViewsByAccountID(accountID)
	if err != nil {
		return nil, err
	}

	response := make([]TransactionResponse, 0)
	for _, transaction := range transactions {
		response = append(response, mapTransactionView(transaction))
	}

	return response, nil
}

func mapTransactionView(transaction transactionView) TransactionResponse {
	return TransactionResponse{
		ID:                        transaction.ID,
		ReferenceCode:             transaction.ReferenceCode,
		SenderAccountID:           transaction.SenderAccountID,
		ReceiverAccountID:         transaction.ReceiverAccountID,
		Amount:                    transaction.Amount,
		Currency:                  transaction.Currency,
		Type:                      transaction.Type,
		Status:                    transaction.Status,
		Description:               transaction.Description,
		Direction:                 transaction.Direction,
		CounterpartyName:          transaction.CounterpartyName,
		CounterpartyAccountNumber: transaction.CounterpartyAccountNumber,
		BalanceAfter:              transaction.BalanceAfter,
		CreatedAt:                 transaction.CreatedAt,
	}
}

func (s *Service) GetMyStaticQR(userID uint) (*QRResponse, error) {
	acc, err := s.repo.FindPaymentAccountByUserID(userID)
	if err != nil {
		return nil, err
	}
	if acc == nil {
		return nil, errors.New("không tìm thấy tài khoản thanh toán")
	}

	qrData := GenerateVietQR("970499", acc.AccountNumber, 0, "")
	qrURL := fmt.Sprintf("https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=%s", qrData)

	return &QRResponse{
		QRData: qrData,
		QRURL:  qrURL,
	}, nil
}

func (s *Service) GenerateDynamicQR(userID uint, req GenerateQRRequest) (*QRResponse, error) {
	acc, err := s.repo.FindPaymentAccountByUserID(userID)
	if err != nil {
		return nil, err
	}
	if acc == nil {
		return nil, errors.New("không tìm thấy tài khoản thanh toán")
	}

	qrData := GenerateVietQR("970499", acc.AccountNumber, req.Amount, req.Description)
	qrURL := fmt.Sprintf("https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=%s", qrData)

	return &QRResponse{
		QRData: qrData,
		QRURL:  qrURL,
	}, nil
}

// Withdraw xử lý yêu cầu rút tiền về tài khoản ngân hàng ngoài của người dùng.
// Bảo mật hai lớp: Mã PIN giao dịch 6 số + 4 số cuối CCCD/CMND.
// Không bao giờ sử dụng mật khẩu đăng nhập ứng dụng.
func (s *Service) Withdraw(userID uint, req WithdrawRequest) (*TransactionResponse, error) {
	req.BankAccountNumber = strings.TrimSpace(req.BankAccountNumber)
	req.AccountHolderName = strings.TrimSpace(req.AccountHolderName)
	req.BankName = strings.TrimSpace(req.BankName)
	req.IdentityCardLast4 = strings.TrimSpace(req.IdentityCardLast4)
	req.Description = strings.TrimSpace(req.Description)
	req.IdempotencyKey = strings.TrimSpace(req.IdempotencyKey)

	// --- Validate đầu vào ---
	if !regexp.MustCompile(`^[A-Za-z0-9._:-]{16,64}$`).MatchString(req.IdempotencyKey) {
		return nil, errors.New("Thiếu hoặc sai định dạng Idempotency-Key")
	}
	if req.BankAccountNumber == "" {
		return nil, errors.New("Số tài khoản ngân hàng thụ hưởng không được để trống")
	}
	if len(req.BankAccountNumber) < 6 || len(req.BankAccountNumber) > 20 {
		return nil, errors.New("Số tài khoản ngân hàng phải từ 6 đến 20 ký tự")
	}
	if req.AccountHolderName == "" {
		return nil, errors.New("Tên chủ tài khoản không được để trống")
	}
	if req.BankName == "" {
		return nil, errors.New("Tên ngân hàng không được để trống")
	}
	if !regexp.MustCompile(`^[0-9]{4}$`).MatchString(req.IdentityCardLast4) {
		return nil, errors.New("4 số cuối CCCD/CMND phải gồm đúng 4 chữ số")
	}
	if len([]rune(req.Description)) > 140 {
		return nil, errors.New("Nội dung rút tiền tối đa 140 ký tự")
	}

	// --- Validate hạn mức rút tiền ---
	if req.Amount < s.cfg.WithdrawMinAmount {
		return nil, fmt.Errorf("Số tiền rút tối thiểu là %s VND", formatMoney(s.cfg.WithdrawMinAmount))
	}
	if req.Amount > s.cfg.WithdrawMaxAmount {
		return nil, fmt.Errorf("Số tiền rút tối đa 1 lần là %s VND", formatMoney(s.cfg.WithdrawMaxAmount))
	}

	// --- Kiểm tra idempotency ---
	existing, err := s.repo.FindTransactionByIdempotencyKey(userID, req.IdempotencyKey)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return mapTransactionResponse(existing), nil
	}

	// --- Xác thực PIN giao dịch (lớp 1) ---
	if err := s.VerifyTransactionPIN(userID, req.TransactionPIN, false); err != nil {
		return nil, err
	}

	// --- Xác thực 4 số cuối CCCD/CMND (lớp 2) ---
	savedLast4, err := s.repo.GetIdentityCardLast4(userID)
	if err != nil {
		return nil, errors.New("Không thể xác minh thông tin định danh")
	}
	if savedLast4 == "" {
		return nil, errors.New("Bạn chưa cập nhật thông tin CCCD/CMND. Vui lòng cập nhật hồ sơ cá nhân trước khi rút tiền")
	}
	if savedLast4 != req.IdentityCardLast4 {
		return nil, errors.New("4 số cuối CCCD/CMND không chính xác")
	}

	// --- Lấy tên người dùng để ghi vào description ---
	userName, err := s.repo.GetUserFullName(userID)
	if err != nil {
		return nil, errors.New("Không thể lấy thông tin người dùng")
	}

	desc := fmt.Sprintf("Rút tiền về TK %s - %s tại %s", req.BankAccountNumber, req.AccountHolderName, req.BankName)
	if req.Description != "" {
		desc = fmt.Sprintf("%s - %s", desc, req.Description)
	}

	var transactionResult *Transaction
	var senderNewBalance int64

	err = s.repo.WithTx(func(tx *gorm.DB) error {
		// 1. Tìm và khóa tài khoản nguồn (PAYMENT account của user)
		senderAccount, err := s.repo.FindPaymentAccountByUserID(userID)
		if err != nil {
			return err
		}
		if senderAccount == nil {
			return errors.New("Không tìm thấy tài khoản thanh toán")
		}

		// 2. Tìm tài khoản đối ứng hệ thống (nhận tiền về kho)
		systemAccount, err := s.repo.FindAccountByNumber(systemOperationsAccountNumber)
		if err != nil {
			return err
		}
		if systemAccount == nil || systemAccount.AccountType != "SYSTEM_FUNDING" {
			return errors.New("Tài khoản hệ thống chưa sẵn sàng")
		}

		// 3. Khóa theo thứ tự ID để chống deadlock
		var lockedSender, lockedSystem *account.Account
		if senderAccount.ID < systemAccount.ID {
			lockedSender, err = s.repo.FindAccountByIDForUpdate(tx, senderAccount.ID)
			if err != nil {
				return err
			}
			lockedSystem, err = s.repo.FindAccountByIDForUpdate(tx, systemAccount.ID)
			if err != nil {
				return err
			}
		} else {
			lockedSystem, err = s.repo.FindAccountByIDForUpdate(tx, systemAccount.ID)
			if err != nil {
				return err
			}
			lockedSender, err = s.repo.FindAccountByIDForUpdate(tx, senderAccount.ID)
			if err != nil {
				return err
			}
		}

		if lockedSender == nil || lockedSystem == nil {
			return errors.New("Không tìm thấy thông tin tài khoản")
		}
		if lockedSender.Status != "ACTIVE" {
			return errors.New("Tài khoản của bạn đang bị khóa hoặc không hoạt động")
		}

		// 4. Kiểm tra số dư
		if lockedSender.Balance < req.Amount {
			return fmt.Errorf("Số dư không đủ. Số dư hiện tại: %s VND", formatMoney(lockedSender.Balance))
		}

		// 5. Cập nhật số dư
		senderNewBalance = lockedSender.Balance - req.Amount
		systemNewBalance := lockedSystem.Balance + req.Amount

		if err := s.repo.UpdateAccountBalance(tx, lockedSender.ID, senderNewBalance); err != nil {
			return err
		}
		if err := s.repo.UpdateAccountBalance(tx, lockedSystem.ID, systemNewBalance); err != nil {
			return err
		}

		// 6. Tạo bản ghi giao dịch WITHDRAW
		newTransaction := &Transaction{
			ReferenceCode:     generateReferenceCode(),
			InitiatorUserID:   &userID,
			IdempotencyKey:    &req.IdempotencyKey,
			SenderAccountID:   &lockedSender.ID,
			ReceiverAccountID: lockedSystem.ID,
			Amount:            req.Amount,
			Currency:          lockedSender.Currency,
			Type:              "WITHDRAW",
			Status:            "SUCCESS",
			Description:       desc,
		}

		if err := s.repo.CreateTransaction(tx, newTransaction); err != nil {
			return err
		}

		// 7. Ghi double-entry ledger
		if err := CreateDoubleEntry(
			tx,
			newTransaction.ID,
			lockedSender.ID,
			lockedSystem.ID,
			req.Amount,
			lockedSender.Currency,
			senderNewBalance,
			systemNewBalance,
		); err != nil {
			return err
		}

		// 8. Tạo thông báo trong DB
		notiMsg := fmt.Sprintf(
			"Yêu cầu rút tiền -%s VND về TK %s (%s - %s) đã được ghi nhận. Số dư còn lại: %s VND.",
			formatMoney(req.Amount),
			req.BankAccountNumber,
			req.AccountHolderName,
			req.BankName,
			formatMoney(senderNewBalance),
		)
		if err := s.notiService.CreateNotification(
			tx,
			userID,
			"BALANCE_FLUCTUATION",
			"Biến động số dư (-)",
			notiMsg,
		); err != nil {
			return err
		}

		transactionResult = newTransaction
		return nil
	})

	if err != nil {
		// Kiểm tra idempotency race condition
		existing, findErr := s.repo.FindTransactionByIdempotencyKey(userID, req.IdempotencyKey)
		if findErr == nil && existing != nil {
			return mapTransactionResponse(existing), nil
		}
		return nil, err
	}

	// Push notification sau khi transaction hoàn thành
	_ = s.notiService.SendPushToUser(
		userID,
		fmt.Sprintf("Yêu cầu rút tiền -%s VND", formatMoney(req.Amount)),
		fmt.Sprintf("Yêu cầu rút -%s VND về TK %s tại %s đang được xử lý. Số dư còn: %s VND", formatMoney(req.Amount), req.BankAccountNumber, req.BankName, formatMoney(senderNewBalance)),
		map[string]string{
			"type":           "BALANCE_FLUCTUATION",
			"reference_code": transactionResult.ReferenceCode,
			"transaction":    "WITHDRAW",
		},
	)

	// Ghi log audit (tên người dùng + tài khoản thụ hưởng, không ghi CCCD)
	_ = userName

	return mapTransactionResponse(transactionResult), nil
}

// formatMoney định dạng số tiền với dấu chấm phân cách hàng nghìn
func formatMoney(amount int64) string {
	s := fmt.Sprintf("%d", amount)
	n := len(s)
	if n <= 3 {
		return s
	}
	result := make([]byte, 0, n+(n-1)/3)
	for i, c := range s {
		if i > 0 && (n-i)%3 == 0 {
			result = append(result, '.')
		}
		result = append(result, byte(c))
	}
	return string(result)
}


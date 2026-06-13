package transaction

import (
	"bank-service/internal/infrastructure/firebase"
	"bank-service/internal/modules/account"
	"errors"
	"fmt"
	"regexp"
	"time"

	"gorm.io/gorm"
)

type Service struct {
	repo           *Repository
	firebaseClient *firebase.Client
}

func NewService(repo *Repository, firebaseClient *firebase.Client) *Service {
	return &Service{
		repo:           repo,
		firebaseClient: firebaseClient,
	}
}

func (s *Service) Transfer(
	userID uint,
	req TransferRequest,
) (*TransactionResponse, error) {

	if req.IDToken == "" {
		return nil, errors.New("giao dịch chuyển tiền yêu cầu xác thực OTP")
	}

	verifiedPhone, err := s.firebaseClient.VerifyIDToken(req.IDToken)
	if err != nil {
		return nil, err
	}

	userPhone, err := s.repo.GetUserPhone(userID)
	if err != nil {
		return nil, errors.New("không thể xác thực thông tin số điện thoại của người dùng")
	}

	if normalizePhone(verifiedPhone) != normalizePhone(userPhone) {
		return nil, errors.New("số điện thoại xác thực OTP không trùng khớp với số điện thoại đăng ký tài khoản")
	}

	var transactionResult *Transaction

	err = s.repo.WithTx(func(tx *gorm.DB) error {
		// 1. Tìm sender account (chưa lock) để lấy ID
		senderAccount, err := s.repo.FindPaymentAccountByUserID(userID)
		if err != nil {
			return err
		}
		if senderAccount == nil {
			return errors.New("không tìm thấy tài khoản gửi")
		}

		// 2. Tìm receiver account (chưa lock) để lấy ID
		receiverAccount, err := s.repo.FindAccountByNumber(req.ReceiverAccountNumber)
		if err != nil {
			return err
		}
		if receiverAccount == nil {
			return errors.New("không tìm thấy tài khoản nhận")
		}

		if senderAccount.ID == receiverAccount.ID {
			return errors.New("không thể chuyển tiền cho chính tài khoản của mình")
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
			return errors.New("không tìm thấy tài khoản gửi")
		}
		if lockedReceiver == nil {
			return errors.New("không tìm thấy tài khoản nhận")
		}

		if lockedSender.Status != "ACTIVE" {
			return errors.New("tài khoản gửi không hoạt động")
		}

		if lockedReceiver.Status != "ACTIVE" {
			return errors.New("tài khoản nhận không hoạt động")
		}

		if lockedSender.Currency != lockedReceiver.Currency {
			return errors.New("không thể chuyển tiền khác loại tiền tệ")
		}

		if lockedSender.Balance < req.Amount {
			return errors.New("số dư không đủ")
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

		newTransaction := &Transaction{
			ReferenceCode:     generateReferenceCode(),
			SenderAccountID:   lockedSender.ID,
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

		transactionResult = newTransaction

		return nil
	})

	if err != nil {
		return nil, err
	}

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
	}, nil
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
		return nil, errors.New("không tìm thấy tài khoản PAYMENT")
	}

	transactions, err := s.repo.FindTransactionsByAccountID(paymentAccount.ID)
	if err != nil {
		return nil, err
	}

	response := make([]TransactionResponse, 0)

	for _, transaction := range transactions {
		response = append(response, TransactionResponse{
			ID:                transaction.ID,
			ReferenceCode:     transaction.ReferenceCode,
			SenderAccountID:   transaction.SenderAccountID,
			ReceiverAccountID: transaction.ReceiverAccountID,
			Amount:            transaction.Amount,
			Currency:          transaction.Currency,
			Type:              transaction.Type,
			Status:            transaction.Status,
			Description:       transaction.Description,
		})
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
		return nil, errors.New("không tìm thấy tài khoản PAYMENT")
	}

	transaction, err := s.repo.FindTransactionByReferenceCode(referenceCode)
	if err != nil {
		return nil, err
	}

	if transaction == nil {
		return nil, errors.New("không tìm thấy giao dịch")
	}

	isOwner :=
		transaction.SenderAccountID == paymentAccount.ID ||
			transaction.ReceiverAccountID == paymentAccount.ID

	if !isOwner {
		return nil, errors.New("không có quyền truy cập giao dịch này")
	}

	return &TransactionResponse{
		ID:                transaction.ID,
		ReferenceCode:     transaction.ReferenceCode,
		SenderAccountID:   transaction.SenderAccountID,
		ReceiverAccountID: transaction.ReceiverAccountID,
		Amount:            transaction.Amount,
		Currency:          transaction.Currency,
		Type:              transaction.Type,
		Status:            transaction.Status,
		Description:       transaction.Description,
	}, nil
}

func normalizePhone(phone string) string {
	reg := regexp.MustCompile(`\D`)
	digits := reg.ReplaceAllString(phone, "")

	if len(digits) >= 11 && digits[:2] == "84" {
		return digits[2:]
	}
	if len(digits) > 0 && digits[:1] == "0" {
		return digits[1:]
	}
	return digits
}

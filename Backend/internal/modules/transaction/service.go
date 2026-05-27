package transaction

import (
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{
		repo: repo,
	}
}

func (s *Service) Transfer(
	userID uint,
	req TransferRequest,
) (*TransactionResponse, error) {

	var transactionResult *Transaction

	err := s.repo.WithTx(func(tx *gorm.DB) error {
		senderAccount, err := s.repo.FindPaymentAccountByUserIDForUpdate(
			tx,
			userID,
		)

		if err != nil {
			return err
		}

		if senderAccount == nil {
			return errors.New("không tìm thấy tài khoản gửi")
		}

		receiverAccount, err := s.repo.FindAccountByNumberForUpdate(
			tx,
			req.ReceiverAccountNumber,
		)
		if err != nil {
			return err
		}

		if receiverAccount == nil {
			return errors.New("không tìm thấy tài khoản nhận")
		}

		if senderAccount.ID == receiverAccount.ID {
			return errors.New("không thể chuyển tiền cho chính tài khoản của mình")
		}

		if senderAccount.Status != "ACTIVE" {
			return errors.New("tài khoản gửi không hoạt động")
		}

		if receiverAccount.Status != "ACTIVE" {
			return errors.New("tài khoản nhận không hoạt động")
		}

		if senderAccount.Currency != receiverAccount.Currency {
			return errors.New("không thể chuyển tiền khác loại tiền tệ")
		}

		if senderAccount.Balance < req.Amount {
			return errors.New("số dư không đủ")
		}

		senderNewBalance := senderAccount.Balance - req.Amount
		receiverNewBalance := receiverAccount.Balance + req.Amount

		if err := s.repo.UpdateAccountBalance(
			tx,
			senderAccount.ID,
			senderNewBalance,
		); err != nil {
			return err
		}

		if err := s.repo.UpdateAccountBalance(
			tx,
			receiverAccount.ID,
			receiverNewBalance,
		); err != nil {
			return err
		}

		newTransaction := &Transaction{
			ReferenceCode:     generateReferenceCode(),
			SenderAccountID:   senderAccount.ID,
			ReceiverAccountID: receiverAccount.ID,
			Amount:            req.Amount,
			Currency:          senderAccount.Currency,
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

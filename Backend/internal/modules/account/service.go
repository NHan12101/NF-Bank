package account

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{
		repo: repo,
	}
}

// CreateAccount tạo account mới cho user
func (s *Service) CreateAccount(
	userID uint,
	req CreateAccountRequest,
) (*AccountResponse, error) {

	// Validate account type
	validTypes := map[string]bool{
		"PAYMENT": true,
		"SAVINGS": true,
	}

	if !validTypes[req.AccountType] {
		return nil, errors.New("loại tài khoản không hợp lệ")
	}

	// Mỗi user chỉ có 1 PAYMENT account
	if req.AccountType == "PAYMENT" {

		existingPaymentAccount, err := s.repo.FindByUserIDAndType(
			userID,
			"PAYMENT",
		)
		if err != nil {
			return nil, err
		}

		if existingPaymentAccount != nil {
			return nil, errors.New(
				"người dùng đã có tài khoản PAYMENT",
			)
		}
	}

	// Validate currency
	validCurrencies := map[string]bool{
		"VND": true,
		"USD": true,
	}

	if !validCurrencies[req.Currency] {
		return nil, errors.New("loại tiền tệ không hợp lệ")
	}

	accountNumber, err := s.generateUniqueAccountNumber()
	if err != nil {
		return nil, err
	}

	account := &Account{
		UserID:        userID,
		AccountNumber: accountNumber,
		AccountType:   req.AccountType,
		Balance:       0,
		Currency:      req.Currency,
		Status:        "ACTIVE",
	}

	if err := s.repo.CreateAccount(account); err != nil {
		return nil, err
	}

	return &AccountResponse{
		ID:            account.ID,
		AccountNumber: account.AccountNumber,
		AccountType:   account.AccountType,
		Balance:       account.Balance,
		Currency:      account.Currency,
		Status:        account.Status,
	}, nil
}

// GetUserAccounts lấy danh sách account của user
func (s *Service) GetUserAccounts(
	userID uint,
) ([]AccountResponse, error) {

	accounts, err := s.repo.FindAccountsByUserID(userID)
	if err != nil {
		return nil, err
	}

	response := make([]AccountResponse, 0)

	for _, account := range accounts {
		response = append(response, AccountResponse{
			ID:            account.ID,
			AccountNumber: account.AccountNumber,
			AccountType:   account.AccountType,
			Balance:       account.Balance,
			Currency:      account.Currency,
			Status:        account.Status,
		})
	}

	return response, nil
}

// generateUniqueAccountNumber tạo số tài khoản unique
func (s *Service) generateUniqueAccountNumber() (string, error) {

	for {
		accountNumber, err := generateAccountNumber()
		if err != nil {
			return "", err
		}

		existingAccount, err := s.repo.FindAccountByNumber(accountNumber)
		if err != nil {
			return "", err
		}

		if existingAccount == nil {
			return accountNumber, nil
		}
	}
}

// generateAccountNumber tạo random account number
func generateAccountNumber() (string, error) {

	number := "9704"

	for i := 0; i < 8; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}

		number += fmt.Sprintf("%d", n.Int64())
	}

	return number, nil
}

// CreateDefaultPaymentAccount tạo tài khoản PAYMENT mặc định
func (s *Service) CreateDefaultPaymentAccount(
	userID uint,
) error {

	accountNumber, err := s.generateUniqueAccountNumber()
	if err != nil {
		return err
	}

	account := &Account{
		UserID:        userID,
		AccountNumber: accountNumber,
		AccountType:   "PAYMENT",
		Balance:       0,
		Currency:      "VND",
		Status:        "ACTIVE",
	}

	return s.repo.CreateAccount(account)
}

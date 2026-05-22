package admin

import (
	"bank-service/internal/modules/auth"
	"errors"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{
		repo: repo,
	}
}

func (s *Service) GetAllUsers() ([]AdminUserResponse, error) {
	users, err := s.repo.FindAllUsers()
	if err != nil {
		return nil, err
	}

	response := make([]AdminUserResponse, 0)

	for _, user := range users {
		response = append(response, mapUserToAdminResponse(user))
	}

	return response, nil
}

func (s *Service) GetUserByID(userID uint) (*AdminUserResponse, error) {
	user, err := s.repo.FindUserByID(userID)
	if err != nil {
		return nil, err
	}

	return &AdminUserResponse{
		ID:             user.ID,
		FullName:       user.FullName,
		Email:          user.Email,
		Phone:          user.Phone,
		Role:           user.Role,
		IsVerified:     user.IsVerified,
		IsLocked:       user.IsLocked,
		SessionVersion: user.SessionVersion,
		CreatedAt:      user.CreatedAt,
		UpdatedAt:      user.UpdatedAt,
	}, nil
}

func (s *Service) LockUser(userID uint) error {
	user, err := s.repo.FindUserByID(userID)
	if err != nil {
		return err
	}

	if user.Role == "admin" {
		return errors.New("không thể khóa tài khoản admin")
	}

	if user.IsLocked {
		return errors.New("tài khoản đã bị khóa")
	}

	return s.repo.LockUser(userID)
}

func (s *Service) UnlockUser(userID uint) error {
	user, err := s.repo.FindUserByID(userID)
	if err != nil {
		return err
	}

	if !user.IsLocked {
		return errors.New("tài khoản chưa bị khóa")
	}

	return s.repo.UnlockUser(userID)
}

func mapUserToAdminResponse(user auth.User) AdminUserResponse {
	return AdminUserResponse{
		ID:             user.ID,
		FullName:       user.FullName,
		Email:          user.Email,
		Phone:          user.Phone,
		Role:           user.Role,
		IsVerified:     user.IsVerified,
		IsLocked:       user.IsLocked,
		SessionVersion: user.SessionVersion,
		CreatedAt:      user.CreatedAt,
		UpdatedAt:      user.UpdatedAt,
	}
}

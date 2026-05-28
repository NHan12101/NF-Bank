package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"regexp"
	"time"

	"bank-service/internal/config"
	"bank-service/internal/infrastructure/email"
	jwtProvider "bank-service/internal/infrastructure/jwt"
	"bank-service/internal/modules/account"
	"bank-service/internal/modules/user"

	"golang.org/x/crypto/bcrypt"
)

// Service cung cấp các phương thức xử lý logic liên quan đến xác thực và quản lý người dùng
type Service struct {
	repo               *Repository
	otpRepo            *OTPRepository
	verifyRegisterRepo *VerifyRegisterRepository
	emailSender        *email.Sender
	accountService     *account.Service
	userService        *user.Service
	cfg                *config.Config
}

// NewService khởi tạo một instance của Service với các dependency cần thiết
func NewService(
	repo *Repository,
	otpRepo *OTPRepository,
	verifyRegisterRepo *VerifyRegisterRepository,
	emailSender *email.Sender,
	accountService *account.Service,
	userService *user.Service,
	cfg *config.Config,
) *Service {
	return &Service{
		repo:               repo,
		otpRepo:            otpRepo,
		accountService:     accountService,
		emailSender:        emailSender,
		userService:        userService,
		cfg:                cfg,
		verifyRegisterRepo: verifyRegisterRepo,
	}
}

// Register xử lý đăng ký tài khoản
func (s *Service) Register(req RegisterRequest) error {
	if err := validatePassword(req.Password); err != nil {
		return err
	}

	existingUser, err := s.repo.FindUserByEmail(req.Email)
	if err := validateVietnamPhone(req.Phone); err != nil {
		return err
	}

	existingPhone, err := s.repo.FindUserByPhone(req.Phone)
	if err != nil {
		return err
	}

	if existingPhone != nil {
		return errors.New("số điện thoại đã được sử dụng")
	}

	if existingUser != nil {
		return errors.New("email đã được sử dụng")
	}

	hashedPassword, err := bcrypt.GenerateFromPassword(
		[]byte(req.Password),
		bcrypt.DefaultCost,
	)
	if err != nil {
		return err
	}

	otp, err := generateOTP()
	if err != nil {
		return err
	}

	otpHash, err := bcrypt.GenerateFromPassword(
		[]byte(otp),
		bcrypt.DefaultCost,
	)
	if err != nil {
		return err
	}

	verifyRegister := &VerifyRegister{
		Email:        req.Email,
		FullName:     req.FullName,
		Phone:        req.Phone,
		PasswordHash: string(hashedPassword),
		OTPHash:      string(otpHash),
		OTPChannel:   req.OTPChannel,
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().Add(5 * time.Minute),
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := s.verifyRegisterRepo.Create(ctx, verifyRegister); err != nil {
		return err
	}

	if err := s.emailSender.SendOTP(req.Email, otp); err != nil {
		return err
	}

	return nil
}

// Login xử lý đăng nhập bước 1: kiểm tra mật khẩu và gửi OTP
func (s *Service) Login(req LoginRequest) error {
	user, err := s.repo.FindUserByEmail(req.Email)
	if err != nil {
		return err
	}

	if user == nil {
		return errors.New("email hoặc mật khẩu không đúng")
	}

	if user.IsLocked {
		return errors.New("tài khoản đã bị khóa")
	}

	if !user.IsVerified {
		return errors.New("tài khoản chưa được xác thực")
	}

	err = bcrypt.CompareHashAndPassword(
		[]byte(user.PasswordHash),
		[]byte(req.Password),
	)
	if err != nil {
		return errors.New("email hoặc mật khẩu không đúng")
	}

	hasActiveSession, err := s.repo.HasActiveSession(user.ID)
	if err != nil {
		return err
	}

	if hasActiveSession {
		if err := s.repo.RevokeAllUserRefreshTokens(user.ID); err != nil {
			return err
		}

		if err := s.repo.IncreaseSessionVersion(user.ID); err != nil {
			return err
		}

		_ = s.emailSender.SendSecurityAlert(user.Email)

		return errors.New(
			"phát hiện đăng nhập từ thiết bị khác, toàn bộ phiên đăng nhập đã bị vô hiệu hóa",
		)
	}

	otp, err := generateOTP()
	if err != nil {
		return err
	}

	otpHash, err := bcrypt.GenerateFromPassword(
		[]byte(otp),
		bcrypt.DefaultCost,
	)
	if err != nil {
		return err
	}

	loginOTP := &OTP{
		UserID:    user.ID,
		Email:     user.Email,
		OTPHash:   string(otpHash),
		Purpose:   "login",
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().Add(5 * time.Minute),
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := s.otpRepo.CreateOTP(ctx, loginOTP); err != nil {
		return err
	}

	if err := s.emailSender.SendOTP(user.Email, otp); err != nil {
		return err
	}

	return nil
}

// validatePassword kiểm tra độ mạnh mật khẩu
func validatePassword(password string) error {
	// Tối thiểu 8 ký tự
	if len(password) < 8 {
		return errors.New("mật khẩu phải có ít nhất 8 ký tự")
	}

	// Ít nhất 1 chữ hoa
	hasUppercase := regexp.MustCompile(`[A-Z]`).MatchString(password)

	// Ít nhất 1 ký tự đặc biệt
	hasSpecialChar := regexp.MustCompile(`[!@#$%^&*(),.?":{}|<>]`).MatchString(password)

	if !hasUppercase || !hasSpecialChar {
		return errors.New(
			"mật khẩu phải có ít nhất 1 chữ hoa và 1 ký tự đặc biệt",
		)
	}
	return nil
}

// Logout xử lý đăng xuất
func (s *Service) Logout(refreshToken string) error {

	refreshTokenHash := sha256.Sum256(
		[]byte(refreshToken),
	)

	return s.repo.RevokeRefreshToken(
		hex.EncodeToString(refreshTokenHash[:]),
	)
}

// RefreshAccessToken tạo access token mới từ refresh token
func (s *Service) RefreshAccessToken(refreshToken string) (*AuthResponse, error) {
	claims, err := jwtProvider.ValidateToken(
		refreshToken,
		s.cfg.RefreshTokenSecret,
	)
	if err != nil {
		return nil, errors.New("refresh token không hợp lệ hoặc đã hết hạn")
	}

	user, err := s.repo.FindUserByID(claims.UserID)
	if err != nil {
		return nil, err
	}

	if user == nil {
		return nil, errors.New("người dùng không tồn tại")
	}

	if user.IsLocked {
		return nil, errors.New("tài khoản đã bị khóa")
	}

	accessToken, err := jwtProvider.GenerateAccessToken(
		user.ID,
		user.Email,
		user.Role,
		user.SessionVersion,
		s.cfg.AccessTokenSecret,
	)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken: accessToken,
		User: UserResponse{
			ID:         user.ID,
			FullName:   user.FullName,
			Email:      user.Email,
			Role:       user.Role,
			IsVerified: user.IsVerified,
		},
	}, nil
}

// ChangePassword xử lý đổi mật khẩu
func (s *Service) ChangePassword(userID uint, req ChangePasswordRequest) error {
	user, err := s.repo.FindUserByID(userID)
	if err != nil {
		return err
	}

	if user == nil {
		return errors.New("người dùng không tồn tại")
	}

	if user.IsLocked {
		return errors.New("tài khoản đã bị khóa")
	}

	err = bcrypt.CompareHashAndPassword(
		[]byte(user.PasswordHash),
		[]byte(req.OldPassword),
	)
	if err != nil {
		return errors.New("mật khẩu cũ không đúng")
	}

	if req.OldPassword == req.NewPassword {
		return errors.New("mật khẩu mới không được trùng mật khẩu cũ")
	}

	if err := validatePassword(req.NewPassword); err != nil {
		return err
	}

	hashedPassword, err := bcrypt.GenerateFromPassword(
		[]byte(req.NewPassword),
		bcrypt.DefaultCost,
	)
	if err != nil {
		return err
	}

	return s.repo.UpdatePassword(userID, string(hashedPassword))
}

// generateOTP tạo một mã OTP ngẫu nhiên 6 chữ số
func generateOTP() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("%06d", n.Int64()), nil
}

// ForgotPassword xử lý yêu cầu quên mật khẩu
func (s *Service) ForgotPassword(req ForgotPasswordRequest) error {
	user, err := s.repo.FindUserByEmail(req.Email)
	if err != nil {
		return err
	}

	// Không leak email tồn tại hay không
	if user == nil {
		return nil
	}

	otp, err := generateOTP()
	if err != nil {
		return err
	}

	otpHash, err := bcrypt.GenerateFromPassword(
		[]byte(otp),
		bcrypt.DefaultCost,
	)
	if err != nil {
		return err
	}

	resetOTP := &OTP{
		UserID:    user.ID,
		Email:     user.Email,
		OTPHash:   string(otpHash),
		Purpose:   "password_reset",
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().Add(5 * time.Minute),
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := s.otpRepo.CreateOTP(ctx, resetOTP); err != nil {
		return err
	}

	if err := s.emailSender.SendOTP(user.Email, otp); err != nil {
		return err
	}
	return nil
}

// ResetPassword xử lý yêu cầu đặt lại mật khẩu
func (s *Service) ResetPassword(req ResetPasswordRequest) error {
	if err := validatePassword(req.NewPassword); err != nil {
		return err
	}

	user, err := s.repo.FindUserByEmail(req.Email)
	if err != nil {
		return err
	}

	if user == nil {
		return errors.New("otp không hợp lệ hoặc đã hết hạn")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resetOTP, err := s.otpRepo.FindValidOTPByEmailAndPurpose(ctx, req.Email, "password_reset")
	if err != nil {
		return err
	}

	if resetOTP == nil {
		return errors.New("otp không hợp lệ hoặc đã hết hạn")
	}

	err = bcrypt.CompareHashAndPassword(
		[]byte(resetOTP.OTPHash),
		[]byte(req.OTP),
	)
	if err != nil {
		return errors.New("otp không hợp lệ hoặc đã hết hạn")
	}

	hashedPassword, err := bcrypt.GenerateFromPassword(
		[]byte(req.NewPassword),
		bcrypt.DefaultCost,
	)
	if err != nil {
		return err
	}

	if err := s.repo.UpdatePassword(user.ID, string(hashedPassword)); err != nil {
		return err
	}

	return s.otpRepo.DeleteOTP(ctx, resetOTP.ID)
}

// ConfirmRegister xác thực OTP đăng ký tài khoản
func (s *Service) ConfirmRegister(req ConfirmRegisterRequest) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	verifyRegister, err := s.verifyRegisterRepo.FindByEmail(ctx, req.Email)
	if err != nil {
		return err
	}

	if verifyRegister == nil {
		return errors.New("otp không hợp lệ hoặc đã hết hạn")
	}

	err = bcrypt.CompareHashAndPassword(
		[]byte(verifyRegister.OTPHash),
		[]byte(req.OTP),
	)
	if err != nil {
		return errors.New("otp không hợp lệ hoặc đã hết hạn")
	}

	user := &User{
		Email:        verifyRegister.Email,
		FullName:     verifyRegister.FullName,
		Phone:        verifyRegister.Phone,
		PasswordHash: verifyRegister.PasswordHash,
		Role:         "user",
		IsVerified:   true,
		IsLocked:     false,
	}

	if err := s.repo.CreateUser(user); err != nil {
		return err
	}

	if err := s.accountService.CreateDefaultPaymentAccount(user.ID); err != nil {
		return err
	}

	if err := s.verifyRegisterRepo.Delete(ctx, verifyRegister.ID); err != nil {
		return err
	}

	return nil
}

// ConfirmLogin xác thực OTP đăng nhập và cấp token
func (s *Service) ConfirmLogin(req ConfirmLoginRequest) (*AuthResponse, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	loginOTP, err := s.otpRepo.FindValidOTPByEmailAndPurpose(
		ctx,
		req.Email,
		"login",
	)
	if err != nil {
		return nil, err
	}

	if loginOTP == nil {
		return nil, errors.New("otp không hợp lệ hoặc đã hết hạn")
	}

	err = bcrypt.CompareHashAndPassword(
		[]byte(loginOTP.OTPHash),
		[]byte(req.OTP),
	)
	if err != nil {
		return nil, errors.New("otp không hợp lệ hoặc đã hết hạn")
	}

	user, err := s.repo.FindUserByEmail(req.Email)
	if err != nil {
		return nil, err
	}

	if user == nil {
		return nil, errors.New("người dùng không tồn tại")
	}

	if user.IsLocked {
		return nil, errors.New("tài khoản đã bị khóa")
	}

	if !user.IsVerified {
		return nil, errors.New("tài khoản chưa được xác thực")
	}

	// Kiểm tra user đã có session active chưa
	hasActiveSession, err := s.repo.HasActiveSession(user.ID)
	if err != nil {
		return nil, err
	}

	if hasActiveSession {

		// Revoke toàn bộ refresh token
		if err := s.repo.RevokeAllUserRefreshTokens(user.ID); err != nil {
			return nil, err
		}

		// Tăng session version để kill access token cũ
		if err := s.repo.IncreaseSessionVersion(user.ID); err != nil {
			return nil, err
		}

		// Gửi email cảnh báo
		_ = s.emailSender.SendSecurityAlert(user.Email)

		return nil, errors.New(
			"phát hiện đăng nhập từ thiết bị khác, toàn bộ phiên đăng nhập đã bị vô hiệu hóa",
		)
	}

	accessToken, err := jwtProvider.GenerateAccessToken(
		user.ID,
		user.Email,
		user.Role,
		user.SessionVersion,
		s.cfg.AccessTokenSecret,
	)
	if err != nil {
		return nil, err
	}

	refreshToken, err := jwtProvider.GenerateRefreshToken(
		user.ID,
		user.Email,
		user.Role,
		user.SessionVersion,
		s.cfg.RefreshTokenSecret,
	)
	if err != nil {
		return nil, err
	}

	refreshTokenHash := sha256.Sum256([]byte(refreshToken))

	savedRefreshToken := &RefreshToken{
		UserID:    user.ID,
		TokenHash: hex.EncodeToString(refreshTokenHash[:]),
		IsRevoked: false,
		ExpiresAt: time.Now().Add(7 * 24 * time.Hour),
	}

	if err := s.repo.CreateRefreshToken(savedRefreshToken); err != nil {
		return nil, err
	}

	if err := s.otpRepo.DeleteOTP(ctx, loginOTP.ID); err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User: UserResponse{
			ID:         user.ID,
			FullName:   user.FullName,
			Email:      user.Email,
			Role:       user.Role,
			IsVerified: user.IsVerified,
		},
	}, nil
}

func validateVietnamPhone(phone string) error {
	pattern := `^(03[2-9]|086|09[6-8]|08[1-5]|087|088|091|094|070|076|077|078|079|089|090|093|052|056|058|092|059|099)[0-9]{7}$`

	matched, err := regexp.MatchString(pattern, phone)
	if err != nil {
		return err
	}

	if !matched {
		return errors.New("số điện thoại không đúng định dạng nhà mạng Việt Nam")
	}

	return nil
}

package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"bank-service/internal/config"
	"bank-service/internal/infrastructure/email"
	"bank-service/internal/infrastructure/firebase"
	jwtProvider "bank-service/internal/infrastructure/jwt"
	"bank-service/internal/infrastructure/totp"
	"bank-service/internal/modules/account"
	"bank-service/internal/modules/user"
	"bank-service/internal/utils"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// Service cung cấp các phương thức xử lý logic liên quan đến xác thực và quản lý người dùng
type Service struct {
	repo           *Repository
	accountService *account.Service
	userService    *user.Service
	cfg            *config.Config
	firebaseClient *firebase.Client
	emailClient    *email.Client
}

// NewService khởi tạo một instance của Service với các dependency cần thiết
func NewService(
	repo *Repository,
	accountService *account.Service,
	userService *user.Service,
	cfg *config.Config,
	firebaseClient *firebase.Client,
	emailClient *email.Client,
) *Service {
	return &Service{
		repo:           repo,
		accountService: accountService,
		userService:    userService,
		cfg:            cfg,
		firebaseClient: firebaseClient,
		emailClient:    emailClient,
	}
}

// Register xử lý đăng ký tài khoản
func (s *Service) Register(req RegisterRequest) error {
	req.FullName = utils.NormalizeFullName(req.FullName)
	if len([]rune(req.FullName)) < 2 || len([]rune(req.FullName)) > 100 {
		return errors.New("Họ và tên phải có từ 2 đến 100 ký tự")
	}
	if err := validatePassword(req.Password); err != nil {
		return err
	}

	phoneToValidate := req.Phone
	if len(req.Phone) >= 11 && req.Phone[:3] == "+84" {
		phoneToValidate = "0" + req.Phone[3:]
	} else if len(req.Phone) >= 10 && req.Phone[:2] == "84" {
		phoneToValidate = "0" + req.Phone[2:]
	}

	if err := validateVietnamPhone(phoneToValidate); err != nil {
		return err
	}

	formattedPhone := req.Phone
	if phoneToValidate[:1] == "0" {
		formattedPhone = "+84" + phoneToValidate[1:]
	}

	verifiedPhone, err := s.firebaseClient.VerifyIDToken(req.IDToken)
	if err != nil {
		return err
	}
	if normalizePhone(verifiedPhone) != normalizePhone(formattedPhone) {
		return errors.New("Số điện thoại xác thực không khớp với số đăng ký")
	}

	existingPhone, err := s.repo.FindUserByPhone(formattedPhone)
	if err != nil {
		return err
	}
	if existingPhone != nil {
		return errors.New("Số điện thoại đã được sử dụng")
	}

	cleanEmail := strings.TrimSpace(req.Email)
	if cleanEmail != "" {
		existingEmail, err := s.repo.FindUserByEmail(cleanEmail)
		if err != nil {
			return err
		}
		if existingEmail != nil {
			return errors.New("Địa chỉ email đã được sử dụng")
		}
	}

	hashedPassword, err := bcrypt.GenerateFromPassword(
		[]byte(req.Password),
		bcrypt.DefaultCost,
	)
	if err != nil {
		return err
	}

	var dob *time.Time
	if req.DateOfBirth != "" {
		if parsed, err := time.Parse("02/01/2006", req.DateOfBirth); err == nil {
			dob = &parsed
		} else if parsed, err := time.Parse("2006-01-02", req.DateOfBirth); err == nil {
			dob = &parsed
		}
	}

	gender := strings.ToLower(strings.TrimSpace(req.Gender))
	if gender == "nam" || gender == "male" {
		gender = "male"
	} else if gender == "nữ" || gender == "female" {
		gender = "female"
	}

	user := &User{
		FullName:     strings.TrimSpace(req.FullName),
		Phone:        formattedPhone,
		Email:        strings.TrimSpace(req.Email),
		PasswordHash: string(hashedPassword),
		Role:         "user",
		IsVerified:   true,
		IsLocked:     false,
	}
	return s.repo.WithTx(func(tx *gorm.DB) error {
		if err := s.repo.withDB(tx).CreateUser(user); err != nil {
			return err
		}
		if err := s.accountService.
			WithTransaction(tx).
			CreateDefaultPaymentAccount(user.ID); err != nil {
			return err
		}
		return s.userService.
			WithTransaction(tx).
			CreateInitialProfile(user.ID, dob, gender, strings.TrimSpace(req.Address))
	})
	if err != nil {
		return err
	}

	// Gửi Email Chào mừng Đăng ký tài khoản thành công nếu người dùng có Email
	if s.emailClient != nil && strings.TrimSpace(req.Email) != "" {
		acc, _ := s.accountService.GetPaymentAccountByUserID(user.ID)
		accountNum := ""
		if acc != nil {
			accountNum = acc.AccountNumber
		}
		go func(toEmail, name, accNum, phoneStr string) {
			_ = s.emailClient.SendWelcomeEmail(toEmail, name, accNum, phoneStr)
		}(strings.TrimSpace(req.Email), req.FullName, accountNum, req.Phone)
	}

	return nil
}

// Login xử lý đăng nhập: trả về AuthResponse chứa cờ yêu cầu OTP SMS với user thường hoặc token trực tiếp với admin/super admin
func (s *Service) Login(req LoginRequest, userAgent string, ipAddress string, deviceID string) (*AuthResponse, error) {
	phoneFormatted := "+84" + normalizePhone(req.Phone)
	user, err := s.repo.FindUserByPhone(phoneFormatted)
	if err != nil {
		return nil, err
	}

	if user == nil {
		return nil, errors.New("Tài khoản hoặc mật khẩu không đúng")
	}

	if user.IsLocked {
		return nil, errors.New("Tài khoản đã bị khóa")
	}

	if !user.IsVerified {
		return nil, errors.New("Tài khoản chưa được xác thực")
	}

	err = bcrypt.CompareHashAndPassword(
		[]byte(user.PasswordHash),
		[]byte(req.Password),
	)
	if err != nil {
		return nil, errors.New("Tài khoản hoặc mật khẩu không đúng")
	}

	// Phân loại xử lý dựa trên vai trò
	if user.Role == "admin" || user.Role == "super_admin" {
		// Yêu cầu TOTP code
		if req.TOTPCode == "" {
			return &AuthResponse{TOTPRequired: true}, nil
		}

		now := time.Now()
		if user.TOTPLockedUntil != nil && user.TOTPLockedUntil.After(now) {
			return nil, errors.New(
				"Xác thực TOTP đang tạm khóa do nhập sai quá nhiều lần",
			)
		}
		timeStep, valid := totp.MatchCodeAt(
			user.TOTPSecret,
			req.TOTPCode,
			now,
		)
		if !valid {
			lockedUntil, recordErr := s.repo.RecordTOTPFailure(
				user.ID,
				now,
				5,
				10*time.Minute,
			)
			if recordErr != nil {
				return nil, recordErr
			}
			if lockedUntil != nil {
				return nil, errors.New(
					"Nhập sai TOTP quá nhiều lần, xác thực bị khóa 10 phút",
				)
			}
			return nil, errors.New("Mã xác thực TOTP không đúng hoặc đã hết hạn")
		}
		if err := s.repo.RecordTOTPUsage(
			user.ID,
			timeStep,
			"ADMIN_LOGIN",
		); err != nil {
			return nil, errors.New(
				"Mã TOTP đã được sử dụng, vui lòng chờ mã mới",
			)
		}
		if err := s.repo.ResetTOTPFailures(user.ID); err != nil {
			return nil, err
		}

		// Tạo Access Token và Refresh Token ngay lập tức cho Admin/Super Admin
		accessToken, err := jwtProvider.GenerateAccessToken(
			user.ID,
			user.Phone,
			user.Role,
			user.SessionVersion,
			s.cfg.AccessTokenSecret,
		)
		if err != nil {
			return nil, err
		}

		refreshToken, err := jwtProvider.GenerateRefreshToken(
			user.ID,
			user.Phone,
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

		if deviceID == "" {
			deviceID = generateUUID()
		}

		return &AuthResponse{
			AccessToken:  accessToken,
			RefreshToken: refreshToken,
			DeviceID:     deviceID,
			User: UserResponse{
				ID:         user.ID,
				FullName:   user.FullName,
				Phone:      user.Phone,
				Role:       user.Role,
				IsVerified: user.IsVerified,
			},
		}, nil
	}

	// Kiểm tra xem thiết bị hiện tại có phải thiết bị tin cậy đã xác minh không
	isTrusted := false
	if deviceID != "" {
		device, err := s.repo.FindUserDevice(user.ID, deviceID)
		if err == nil && device != nil {
			isTrusted = true
			location := resolveLocation(ipAddress)
			_ = s.repo.UpdateUserDeviceLastLogin(device.ID, ipAddress, location)
		}
	}

	// Nếu đăng nhập bằng sinh trắc học hoặc thiết bị đã tin cậy -> Cấp token ngay lập tức
	if req.IsBiometric || isTrusted {
		thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
		_ = s.repo.DeleteStaleUserDevices(user.ID, thirtyDaysAgo)

		if deviceID == "" {
			deviceID = generateUUID()
		}

		if !isTrusted {
			location := resolveLocation(ipAddress)
			device := &UserDevice{
				UserID:         user.ID,
				DeviceID:       deviceID,
				UserAgent:      userAgent,
				LastActiveIP:   ipAddress,
				LastLocation:   location,
				LastLoggedInAt: time.Now(),
			}
			_ = s.repo.CreateUserDevice(device)
		}

		activeSessions, err := s.repo.GetActiveSessions(user.ID)
		if err == nil && len(activeSessions) >= 3 {
			_ = s.repo.RevokeRefreshTokenByID(activeSessions[0].ID)
		}

		accessToken, err := jwtProvider.GenerateAccessToken(
			user.ID,
			user.Phone,
			user.Role,
			user.SessionVersion,
			s.cfg.AccessTokenSecret,
		)
		if err != nil {
			return nil, err
		}

		refreshToken, err := jwtProvider.GenerateRefreshToken(
			user.ID,
			user.Phone,
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

		return &AuthResponse{
			AccessToken:  accessToken,
			RefreshToken: refreshToken,
			DeviceID:     deviceID,
			User: UserResponse{
				ID:         user.ID,
				FullName:   user.FullName,
				Phone:      user.Phone,
				Role:       user.Role,
				IsVerified: user.IsVerified,
			},
		}, nil
	}

	return &AuthResponse{
		SMSAuthRequired: true,
		Phone:           user.Phone,
	}, nil
}

// validatePassword kiểm tra độ mạnh mật khẩu
func validatePassword(password string) error {
	if len(password) < 8 {
		return errors.New("Mật khẩu phải có ít nhất 8 ký tự")
	}
	if strings.Contains(password, " ") {
		return errors.New("Mật khẩu không được chứa khoảng trắng")
	}
	hasUpper := regexp.MustCompile(`[A-Z]`).MatchString(password)
	hasLower := regexp.MustCompile(`[a-z]`).MatchString(password)
	if !hasUpper || !hasLower {
		return errors.New("Mật khẩu phải có ít nhất 1 chữ hoa (A-Z) và 1 chữ thường (a-z)")
	}
	hasDigit := regexp.MustCompile(`[0-9]`).MatchString(password)
	if !hasDigit {
		return errors.New("Mật khẩu phải có ít nhất 1 chữ số (0-9)")
	}
	hasSpecial := regexp.MustCompile(`[!@#$%^&*()_+\-=\[\]{}|\\:;"'<>,.?/~]`).MatchString(password) || strings.Contains(password, "`")
	if !hasSpecial {
		return errors.New("Mật khẩu phải có ít nhất 1 ký tự đặc biệt")
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
		return nil, errors.New("Refresh token không hợp lệ hoặc đã hết hạn")
	}

	refreshTokenHash := sha256.Sum256([]byte(refreshToken))
	storedToken, err := s.repo.FindActiveRefreshToken(hex.EncodeToString(refreshTokenHash[:]))
	if err != nil {
		return nil, err
	}
	if storedToken == nil || storedToken.UserID != claims.UserID {
		return nil, errors.New("Phiên đăng nhập không tồn tại hoặc đã bị thu hồi")
	}

	user, err := s.repo.FindUserByID(claims.UserID)
	if err != nil {
		return nil, err
	}

	if user == nil {
		return nil, errors.New("Người dùng không tồn tại")
	}

	if user.IsLocked {
		return nil, errors.New("Tài khoản đã bị khóa")
	}
	if claims.SessionVersion != user.SessionVersion {
		return nil, errors.New("Phiên đăng nhập đã hết hiệu lực")
	}

	accessToken, err := jwtProvider.GenerateAccessToken(
		user.ID,
		user.Phone,
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
			Phone:      user.Phone,
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
		return errors.New("Tài khoản đã bị khóa")
	}

	err = bcrypt.CompareHashAndPassword(
		[]byte(user.PasswordHash),
		[]byte(req.OldPassword),
	)
	if err != nil {
		return errors.New("Mật khẩu cũ không đúng")
	}

	if req.OldPassword == req.NewPassword {
		return errors.New("Mật khẩu mới không được trùng mật khẩu cũ")
	}

	if err := validatePassword(req.NewPassword); err != nil {
		return err
	}

	verifiedPhone, err := s.firebaseClient.VerifyIDToken(req.IDToken)
	if err != nil {
		return errors.New("Mã xác thực OTP không hợp lệ hoặc đã hết hạn")
	}
	if normalizePhone(verifiedPhone) != normalizePhone(user.Phone) {
		return errors.New("Số điện thoại xác thực không khớp với tài khoản")
	}

	hashedPassword, err := bcrypt.GenerateFromPassword(
		[]byte(req.NewPassword),
		bcrypt.DefaultCost,
	)
	if err != nil {
		return err
	}

	if err := s.repo.UpdatePassword(userID, string(hashedPassword)); err != nil {
		return err
	}
	_ = s.repo.RevokeAllUserRefreshTokens(userID)
	return s.repo.IncreaseSessionVersion(userID)
}

// ResetPassword xử lý yêu cầu đặt lại mật khẩu
func (s *Service) ResetPassword(req ResetPasswordRequest) error {
	if err := validatePassword(req.NewPassword); err != nil {
		return err
	}

	phone := "+84" + normalizePhone(req.Phone)
	user, err := s.repo.FindUserByPhone(phone)
	if err != nil {
		return err
	}

	if user == nil {
		return errors.New("Thông tin xác thực không hợp lệ")
	}

	verifiedPhone, err := s.firebaseClient.VerifyIDToken(req.IDToken)
	if err != nil {
		return err
	}
	if normalizePhone(verifiedPhone) != normalizePhone(user.Phone) {
		return errors.New("Số điện thoại xác thực không khớp với tài khoản")
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
	_ = s.repo.RevokeAllUserRefreshTokens(user.ID)
	return s.repo.IncreaseSessionVersion(user.ID)
}

// ConfirmLogin xác thực OTP đăng nhập và cấp token (đã nâng cấp hỗ trợ Firebase SMS OTP và nhận diện thiết bị đầu tiên)
func (s *Service) ConfirmLogin(req ConfirmLoginRequest, userAgent string, ipAddress string, deviceID string) (*AuthResponse, error) {
	phoneFormatted := "+84" + normalizePhone(req.Phone)
	user, err := s.repo.FindUserByPhone(phoneFormatted)

	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("Người dùng không tồn tại")
	}

	if user.IsLocked {
		return nil, errors.New("Tài khoản đã bị khóa")
	}

	if !user.IsVerified {
		return nil, errors.New("Tài khoản chưa được xác thực")
	}

	verifiedPhone, err := s.firebaseClient.VerifyIDToken(req.IDToken)
	if err != nil {
		return nil, err
	}
	if normalizePhone(verifiedPhone) != normalizePhone(user.Phone) {
		return nil, errors.New("Số điện thoại xác thực không khớp với tài khoản")
	}

	// 1. Tự động dọn dẹp các thiết bị tin cậy cũ quá 30 ngày của user này
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
	_ = s.repo.DeleteStaleUserDevices(user.ID, thirtyDaysAgo)

	// 2. Định vị địa lý của IP đăng nhập
	location := resolveLocation(ipAddress)

	// 3. Kiểm tra thiết bị đăng nhập hiện tại
	var isTrusted bool = false

	// Kiểm tra xem đây có phải là thiết bị đăng nhập đầu tiên không
	deviceCount, err := s.repo.CountUserDevices(user.ID)
	if err == nil && deviceCount == 0 {
		// Tự động nhận diện đây là thiết bị quen đầu tiên!
		newDeviceID := deviceID
		if newDeviceID == "" {
			newDeviceID = generateUUID()
		}
		device := &UserDevice{
			UserID:         user.ID,
			DeviceID:       newDeviceID,
			UserAgent:      userAgent,
			LastActiveIP:   ipAddress,
			LastLocation:   location,
			LastLoggedInAt: time.Now(),
		}
		if err := s.repo.CreateUserDevice(device); err == nil {
			deviceID = newDeviceID
			isTrusted = true
		}
	}

	if !isTrusted && deviceID != "" {
		device, err := s.repo.FindUserDevice(user.ID, deviceID)
		if err == nil && device != nil {
			// Thiết bị khớp! Cập nhật IP, vị trí và thời điểm hoạt động cuối (đã gia hạn 30 ngày)
			_ = s.repo.UpdateUserDeviceLastLogin(device.ID, ipAddress, location)
			isTrusted = true
		}
	}

	// OTP điện thoại vừa xác minh chính chủ, vì vậy đăng ký thiết bị mới.
	if !isTrusted {
		newDeviceID := deviceID
		if newDeviceID == "" {
			newDeviceID = generateUUID()
		}
		device := &UserDevice{
			UserID:         user.ID,
			DeviceID:       newDeviceID,
			UserAgent:      userAgent,
			LastActiveIP:   ipAddress,
			LastLocation:   location,
			LastLoggedInAt: time.Now(),
		}
		if err := s.repo.CreateUserDevice(device); err != nil {
			return nil, err
		}
		deviceID = newDeviceID
	}

	// 5. Nếu là thiết bị quen -> Cho phép đăng nhập bình thường
	// Kiểm tra giới hạn tối đa 3 thiết bị đồng thời
	activeSessions, err := s.repo.GetActiveSessions(user.ID)
	if err == nil && len(activeSessions) >= 3 {
		// Vô hiệu hóa session cũ nhất
		_ = s.repo.RevokeRefreshTokenByID(activeSessions[0].ID)
	}

	accessToken, err := jwtProvider.GenerateAccessToken(
		user.ID,
		user.Phone,
		user.Role,
		user.SessionVersion,
		s.cfg.AccessTokenSecret,
	)
	if err != nil {
		return nil, err
	}

	refreshToken, err := jwtProvider.GenerateRefreshToken(
		user.ID,
		user.Phone,
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

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		DeviceID:     deviceID,
		User: UserResponse{
			ID:         user.ID,
			FullName:   user.FullName,
			Phone:      user.Phone,
			Role:       user.Role,
			IsVerified: user.IsVerified,
		},
	}, nil
}

func resolveLocation(ip string) string {
	if ip == "127.0.0.1" || ip == "::1" || ip == "localhost" {
		return "Thiết bị thử nghiệm"
	}

	// Kiểm tra nếu là IP mạng nội bộ (LAN / Wi-Fi)
	if strings.HasPrefix(ip, "192.168.") ||
		strings.HasPrefix(ip, "10.") ||
		strings.HasPrefix(ip, "172.16.") ||
		strings.HasPrefix(ip, "172.17.") ||
		strings.HasPrefix(ip, "172.18.") ||
		strings.HasPrefix(ip, "172.19.") ||
		strings.HasPrefix(ip, "172.2") ||
		strings.HasPrefix(ip, "172.3") ||
		strings.HasPrefix(ip, "169.254.") {
		return "Mạng nội bộ (LAN / Wi-Fi)"
	}

	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://ip-api.com/json/" + ip + "?fields=status,country,regionName,city,isp")
	if err != nil {
		return "Không xác định"
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "Không xác định"
	}

	var geo struct {
		Status     string `json:"status"`
		Country    string `json:"country"`
		RegionName string `json:"regionName"`
		City       string `json:"city"`
		ISP        string `json:"isp"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&geo); err != nil {
		return "Không xác định"
	}

	if geo.Status != "success" {
		return "Không xác định"
	}

	return fmt.Sprintf("%s, %s (%s)", geo.City, geo.Country, geo.ISP)
}

func generateUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func validateVietnamPhone(phone string) error {
	pattern := `^(03[2-9]|086|09[6-8]|08[1-5]|087|088|091|094|070|076|077|078|079|089|090|093|052|056|058|092|059|099)[0-9]{7}$`

	matched, err := regexp.MatchString(pattern, phone)
	if err != nil {
		return err
	}

	if !matched {
		return errors.New("Số điện thoại không đúng định dạng nhà mạng Việt Nam")
	}

	return nil
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

func (s *Service) CheckPhone(rawPhone string) error {
	phoneToValidate := rawPhone
	if len(rawPhone) >= 11 && rawPhone[:3] == "+84" {
		phoneToValidate = "0" + rawPhone[3:]
	} else if len(rawPhone) >= 10 && rawPhone[:2] == "84" {
		phoneToValidate = "0" + rawPhone[2:]
	}

	if err := validateVietnamPhone(phoneToValidate); err != nil {
		return err
	}

	formattedPhone := rawPhone
	if len(phoneToValidate) > 0 && phoneToValidate[:1] == "0" {
		formattedPhone = "+84" + phoneToValidate[1:]
	}

	existingPhone, err := s.repo.FindUserByPhone(formattedPhone)
	if err != nil {
		return err
	}
	if existingPhone != nil {
		return errors.New("Số điện thoại đã được sử dụng")
	}

	return nil
}

func (s *Service) CheckEmail(rawEmail string) error {
	email := strings.TrimSpace(rawEmail)
	if email == "" {
		return errors.New("Vui lòng nhập địa chỉ email")
	}

	existingUser, err := s.repo.FindUserByEmail(email)
	if err != nil {
		return err
	}
	if existingUser != nil {
		return errors.New("Địa chỉ email đã được đăng ký trên hệ thống")
	}

	return nil
}

type emailOTPRecord struct {
	Email     string
	OTP       string
	ExpiresAt time.Time
}

var emailOTPStore sync.Map

// SendEmailOTPByPhoneOrEmail tìm người dùng qua Phone hoặc Email, lấy Email đăng ký và phát sinh OTP
func (s *Service) SendEmailOTPByPhoneOrEmail(rawPhone string, rawEmail string) (targetEmail string, maskedEmail string, err error) {
	phone := strings.TrimSpace(rawPhone)
	email := strings.ToLower(strings.TrimSpace(rawEmail))

	if phone != "" {
		phoneFormatted := "+84" + normalizePhone(phone)
		u, findErr := s.repo.FindUserByPhone(phoneFormatted)
		if findErr != nil || u == nil {
			return "", "", errors.New("Số điện thoại chưa được đăng ký trên hệ thống")
		}
		if strings.TrimSpace(u.Email) == "" {
			return "", "", errors.New("Tài khoản chưa được liên kết địa chỉ Email")
		}
		email = strings.ToLower(strings.TrimSpace(u.Email))
	} else if email != "" {
		u, findErr := s.repo.FindUserByEmail(email)
		if findErr != nil || u == nil {
			return "", "", errors.New("Địa chỉ email chưa được đăng ký trên hệ thống")
		}
	} else {
		return "", "", errors.New("Vui lòng nhập số điện thoại hoặc email")
	}

	b := make([]byte, 3)
	_, _ = rand.Read(b)
	otpNum := (int(b[0])<<16 | int(b[1])<<8 | int(b[2])) % 1000000
	otp := fmt.Sprintf("%06d", otpNum)

	emailOTPStore.Store(email, emailOTPRecord{
		Email:     email,
		OTP:       otp,
		ExpiresAt: time.Now().Add(5 * time.Minute),
	})

	if s.emailClient != nil {
		go func(to, code string) {
			_ = s.emailClient.SendOTPEmail(to, code)
		}(email, otp)
	}

	masked := MaskEmail(email)
	return email, masked, nil
}

func MaskEmail(email string) string {
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return email
	}
	name := parts[0]
	domain := parts[1]
	if len(name) <= 2 {
		return name + "***@" + domain
	}
	return name[:2] + "***" + name[len(name)-1:] + "@" + domain
}

func (s *Service) SendEmailOTP(rawEmail string) error {
	_, _, err := s.SendEmailOTPByPhoneOrEmail("", rawEmail)
	return err
}

// VerifyEmailOTP kiểm tra mã OTP gửi về Email
func (s *Service) VerifyEmailOTP(rawEmail string, rawOTP string) error {
	email := strings.ToLower(strings.TrimSpace(rawEmail))
	otp := strings.TrimSpace(rawOTP)

	if email == "" || otp == "" {
		return errors.New("Vui lòng nhập đầy đủ Email và mã OTP")
	}

	val, ok := emailOTPStore.Load(email)
	if !ok {
		return errors.New("Mã OTP không hợp lệ hoặc đã hết hạn")
	}

	rec := val.(emailOTPRecord)
	if time.Now().After(rec.ExpiresAt) {
		emailOTPStore.Delete(email)
		return errors.New("Mã OTP đã hết hạn. Vui lòng nhận mã mới")
	}

	if rec.OTP != otp {
		return errors.New("Mã OTP không chính xác")
	}

	return nil
}

// ResetPasswordWithEmailOTP đặt lại mật khẩu sử dụng mã OTP Email
func (s *Service) ResetPasswordWithEmailOTP(rawEmail string, rawOTP string, newPassword string) error {
	if err := s.VerifyEmailOTP(rawEmail, rawOTP); err != nil {
		return err
	}

	if err := validatePassword(newPassword); err != nil {
		return err
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return errors.New("Không thể mã hóa mật khẩu mới")
	}

	email := strings.ToLower(strings.TrimSpace(rawEmail))
	if err := s.repo.UpdateUserPasswordByEmail(email, string(hashedPassword)); err != nil {
		return fmt.Errorf("Đổi mật khẩu thất bại: %w", err)
	}

	emailOTPStore.Delete(email)
	return nil
}

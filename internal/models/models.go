	package models

	import (
		"time"
		"go.mongodb.org/mongo-driver/bson/primitive"
	)

	// User đại diện cho người dùng đăng nhập hệ thống
	type User struct {
	ID               primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Username         string             `bson:"username" json:"username"`
	Password         string             `bson:"password" json:"-"`
	Email            string             `bson:"email" json:"email"`
	PhoneNumber      string             `bson:"phone_number" json:"phone"`
	Role             string             `bson:"role" json:"role"`
	TrustedDevices   []string           `bson:"trusted_devices" json:"-"`
	IsLocked         bool               `bson:"is_locked" json:"is_locked"`
	CurrentSessionID string             `bson:"current_session_id" json:"current_session_id"`
	CreatedAt        time.Time          `bson:"created_at" json:"created_at"`
	FailedAttempts   int                `bson:"failed_attempts" json:"failed_attempts"`
	}

	// Account đại diện cho ví tiền/tài khoản ngân hàng của User
	type Account struct {
		ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
		UserID    primitive.ObjectID `bson:"user_id" json:"user_id"`
		Balance   int64              `bson:"balance" json:"balance"` // Đơn vị: VNĐ
		Status    string             `bson:"status" json:"status"`   // "active", "locked"
		CreatedAt time.Time          `bson:"created_at" json:"created_at"`
	}

	// Transaction đại diện cho lịch sử giao dịch
	type Transaction struct {
		ID          primitive.ObjectID `bson:"_id,omitempty" json:"id"`
		Type        string             `bson:"type" json:"type"` // "DEPOSIT", "TRANSFER", "PAYMENT"
		FromAccount string             `bson:"from_account,omitempty" json:"from_account,omitempty"`
		ToAccount   string             `bson:"to_account,omitempty" json:"to_account,omitempty"`
		Amount      int64              `bson:"amount" json:"amount"`
		Status      string             `bson:"status" json:"status"` // "SUCCESS", "FAILED", "PENDING"
		Description string             `bson:"description" json:"description"`
		CreatedAt   time.Time          `bson:"created_at" json:"created_at"`
	}

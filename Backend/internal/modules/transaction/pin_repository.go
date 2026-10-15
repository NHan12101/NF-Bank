package transaction

import (
	"errors"
	"time"

	"bank-service/internal/modules/auth"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

func (r *Repository) FindTransactionPIN(userID uint) (*TransactionPIN, error) {
	var pin TransactionPIN
	err := r.db.Where("user_id = ?", userID).First(&pin).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &pin, nil
}

func (r *Repository) CreateTransactionPIN(pin *TransactionPIN) error {
	return r.db.Create(pin).Error
}

func (r *Repository) ResetTransactionPINFailures(userID uint) error {
	return r.db.Model(&TransactionPIN{}).
		Where("user_id = ?", userID).
		Updates(map[string]interface{}{
			"failed_attempts": 0,
			"locked_until":    nil,
		}).Error
}

func (r *Repository) RecordTransactionPINFailure(
	userID uint,
	maxAttempts int,
	lockDuration time.Duration,
) (int, *time.Time, error) {
	var attempts int
	var lockedUntil *time.Time

	err := r.db.Transaction(func(tx *gorm.DB) error {
		var pin TransactionPIN
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("user_id = ?", userID).
			First(&pin).Error; err != nil {
			return err
		}

		now := time.Now()
		if pin.LockedUntil != nil && !now.Before(*pin.LockedUntil) {
			pin.FailedAttempts = 0
			pin.LockedUntil = nil
		}

		pin.FailedAttempts++
		if pin.FailedAttempts >= maxAttempts {
			until := now.Add(lockDuration)
			pin.LockedUntil = &until
		}
		attempts = pin.FailedAttempts
		lockedUntil = pin.LockedUntil

		return tx.Model(&pin).Updates(map[string]interface{}{
			"failed_attempts": pin.FailedAttempts,
			"locked_until":    pin.LockedUntil,
		}).Error
	})
	return attempts, lockedUntil, err
}

func (r *Repository) LockUserAccount(userID uint, summary string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&auth.User{}).
			Where("id = ?", userID).
			Updates(map[string]interface{}{
				"is_locked":       true,
				"session_version": gorm.Expr("session_version + 1"),
			}).Error; err != nil {
			return err
		}
		if err := tx.Model(&auth.RefreshToken{}).
			Where("user_id = ? AND is_revoked = ?", userID, false).
			Update("is_revoked", true).Error; err != nil {
			return err
		}
		return nil
	})
}


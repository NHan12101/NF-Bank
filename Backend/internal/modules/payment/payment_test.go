package payment

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"testing"
)

func TestVerifyAccountRawStringAndSignature(t *testing.T) {
	req := VerifyAccountRequest{
		PartnerCode:   "CHILLFY",
		AccessKey:     "test_access",
		RequestID:     "req_123",
		AccountNumber: "123456789",
	}

	raw := buildVerifyAccountRawString(req)
	expectedRaw := "accessKey=test_access&accountNumber=123456789&partnerCode=CHILLFY&requestId=req_123"

	if raw != expectedRaw {
		t.Fatalf("Raw string mismatch. Got: %s, Expected: %s", raw, expectedRaw)
	}

	secretKey := "secret_key"
	h := hmac.New(sha256.New, []byte(secretKey))
	h.Write([]byte(raw))
	expectedSig := hex.EncodeToString(h.Sum(nil))

	calculatedSig := calculateHMACSHA256(raw, secretKey)
	if calculatedSig != expectedSig {
		t.Fatalf("Signature mismatch. Got: %s, Expected: %s", calculatedSig, expectedSig)
	}
}

func TestMerchantPayoutRawStringAndSignature(t *testing.T) {
	req := MerchantPayoutRequest{
		PartnerCode:   "CHILLFY",
		AccessKey:     "test_access",
		RequestID:     "req_456",
		OrderID:       "order_789",
		Amount:        50000,
		AccountNumber: "987654321",
	}

	raw := buildPayoutRawString(req)
	expectedRaw := "accessKey=test_access&accountNumber=987654321&amount=50000&orderId=order_789&partnerCode=CHILLFY&requestId=req_456"

	if raw != expectedRaw {
		t.Fatalf("Raw string mismatch. Got: %s, Expected: %s", raw, expectedRaw)
	}

	secretKey := "secret_key"
	h := hmac.New(sha256.New, []byte(secretKey))
	h.Write([]byte(raw))
	expectedSig := hex.EncodeToString(h.Sum(nil))

	calculatedSig := calculateHMACSHA256(raw, secretKey)
	if calculatedSig != expectedSig {
		t.Fatalf("Signature mismatch. Got: %s, Expected: %s", calculatedSig, expectedSig)
	}
}

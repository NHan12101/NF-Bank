package transaction

import (
	"fmt"
)

type GenerateQRRequest struct {
	Amount      int64  `json:"amount"`
	Description string `json:"description"`
}

type QRResponse struct {
	QRData string `json:"qr_data"`
	QRURL  string `json:"qr_url"`
}

// CRC16 計算 CRC-16/CCITT-FALSE hash checksum (polynomial 0x1021, init 0xFFFF)
func CRC16(data string) string {
	var crc uint16 = 0xFFFF
	for i := 0; i < len(data); i++ {
		crc ^= uint16(data[i]) << 8
		for j := 0; j < 8; j++ {
			if (crc & 0x8000) != 0 {
				crc = (crc << 1) ^ 0x1021
			} else {
				crc <<= 1
			}
		}
	}
	return fmt.Sprintf("%04X", crc)
}

// GenerateVietQR sinh chuỗi VietQR chuẩn EMVCo
func GenerateVietQR(bin string, accountNumber string, amount int64, description string) string {
	// Tag 00: Payload Format Indicator (Cố định "01")
	payloadFormat := "000201"

	// Tag 01: Point of Initiation Method (11: static QR, 12: dynamic QR)
	initiationMethod := "010211"
	if amount > 0 {
		initiationMethod = "010212"
	}

	// Tag 38: Merchant Account Information (VietQR)
	// Sub-tag 00: GUID của VietQR (A000000727)
	guid := "0010A000000727"
	// Sub-tag 01: Beneficiary Info
	subBin := fmt.Sprintf("0006%s", bin)
	subAcc := fmt.Sprintf("01%02d%s", len(accountNumber), accountNumber)
	beneficiary := fmt.Sprintf("01%02d%s%s", len(subBin)+len(subAcc), subBin, subAcc)
	// Sub-tag 02: Service Code (QRIBFTTA - chuyển khoản nhanh Napas 247)
	service := "0208QRIBFTTA"

	tag38Value := fmt.Sprintf("%s%s%s", guid, beneficiary, service)
	tag38 := fmt.Sprintf("38%02d%s", len(tag38Value), tag38Value)

	// Tag 52: Merchant Category Code (Cố định "6011" cho rút tiền/chuyển khoản)
	mcc := "52046011"

	// Tag 53: Transaction Currency (VND = 704)
	currency := "5303704"

	// Tag 54: Transaction Amount (Số tiền - chỉ có nếu là dynamic QR)
	amountStr := ""
	if amount > 0 {
		amtVal := fmt.Sprintf("%d", amount)
		amountStr = fmt.Sprintf("54%02d%s", len(amtVal), amtVal)
	}

	// Tag 58: Country Code (VN)
	country := "5802VN"

	// Tag 62: Additional Data Field (Nội dung)
	additionalData := ""
	if description != "" {
		// Chỉ lấy tối đa 50 ký tự không dấu/chuẩn để tránh tràn QR
		if len(description) > 50 {
			description = description[:50]
		}
		descTag := fmt.Sprintf("08%02d%s", len(description), description)
		additionalData = fmt.Sprintf("62%02d%s", len(descTag), descTag)
	}

	// Tag 63: CRC16 Checksum
	crcPrefix := "6304"

	// Ghép toàn bộ chuỗi để tính CRC
	rawQR := fmt.Sprintf("%s%s%s%s%s%s%s%s%s",
		payloadFormat,
		initiationMethod,
		tag38,
		mcc,
		currency,
		amountStr,
		country,
		additionalData,
		crcPrefix,
	)

	checksum := CRC16(rawQR)
	return fmt.Sprintf("%s%s", rawQR, checksum)
}

package location

import "time"

// Province đại diện cho Tỉnh / Thành phố
type Province struct {
	Code      string    `gorm:"primaryKey;type:varchar(10)" json:"code"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
	Type      string    `gorm:"type:varchar(50)" json:"type"`
	IsCentral bool      `gorm:"default:false" json:"is_central"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Province) TableName() string {
	return "provinces"
}

// Ward đại diện cho Phường / Xã / Đặc khu
type Ward struct {
	Code         string    `gorm:"primaryKey;type:varchar(10)" json:"code"`
	Name         string    `gorm:"type:varchar(255);not null" json:"name"`
	Type         string    `gorm:"type:varchar(50)" json:"type"`
	ProvinceCode string    `gorm:"type:varchar(10);index;not null" json:"province_code"`
	ProvinceName string    `gorm:"type:varchar(255)" json:"province_name"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (Ward) TableName() string {
	return "wards"
}

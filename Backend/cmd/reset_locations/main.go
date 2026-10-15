package main

import (
	"fmt"
	"log"

	"bank-service/internal/config"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func main() {
	cfg := config.LoadConfig()
	dsn := cfg.GetMySQLDSN()
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("Lỗi kết nối MySQL: %v", err)
	}

	db.Exec("SET FOREIGN_KEY_CHECKS = 0;")
	db.Exec("TRUNCATE TABLE wards;")
	db.Exec("TRUNCATE TABLE provinces;")
	db.Exec("SET FOREIGN_KEY_CHECKS = 1;")

	fmt.Println("SUCCESS_RESET_LOCATION_TABLES")
}

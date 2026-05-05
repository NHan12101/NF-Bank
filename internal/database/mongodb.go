package database

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var Client *mongo.Client
var DB *mongo.Database

func ConnectDB(uri string, dbName string) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	clientOptions := options.Client().ApplyURI(uri)
	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		log.Fatal("❌ Lỗi cấu hình kết nối MongoDB: ", err)
	}

	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatal("❌ Không thể kết nối tới MongoDB: ", err)
	}

	fmt.Println("✅ Đã kết nối thành công tới MongoDB!")

	Client = client
	DB = client.Database(dbName)

	indexModel := mongo.IndexModel{
		Keys: bson.M{"created_at": 1},
		Options: options.Index().SetExpireAfterSeconds(120), 
	}
	
	_, err = DB.Collection("otp_verifications").Indexes().CreateOne(context.TODO(), indexModel)
	if err != nil {
		fmt.Println("⚠️ Không thể tạo TTL Index:", err)
	} else {
		fmt.Println("🧹 Đã kích hoạt chổi quét rác tự động (TTL) cho OTP!")
	}
}

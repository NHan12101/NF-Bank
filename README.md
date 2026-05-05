# 🏦 Bank-Service Backend (Core Banking System)

## 📝 Giới thiệu
Đây là hệ thống Backend đóng vai trò như một **Cổng thanh toán (Payment Gateway)**. Hệ thống cho phép người dùng đăng ký tài khoản ngân hàng, quản lý số dư và thực hiện các giao dịch thanh toán an toàn cho các dịch vụ bên thứ ba (cụ thể là ứng dụng âm nhạc trong cùng hệ sinh thái).

## 🚀 Công nghệ sử dụng
- **Ngôn ngữ:** [Golang](https://go.dev/) (Hiệu năng cao, xử lý song song tốt).
- **Framework:** [Gin Web Framework](https://gin-gonic.com/) (Router nhanh và nhẹ).
- **Database:** [MongoDB](https://www.mongodb.com/) (Lưu trữ linh hoạt, dễ mở rộng).
- **Authentication:** JWT (JSON Web Token) & HTTP-Only Cookie.
- **Security:** SMTP Server (Gmail), Goroutine for Background Tasks.

## 🛠 Cài đặt & Chạy dự án

1. **Clone dự án:**
   ```bash
   git clone <link-repo-cua-ban>
   cd bank-service
Cấu hình môi trường:
Tạo file .env tại thư mục gốc và cấu hình các thông số sau:

Đoạn mã
PORT=8080
MONGO_URI=mongodb://localhost:27017
DB_NAME=bank_db
JWT_SECRET=your_super_secret_key

# Cấu hình Email (Dùng để gửi OTP & Cảnh báo)
EMAIL_FROM=email_cua_ban@gmail.com
EMAIL_PASSWORD=mat_khau_ung_dung_google
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
Cài đặt thư viện & Chạy:

Bash
go mod tidy
go run main.go
🔐 Các tính năng bảo mật cốt lõi (Core Security)
Hệ thống được thiết kế với các chốt chặn an ninh cấp ngân hàng:

1. Cơ chế "Đá văng" thiết bị (Single Session Management)
Hoạt động: Mỗi người dùng chỉ được phép có một phiên đăng nhập duy nhất trên một thiết bị tại một thời điểm.

Logic: Khi người dùng đăng nhập ở máy mới, hệ thống sinh SessionID mới và cập nhật vào DB. Middleware sẽ kiểm tra SessionID trong Token cũ; nếu không khớp với DB, người dùng sẽ bị 403 Forbidden và yêu cầu đăng nhập lại.

2. Hệ thống cảnh báo đăng nhập lạ
Sử dụng Goroutine để gửi Email cảnh báo ngay lập tức nếu phát hiện tài khoản bị đăng nhập từ thiết bị thứ hai (lúc thiết bị cũ bị đá văng).

Không làm gián đoạn tốc độ phản hồi của API (chạy ngầm).

3. Chống dò mật khẩu & OTP (Brute-force Protection)
Tự động khóa tài khoản/chức năng nếu:

Nhập sai mật khẩu quá 5 lần.

Nhập sai mã OTP quá 5 lần.

Chỉ Admin mới có quyền mở khóa hoặc phải thực hiện quy trình xác thực nghiêm ngặt.

4. Quên mật khẩu & Xác thực OTP
Quy trình 3 bước: Gửi yêu cầu -> Nhận mã 6 số qua Email -> Xác thực & Đổi mật khẩu.

OTP có thời hạn sử dụng (Expired time) để đảm bảo an toàn.

🛣 Luồng xử lý chính (Workflows)
Luồng Đăng nhập & Bảo mật
Client gửi username/password.

Server kiểm tra DB -> Kiểm tra SessionID hiện tại.

Nếu có SessionID cũ -> Kích hoạt Goroutine gửi mail cảnh báo "Đá văng".

Cập nhật SessionID mới -> Trả về Access Token & Refresh Token.

Luồng Thanh toán (Đang phát triển)
App Âm nhạc gọi API thanh toán kèm mã đơn hàng.

Bank-Service kiểm tra số dư (balance) của User.

Thực hiện trừ tiền & Ghi log vào bảng transactions.

Trả kết quả thành công cho App Âm nhạc.

📂 Cấu trúc thư mục (Project Structure)
Plaintext
├── cmd/                # Điểm khởi đầu của ứng dụng
├── internal/
│   ├── auth/           # Xử lý JWT, Bcrypt
│   ├── database/       # Kết nối MongoDB
│   ├── handlers/       # Xử lý Logic API (Login, Register, Profile...)
│   ├── middleware/     # Các bộ lọc bảo vệ API (RequireAuth)
│   ├── models/         # Định nghĩa cấu trúc dữ liệu (User, Account, Transaction)
│   └── utils/          # Các hàm hỗ trợ (Gửi mail, tạo OTP)
├── .env                # Lưu biến môi trường
└── main.go             # File chạy chính
Note cho Team: Mọi người nhớ chạy go mod tidy thường xuyên để cập nhật thư viện mới nhất nhé!


---

### Một vài lưu ý nhỏ cho bạn:
- Tôi đã để mục **Luồng thanh toán** là "Đang phát triển" để các thành viên khác biết bạn đang làm gì tiếp theo.
- Phần **Cấu trúc thư mục** tôi trình bày theo chuẩn Go Layout để thầy cô nhìn vào thấy bạn có kiến thức về kiến trúc phần mềm.

Bạn có muốn tôi bổ sung thêm mục nào khác (ví dụ bảng mã lỗi hoặc hướng dẫn sử dụng Postman) vào README này không? Nếu không
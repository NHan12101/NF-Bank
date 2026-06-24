const crypto = require('crypto');

// Cấu hình kết nối tới server Backend NF-Bank và thông tin đối tác mặc định
const BACKEND_URL = 'http://localhost:8080/api/v1/payments/create';
const PARTNER_CODE = 'NFBANK_PROD_OR_TEST_ID';
const ACCESS_KEY = 'your_nfbank_access_key_here';
const SECRET_KEY = 'your_nfbank_secret_key_here';

async function createTestPayment() {
  const orderId = `MUSIC_APP_${Date.now()}`;
  const requestId = `REQ_${Date.now()}`;
  const amount = 50000; // 50,000 VND
  const orderInfo = 'Thanh toan VIP Premium Music App (1 Thang)';
  const redirectUrl = 'https://huddling-spouse-unnamable.ngrok-free.dev/dashboard'; // URL quay lại đối tác sau thanh toán
  const ipnUrl = 'https://webhook.site/2bd66f4e-2895-46f0-b0ba-8ce945f3a097'; // Webhook IPN nhận kết quả thanh toán ngầm
  const extraData = JSON.stringify({ userId: 123, packageName: 'premium_monthly' });

  // 1. Xây dựng chuỗi Raw String theo đúng quy chuẩn bảng chữ cái của tên trường
  const rawSignature = [
    `accessKey=${ACCESS_KEY}`,
    `amount=${amount}`,
    `extraData=${extraData}`,
    `ipnUrl=${ipnUrl}`,
    `orderId=${orderId}`,
    `orderInfo=${encodeURIComponent(orderInfo)}`, // Đảm bảo mã hóa URL phần ký nếu backend giải mã
    `partnerCode=${PARTNER_CODE}`,
    `redirectUrl=${redirectUrl}`,
    `requestId=${requestId}`
  ].join('&');

  // Lưu ý: Nếu backend nhận orderInfo dạng raw không urlencode thì ký chuỗi raw. 
  // Hãy xem lại backend service.go định nghĩa raw string: req.OrderInfo trực tiếp
  const rawSignatureStandard = `accessKey=${ACCESS_KEY}&amount=${amount}&extraData=${extraData}&ipnUrl=${ipnUrl}&orderId=${orderId}&orderInfo=${orderInfo}&partnerCode=${PARTNER_CODE}&redirectUrl=${redirectUrl}&requestId=${requestId}`;

  // 2. Tính toán chữ ký số HMAC-SHA256
  const signature = crypto
    .createHmac('sha256', SECRET_KEY)
    .update(rawSignatureStandard)
    .digest('hex');

  const payload = {
    partnerCode: PARTNER_CODE,
    accessKey: ACCESS_KEY,
    requestId: requestId,
    amount: amount,
    orderId: orderId,
    orderInfo: orderInfo,
    redirectUrl: redirectUrl,
    ipnUrl: ipnUrl,
    extraData: extraData,
    signature: signature
  };

  console.log('📣 Gửi yêu cầu khởi tạo đơn hàng sang NF-Bank...');
  console.log('📦 Payload gửi đi:', JSON.stringify(payload, null, 2));

  try {
    const response = await fetch(BACKEND_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const data = await response.json();

    if (response.ok && data.resultCode === 0) {
      console.log('\n✅ Khởi tạo giao dịch THÀNH CÔNG!');
      console.log('--------------------------------------------------');
      console.log('🔗 Link thanh toán của bạn (Hãy click vào đây):');
      console.log(`\x1b[36m%s\x1b[0m`, data.payUrl);
      console.log('--------------------------------------------------');
      console.log('🔍 Chi tiết phản hồi:', JSON.stringify(data, null, 2));
    } else {
      console.error('\n❌ Khởi tạo giao dịch THẤT BẠI!');
      console.error('Chi tiết phản hồi lỗi:', data);
    }
  } catch (error) {
    console.error('\n❌ Lỗi kết nối tới Go Backend:', error.message);
    console.error('Hãy chắc chắn rằng server Golang Backend của bạn đang chạy tại port 8080.');
  }
}

createTestPayment();

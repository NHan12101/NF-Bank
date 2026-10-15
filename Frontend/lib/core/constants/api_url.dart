import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiUrl {
  ApiUrl._();

  static String get baseUrl {
    final value = dotenv.env['API_BASE_URL']?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Thiếu API_BASE_URL trong file .env');
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  static String get auth => '$baseUrl/auth';
  static String get checkPhone => '$auth/check-phone';
  static String get checkEmail => '$auth/check-email';
  static String get login => '$auth/login';
  static String get confirmLogin => '$auth/confirm-login';
  static String get register => '$auth/register';
  static String get logout => '$auth/logout';
  static String get refresh => '$auth/refresh';
  static String get changePassword => '$auth/change-password';
  static String get resetPassword => '$auth/password-reset/confirm';
  static String get sendEmailOTP => '$auth/send-email-otp';
  static String get verifyEmailOTP => '$auth/verify-email-otp';
  static String get resetPasswordEmail => '$auth/reset-password-email';
  static String get sessionCheck => '$auth/session-check';

  static String get accounts => '$baseUrl/accounts';
  static String get profile => '$baseUrl/users/me';
  static String get transferLimit => '$profile/transfer-limit';
  static String get profileAvatar => '$profile/avatar';
  static String get transactions => '$baseUrl/transactions';
  static String get transfer => '$transactions/transfer';
  static String get qr => '$transactions/qr';
  static String get transactionPinStatus => '$transactions/pin/status';
  static String get setupTransactionPin => '$transactions/pin/setup';
  static String get verifyTransactionPin => '$transactions/pin/verify';
  static String resolveAccount(String accountNumber) =>
      '$transactions/resolve/$accountNumber';
  static String get withdraw => '$transactions/withdraw';
  static String get savings => '$baseUrl/savings';
  static String get notifications => '$baseUrl/notifications';
  static String get admin => '$baseUrl/admin';

  static String get paymentSession => '$baseUrl/payments/session';
  static String get confirmPayment => '$baseUrl/payments/confirm';
  static String get testCreatePayment => '$baseUrl/payments/test-create';

  static String get locations => '$baseUrl/locations';
  static String get provinces => '$locations/provinces';
  static String wards(String provinceCode) => '$locations/wards?province_code=$provinceCode';
}

import '../../../core/constants/api_url.dart';
import '../../../core/network/api_service.dart';

class PaymentRepository {
  const PaymentRepository();

  Future<Map<String, dynamic>> getPaymentSession(String token) async {
    final result = await ApiService.get(
      '${ApiUrl.paymentSession}/$token',
      auth: true,
    );
    return _map(result.data);
  }

  Future<Map<String, dynamic>> confirmPayment({
    required String token,
    required int accountId,
    String? idToken,
    String? otp,
  }) async {
    final body = {
      'payment_token': token,
      'payment_account_id': accountId,
    };
    if (idToken != null && idToken.isNotEmpty) {
      body['id_token'] = idToken;
    }
    if (otp != null && otp.isNotEmpty) {
      body['otp'] = otp;
    }

    final result = await ApiService.post(
      ApiUrl.confirmPayment,
      auth: true,
      body: body,
    );
    return _map(result.data);
  }

  Future<String> testCreatePayment({
    required int amount,
    required String orderInfo,
  }) async {
    final result = await ApiService.post(
      ApiUrl.testCreatePayment,
      auth: true,
      body: {
        'amount': amount,
        'order_info': orderInfo,
      },
    );
    final data = _map(result.data);
    final token = data['payment_token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const ApiException('Không tạo được token phiên thanh toán thử nghiệm');
    }
    return token;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};
}

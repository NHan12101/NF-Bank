import '../../../core/constants/api_url.dart';
import '../../../core/network/api_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../transfers/services/transfer_repository.dart';
import '../../transfers/utils/vietqr_parser.dart';

enum LoginStep { authenticated, totpRequired, otpRequired }

class LoginResult {
  const LoginResult(this.step, {this.phone});

  final LoginStep step;
  final String? phone;
}

class AuthService {
  Future<LoginResult> login(
    String phone,
    String password, {
    String totpCode = '',
    bool isBiometric = false,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'password': password,
      'totp_code': totpCode,
    };
    if (isBiometric) {
      body['is_biometric'] = true;
    }
    final result = await ApiService.post(
      ApiUrl.login,
      body: body,
    );
    final data = _map(result.data);
    if (data['totp_required'] == true) {
      return const LoginResult(LoginStep.totpRequired);
    }
    if (data['access_token'] != null) {
      await _persist(data);
      return const LoginResult(LoginStep.authenticated);
    }
    return LoginResult(LoginStep.otpRequired, phone: data['phone']?.toString());
  }

  Future<void> confirmLogin(String phone, String idToken) async {
    final result = await ApiService.post(
      ApiUrl.confirmLogin,
      body: {'phone': phone, 'id_token': idToken},
    );
    await _persist(_map(result.data));
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String password,
    required String idToken,
    String? email,
    String? gender,
    String? dateOfBirth,
    String? address,
  }) async => ApiService.post(
    ApiUrl.register,
    body: {
      'full_name': fullName,
      'phone': phone,
      'password': password,
      'id_token': idToken,
      if (email != null && email.isNotEmpty) 'email': email,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'date_of_birth': dateOfBirth,
      if (address != null && address.isNotEmpty) 'address': address,
    },
  );

  Future<void> resetPassword(
    String phone,
    String idToken,
    String password,
  ) async => ApiService.post(
    ApiUrl.resetPassword,
    body: {'phone': phone, 'id_token': idToken, 'new_password': password},
  );

  Future<ApiResult> sendEmailOTP({String? email, String? phone}) async {
    final body = <String, dynamic>{};
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    return ApiService.post(
      ApiUrl.sendEmailOTP,
      body: body,
    );
  }

  Future<void> verifyEmailOTP(String email, String otp) async => ApiService.post(
    ApiUrl.verifyEmailOTP,
    body: {'email': email, 'otp': otp},
  );

  Future<void> resetPasswordWithEmail(
    String email,
    String otp,
    String newPassword,
  ) async => ApiService.post(
    ApiUrl.resetPasswordEmail,
    body: {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    },
  );

  Future<void> changePassword(
    String oldPassword,
    String newPassword,
    String idToken,
  ) async {
    await ApiService.put(
      ApiUrl.changePassword,
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'id_token': idToken,
      },
    );
    await TokenStorage.clearAuth();
  }

  Future<void> logout() async {
    try {
      await ApiService.post(ApiUrl.logout, auth: true);
    } on ApiException {
    } finally {
      await TokenStorage.clearAuth();
    }
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    final token = data['access_token']?.toString();
    final user = data['user'];
    if (token == null || user is! Map<String, dynamic>) {
      throw const ApiException('Phản hồi đăng nhập không hợp lệ');
    }
    await TokenStorage.saveAuthData(token, user);

    try {
      final qrResult = await const TransferRepository().getMyStaticQR(tokenOverride: token);
      final qrData = qrResult['qr_data']?.toString() ?? '';
      var qrUrl = qrResult['qr_url']?.toString() ?? '';
      var accountNumber = _extractAccountNumber(qrData);

      if (accountNumber.isEmpty || !accountNumber.startsWith('9704')) {
        final result = await ApiService.get(
          ApiUrl.accounts,
          auth: true,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (result.isSuccess && result.data is List) {
          for (final item in (result.data as List)) {
            if (item is Map && item['account_type'] == 'PAYMENT') {
              accountNumber = item['account_number']?.toString() ?? '';
              break;
            }
          }
        }
      }

      if (accountNumber.startsWith('9704') && qrUrl.isEmpty) {
        qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=00020101021138540010A000000727012600069704990112${accountNumber}0208QRIBFTTA5204601153037045802VN6304";
      }

      await TokenStorage.saveUserQR(
        qrData: qrData,
        qrUrl: qrUrl,
        accountNumber: accountNumber,
      );
    } catch (_) {}
  }

  static String _extractAccountNumber(String qrData) {
    if (qrData.isEmpty) return '';
    final parsed = VietQRParser.parse(qrData);
    if (parsed != null && parsed['account'] != null && parsed['account']!.isNotEmpty) {
      return parsed['account']!;
    }
    final match = RegExp(r'9704\d{8}').firstMatch(qrData);
    if (match != null) return match.group(0)!;
    return '';
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};
}

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const _secureStorage = FlutterSecureStorage();

  static const _keyBiometricLogin = 'BIOMETRIC_LOGIN_ENABLED';
  static const _keyBiometricTx = 'BIOMETRIC_TX_ENABLED';

  // Các keys trong Secure Storage
  static const _keyPhone = 'BIO_PHONE';
  static const _keyPassword = 'BIO_PASSWORD';
  static const _keyPin = 'BIO_PIN';

  /// Kiểm tra thiết bị có hỗ trợ phần cứng sinh trắc học và đã cài đặt vân tay/khuôn mặt chưa
  static Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Trạng thái bật/tắt của tính năng Đăng nhập vân tay
  static Future<bool> isLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricLogin) ?? false;
  }

  /// Bật/tắt Đăng nhập vân tay
  static Future<void> setLoginEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricLogin, enabled);
  }

  /// Trạng thái bật/tắt của tính năng Xác thực giao dịch vân tay
  static Future<bool> isTxEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricTx) ?? false;
  }

  /// Bật/tắt Xác thực giao dịch vân tay
  static Future<void> setTxEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricTx, enabled);
  }

  static String? lastError;
  static bool _isAuthenticating = false;

  /// Gọi xác thực sinh trắc học (Vân tay/FaceID)
  static Future<bool> authenticate({
    String reason = 'Vui lòng xác thực vân tay hoặc khuôn mặt để tiếp tục',
  }) async {
    lastError = null;
    if (_isAuthenticating) {
      try {
        await _auth.stopAuthentication();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _isAuthenticating = true;
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!isSupported && !canCheck) {
        lastError = 'Thiết bị không hỗ trợ hoặc chưa bật phần cứng sinh trắc học';
        return false;
      }

      final available = await _auth.getAvailableBiometrics();
      if (available.isEmpty && !canCheck) {
        lastError = 'Thiết bị chưa cài đặt vân tay/khuôn mặt trong Cài đặt máy';
        return false;
      }

      bool res = false;
      try {
        res = await _auth.authenticate(
          localizedReason: reason,
          authMessages: const <AuthMessages>[
            AndroidAuthMessages(
              signInTitle: 'Xác thực vân tay',
              biometricHint: 'Chạm vào cảm biến vân tay ở nút nguồn',
              cancelButton: 'Hủy',
              biometricNotRecognized: 'Vân tay không trùng khớp. Vui lòng thử lại.',
              biometricSuccess: 'Xác thực vân tay thành công',
            ),
          ],
          options: const AuthenticationOptions(
            biometricOnly: true,
            useErrorDialogs: true,
            stickyAuth: true,
          ),
        );
      } on PlatformException catch (e) {
        if (e.code == 'NotAvailable') {
          res = await _auth.authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(
              biometricOnly: false,
              useErrorDialogs: true,
              stickyAuth: true,
            ),
          );
        } else {
          rethrow;
        }
      }

      if (!res && lastError == null) {
        lastError = 'Xác thực vân tay không thành công hoặc đã bị hủy.';
      }
      return res;
    } on PlatformException catch (e) {
      if (e.code == 'auth_in_progress') {
        try {
          await _auth.stopAuthentication();
        } catch (_) {}
        lastError = 'Cảm biến đang bận, vui lòng thử chạm lại một lần nữa.';
      } else if (e.code == 'NotEnrolled') {
        lastError = 'Thiết bị chưa đăng ký vân tay/FaceID trong Cài đặt máy.';
      } else if (e.code == 'PasscodeNotSet') {
        lastError = 'Thiết bị chưa thiết lập mật khẩu/mã PIN màn hình khóa.';
      } else if (e.code == 'NotAvailable') {
        lastError = 'Cảm biến sinh trắc học hiện không khả dụng.';
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        lastError = 'Cảm biến vân tay bị tạm khóa do thử sai quá nhiều lần. Vui lòng mở khóa bằng mật khẩu máy.';
      } else {
        lastError = 'Lỗi Android Biometric (${e.code}): ${e.message}';
      }
      return false;
    } catch (e) {
      lastError = 'Lỗi xác thực: $e';
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Lưu thông tin mật khẩu phục vụ Đăng nhập vân tay
  static Future<void> saveLoginCredentials(String phone, String password) async {
    try {
      await _secureStorage.write(key: _keyPhone, value: phone);
      await _secureStorage.write(key: _keyPassword, value: password);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPhone, phone);
      await prefs.setString(_keyPassword, password);
      await prefs.setBool(_keyBiometricLogin, true);
    } catch (_) {}
  }

  /// Xoá thông tin đăng nhập vân tay
  static Future<void> clearLoginCredentials() async {
    try {
      await _secureStorage.delete(key: _keyPhone);
      await _secureStorage.delete(key: _keyPassword);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPhone);
      await prefs.remove(_keyPassword);
      await prefs.setBool(_keyBiometricLogin, false);
    } catch (_) {}
  }

  /// Lấy thông tin đăng nhập đã lưu
  static Future<Map<String, String>?> getLoginCredentials() async {
    try {
      final phone = await _secureStorage.read(key: _keyPhone);
      final password = await _secureStorage.read(key: _keyPassword);
      if (phone != null && phone.isNotEmpty && password != null && password.isNotEmpty) {
        return {'phone': phone, 'password': password};
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString(_keyPhone);
      final password = prefs.getString(_keyPassword);
      if (phone != null && phone.isNotEmpty && password != null && password.isNotEmpty) {
        return {'phone': phone, 'password': password};
      }
    } catch (_) {}
    return null;
  }

  /// Lưu mã PIN giao dịch phục vụ ký duyệt nhanh
  static Future<void> saveTransactionPin(String pin) async {
    await _secureStorage.write(key: _keyPin, value: pin);
  }

  /// Xoá PIN giao dịch
  static Future<void> clearTransactionPin() async {
    await _secureStorage.delete(key: _keyPin);
  }

  /// Lấy PIN giao dịch đã lưu
  static Future<String?> getTransactionPin() async {
    return await _secureStorage.read(key: _keyPin);
  }
}

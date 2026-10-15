import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isVerified,
  });

  final int id;
  final String fullName;
  final String phone;
  final String role;
  final bool isVerified;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    fullName: json['full_name']?.toString() ?? 'Người dùng',
    phone: json['phone']?.toString() ?? '',
    role: json['role']?.toString() ?? 'user',
    isVerified: json['is_verified'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'phone': phone,
    'role': role,
    'is_verified': isVerified,
  };
}

class TokenStorage {
  TokenStorage._();

  static const _accessTokenKey = 'ACCESS_TOKEN';
  static const _userKey = 'SESSION_USER';
  static const _cookieKey = 'HTTP_AUTH_COOKIES';
  static const _lastUserNameKey = 'LAST_USER_NAME';
  static const _lastUserPhoneKey = 'LAST_USER_PHONE';
  static const _lastUserAccountKey = 'LAST_USER_ACCOUNT';
  static const _lastUserQrUrlKey = 'LAST_USER_QR_URL';
  static const _lastUserQrDataKey = 'LAST_USER_QR_DATA';
  static const _secureStorage = FlutterSecureStorage();

  static Future<void> saveAuthData(
    String token,
    Map<String, dynamic> user,
  ) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
    await _secureStorage.write(key: _userKey, value: jsonEncode(user));

    final fullName = user['full_name']?.toString();
    final phone = user['phone']?.toString();

    final prefs = await SharedPreferences.getInstance();
    if (fullName != null && fullName.isNotEmpty) {
      await prefs.setString(_lastUserNameKey, fullName);
    }
    if (phone != null && phone.isNotEmpty) {
      await prefs.setString(_lastUserPhoneKey, phone);
    }
  }

  static Future<void> saveUserQR({
    required String qrData,
    required String qrUrl,
    required String accountNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (qrData.isNotEmpty) await prefs.setString(_lastUserQrDataKey, qrData);
    if (qrUrl.isNotEmpty) await prefs.setString(_lastUserQrUrlKey, qrUrl);
    if (accountNumber.isNotEmpty) await prefs.setString(_lastUserAccountKey, accountNumber);
  }

  static Future<String?> getLastUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUserNameKey);
  }

  static Future<String?> getLastUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUserPhoneKey);
  }

  static Future<String?> getLastUserAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUserAccountKey);
  }

  static Future<String?> getLastUserQrUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUserQrUrlKey);
  }

  static Future<String?> getLastUserQrData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUserQrDataKey);
  }

  static Future<String?> getToken() =>
      _secureStorage.read(key: _accessTokenKey);

  static Future<SessionUser?> getUser() async {
    final value = await _secureStorage.read(key: _userKey);
    if (value == null) return null;
    try {
      return SessionUser.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<String> getUserName() async =>
      (await getUser())?.fullName ?? 'Người dùng';

  static Future<void> clearAuth() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _userKey);

    // Giữ lại device_id trong cookies để nhận diện thiết bị tin cậy, chỉ xóa refresh_token
    try {
      final cookieVal = await _secureStorage.read(key: _cookieKey);
      if (cookieVal != null) {
        final decoded = jsonDecode(cookieVal);
        if (decoded is Map<String, dynamic>) {
          decoded.remove('refresh_token');
          if (decoded.isEmpty) {
            await _secureStorage.delete(key: _cookieKey);
          } else {
            await _secureStorage.write(key: _cookieKey, value: jsonEncode(decoded));
          }
        }
      }
    } catch (_) {
      await _secureStorage.delete(key: _cookieKey);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_userKey);
  }

  static Future<bool> isSmartOtpActivatedOnDevice(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('SMART_OTP_DEVICE_ACTIVATED_$userId') == true;
  }

  static Future<void> setSmartOtpActivatedOnDevice(int userId, bool activated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('SMART_OTP_DEVICE_ACTIVATED_$userId', activated);
  }
}

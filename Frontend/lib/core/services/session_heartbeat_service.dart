import 'dart:async';

import '../constants/api_url.dart';
import '../network/api_service.dart';
import '../storage/token_storage.dart';

/// Dịch vụ kiểm tra phiên định kỳ (Heartbeat) đảm bảo chế độ 1 thiết bị duy nhất.
/// Nếu tài khoản được đăng nhập ở thiết bị khác, thiết bị hiện tại sẽ ngay lập tức
/// nhận diện phiên bị hủy và bị văng ra trang đăng nhập.
class SessionHeartbeatService {
  SessionHeartbeatService._();

  static Timer? _timer;
  static bool _isChecking = false;

  /// Bắt đầu gửi tín hiệu heartbeat kiểm tra phiên định kỳ (mỗi 4 giây)
  static void start({Duration interval = const Duration(seconds: 4)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => checkSession());
  }

  /// Dừng kiểm tra phiên khi người dùng đăng xuất hoặc phiên kết thúc
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _isChecking = false;
  }

  /// Kiểm tra trạng thái phiên trực tiếp một lần
  static Future<void> checkSession() async {
    if (_isChecking) return;

    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      stop();
      return;
    }

    _isChecking = true;
    try {
      // Endpoint /auth/session-check chạy qua AuthMiddleware
      // Nếu thiết bị khác đã đăng nhập, claims.SessionVersion != user.SessionVersion
      // Request sẽ trả về HTTP 401 và ApiService tự động kích hoạt _expireSession()
      await ApiService.get(ApiUrl.sessionCheck, auth: true);
    } catch (_) {
      // Các lỗi 401 đã được ApiService xử lý tự động qua _expireSession()
    } finally {
      _isChecking = false;
    }
  }
}

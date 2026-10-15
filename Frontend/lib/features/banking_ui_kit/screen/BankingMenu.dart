import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../notifications/services/push_notification_service.dart';
import '../utils/BankingColors.dart';
import '../utils/BankingWidget.dart';

import 'BankingChangePasword.dart';
import 'BankingContact.dart';
import 'BankingNews.dart';
import 'BankingQuestionAnswer.dart';
import 'BankingRateInfo.dart';
import 'BankingTermsCondition.dart';

class BankingMenu extends StatefulWidget {
  static var tag = "/BankingMenu";

  const BankingMenu({Key? key}) : super(key: key);

  @override
  _BankingMenuState createState() => _BankingMenuState();
}

class _BankingMenuState extends State<BankingMenu> {
  SessionUser? _user;
  String _phoneOrAccount = '';
  bool _deviceSupported = false;
  bool _biometricLoginEnabled = false;
  bool _biometricTxEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkBiometrics();
  }

  Future<void> _loadUserInfo() async {
    final results = await Future.wait([
      TokenStorage.getUser(),
      TokenStorage.getLastUserAccount(),
    ]);
    final user = results[0] as SessionUser?;
    final account = results[1] as String?;
    if (mounted) {
      setState(() {
        _user = user;
        _phoneOrAccount = account ?? user?.phone ?? '';
      });
    }
  }

  Future<void> _checkBiometrics() async {
    final results = await Future.wait([
      BiometricService.isDeviceSupported(),
      BiometricService.isLoginEnabled(),
      BiometricService.isTxEnabled(),
    ]);
    if (mounted) {
      setState(() {
        _deviceSupported = results[0] as bool;
        _biometricLoginEnabled = results[1] as bool;
        _biometricTxEnabled = results[2] as bool;
      });
    }
  }

  Future<void> _toggleBiometricLogin(bool enabled) async {
    if (!_deviceSupported) {
      toast(LanguageController.instance.isEnglish
          ? 'Device does not support biometrics'
          : 'Thiết bị không hỗ trợ sinh trắc học');
      return;
    }
    final isEn = LanguageController.instance.isEnglish;
    if (enabled) {
      final savedCreds = await BiometricService.getLoginCredentials();
      String? password = savedCreds?['password'];
      String phone = savedCreds?['phone'] ?? _user?.phone ?? await TokenStorage.getLastUserPhone() ?? '';

      // Chỉ khi máy chưa từng lưu mật khẩu trước đó mới cần hỏi mật khẩu 1 lần
      if (password == null || password.isEmpty) {
        password = await showDialog<String>(
          context: context,
          builder: (ctx) => _buildPasswordPromptDialog(ctx, isEn),
        );
        if (password == null || password.trim().isEmpty) {
          if (mounted) setState(() => _biometricLoginEnabled = false);
          return;
        }
        // Đợi dialog hoàn tất animation đóng trước khi mở cảm biến vân tay Android
        await Future.delayed(const Duration(milliseconds: 350));
      }

      final success = await BiometricService.authenticate(
        reason: isEn
            ? 'Authenticate biometrics to enable quick login'
            : 'Xác thực sinh trắc học để kích hoạt đăng nhập nhanh',
      );

      if (success) {
        if (phone.isEmpty) {
          phone = _user?.phone ?? await TokenStorage.getLastUserPhone() ?? '';
        }
        if (phone.isNotEmpty && password.isNotEmpty) {
          await BiometricService.saveLoginCredentials(phone, password.trim());
        }
        await BiometricService.setLoginEnabled(true);
        if (mounted) {
          setState(() => _biometricLoginEnabled = true);
          toast(isEn ? 'Biometric login enabled' : 'Đã bật đăng nhập bằng sinh trắc học');
        }
      } else {
        if (mounted) {
          setState(() => _biometricLoginEnabled = false);
          final err = BiometricService.lastError;
          toast(err != null && err.isNotEmpty
              ? err
              : (isEn ? 'Biometric authentication cancelled' : 'Chưa xác thực được vân tay hoặc đã hủy'));
        }
      }
    } else {
      await BiometricService.setLoginEnabled(false);
      if (mounted) {
        setState(() => _biometricLoginEnabled = false);
        toast(isEn ? 'Biometric login disabled' : 'Đã tắt đăng nhập bằng sinh trắc học');
      }
    }
  }

  Future<void> _toggleBiometricTx(bool enabled) async {
    if (!_deviceSupported) {
      toast(LanguageController.instance.isEnglish
          ? 'Device does not support biometrics'
          : 'Thiết bị không hỗ trợ sinh trắc học');
      return;
    }
    final isEn = LanguageController.instance.isEnglish;
    if (enabled) {
      final pin = await showDialog<String>(
        context: context,
        builder: (ctx) => _buildPinPromptDialog(ctx, isEn),
      );
      if (pin == null || pin.length != 6) {
        if (mounted) setState(() => _biometricTxEnabled = false);
        return;
      }
      // Đợi dialog hoàn tất animation đóng trước khi mở cảm biến vân tay Android
      await Future.delayed(const Duration(milliseconds: 350));

      final success = await BiometricService.authenticate(
        reason: isEn
            ? 'Authenticate biometrics to link Transaction PIN'
            : 'Xác thực sinh trắc học để liên kết PIN giao dịch',
      );
      if (success) {
        await BiometricService.saveTransactionPin(pin);
        await BiometricService.setTxEnabled(true);
        if (mounted) {
          setState(() => _biometricTxEnabled = true);
          toast(isEn ? 'Biometric transaction authentication enabled' : 'Đã bật xác thực giao dịch bằng sinh trắc học');
        }
      } else {
        if (mounted) {
          setState(() => _biometricTxEnabled = false);
          final err = BiometricService.lastError;
          toast(err != null && err.isNotEmpty
              ? err
              : (isEn ? 'Biometric authentication cancelled' : 'Chưa xác thực được vân tay hoặc đã hủy'));
        }
      }
    } else {
      await BiometricService.clearTransactionPin();
      await BiometricService.setTxEnabled(false);
      if (mounted) {
        setState(() => _biometricTxEnabled = false);
        toast(isEn ? 'Biometric transaction authentication disabled' : 'Đã tắt xác thực giao dịch bằng sinh trắc học');
      }
    }
  }

  Widget _buildPasswordPromptDialog(BuildContext ctx, bool isEn) {
    final controller = TextEditingController();
    final isDark = ThemeController.instance.isDarkMode;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E0E30) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEn ? 'Confirm Password' : 'Xác nhận mật khẩu',
        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF562875)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn
                ? 'Please enter your password to save biometric login credentials.'
                : 'Vui lòng nhập mật khẩu tài khoản của bạn để lưu thông tin đăng nhập sinh trắc học.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: isEn ? 'Password' : 'Mật khẩu',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF562875)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(isEn ? 'Cancel' : 'Hủy', style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF7941D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(isEn ? 'Confirm' : 'Xác nhận'),
        ),
      ],
    );
  }

  Widget _buildPinPromptDialog(BuildContext ctx, bool isEn) {
    final controller = TextEditingController();
    final isDark = ThemeController.instance.isDarkMode;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E0E30) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEn ? 'Confirm Transaction PIN' : 'Xác nhận mã PIN',
        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF562875)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn
                ? 'Please enter your 6-digit PIN to enable biometric transaction authentication.'
                : 'Vui lòng nhập mã PIN giao dịch 6 số hiện tại để kích hoạt sinh trắc học.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              counterText: '',
              labelText: isEn ? '6-digit PIN' : 'Mã PIN 6 số',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF562875)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(isEn ? 'Cancel' : 'Hủy', style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF7941D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(isEn ? 'Confirm' : 'Xác nhận'),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    try {
      await PushNotificationService.instance.unregister();
    } catch (_) {}
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        final isDark = ThemeController.instance.isDarkMode;
        final isEn = LanguageController.instance.isEnglish;
        final userName = _user?.fullName ?? 'NF BANK USER';
        final userSub = _phoneOrAccount.isNotEmpty ? _phoneOrAccount : (_user?.phone ?? '');

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF140824) : const Color(0xFFF6F5FA),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 24),
                Text(
                  isEn ? 'Menu & Settings' : 'Menu & Cài đặt',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF562875),
                  ),
                ),
                const SizedBox(height: 18),

                // Profile Card TPBank Violet Style
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1F0D33), const Color(0xFF12071F)]
                          : [const Color(0xFF562875), const Color(0xFF3B1554)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF562875).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFFF7941D),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'N',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'STK: $userSub',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7941D).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF7941D)),
                              ),
                              child: Text(
                                isEn ? 'TPBank Digital Customer' : 'Khách hàng Ngân hàng số TPBank',
                                style: const TextStyle(color: Color(0xFFFFC107), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Settings Group 1: Security
                _buildSectionHeader(isEn ? 'Security & Preferences' : 'Cài đặt & Bảo mật', isDark),
                const SizedBox(height: 10),
                _buildCardContainer(
                  isDark: isDark,
                  children: [
                    _buildTile(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF562875),
                      title: isEn ? 'Change Password' : 'Đổi mật khẩu',
                      onTap: () => BankingChangePassword().launch(context),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.fingerprint_rounded, color: Color(0xFFF7941D), size: 22),
                      ),
                      title: Text(
                        isEn ? 'Biometric Login' : 'Đăng nhập Vân tay / FaceID',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        isEn ? 'Log in quickly without typing password' : 'Đăng nhập nhanh không cần nhập mật khẩu',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
                      ),
                      trailing: Switch(
                        value: _biometricLoginEnabled,
                        activeColor: const Color(0xFFF7941D),
                        onChanged: _toggleBiometricLogin,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF562875).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.security_rounded, color: Color(0xFF562875), size: 22),
                      ),
                      title: Text(
                        isEn ? 'Biometric Transactions' : 'Xác thực Chuyển tiền bằng Vân tay',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        isEn ? 'Use biometric instead of typing 6-digit PIN' : 'Ký duyệt giao dịch thay thế mã PIN 6 số',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
                      ),
                      trailing: Switch(
                        value: _biometricTxEnabled,
                        activeColor: const Color(0xFFF7941D),
                        onChanged: _toggleBiometricTx,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.language_rounded, color: Colors.blue, size: 22),
                      ),
                      title: Text(
                        isEn ? 'Language (English)' : 'Ngôn ngữ (Tiếng Việt)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      trailing: IconButton(
                        icon: Text(isEn ? '🇬🇧' : '🇻🇳', style: const TextStyle(fontSize: 22)),
                        onPressed: () => LanguageController.instance.toggleLanguage(),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.purple, size: 22),
                      ),
                      title: Text(
                        isDark ? (isEn ? 'Light Theme' : 'Giao diện Sáng') : (isEn ? 'Dark Theme' : 'Giao diện Tối'),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      trailing: Switch(
                        value: isDark,
                        activeColor: const Color(0xFFF7941D),
                        onChanged: (val) => ThemeController.instance.toggleTheme(val),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Settings Group 2: Information & Utilities
                _buildSectionHeader(isEn ? 'Information & Help' : 'Thông tin & Hỗ trợ', isDark),
                const SizedBox(height: 10),
                _buildCardContainer(
                  isDark: isDark,
                  children: [
                    _buildTile(
                      icon: Icons.newspaper_rounded,
                      iconColor: Colors.blue,
                      title: isEn ? 'Banking News' : 'Tin tức ngân hàng',
                      onTap: () => BankingNews().launch(context),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildTile(
                      icon: Icons.show_chart_rounded,
                      iconColor: Colors.green,
                      title: isEn ? 'Interest Rate Table' : 'Thông tin lãi suất',
                      onTap: () => BankingRateInfo().launch(context),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildTile(
                      icon: Icons.help_outline_rounded,
                      iconColor: Colors.amber,
                      title: isEn ? 'Q&A & Help' : 'Hỏi đáp & Trợ giúp',
                      onTap: () => BankingQuestionAnswer().launch(context),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildTile(
                      icon: Icons.support_agent_rounded,
                      iconColor: Colors.teal,
                      title: isEn ? 'Customer Support' : 'Liên hệ hỗ trợ 24/7',
                      onTap: () => BankingContact().launch(context),
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Logout Button
                _buildCardContainer(
                  isDark: isDark,
                  children: [
                    _buildTile(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.redAccent,
                      title: isEn ? 'Log Out' : 'Đăng xuất tài khoản',
                      onTap: () => _showLogoutDialog(context),
                      isDark: isDark,
                      titleColor: Colors.redAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : Colors.grey[700],
      ),
    );
  }

  Widget _buildCardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF26133B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    Color? titleColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: titleColor ?? (isDark ? Colors.white : Colors.black87),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEn ? 'Confirm Logout' : 'Xác nhận Đăng xuất', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          isEn ? 'Are you sure you want to log out of TPBank?' : 'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(isEn ? 'Cancel' : 'Hủy', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEn ? 'Log Out' : 'Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

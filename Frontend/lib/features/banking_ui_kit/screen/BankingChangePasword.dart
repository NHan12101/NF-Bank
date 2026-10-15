import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../../core/constants/api_url.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../utils/BankingColors.dart';

class BankingChangePassword extends StatefulWidget {
  static var tag = "/BankingChangePassword";

  const BankingChangePassword({Key? key}) : super(key: key);

  @override
  _BankingChangePasswordState createState() => _BankingChangePasswordState();
}

class _BankingChangePasswordState extends State<BankingChangePassword> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _oldHidden = true;
  bool _newHidden = true;
  bool _confirmHidden = true;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isEn = LanguageController.instance.isEnglish;
    final oldPass = _oldController.text.trim();
    final newPass = _newController.text.trim();
    final confirmPass = _confirmController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      toasty(context, isEn ? 'Please fill in all password fields' : 'Vui lòng nhập đầy đủ các trường mật khẩu');
      return;
    }
    if (newPass.length < 8) {
      toasty(context, isEn ? 'New password must be at least 8 characters' : 'Mật khẩu mới phải từ 8 ký tự trở lên');
      return;
    }
    if (newPass != confirmPass) {
      toasty(context, isEn ? 'New passwords do not match' : 'Mật khẩu mới nhập lại không khớp');
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiService.post(
        ApiUrl.changePassword,
        auth: true,
        body: {'old_password': oldPass, 'new_password': newPass},
      );
      if (!mounted) return;
      toasty(context, isEn ? 'Password changed successfully!' : 'Đổi mật khẩu thành công!');
      finish(context);
    } on ApiException catch (e) {
      if (mounted) toasty(context, e.message);
    } catch (e) {
      if (mounted) toasty(context, isEn ? 'An error occurred, please try again' : 'Có lỗi xảy ra, vui lòng thử lại sau');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF140824) : const Color(0xFFF6F5FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF562875),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              isEn ? 'Change Password' : 'Đổi mật khẩu',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Image.asset(
                    'assets/images/logo_transparent.png',
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    isEn ? 'Enhance Account Security' : 'Tăng cường bảo mật tài khoản',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF562875),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Card form
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF26133B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Current Password
                      TextField(
                        controller: _oldController,
                        obscureText: _oldHidden,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: isEn ? 'Current Password' : 'Mật khẩu hiện tại',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF562875)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E0E30) : const Color(0xFFF5F2F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            icon: Icon(_oldHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF562875)),
                            onPressed: () => setState(() => _oldHidden = !_oldHidden),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Password
                      TextField(
                        controller: _newController,
                        obscureText: _newHidden,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: isEn ? 'New Password' : 'Mật khẩu mới',
                          prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF562875)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E0E30) : const Color(0xFFF5F2F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            icon: Icon(_newHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF562875)),
                            onPressed: () => setState(() => _newHidden = !_newHidden),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      TextField(
                        controller: _confirmController,
                        obscureText: _confirmHidden,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: isEn ? 'Confirm New Password' : 'Nhập lại mật khẩu mới',
                          prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF562875)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E0E30) : const Color(0xFFF5F2F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            icon: Icon(_confirmHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF562875)),
                            onPressed: () => setState(() => _confirmHidden = !_confirmHidden),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF7941D),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        child: _loading
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEn ? 'CONFIRM CHANGE' : 'XÁC NHẬN ĐỔI MẬT KHẨU'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

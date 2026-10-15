import 'package:flutter/material.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';

class BankingTermsCondition extends StatefulWidget {
  static var tag = "/BankingTermsCondition";

  const BankingTermsCondition({Key? key}) : super(key: key);

  @override
  _BankingTermsConditionState createState() => _BankingTermsConditionState();
}

class _BankingTermsConditionState extends State<BankingTermsCondition> {
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
              isEn ? 'Terms & Conditions' : 'Điều khoản sử dụng',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF26133B) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'TPBank Digital Service Agreement' : 'Thỏa thuận Sử dụng Ngân hàng số TPBank',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF562875),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTermPoint(
                    isEn
                        ? '1. All transactions performed on TPBank mobile application are encrypted with SSL 256-bit security standards.'
                        : '1. Mọi giao dịch thực hiện trên ứng dụng ngân hàng số TPBank được mã hóa an toàn theo tiêu chuẩn SSL 256-bit.',
                    isDark,
                  ),
                  _buildTermPoint(
                    isEn
                        ? '2. Customers are responsible for protecting their login password, OTP, and transaction PIN code.'
                        : '2. Khách hàng có trách nhiệm bảo mật thông tin đăng nhập, mã OTP và mã PIN giao dịch của cá nhân.',
                    isDark,
                  ),
                  _buildTermPoint(
                    isEn
                        ? '3. Fast transfers 24/7 are processed instantly through Napas & internal bank network.'
                        : '3. Chuyển tiền nhanh Napas 24/7 được xử lý ngay lập tức thông qua hệ thống ngân hàng liên kết.',
                    isDark,
                  ),
                  _buildTermPoint(
                    isEn
                        ? '4. TPBank offers free online transfers and zero maintenance fee for active digital accounts.'
                        : '4. TPBank miễn phí chuyển tiền online và không thu phí duy trì cho tài khoản ngân hàng số.',
                    isDark,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTermPoint(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
}

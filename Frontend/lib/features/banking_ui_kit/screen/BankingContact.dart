import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../utils/BankingColors.dart';

class BankingContact extends StatefulWidget {
  static var tag = "/BankingContact";

  const BankingContact({Key? key}) : super(key: key);

  @override
  _BankingContactState createState() => _BankingContactState();
}

class _BankingContactState extends State<BankingContact> {
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
              isEn ? 'Customer Support 24/7' : 'Liên hệ Hỗ trợ 24/7',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF562875), Color(0xFF3B1554)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF562875).withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7941D).withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.headset_mic_rounded, color: Color(0xFFF7941D), size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'TPBank Support Care' : 'Tổng đài Chăm sóc TPBank',
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEn ? 'Always ready to assist you anytime' : 'Luôn sẵn sàng hỗ trợ quý khách 24/7',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Info Cards
                Container(
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
                        isEn ? 'Headquarters' : 'Trụ sở chính',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF562875),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildContactRow(
                        icon: Icons.location_on_rounded,
                        color: const Color(0xFF562875),
                        title: isEn ? 'Address' : 'Địa chỉ',
                        subtitle: 'Tòa nhà TPBank, 57 Lý Thường Kiệt, Hoàn Kiếm, Hà Nội',
                        isDark: isDark,
                      ),
                      const Divider(height: 24),
                      _buildContactRow(
                        icon: Icons.phone_in_talk_rounded,
                        color: const Color(0xFFF7941D),
                        title: isEn ? 'Hotline 24/7' : 'Tổng đài 24/7',
                        subtitle: '1900 58 58 85 / 1900 1234',
                        isDark: isDark,
                      ),
                      const Divider(height: 24),
                      _buildContactRow(
                        icon: Icons.email_rounded,
                        color: Colors.blue,
                        title: 'Email',
                        subtitle: 'dichvukhachhang@tpb.com.vn',
                        isDark: isDark,
                      ),
                      const Divider(height: 24),
                      _buildContactRow(
                        icon: Icons.language_rounded,
                        color: Colors.green,
                        title: 'Website',
                        subtitle: 'www.tpb.vn / www.nfbank.com.vn',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600])),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

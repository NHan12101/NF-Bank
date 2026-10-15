import 'package:flutter/material.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../transfers/screens/qr_scanner_page.dart';

class TPBankBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCenterQRTap;

  const TPBankBottomBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.onCenterQRTap,
  }) : super(key: key);

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

        final barBgColor = isDark
            ? const Color(0xFF231038).withOpacity(0.96)
            : Colors.white.withOpacity(0.95);

        return Container(
          height: 96,
          margin: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Custom Painter notched background bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 66,
                child: CustomPaint(
                  painter: TPBankBottomBarPainter(
                    color: barBgColor,
                    shadowColor: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                  ),
                ),
              ),

              // Bottom 5 Nav items row
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 66,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Item 0: Trang chủ
                    Expanded(
                      child: _buildNavItem(
                        index: 0,
                        label: isEn ? 'Home' : 'Trang Chủ',
                        iconWidget: Image.asset(
                          'assets/images/logo_transparent.png',
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                        isSelected: currentIndex == 0,
                        onTap: () => onTap(0),
                        isDark: isDark,
                      ),
                    ),

                    // Khoảng trống cho nút QR nổi ở giữa
                    const SizedBox(width: 80),

                    // Item 1: Cá nhân
                    Expanded(
                      child: _buildNavItem(
                        index: 1,
                        label: isEn ? 'Profile' : 'Cá Nhân',
                        iconData: Icons.person_outline_rounded,
                        isSelected: currentIndex == 1,
                        onTap: () => onTap(1),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),

              // Center Floating Gradient QR Button
              Positioned(
                bottom: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (onCenterQRTap != null) {
                          onCenterQRTap!();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QRScannerPage()),
                          );
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF9C3CE6), Color(0xFF562875)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF562875).withOpacity(0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isEn ? 'Scan QR' : 'Quét mọi QR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF6C6C6C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    IconData? iconData,
    Widget? iconWidget,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeColor = const Color(0xFF562875);
    final inactiveColor = isDark ? Colors.white54 : const Color(0xFF757575);

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconWidget != null)
            iconWidget
          else
            Icon(
              iconData,
              size: 24,
              color: isSelected ? activeColor : inactiveColor,
            ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class TPBankBottomBarPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  TPBankBottomBarPainter({required this.color, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path();
    const radius = 24.0;
    const notchRadius = 34.0;
    final centerX = size.width / 2;

    path.moveTo(radius, 0);
    path.lineTo(centerX - notchRadius - 10, 0);
    path.cubicTo(
      centerX - notchRadius + 2, 0,
      centerX - notchRadius + 6, notchRadius,
      centerX, notchRadius,
    );
    path.cubicTo(
      centerX + notchRadius - 6, notchRadius,
      centerX + notchRadius - 2, 0,
      centerX + notchRadius + 10, 0,
    );
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

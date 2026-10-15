import 'package:flutter/material.dart';

import '../../../../core/theme/language_controller.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.onScanQR,
    required this.onMyQR,
  });

  final VoidCallback onScanQR;
  final VoidCallback onMyQR;

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    return Row(
      children: [
        Expanded(
          child: QuickActionBtn(
            icon: Icons.qr_code_scanner_rounded,
            label: isEn ? 'Scan QR Code' : 'Quét mã QR',
            onTap: onScanQR,
            colors: const [Color(0xFF7C83FD), Color(0xFF4D5CE5)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: QuickActionBtn(
            icon: Icons.qr_code_rounded,
            label: isEn ? 'My QR Code' : 'QR của tôi',
            onTap: onMyQR,
            colors: const [Color(0xFF8F95FF), Color(0xFF6C73F0)],
          ),
        ),
      ],
    );
  }
}

class QuickActionBtn extends StatelessWidget {
  const QuickActionBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

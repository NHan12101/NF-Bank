import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/vietqr_parser.dart';
import 'merchant_checkout_page.dart';
import 'my_qr_page.dart';
import 'transfer_page.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;
  double _zoomScale = 0.0;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleScannedValue(String value) {
    if (_isProcessing) return;

    final parsed = VietQRParser.parse(value);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã QR không đúng định dạng VietQR hoặc NF Bank!'),
          backgroundColor: Color(0xFFFF5C72),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    _scannerController.stop();

    if (parsed['type'] == 'PAYMENT') {
      final token = parsed['token'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải thông tin thanh toán hóa đơn...'),
          backgroundColor: Color(0xFF7C83FD),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MerchantCheckoutPage(token: token),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nhận diện tài khoản: ${parsed['account']}'),
          backgroundColor: const Color(0xFF68D391),
        ),
      );

      final amount = int.tryParse(parsed['amount'] ?? '') ?? 0;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TransferPage(
            preFilledAccount: parsed['account'],
            preFilledAmount: amount > 0 ? amount : null,
            preFilledDescription: parsed['description'],
          ),
        ),
      );
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  void _onZoomChanged(double value) {
    setState(() => _zoomScale = value);
    _scannerController.setZoomScale(value);
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bộ nhớ tạm không có dữ liệu văn bản!'),
              backgroundColor: Color(0xFFFF5C72),
            ),
          );
        }
        return;
      }
      _handleScannedValue(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể đọc bộ nhớ tạm: $e'),
            backgroundColor: const Color(0xFFFF5C72),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final BarcodeCapture? capture = await _scannerController.analyzeImage(file.path);
      final barcodes = capture?.barcodes;
      if (barcodes != null && barcodes.isNotEmpty) {
        for (final barcode in barcodes) {
          final val = barcode.rawValue;
          if (val != null && val.isNotEmpty) {
            _handleScannedValue(val);
            return;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy mã QR hợp lệ trong hình ảnh đã chọn!'),
            backgroundColor: Color(0xFFFF5C72),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể quét ảnh: $e'),
            backgroundColor: const Color(0xFFFF5C72),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          // Tính kích thước và vị trí khung ngắm (Cutout)
          final boxWidth = math.min(screenWidth * 0.90, 380.0);
          final boxHeight = math.min(screenWidth * 0.90 * 1.16, 420.0);
          final boxLeft = (screenWidth - boxWidth) / 2;
          final boxTop = (screenHeight - boxHeight) * 0.44;
          final cutoutRect = Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight);

          return Stack(
            children: [
              // 1. Toàn màn hình Camera Preview
              Positioned.fill(
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final val = barcode.rawValue;
                      if (val != null && val.isNotEmpty) {
                        _handleScannedValue(val);
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error, child) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.videocam_off_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Lỗi máy ảnh: ${error.errorCode.name}',
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _scannerController.start(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 2. Lớp phủ đen làm mờ vùng bên ngoài khung ngắm
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScannerCutoutPainter(
                    cutoutRect: cutoutRect,
                    borderRadius: 28.0,
                    overlayColor: Colors.black.withValues(alpha: 0.58),
                  ),
                ),
              ),

              // 3. Toàn bộ UI Controls & Thông tin điều hướng
              Positioned.fill(
                child: SafeArea(
                  child: Column(
                    children: [
                      // --- Header AppBar ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                              tooltip: 'Quay lại',
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text(
                              'Quét mã QR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                color: _isTorchOn ? const Color(0xFFFFD54F) : Colors.white,
                                size: 24,
                              ),
                              tooltip: _isTorchOn ? 'Tắt đèn Flash' : 'Bật đèn Flash',
                              onPressed: _toggleTorch,
                            ),
                          ],
                        ),
                      ),

                      // --- Thông tin giới thiệu ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Quét mã QR để thực hiện thanh toán, rút tiền mặt,\nchuyển tiền song phương, hoặc ',
                              ),
                              TextSpan(
                                text: 'napas',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              TextSpan(
                                text: '247',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF00D287),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // --- Nút Zoom Slider ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            const Text(
                              '—',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.white38,
                                  inactiveTrackColor: Colors.white24,
                                  trackHeight: 2.0,
                                  thumbColor: Colors.white,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7.0,
                                  ),
                                  overlayColor: Colors.white.withValues(alpha: 0.15),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                ),
                                child: Slider(
                                  value: _zoomScale,
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: _onZoomChanged,
                                ),
                              ),
                            ),
                            const Text(
                              '+',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 20,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // --- Nút hành động đáy "Tạo QR nhận tiền" ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MyQRPage()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                            backgroundColor: Colors.black.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tạo QR nhận tiền',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              // 4. Thanh Pill nổi bên trong đáy khung ngắm: [ Dán mã QR | Chọn QR từ ảnh ]
              Positioned(
                left: boxLeft + 16,
                right: boxLeft + 16,
                top: boxTop + boxHeight - 58,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F222E).withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nút Dán mã QR
                        InkWell(
                          onTap: _pasteFromClipboard,
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Dán mã QR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Đường gạch ngăn cách
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            width: 1,
                            height: 14,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),

                        // Nút Chọn QR từ ảnh
                        InkWell(
                          onTap: _pickImageFromGallery,
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.photo_library_outlined, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Chọn QR từ ảnh',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Lớp vẽ CustomPainter tạo hiệu ứng đục lỗ (Cutout) bo tròn thẩm mỹ
class _ScannerCutoutPainter extends CustomPainter {
  const _ScannerCutoutPainter({
    required this.cutoutRect,
    required this.borderRadius,
    required this.overlayColor,
  });

  final Rect cutoutRect;
  final double borderRadius;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutRRect = RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius));
    final cutoutPath = Path()..addRRect(cutoutRRect);

    // Đục lỗ cutout
    final transparentPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(transparentPath, Paint()..color = overlayColor);

    // Vẽ viền bo tròn nhẹ xung quanh khung ngắm
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(cutoutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCutoutPainter oldDelegate) {
    return oldDelegate.cutoutRect != cutoutRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

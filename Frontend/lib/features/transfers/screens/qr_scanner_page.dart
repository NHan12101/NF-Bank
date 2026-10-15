import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/vietqr_parser.dart';
import 'transfer_page.dart';
import 'merchant_checkout_page.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            tooltip: 'Bật/Tắt đèn Flash',
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
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
          // Khung ngắm quét QR thẩm mỹ
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF7C83FD),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.black.withValues(alpha: .15),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Text(
              'Đặt mã VietQR vào trung tâm để quét',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

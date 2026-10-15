import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../shared/widgets/common.dart';
import '../utils/vietqr_parser.dart';
import 'transfer_page.dart';
import 'merchant_checkout_page.dart';
import '../services/payment_repository.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _simulateController = TextEditingController();
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _simulateController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleScannedValue(String value) {
    if (_isProcessing) return;
    
    final parsed = VietQRParser.parse(value);
    if (parsed == null) {
      // Báo lỗi định dạng mã QR không hợp lệ
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
      // Hiển thị thông báo bóc tách thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nhận diện tài khoản: ${parsed['account']}'),
          backgroundColor: const Color(0xFF68D391),
        ),
      );

      // Điền sẵn và điều hướng sang trang chuyển khoản
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

  // Tạo mã VietQR giả lập nhanh để kiểm tra
  void _simulateMockQR(String accountNumber, int amount, String description) {
    // Tạo chuỗi VietQR tĩnh/động giả lập
    // BIN: 970499
    // Tag 00: 000201
    // Tag 01: 010212 (dynamic) hoặc 010211 (static)
    final method = amount > 0 ? '010212' : '010211';
    
    final guid = '0010A000000727';
    final subBin = '0006970499';
    final subAcc = '01${accountNumber.length.toString().padLeft(2, '0')}$accountNumber';
    final beneficiary = '01${(subBin.length + subAcc.length).toString().padLeft(2, '0')}$subBin$subAcc';
    final service = '0208QRIBFTTA';
    
    final tag38Val = '$guid$beneficiary$service';
    final tag38 = '38${tag38Val.length.toString().padLeft(2, '0')}$tag38Val';
    
    final mcc = '52046011';
    final currency = '5303704';
    
    final amountStr = amount > 0 
        ? '54${amount.toString().length.toString().padLeft(2, '0')}$amount' 
        : '';
        
    final country = '5802VN';
    
    final descTag = description.isNotEmpty 
        ? '08${description.length.toString().padLeft(2, '0')}$description' 
        : '';
    final additional = description.isNotEmpty 
        ? '62${descTag.length.toString().padLeft(2, '0')}$descTag' 
        : '';
        
    final raw = '000201$method$tag38$mcc$currency$amountStr$country${additional}6304';
    
    // Tính CRC-16 giả định
    var crc = 0xFFFF;
    for (var i = 0; i < raw.length; i++) {
      crc ^= raw.codeUnitAt(i) << 8;
      for (var j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
      }
    }
    final crcStr = (crc & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
    final mockVietQR = '$raw$crcStr';

    _simulateController.text = mockVietQR;
    _handleScannedValue(mockVietQR);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã QR'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7C83FD),
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt_outlined), text: 'Quét Camera'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Giả lập Quét (Test)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Tránh xung đột cử chỉ camera
        children: [
          // 1. Quét Camera
          Stack(
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
                          const Icon(Icons.videocam_off_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Lỗi camera: ${error.errorCode.name}',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _tabController.animateTo(1),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Chuyển sang Giả lập Quét'),
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
                      border: Border.all(color: const Color(0xFF7C83FD), width: 3),
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

          // 2. Giả lập Quét (Phục vụ Test)
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const PageTitle(
                'Giả lập Quét QR',
                subtitle: 'Dán chuỗi VietQR hoặc sử dụng các phím tắt nhanh để thử nghiệm chuyển khoản trên máy ảo.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _simulateController,
                maxLines: 5,
                decoration: fieldDecoration(
                  'Dán chuỗi mã VietQR hoặc URL nội bộ tại đây',
                ).copyWith(
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _handleScannedValue(_simulateController.text.trim()),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Phân tích và Chuyển khoản'),
              ),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 14),
              const Text(
                'Tạo nhanh mã quét thử nghiệm (Mock Accounts):',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Super Admin (Không số tiền)'),
                    onPressed: () => _simulateMockQR('970499999999', 0, 'Quyet toan noi bo'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Super Admin (50,000 VND)'),
                    onPressed: () => _simulateMockQR('970499999999', 50000, 'Tra tien ca phe'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: const Text('TK Test 1 (200,000 VND)'),
                    onPressed: () => _simulateMockQR('970408123456', 200000, 'Mock chuyen tien'),
                  ),
                  ActionChip(
                    backgroundColor: const Color(0xFF7C83FD).withValues(alpha: .15),
                    avatar: const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFF9EA4FF)),
                    label: const Text('Giả lập Thanh toán Đối tác (50k)', style: TextStyle(color: Color(0xFF9EA4FF))),
                    onPressed: () async {
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đang tạo đơn hàng thanh toán đối tác...')),
                        );
                        final token = await const PaymentRepository().testCreatePayment(
                          amount: 50000,
                          orderInfo: 'Thanh toán hóa đơn cửa hàng đối tác',
                        );
                        _handleScannedValue('nfbank://payment?token=$token');
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi tạo đơn hàng: $e'),
                            backgroundColor: const Color(0xFFFF5C72),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

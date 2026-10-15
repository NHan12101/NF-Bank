import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/storage/token_storage.dart';
import '../services/transfer_repository.dart';
import '../utils/vietqr_parser.dart';

class UserReceiveQRDialog extends StatefulWidget {
  const UserReceiveQRDialog({
    super.key,
    this.userName,
    this.userAccount,
    this.qrData,
    this.qrUrl,
  });

  final String? userName;
  final String? userAccount;
  final String? qrData;
  final String? qrUrl;

  static Future<void> show(
    BuildContext context, {
    String? userName,
    String? userAccount,
    String? qrData,
    String? qrUrl,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => UserReceiveQRDialog(
        userName: userName,
        userAccount: userAccount,
        qrData: qrData,
        qrUrl: qrUrl,
      ),
    );
  }

  @override
  State<UserReceiveQRDialog> createState() => _UserReceiveQRDialogState();
}

class _UserReceiveQRDialogState extends State<UserReceiveQRDialog> {
  final GlobalKey _repaintKey = GlobalKey();

  String _name = '';
  String _account = '';
  String _qrData = '';
  String _qrUrl = '';

  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    _name = widget.userName?.trim() ?? '';
    _account = widget.userAccount?.trim() ?? '';
    _qrData = widget.qrData?.trim() ?? '';
    _qrUrl = widget.qrUrl?.trim() ?? '';

    // Nếu thiếu thông tin, cố gắng đọc từ TokenStorage
    if (_name.isEmpty) {
      _name = (await TokenStorage.getLastUserName()) ?? '';
    }
    if (_account.isEmpty) {
      _account = (await TokenStorage.getLastUserAccount()) ?? '';
    }
    if (_qrData.isEmpty) {
      _qrData = (await TokenStorage.getLastUserQrData()) ?? '';
    }
    if (_qrUrl.isEmpty) {
      _qrUrl = (await TokenStorage.getLastUserQrUrl()) ?? '';
    }

    // Nếu vẫn chưa có QR Data nhưng có số tài khoản, tự sinh chuỗi VietQR chuẩn EMVCo
    if (_qrData.isEmpty && _account.isNotEmpty && _account.startsWith('9704')) {
      _qrData = _generateVietQRString(_account);
    }

    // Nếu đã đăng nhập và chưa có qrData, gọi API lấy thông tin chính xác
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty && (_qrData.isEmpty || _account.isEmpty)) {
      if (mounted) setState(() => _loading = true);
      try {
        final result = await const TransferRepository().getMyStaticQR();
        final fetchedData = result['qr_data']?.toString() ?? '';
        final fetchedUrl = result['qr_url']?.toString() ?? '';
        if (fetchedData.isNotEmpty) {
          _qrData = fetchedData;
          _qrUrl = fetchedUrl;
          final extractedAcc = _extractAccountFromData(fetchedData);
          if (extractedAcc.isNotEmpty) {
            _account = extractedAcc;
          }
          await TokenStorage.saveUserQR(
            qrData: _qrData,
            qrUrl: _qrUrl,
            accountNumber: _account,
          );
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }

    if (mounted) setState(() {});
  }

  String _extractAccountFromData(String data) {
    final parsed = VietQRParser.parse(data);
    if (parsed != null && parsed['account'] != null && parsed['account']!.isNotEmpty) {
      return parsed['account']!;
    }
    final match = RegExp(r'9704\d{8}').firstMatch(data);
    if (match != null) return match.group(0)!;
    return '';
  }

  /// Sinh chuỗi VietQR chuẩn EMVCo 100% đồng bộ với Backend
  String _generateVietQRString(String accountNumber, {String bin = '970499'}) {
    const payloadFormat = '000201';
    const initiationMethod = '010211';
    const guid = '0010A000000727';

    final subBin = '0006$bin';
    final subAcc = '01${accountNumber.length.toString().padLeft(2, '0')}$accountNumber';
    final beneficiary = '01${(subBin.length + subAcc.length).toString().padLeft(2, '0')}$subBin$subAcc';
    const service = '0208QRIBFTTA';

    final tag38Value = '$guid$beneficiary$service';
    final tag38 = '38${tag38Value.length.toString().padLeft(2, '0')}$tag38Value';

    const mcc = '52046011';
    const currency = '5303704';
    const country = '5802VN';
    const crcPrefix = '6304';

    final rawQR = '$payloadFormat$initiationMethod$tag38$mcc$currency$country$crcPrefix';
    final checksum = _calculateCRC16(rawQR);
    return '$rawQR$checksum';
  }

  String _calculateCRC16(String data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      crc ^= (data.codeUnitAt(i) << 8) & 0xFFFF;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  Future<void> _saveQRImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Không tìm thấy vùng QR');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('Không thể tạo ảnh QR');

      var hasAccess = await Gal.hasAccess();
      if (!hasAccess) hasAccess = await Gal.requestAccess();
      if (!hasAccess) throw StateError('Chưa cấp quyền lưu ảnh');

      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'NFBank_Receive_QR_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu ảnh QR nhận tiền vào bộ sưu tập'),
            backgroundColor: Color(0xFF562875),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu ảnh QR vào bộ sưu tập'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copyAccountNumber() {
    if (_account.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _account));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã sao chép số tài khoản: $_account'),
          backgroundColor: const Color(0xFF562875),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final isEn = LanguageController.instance.isEnglish;

    final displayName = _name.isNotEmpty ? _name : 'NF BANK USER';
    final displayAccount = _account.isNotEmpty ? _account : '...';

    // Xác định dữ liệu hiển thị QR
    final qrDataToRender = _qrData.isNotEmpty
        ? _qrData
        : (_account.isNotEmpty && _account.startsWith('9704') ? _generateVietQRString(_account) : '');

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1F0D33) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Tiêu đề + Nút đóng X
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? 'Receive QR Code' : 'Mã QR nhận tiền',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF562875),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: isEn ? 'Close' : 'Đóng',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Vùng Thẻ QR (Dùng RepaintBoundary để tải ảnh)
            RepaintBoundary(
              key: _repaintKey,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo NF-Bank
                    Image.asset(
                      'assets/images/logo_transparent.png',
                      height: 54,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),

                    // Tên người dùng
                    Text(
                      displayName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E2841),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Số tài khoản + nút sao chép
                    InkWell(
                      onTap: _copyAccountNumber,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'STK: $displayAccount',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mã QR kèm Logo App ở chính giữa (Phong cách TPBank)
                    _loading
                        ? const SizedBox(
                            height: 210,
                            width: 210,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF562875),
                              ),
                            ),
                          )
                        : qrDataToRender.isNotEmpty
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Mã QR chất lượng cao với Error Correction Level H
                                  QrImageView(
                                    data: qrDataToRender,
                                    version: QrVersions.auto,
                                    size: 210.0,
                                    padding: EdgeInsets.zero,
                                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF1E2841),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF1E2841),
                                    ),
                                  ),
                                  // Logo Ngân hàng NF-Bank ở tâm QR giống TPBank
                                  Container(
                                    width: 44,
                                    height: 44,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF562875).withValues(alpha: 0.18),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        'assets/images/logo_transparent.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _qrUrl.isNotEmpty
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Image.network(
                                        _qrUrl,
                                        height: 210,
                                        width: 210,
                                        fit: BoxFit.contain,
                                      ),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFF562875).withValues(alpha: 0.18),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.asset(
                                            'assets/images/logo_transparent.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    height: 210,
                                    width: 210,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 140,
                                      color: Colors.grey[400],
                                    ),
                                  ),

                    const SizedBox(height: 10),
                    Text(
                      'VIETQR • NAPAS 247',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Nút: Tải ảnh QR
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveQRImage,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                _saving
                    ? (isEn ? 'Saving...' : 'Đang lưu...')
                    : (isEn ? 'Download QR' : 'Tải ảnh QR'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7941D),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/services/bank_repository.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../services/transfer_repository.dart';

class MyQRPage extends StatefulWidget {
  const MyQRPage({super.key});

  @override
  State<MyQRPage> createState() => _MyQRPageState();
}

class _MyQRPageState extends State<MyQRPage> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _repository = const TransferRepository();
  final _bankRepository = const BankRepository();
  final _qrBoundaryKey = GlobalKey();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _fullName = '';
  String _accountNumber = '';
  String _qrData = '';
  String _qrUrl = '';

  int get _parsedAmount =>
      int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadStaticQR();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadStaticQR() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await TokenStorage.getUser();
      final qrResult = await _repository.getMyStaticQR();

      if (mounted) {
        setState(() {
          _fullName = user?.fullName ?? 'Người dùng NF Bank';
          _accountNumber = qrResult['qr_data'] != null
              ? _extractAccountNumber(qrResult['qr_data'].toString())
              : '—';
          if (_accountNumber == '—') {
            // Fallback: Lấy tài khoản payment
            _loadFallbackAccount();
          }
          _qrData = qrResult['qr_data']?.toString() ?? '';
          _qrUrl = qrResult['qr_url']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải mã QR: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadFallbackAccount() async {
    try {
      final accounts = await _bankRepository.accounts();
      for (final acc in accounts) {
        if (acc['account_type'] == 'PAYMENT') {
          setState(() {
            _accountNumber = acc['account_number']?.toString() ?? '—';
          });
          break;
        }
      }
    } catch (_) {}
  }

  String _extractAccountNumber(String qrData) {
    // Phân tích nhanh số tài khoản từ tag 38 -> sub-tag 01 -> sub-sub-tag 01
    // VietQR EMVCo parser đơn giản phục vụ hiển thị
    try {
      final idx38 = qrData.indexOf('38');
      if (idx38 == -1) return '—';
      final len38 = int.tryParse(qrData.substring(idx38 + 2, idx38 + 4)) ?? 0;
      final val38 = qrData.substring(idx38 + 4, idx38 + 4 + len38);
      
      final idx01 = val38.indexOf('01');
      if (idx01 == -1) return '—';
      final len01 = int.tryParse(val38.substring(idx01 + 2, idx01 + 4)) ?? 0;
      final val01 = val38.substring(idx01 + 4, idx01 + 4 + len01);
      
      final idxSub01 = val01.lastIndexOf('01');
      if (idxSub01 == -1) return '—';
      final lenSub01 = int.tryParse(val01.substring(idxSub01 + 2, idxSub01 + 4)) ?? 0;
      return val01.substring(idxSub01 + 4, idxSub01 + 4 + lenSub01);
    } catch (_) {
      return '—';
    }
  }

  Future<void> _generateQR() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_parsedAmount == 0 && _descController.text.trim().isEmpty) {
        // Trở về QR tĩnh
        final qrResult = await _repository.getMyStaticQR();
        setState(() {
          _qrData = qrResult['qr_data']?.toString() ?? '';
          _qrUrl = qrResult['qr_url']?.toString() ?? '';
          _loading = false;
        });
      } else {
        // Sinh QR động
        final qrResult = await _repository.generateDynamicQR(
          _parsedAmount,
          removeVietnameseDiacritics(_descController.text.trim()),
        );
        setState(() {
          _qrData = qrResult['qr_data']?.toString() ?? '';
          _qrUrl = qrResult['qr_url']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Không thể sinh mã QR: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveQRImage() async {
    if (_saving || _qrUrl.isEmpty) return;
    setState(() => _saving = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await WidgetsBinding.instance.endOfFrame;
      
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Không tìm thấy vùng ảnh QR');
      }
      
      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }
      
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      
      if (byteData == null) {
        throw StateError('Không thể tạo ảnh QR');
      }

      var hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!hasAccess) {
        throw StateError('Chưa cấp quyền lưu ảnh');
      }

      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'NF_Bank_QR_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (mounted) {
        showMessage(context, 'Đã lưu mã QR vào thư viện ảnh');
      }
    } on GalException catch (e) {
      if (mounted) showMessage(context, 'Lỗi lưu ảnh: ${e.type.message}', error: true);
    } on MissingPluginException {
      if (mounted) {
        showMessage(
          context,
          'Tính năng vừa cài đặt. Hãy khởi động lại ứng dụng.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Không thể lưu ảnh QR', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã QR của tôi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AsyncPage(
        loading: _loading && _qrUrl.isEmpty,
        error: _error,
        onRetry: _loadStaticQR,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            // Thẻ chứa QR để tải xuống
            RepaintBoundary(
              key: _qrBoundaryKey,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E2841), Color(0xFF131A2B)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x337C83FD), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/images/logo_transparent.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'NF BANK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Ảnh QR Code nhận diện
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        width: 240,
                        height: 240,
                        child: _qrData.isNotEmpty
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  QrImageView(
                                    data: _qrData,
                                    version: QrVersions.auto,
                                    size: 216.0,
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
                                  Container(
                                    width: 44,
                                    height: 44,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
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
                                    child: ClipOval(
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
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(strokeWidth: 3),
                                          );
                                        },
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(
                                            Icons.qr_code_rounded,
                                            size: 80,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
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
                                        child: ClipOval(
                                          child: Image.asset(
                                            'assets/images/logo_transparent.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _fullName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'Tài khoản: $_accountNumber',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9AA6C0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_parsedAmount > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x147C83FD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Số tiền: ${money(_parsedAmount)}',
                          style: const TextStyle(
                            color: Color(0xFF9EA4FF),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (_descController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '"${_descController.text.trim()}"',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Ô nhập số tiền tùy chọn
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF151D31),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tạo mã QR có số tiền (Tùy chọn)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9EA4FF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: fieldDecoration('Nhập số tiền nhận').copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixText: 'VND',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    maxLength: 50,
                    decoration: fieldDecoration('Nội dung nhận tiền').copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _loading ? null : _generateQR,
                          child: Text(_loading ? 'Đang tạo...' : 'Cập nhật QR'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: _saving ? null : _saveQRImage,
                        tooltip: 'Tải mã QR xuống',
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/services/phone_auth_service.dart';
import '../services/payment_repository.dart';

class PaymentGatewayCheckoutPage extends StatefulWidget {
  const PaymentGatewayCheckoutPage({
    super.key,
    required this.token,
    required this.initialSession,
  });

  final String token;
  final Map<String, dynamic> initialSession;

  @override
  State<PaymentGatewayCheckoutPage> createState() =>
      _PaymentGatewayCheckoutPageState();
}

class _PaymentGatewayCheckoutPageState extends State<PaymentGatewayCheckoutPage> {
  final _repo = const BankRepository();
  final _paymentRepo = const PaymentRepository();
  final _phoneAuth = PhoneAuthService();

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _session = {};
  List<Map<String, dynamic>> _accounts = [];
  Map<String, dynamic>? _selectedAccount;
  SessionUser? _currentUser;
  late Timer _countdownTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _setupCountdown();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  void _setupCountdown() {
    final expiresStr = _session['expires_at']?.toString() ?? '';
    final expires = DateTime.tryParse(expiresStr) ??
        DateTime.now().add(const Duration(minutes: 15));
    _secondsRemaining = expires.difference(DateTime.now()).inSeconds;
    if (_secondsRemaining < 0) _secondsRemaining = 0;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() => _error = 'Phiên thanh toán đã hết hạn');
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repo.accounts(),
        TokenStorage.getUser(),
      ]);

      final allAccounts = results[0] as List<Map<String, dynamic>>;
      _currentUser = results[1] as SessionUser?;

      _accounts = allAccounts.where((acc) {
        final isPayment = acc['account_type']?.toString() == 'PAYMENT';
        final isActive = acc['status']?.toString() == 'ACTIVE';
        return isPayment && isActive;
      }).toList();

      if (_accounts.isNotEmpty) {
        _selectedAccount = _accounts.first;
      }
    } catch (e) {
      _error = 'Lỗi tải dữ liệu tài khoản: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmPayment() async {
    if (_selectedAccount == null) {
      showMessage(context, 'Vui lòng chọn tài khoản nguồn', error: true);
      return;
    }

    final balance = (_selectedAccount!['balance'] as num?)?.toInt() ?? 0;
    final amount = (_session['amount'] as num?)?.toInt() ?? 0;

    if (balance < amount) {
      showMessage(context, 'Số dư tài khoản không đủ để thanh toán', error: true);
      return;
    }

    if (_currentUser == null || _currentUser!.phone.isEmpty) {
      showMessage(context, 'Không tìm thấy số điện thoại của tài khoản', error: true);
      return;
    }

    setState(() => _loading = true);
    String verificationId;
    try {
      verificationId = await _phoneAuth.sendCode(_currentUser!.phone);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showMessage(context, 'Lỗi gửi mã OTP: $e', error: true);
      return;
    }

    setState(() => _loading = false);
    if (!mounted) return;

    final otpCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OTPVerifyDialog(phone: _currentUser!.phone),
    );

    if (otpCode == null || otpCode.isEmpty) return;

    setState(() => _loading = true);
    try {
      final idToken = await _phoneAuth.verifyCode(verificationId, otpCode);
      
      final confirmRes = await _paymentRepo.confirmPayment(
        token: widget.token,
        accountId: (_selectedAccount!['id'] as num).toInt(),
        idToken: idToken,
      );

      final redirectUrl = confirmRes['redirect_url']?.toString() ?? '';
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _PaymentSuccessReceiptPage(
            session: _session,
            accountNumber: _selectedAccount!['account_number']?.toString() ?? '',
            redirectUrl: redirectUrl,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'Thanh toán thất bại: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (_session['amount'] as num?)?.toInt() ?? 0;
    final merchantName = _session['merchant_name']?.toString() ?? 'Đối tác';
    final orderInfo = _session['order_info']?.toString() ?? '';
    final orderId = _session['order_id']?.toString() ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán hóa đơn'),
        centerTitle: true,
      ),
      body: AsyncPage(
        loading: _loading,
        error: _error,
        onRetry: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SurfaceCard(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .15),
                      child: Text(
                        merchantName.isNotEmpty ? merchantName[0].toUpperCase() : 'M',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          merchantName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: Color(0xFF68D391),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'NF Bank Checkout Portal',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    const Text(
                      'TỔNG SỐ TIỀN',
                      style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(amount),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: .2), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Thời gian thanh toán còn lại:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    Text(
                      _formatDuration(_secondsRemaining),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'CHI TIẾT HÓA ĐƠN',
                style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _CheckoutRow(label: 'Mã đơn hàng', value: orderId),
                    const Divider(color: Colors.white10, height: 20),
                    _CheckoutRow(label: 'Nội dung', value: orderInfo),
                    const Divider(color: Colors.white10, height: 20),
                    const _CheckoutRow(label: 'Phí giao dịch', value: '0 VND (Miễn phí)'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'TÀI KHOẢN NGUỒN',
                style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              _accounts.isEmpty
                  ? const Text(
                      'Bạn không có tài khoản thanh toán PAYMENT nào khả dụng.',
                      style: TextStyle(color: Color(0xFFFF5C72), fontSize: 13),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171A27),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: _selectedAccount,
                          dropdownColor: const Color(0xFF171A27),
                          isExpanded: true,
                          items: _accounts.map((acc) {
                            final number = acc['account_number']?.toString() ?? '';
                            final balanceVal = (acc['balance'] as num?)?.toInt() ?? 0;
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: acc,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Ví thanh toán ($number)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Số dư: ${money(balanceVal)}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedAccount = val);
                          },
                        ),
                      ),
                    ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _secondsRemaining > 0 ? _confirmPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C7CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined),
                    const SizedBox(width: 10),
                    Text('XÁC NHẬN THANH TOÁN', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Colors.white30),
                  SizedBox(width: 6),
                  Text(
                    'Thông tin giao dịch được bảo mật bởi NF Bank',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  const _CheckoutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _OTPVerifyDialog extends StatefulWidget {
  const _OTPVerifyDialog({required this.phone});

  final String phone;

  @override
  State<_OTPVerifyDialog> createState() => _OTPVerifyDialogState();
}

class _OTPVerifyDialogState extends State<_OTPVerifyDialog> {
  final otp = TextEditingController();

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return phone;
    return '${digits.substring(0, 3)}••••${digits.substring(digits.length - 3)}';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Xác nhận OTP'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nhập mã gồm 6 số đã gửi tới ${_maskPhone(widget.phone)}.',
                style: const TextStyle(color: Color(0xFF9BA8C7)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Mã OTP',
                  counterText: '',
                  prefixIcon: const Icon(Icons.sms_outlined),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .045),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!RegExp(r'^\d{6}$').hasMatch(otp.text.trim())) {
                showMessage(context, 'Mã OTP phải gồm đúng 6 số', error: true);
                return;
              }
              Navigator.pop(context, otp.text.trim());
            },
            child: const Text('Xác nhận'),
          ),
        ],
      );
}

class _PaymentSuccessReceiptPage extends StatelessWidget {
  const _PaymentSuccessReceiptPage({
    required this.session,
    required this.accountNumber,
    required this.redirectUrl,
  });

  final Map<String, dynamic> session;
  final String accountNumber;
  final String redirectUrl;

  Future<void> _copyRedirectUrl(BuildContext context) async {
    if (redirectUrl.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: redirectUrl));
    if (context.mounted) {
      showMessage(context, 'Đã sao chép link kết quả thanh toán');
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (session['amount'] as num?)?.toInt() ?? 0;
    final merchantName = session['merchant_name']?.toString() ?? 'Đối tác';
    final orderId = session['order_id']?.toString() ?? '—';
    final orderInfo = session['order_info']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F18),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thanh toán thành công!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hóa đơn đã được thanh toán và đối soát hoàn tất.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 32),

              SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _CheckoutRow(label: 'Đơn vị thụ hưởng', value: merchantName),
                    const Divider(color: Colors.white10, height: 24),
                    _CheckoutRow(label: 'Mã đơn hàng', value: orderId),
                    const Divider(color: Colors.white10, height: 24),
                    _CheckoutRow(label: 'Nội dung', value: orderInfo),
                    const Divider(color: Colors.white10, height: 24),
                    _CheckoutRow(label: 'Tài khoản thanh toán', value: accountNumber),
                    const Divider(color: Colors.white10, height: 24),
                    _CheckoutRow(
                      label: 'Số tiền thanh toán',
                      value: money(amount),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (redirectUrl.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171A27),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF6C7CFF).withValues(alpha: .2), width: 1),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Bạn cần phản hồi kết quả về ứng dụng đối tác để hoàn thành dịch vụ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _copyRedirectUrl(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6C7CFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Sao chép link phản hồi đối tác'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              OutlinedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Quay về trang chủ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

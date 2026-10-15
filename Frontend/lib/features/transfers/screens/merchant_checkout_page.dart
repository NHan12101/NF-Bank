import 'package:flutter/material.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../services/payment_repository.dart';

class MerchantCheckoutPage extends StatefulWidget {
  const MerchantCheckoutPage({super.key, required this.token});

  final String token;

  @override
  State<MerchantCheckoutPage> createState() => _MerchantCheckoutPageState();
}

class _MerchantCheckoutPageState extends State<MerchantCheckoutPage> {
  final _paymentRepository = const PaymentRepository();
  final _bankRepository = const BankRepository();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _accounts = [];
  Map<String, dynamic>? _selectedAccount;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final session = await _paymentRepository.getPaymentSession(widget.token);
      final accounts = await _bankRepository.accounts();
      
      final paymentAccounts = accounts
          .where((acc) => acc['account_type']?.toString() == 'PAYMENT')
          .toList();

      if (mounted) {
        setState(() {
          _session = session;
          _accounts = paymentAccounts;
          _selectedAccount = paymentAccounts.isNotEmpty ? paymentAccounts.first : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _showAccountSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF151D31)
              : Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(top: BorderSide(color: Color(0x337C83FD))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 9),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Chọn tài khoản nguồn',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _accounts.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.cardBorder(context)),
                  itemBuilder: (context, index) {
                    final acc = _accounts[index];
                    final isSelected = acc['id'] == _selectedAccount?['id'];
                    return ListTile(
                      title: Text('THANH TOÁN · ${acc['account_number']}'),
                      subtitle: Text(money(acc['balance'], acc['currency']?.toString() ?? 'VND')),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C83FD)) : null,
                      onTap: () {
                        setState(() => _selectedAccount = acc);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOTPVerifySheet() {
    final otpController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF151D31)
                : Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(top: BorderSide(color: Color(0x337C83FD))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Xác nhận mã OTP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Nhập mã OTP thanh toán để xác nhận giao dịch (dùng mã 123456 cho môi trường test).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: fieldDecoration('Mã OTP').copyWith(
                      counterText: '',
                      prefixIcon: const Icon(Icons.sms_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      final otp = otpController.text.trim();
                      if (otp.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mã OTP phải gồm 6 chữ số!')),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      _submitPayment(otp);
                    },
                    child: const Text('Xác nhận thanh toán'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPayment(String otp) async {
    if (_selectedAccount == null || _session == null) return;
    setState(() => _submitting = true);

    try {
      await _paymentRepository.confirmPayment(
        token: widget.token,
        accountId: (_selectedAccount!['id'] as num).toInt(),
        otp: otp,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Thanh toán thành công!'),
            content: Text(
              'Giao dịch thanh toán hóa đơn ${money(_session!['amount'])} cho "${_session!['merchant_name']}" đã được xử lý hoàn tất.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close checkout page
                },
                child: const Text('Quay lại Trang chủ'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFFF5C72),
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán hóa đơn'),
        centerTitle: true,
      ),
      body: AsyncPage(
        loading: _loading,
        error: _error,
        onRetry: _loadDetails,
        child: _session == null
            ? const Center(child: Text('Không tìm thấy thông tin hóa đơn'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Merchant Header Card
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D31) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder(context)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C83FD).withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.store_mall_directory_rounded,
                            size: 30,
                            color: Color(0xFF7C83FD),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _session!['merchant_name']?.toString() ?? 'Đối tác NF Bank',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          money(_session!['amount']),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF7C83FD),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D31) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _infoLine('Mã đơn hàng', _session!['order_id']?.toString() ?? '—'),
                        const Divider(height: 20),
                        _infoLine('Nội dung', _session!['order_info']?.toString() ?? '—'),
                        const Divider(height: 20),
                        _infoLine('Trạng thái', _session!['status']?.toString() == 'PENDING' ? 'Chờ thanh toán' : _session!['status']?.toString() ?? '—'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Account Selector Card
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'Tài khoản nguồn thanh toán',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  InkWell(
                    onTap: _accounts.length > 1 ? _showAccountSelector : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151D31) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder(context)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C83FD).withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 20,
                              color: Color(0xFF7C83FD),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _selectedAccount == null
                                ? const Text(
                                    'Không có tài khoản thanh toán khả dụng',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tài khoản: ${_selectedAccount!['account_number']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Số dư: ${money(_selectedAccount!['balance'])}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                          ),
                          if (_accounts.length > 1)
                            const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  FilledButton(
                    onPressed: _submitting || _selectedAccount == null ? null : _showOTPVerifySheet,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Xác nhận thanh toán',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

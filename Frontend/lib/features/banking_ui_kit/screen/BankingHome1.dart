import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../model/BankingModel.dart';
import '../utils/BankingColors.dart';
import '../utils/BankingContants.dart';
import '../utils/BankingImages.dart';
import '../../banking/screens/user_pages.dart';
import '../../auth/screens/login_screen.dart';
import '../../transfers/widgets/user_receive_qr_dialog.dart';
import '../../transfers/screens/transfer_page.dart';
import 'BankingPayment.dart';

class BankingHome1 extends StatefulWidget {
  static String tag = '/BankingHome1';
  final Function(int)? onSelectTab;

  const BankingHome1({Key? key, this.onSelectTab}) : super(key: key);

  @override
  BankingHome1State createState() => BankingHome1State();
}

class BankingHome1State extends State<BankingHome1> {
  SessionUser? _user;
  String _accountNumber = '...';
  String _formattedBalance = '0 đ';
  num _rawBalance = 0;
  bool _loadingBalance = true;
  bool _isBalanceVisible = true;
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await TokenStorage.getUser();
    if (mounted) setState(() => _user = user);
    try {
      final repo = const BankRepository();
      final results = await Future.wait([
        repo.accounts(),
        repo.transactions(),
      ]);

      final accounts = results[0] as List<Map<String, dynamic>>;
      final rawTransactions = results[1] as List<Map<String, dynamic>>;

      String accNum = '';
      if (accounts.isNotEmpty && mounted) {
        final paymentAccount = accounts.firstWhere(
          (acc) => acc['account_type'] == 'PAYMENT',
          orElse: () => accounts.first,
        );
        final num bal = paymentAccount['balance'] ?? 0;
        accNum = paymentAccount['account_number']?.toString() ?? '';
        setState(() {
          _accountNumber = accNum;
          _rawBalance = bal;
          _formattedBalance = '${bal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
          _loadingBalance = false;
        });
      }

      if (mounted) {
        setState(() {
          _recentTransactions = rawTransactions.take(5).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  void _copyAccountNumber() {
    if (_accountNumber.isNotEmpty && _accountNumber != '...') {
      Clipboard.setData(ClipboardData(text: _accountNumber));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageController.instance.isEnglish
                ? 'Copied account number: $_accountNumber'
                : 'Đã sao chép số tài khoản: $_accountNumber',
          ),
          backgroundColor: const Color(0xFF562875),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showQRModal() {
    UserReceiveQRDialog.show(
      context,
      userName: _user?.fullName,
      userAccount: _accountNumber != '...' ? _accountNumber : null,
    );
  }

  void _openSavings() {
    final isEn = LanguageController.instance.isEnglish;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF562875),
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              isEn ? 'Online Savings' : 'Tiết kiệm trực tuyến',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: const SavingsPage(),
        ),
      ),
    );
  }

  void _openTransfer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransferPage()),
    );
  }

  void _openPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BankingPayment()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ),
    );
  }

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
        final userName = _user?.fullName ?? (isEn ? 'TPBank Customer' : 'Khách hàng TPBank');

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF140824) : const Color(0xFFF6F5FA),
          body: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFFF7941D),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // --- TPBank Header Gradient ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF1F0D33), const Color(0xFF12071F)]
                            : [const Color(0xFF562875), const Color(0xFF3B1554)],
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF562875).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Avatar + Name + Notification & QR icons
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Image.asset('assets/images/logo_transparent.png', fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEn ? 'Good day 👋' : 'Xin chào 👋',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _showQRModal,
                              tooltip: isEn ? 'QR Pay' : 'Quét QR',
                              icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFF7941D), size: 28),
                            ),
                            IconButton(
                              onPressed: _openNotifications,
                              tooltip: isEn ? 'Notifications' : 'Thông báo',
                              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- TPBank Main Account Card ---
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6C3494), Color(0xFF451A62)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7941D).withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFF7941D).withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          isEn ? 'Payment Account' : 'Tài khoản chính',
                                          style: const TextStyle(
                                            color: Color(0xFFFFB356),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: _copyAccountNumber,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Row(
                                        children: [
                                          Text(
                                            _accountNumber,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.copy_rounded, color: Color(0xFFFFB356), size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isEn ? 'Available Balance' : 'Số dư khả dụng',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _loadingBalance
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : Text(
                                                _isBalanceVisible ? _formattedBalance : '•••••••• đ',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _isBalanceVisible = !_isBalanceVisible);
                                    },
                                    icon: Icon(
                                      _isBalanceVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Quick Actions Bar (Chuyển tiền, Nạp tiền, Tiết kiệm, QR) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF26133B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickActionButton(
                            icon: Icons.send_rounded,
                            label: isEn ? 'Transfer' : 'Chuyển tiền',
                            color: const Color(0xFFF7941D),
                            onTap: _openTransfer,
                          ),
                          _buildQuickActionButton(
                            icon: Icons.phone_android_rounded,
                            label: isEn ? 'Top Up' : 'Nạp tiền',
                            color: const Color(0xFF562875),
                            onTap: _openPayment,
                          ),
                          _buildQuickActionButton(
                            icon: Icons.savings_rounded,
                            label: isEn ? 'Savings' : 'Tiết kiệm',
                            color: const Color(0xFF00B0FF),
                            onTap: _openSavings,
                          ),
                          _buildQuickActionButton(
                            icon: Icons.qr_code_2_rounded,
                            label: isEn ? 'QR Code' : 'Mã QR',
                            color: const Color(0xFFE91E63),
                            onTap: _showQRModal,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Recent Transactions ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEn ? 'Recent Transactions' : 'Giao dịch gần đây',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF2D1442),
                              ),
                            ),
                            TextButton(
                              onPressed: _openNotifications,
                              child: Text(
                                isEn ? 'View all' : 'Xem tất cả',
                                style: const TextStyle(
                                  color: Color(0xFF562875),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_recentTransactions.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF26133B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                isEn ? 'No recent transactions' : 'Chưa có giao dịch nào gần đây',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentTransactions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final tx = _recentTransactions[index];
                              final isCredit = tx['receiver_account_number'] == _accountNumber || tx['transaction_type'] == 'DEPOSIT';
                              final num amount = (tx['amount'] as num?) ?? 0;
                              final desc = tx['description']?.toString() ?? (isEn ? 'Account Transaction' : 'Giao dịch tài khoản');
                              final sign = isCredit ? '+' : '-';
                              final formattedAmount = '$sign${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF26133B) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isCredit ? Colors.green.withOpacity(0.12) : const Color(0xFF562875).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                        color: isCredit ? Colors.green : const Color(0xFF562875),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            desc,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            tx['created_at'] != null
                                                ? tx['created_at'].toString().split('T').first
                                                : (isEn ? 'Today' : 'Hôm nay'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white54 : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formattedAmount,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isCredit ? Colors.green : const Color(0xFFF7941D),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

}

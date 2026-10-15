import 'package:flutter/material.dart';

import '../../../core/services/bank_repository.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/language_controller.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../transfers/screens/my_qr_page.dart';
import '../../transfers/screens/qr_scanner_page.dart';
import '../widgets/common/quick_actions.dart';
import '../widgets/common/transaction_tile.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onOpenSavings});

  final VoidCallback? onOpenSavings;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _repo = BankRepository();
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> transactions = [];
  SessionUser? user;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        _repo.accounts(),
        _repo.transactions(),
        TokenStorage.getUser(),
      ]);
      accounts = results[0] as List<Map<String, dynamic>>;
      transactions = results[1] as List<Map<String, dynamic>>;
      user = results[2] as SessionUser?;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    return AsyncPage(
      loading: loading,
      error: error,
      onRetry: load,
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          children: [
            PageTitle(
              isEn
                  ? 'Hello, ${user?.fullName ?? 'there'}'
                  : 'Xin chào, ${user?.fullName ?? 'bạn'}',
              subtitle: isEn
                  ? 'Here is your financial overview today.'
                  : 'Đây là tình hình tài chính hôm nay.',
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 700
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                final savingsAccounts = accounts
                    .where(
                      (account) =>
                          account['account_type']?.toString() == 'SAVINGS' &&
                          account['status']?.toString() == 'ACTIVE',
                    )
                    .toList();
                final regularAccounts = accounts
                    .where(
                      (account) =>
                          account['account_type']?.toString() != 'SAVINGS',
                    )
                    .toList();
                final savingsBalance = savingsAccounts.fold<int>(
                  0,
                  (total, account) =>
                      total + ((account['balance'] as num?)?.toInt() ?? 0),
                );

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final account in regularAccounts)
                      SizedBox(
                        width: width,
                        child: OverviewAccountCard(
                          title: account['account_type']?.toString() == 'CREDIT'
                              ? (isEn ? 'CREDIT' : 'TÍN DỤNG')
                              : (isEn ? 'PAYMENT' : 'THANH TOÁN'),
                          balance: money(
                            account['balance'],
                            account['currency']?.toString() ?? 'VND',
                          ),
                          subtitle: account['account_number']?.toString() ?? '—',
                          icon: Icons.contactless_rounded,
                          colors: Theme.of(context).brightness == Brightness.dark
                              ? const [Color(0xFF4D5CE5), Color(0xFF252951)]
                              : const [Color(0xFF4F62FF), Color(0xFF8EB7FF)],
                        ),
                      ),
                    if (savingsAccounts.isNotEmpty)
                      SizedBox(
                        width: width,
                        child: OverviewAccountCard(
                          title: isEn ? 'SAVINGS' : 'TIẾT KIỆM',
                          balance: money(savingsBalance),
                          subtitle: isEn
                              ? '${savingsAccounts.length} active savings deposits'
                              : '${savingsAccounts.length} sổ tiết kiệm đang hoạt động',
                          actionLabel: isEn
                              ? 'View savings list'
                              : 'Xem danh sách sổ',
                          icon: Icons.savings_rounded,
                          colors: Theme.of(context).brightness == Brightness.dark
                              ? const [Color(0xFF078A91), Color(0xFF16304C)]
                              : const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                          onTap: widget.onOpenSavings,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            QuickActions(
              onScanQR: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QRScannerPage()),
                );
              },
              onMyQR: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyQRPage()),
                );
              },
            ),
            const SizedBox(height: 28),
            PageTitle(isEn ? 'Recent Transactions' : 'Giao dịch gần đây'),
            const SizedBox(height: 14),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: transactions.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: isEn ? 'No transactions yet' : 'Chưa có giao dịch',
                      message: isEn
                          ? 'New transactions will appear here.'
                          : 'Các giao dịch mới sẽ xuất hiện tại đây.',
                    )
                  : Column(
                      children: transactions
                          .take(5)
                          .map((tx) => TransactionTile(tx: tx))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class OverviewAccountCard extends StatelessWidget {
  const OverviewAccountCard({
    super.key,
    required this.title,
    required this.balance,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String balance;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Ink(
        height: 190,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 21, color: Colors.white),
                ),
              ],
            ),
            const Spacer(),
            Text(
              balance,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    actionLabel ?? subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .48),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

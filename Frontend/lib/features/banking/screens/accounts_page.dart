import 'package:flutter/material.dart';

import '../../../core/services/bank_repository.dart';
import '../../../core/theme/language_controller.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  static const _repo = BankRepository();
  bool loading = true;
  List<Map<String, dynamic>> accounts = [];
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      accounts = await _repo.accounts();
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
      child: ListView(
        children: [
          PageTitle(
            isEn ? 'My Accounts' : 'Tài khoản của tôi',
            subtitle: isEn
                ? 'Track balance and status for each account.'
                : 'Theo dõi số dư và trạng thái từng tài khoản.',
          ),
          const SizedBox(height: 20),
          for (final account in accounts) ...[
            SurfaceCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Icon(
                      account['account_type'] == 'SAVINGS'
                          ? Icons.savings_outlined
                          : Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account['account_type']?.toString() ?? 'Tài khoản',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          account['account_number']?.toString() ?? '—',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(
                          account['balance'],
                          account['currency']?.toString() ?? 'VND',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account['status']?.toString() ?? '',
                        style: const TextStyle(color: Color(0xFF68D391)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

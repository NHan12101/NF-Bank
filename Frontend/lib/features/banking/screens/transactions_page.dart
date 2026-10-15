import 'package:flutter/material.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/theme/language_controller.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/widgets/admin_detail_dialog.dart';
import '../widgets/common/transaction_tile.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  static const _repo = BankRepository();
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];
  String query = '';

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
      items = await _repo.transactions();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> detail(Map<String, dynamic> tx) async {
    try {
      final data = await _repo.transaction(
        tx['reference_code']?.toString() ?? '',
      );
      if (!mounted) return;
      final direction = data['direction']?.toString().toUpperCase() ?? 'IN';
      final type = data['type']?.toString().toUpperCase() ?? 'GIAO DỊCH';
      final counterparty = data['counterparty_name']?.toString().trim() ?? '';
      final incoming = direction == 'IN';
      final sender = incoming
          ? type == 'DEPOSIT'
                ? 'Hệ thống / Admin'
                : counterparty.isEmpty
                ? 'Hệ thống / Chuyển khoản'
                : counterparty
          : 'Bạn';
      final receiver = incoming
          ? 'Bạn'
          : type == 'WITHDRAWAL'
          ? 'Rút tiền mặt'
          : counterparty.isEmpty
          ? 'Người nhận'
          : counterparty;
      await showAdminTransactionDetail(
        context,
        referenceCode: data['reference_code']?.toString() ?? '—',
        type: type,
        amount: data['amount'],
        currency: data['currency']?.toString() ?? 'VND',
        status: data['status']?.toString() ?? 'SUCCESS',
        description: data['description']?.toString() ?? '',
        createdAt: data['created_at'],
        sender: sender,
        receiver: receiver,
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    final filtered = items.where((tx) {
      final haystack =
          '${tx['reference_code']} ${tx['description']} ${tx['type']}'
              .toLowerCase();
      return haystack.contains(query.toLowerCase());
    }).toList();
    return AsyncPage(
      loading: loading,
      error: error,
      onRetry: load,
      child: ListView(
        children: [
          PageTitle(
            isEn ? 'Transaction History' : 'Lịch sử giao dịch',
            subtitle: isEn
                ? 'Search and view details of all account movements.'
                : 'Tra cứu và xem chi tiết mọi biến động.',
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: fieldDecoration(
              isEn ? 'Search by code or content' : 'Tìm theo mã hoặc nội dung',
            ).copyWith(prefixIcon: const Icon(Icons.search)),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'Không có kết quả',
                    message: 'Hãy thử một từ khóa khác.',
                  )
                : Column(
                    children: filtered
                        .map(
                          (tx) => InkWell(
                            onTap: () => detail(tx),
                            child: TransactionTile(tx: tx),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

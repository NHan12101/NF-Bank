import 'package:flutter/material.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/theme/language_controller.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../transfers/screens/transfer_page.dart'
    show showTransactionPINSheet;
import '../../transfers/services/transfer_repository.dart';
import '../widgets/common/transaction_tile.dart';
import '../widgets/savings/savings_account_card.dart';
import '../widgets/savings/savings_detail_sheet.dart';
import '../widgets/savings/savings_review_sheet.dart';
import '../widgets/savings/savings_withdrawal_sheet.dart';

class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  static const _repo = BankRepository();
  final amount = TextEditingController();
  final pinRepository = const TransferRepository();
  bool initialLoading = true;
  String? contextError;
  bool loading = false;
  bool showOpenForm = false;
  bool? hasTransactionPIN;
  Map<String, dynamic>? sourceAccount;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> savingsAccounts = [];
  int termMonths = 12;
  String maturityInstruction = 'PAYOUT';
  String? savingsRequestID;
  final Map<String, ({int amount, String key})> withdrawalRequests = {};

  int get parsedAmount =>
      int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  Map<String, dynamic>? get selectedProduct {
    for (final product in products) {
      if ((product['term_months'] as num?)?.toInt() == termMonths) {
        return product;
      }
    }
    return null;
  }

  double get interestRate =>
      (selectedProduct?['interest_rate'] as num?)?.toDouble() ?? 0;
  int get minimumAmount =>
      (selectedProduct?['minimum_amount'] as num?)?.toInt() ?? 5000000;
  int get expectedInterest =>
      (parsedAmount * interestRate / 100 * termMonths / 12).round();

  @override
  void initState() {
    super.initState();
    loadContext(initializeView: true);
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> loadContext({
    bool initializeView = false,
    bool showLoading = false,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        initialLoading = true;
        contextError = null;
      });
    }
    try {
      final responses = await Future.wait([
        _repo.accounts(),
        pinRepository.hasTransactionPin(),
        _repo.savingsProducts(),
        _repo.savingsAccounts(),
      ]);
      final accounts = responses[0] as List<Map<String, dynamic>>;
      final loadedProducts = responses[2] as List<Map<String, dynamic>>;
      final loadedSavings = responses[3] as List<Map<String, dynamic>>;
      Map<String, dynamic>? paymentAccount;
      for (final account in accounts) {
        if (account['account_type']?.toString() == 'PAYMENT') {
          paymentAccount = account;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        sourceAccount = paymentAccount;
        hasTransactionPIN = responses[1] as bool;
        products = loadedProducts;
        savingsAccounts = loadedSavings;
        if (loadedProducts.isNotEmpty &&
            !loadedProducts.any(
              (item) => (item['term_months'] as num?)?.toInt() == termMonths,
            )) {
          termMonths =
              (loadedProducts.first['term_months'] as num?)?.toInt() ?? 12;
        }
        if (initializeView) showOpenForm = loadedSavings.isEmpty;
        contextError = null;
        initialLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        contextError = error.message;
        initialLoading = false;
      });
      showMessage(context, error.message, error: true);
    }
  }

  Future<void> review() async {
    final value = parsedAmount;
    if (value < minimumAmount) {
      showMessage(
        context,
        'Số tiền tối thiểu là ${money(minimumAmount)}',
        error: true,
      );
      return;
    }
    final balance = (sourceAccount?['balance'] as num?)?.toInt();
    if (balance != null && value > balance) {
      showMessage(
        context,
        'Số dư tài khoản thanh toán không đủ',
        error: true,
        transaction: true,
      );
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavingsReviewSheet(
        amount: value,
        expectedInterest: expectedInterest,
        sourceAccount: sourceAccount,
        termMonths: termMonths,
        interestRate: interestRate,
        maturityInstruction: maturityInstruction,
      ),
    );
    if (confirmed == true && mounted) {
      savingsRequestID ??= TransferRepository.createIdempotencyKey();
      await authorizeAndOpen(value);
    }
  }

  Future<void> authorizeAndOpen(int value) async {
    bool hasPIN;
    try {
      hasPIN = hasTransactionPIN ?? await pinRepository.hasTransactionPin();
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message, error: true, transaction: true);
      }
      return;
    }

    if (!mounted) return;
    final pinInput = await showTransactionPINSheet(
      context,
      createPIN: !hasPIN,
      actionLabel: 'mở sổ tiết kiệm',
    );
    if (pinInput == null || !mounted) return;

    setState(() => loading = true);
    try {
      if (!hasPIN) {
        await pinRepository.setupTransactionPin(
          pinInput.pin,
          pinInput.confirmPIN!,
        );
        hasTransactionPIN = true;
      }
      await _repo.openSavings(
        amount: value,
        termMonths: termMonths,
        maturityInstruction: maturityInstruction,
        transactionPin: pinInput.pin,
        idempotencyKey: savingsRequestID ??=
            TransferRepository.createIdempotencyKey(),
      );
      if (mounted) {
        amount.clear();
        savingsRequestID = null;
        await loadContext();
        if (!mounted) return;
        setState(() => showOpenForm = false);
        showMessage(context, 'Mở sổ tiết kiệm thành công', transaction: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message, error: true, transaction: true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> showSavingsDetail(Map<String, dynamic> item) async {
    final withdraw = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SavingsDetailSheet(item: item),
    );
    if (withdraw == true && mounted) {
      await requestEarlyWithdrawal(item);
    }
  }

  Future<void> requestEarlyWithdrawal(Map<String, dynamic> item) async {
    final principal = (item['original_principal'] as num?)?.toInt() ?? 0;
    final amountToWithdraw = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavingsWithdrawalSheet(
        principal: principal,
        startDate: DateTime.tryParse(item['start_date']?.toString() ?? ''),
        demandInterestRate:
            (item['demand_interest_rate'] as num?)?.toDouble() ?? .5,
      ),
    );
    if (amountToWithdraw == null || !mounted) return;

    bool hasPIN;
    try {
      hasPIN = hasTransactionPIN ?? await pinRepository.hasTransactionPin();
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message, error: true, transaction: true);
      }
      return;
    }
    if (!mounted) return;
    final pinInput = await showTransactionPINSheet(
      context,
      createPIN: !hasPIN,
      actionLabel: 'rút tiết kiệm trước hạn',
    );
    if (pinInput == null || !mounted) return;

    final accountNumber = item['account_number']?.toString() ?? '';
    final previousRequest = withdrawalRequests[accountNumber];
    final request = previousRequest?.amount == amountToWithdraw
        ? previousRequest!
        : (
            amount: amountToWithdraw,
            key: TransferRepository.createIdempotencyKey(),
          );
    withdrawalRequests[accountNumber] = request;
    setState(() => loading = true);
    try {
      if (!hasPIN) {
        await pinRepository.setupTransactionPin(
          pinInput.pin,
          pinInput.confirmPIN!,
        );
        hasTransactionPIN = true;
      }
      final result = await _repo.withdrawSavingsEarly(
        accountNumber: accountNumber,
        amount: amountToWithdraw,
        transactionPin: pinInput.pin,
        idempotencyKey: request.key,
      );
      withdrawalRequests.remove(accountNumber);
      await loadContext();
      if (!mounted) return;
      showMessage(
        context,
        result['is_full_withdrawal'] == true
            ? 'Đã tất toán sổ trước hạn'
            : 'Rút một phần tiền gửi thành công',
        transaction: true,
      );
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message, error: true, transaction: true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    if (initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (contextError != null &&
        sourceAccount == null &&
        products.isEmpty &&
        savingsAccounts.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: isEn ? 'Unable to load savings' : 'Không tải được tiết kiệm',
        message: contextError!,
        actionLabel: isEn ? 'Retry' : 'Thử lại',
        onAction: () => loadContext(initializeView: true, showLoading: true),
      );
    }
    final totalPrincipal = savingsAccounts.fold<int>(
      0,
      (total, item) => item['is_settled'] == true
          ? total
          : total + ((item['original_principal'] as num?)?.toInt() ?? 0),
    );
    final activeSavings = savingsAccounts
        .where(
          (item) =>
              item['is_settled'] != true &&
              item['status']?.toString() == 'ACTIVE',
        )
        .toList();
    final settledSavings = savingsAccounts
        .where(
          (item) =>
              item['is_settled'] == true ||
              item['status']?.toString() == 'CLOSED',
        )
        .toList();
    return ListView(
      children: [
        PageTitle(
          isEn ? 'Online Savings' : 'Tiết kiệm trực tuyến',
          subtitle: showOpenForm
              ? (isEn
                  ? 'Choose term and check benefits before confirming.'
                  : 'Chọn kỳ hạn và kiểm tra quyền lợi trước khi xác nhận.')
              : isEn
                  ? '${activeSavings.length} active deposits'
                  : '${activeSavings.length} sổ đang hoạt động'
                    '${settledSavings.isEmpty ? '' : ' · ${settledSavings.length} sổ đã tất toán'}',
          trailing: savingsAccounts.isNotEmpty && !showOpenForm
              ? FilledButton.icon(
                  onPressed: () => setState(() => showOpenForm = true),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(isEn ? 'Open new deposit' : 'Mở sổ mới'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: showOpenForm
                ? _buildOpenForm()
                : _buildSavingsList(
                    totalPrincipal,
                    activeSavings,
                    settledSavings,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsList(
    int totalPrincipal,
    List<Map<String, dynamic>> activeSavings,
    List<Map<String, dynamic>> settledSavings,
  ) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF562875), Color(0xFF3B1554)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF562875).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng tiền gửi',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 5),
            Text(
              money(totalPrincipal),
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              '${activeSavings.length} khoản tiền gửi đang sinh lãi',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (activeSavings.isEmpty)
        const EmptyState(
          icon: Icons.savings_outlined,
          title: 'Không có sổ đang hoạt động',
          message: 'Bạn có thể mở một sổ tiết kiệm mới bất cứ lúc nào.',
        )
      else ...[
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Đang hoạt động',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 9),
      ],
      for (final item in activeSavings) ...[
        SavingsAccountCard(item: item, onTap: () => showSavingsDetail(item)),
        const SizedBox(height: 10),
      ],
      if (settledSavings.isNotEmpty) ...[
        const SizedBox(height: 6),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Đã tất toán',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 9),
        for (final item in settledSavings) ...[
          SavingsAccountCard(item: item, onTap: () => showSavingsDetail(item)),
          const SizedBox(height: 10),
        ],
      ],
    ],
  );

  Widget _buildOpenForm() => Column(
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Mở sổ tiết kiệm mới',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          if (savingsAccounts.isNotEmpty)
            IconButton(
              tooltip: 'Đóng',
              onPressed: () => setState(() => showOpenForm = false),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF562875), Color(0xFF3B1554)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.savings_rounded, size: 26, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tiết kiệm An tâm',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '$interestRate%/năm',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB7BBFF)
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              sourceAccount == null
                  ? 'Nguồn tiền: Tài khoản thanh toán'
                  : 'Nguồn tiền: ${sourceAccount!['account_number']} · ${money(sourceAccount!['balance'])}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: termMonths,
              decoration: fieldDecoration('Kỳ hạn'),
              items: products
                  .map(
                    (product) => DropdownMenuItem<int>(
                      value: (product['term_months'] as num).toInt(),
                      child: Text(
                        '${product['term_months']} tháng · ${product['interest_rate']}%/năm',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    termMonths = value;
                    savingsRequestID = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              onChanged: (_) => setState(() => savingsRequestID = null),
              decoration: fieldDecoration(
                'Số tiền gửi',
              ).copyWith(suffixText: 'VND'),
            ),
            if (parsedAmount > 0) ...[
              const SizedBox(height: 6),
              Text(
                moneyInVietnameseWords(parsedAmount),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [5000000, 10000000, 20000000, 50000000, 100000000, 200000000]
                      .map(
                        (value) => ActionChip(
                          label: Text(money(value).replaceAll(' VND', '')),
                          onPressed: () {
                            amount.text = formatCurrencyInput(value);
                            setState(() => savingsRequestID = null);
                          },
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: maturityInstruction,
              decoration: fieldDecoration('Khi đến hạn'),
              items: const [
                DropdownMenuItem(
                  value: 'PAYOUT',
                  child: Text('Tất toán về tài khoản thanh toán'),
                ),
                DropdownMenuItem(
                  value: 'RENEW_PRINCIPAL',
                  child: Text('Tái tục tiền gốc'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    maturityInstruction = value;
                    savingsRequestID = null;
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF11192B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  DetailRow('Tiền lãi dự kiến', money(expectedInterest)),
                  DetailRow(
                    'Nhận khi đáo hạn',
                    money(parsedAmount + expectedInterest),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            FilledButton(
              onPressed: loading ? null : review,
              child: Text(loading ? 'Đang xử lý...' : 'Tiếp tục'),
            ),
          ],
        ),
      ),
    ],
  );
}

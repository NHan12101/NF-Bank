import 'package:flutter/material.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../transfers/screens/transfer_page.dart'
    show TransferPage, showTransactionPINSheet;
import '../../transfers/services/transfer_repository.dart';
import '../widgets/common/transaction_tile.dart' show DetailRow;
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
  String openFormProductType = 'TERM'; // 'TERM' (Tiết kiệm Online) hoặc 'ACCUMULATED' (Tích lũy Online)

  bool? hasTransactionPIN;
  Map<String, dynamic>? sourceAccount;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> savingsAccounts = [];
  int termMonths = 12;
  String maturityInstruction = 'PAYOUT';
  String? savingsRequestID;
  final Map<String, ({int amount, String key})> withdrawalRequests = {};

  // Tab chính: 0: Thanh toán, 1: Tiết kiệm (mặc định), 2: Tiền vay
  int _selectedMainTab = 1;

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

  void _startOpenSavings({required String type}) {
    setState(() {
      openFormProductType = type;
      showOpenForm = true;
    });
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
    final isDark = ThemeController.instance.isDarkMode;
    final isEn = LanguageController.instance.isEnglish;

    if (initialLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1716) : const Color(0xFFF6F9F8),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0C4E44)),
        ),
      );
    }

    if (contextError != null &&
        sourceAccount == null &&
        products.isEmpty &&
        savingsAccounts.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1716) : const Color(0xFFF6F9F8),
        body: Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: isEn ? 'Unable to load accounts' : 'Không tải được tài khoản',
            message: contextError!,
            actionLabel: isEn ? 'Retry' : 'Thử lại',
            onAction: () => loadContext(initializeView: true, showLoading: true),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1716) : const Color(0xFFF6F9F8),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF162522), const Color(0xFF0F1716)]
                : [const Color(0xFFE2F3F0), const Color(0xFFF6F9F8)],
            stops: const [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Top Bar (Back Button + Refresh Button) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: 48),
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                        size: 24,
                      ),
                      tooltip: isEn ? 'Reload' : 'Làm mới',
                      onPressed: () => loadContext(showLoading: true),
                    ),
                  ],
                ),
              ),

              // --- Page Title "Tài khoản" ---
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                child: Text(
                  isEn ? 'Accounts' : 'Tài khoản',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),

              // --- Main Tabs: Thanh toán | Tiết kiệm | Tiền vay ---
              _buildMainTabs(isDark, isEn),

              const SizedBox(height: 12),

              // --- Body Content based on Tab ---
              Expanded(
                child: _buildTabBody(isDark, isEn),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainTabs(bool isDark, bool isEn) {
    final tabs = [
      isEn ? 'Payment' : 'Thanh toán',
      isEn ? 'Savings' : 'Tiết kiệm',
      isEn ? 'Loans' : 'Tiền vay',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedMainTab == index;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedMainTab = index;
                showOpenForm = false;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0C4E44)
                          : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 2.5,
                    width: 52,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFB8860B) // Gold indicator line as in screenshot
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabBody(bool isDark, bool isEn) {
    if (_selectedMainTab == 0) {
      return _buildPaymentTab(isDark, isEn);
    } else if (_selectedMainTab == 2) {
      return _buildLoanTab(isDark, isEn);
    }
    // Tab 1: Tiết kiệm
    if (showOpenForm) {
      return _buildOpenForm(isDark, isEn);
    }
    return _buildSavingsHome(isDark, isEn);
  }

  // --- TAB 1: TIẾT KIỆM (Theo chuẩn Screenshot 100%) ---
  Widget _buildSavingsHome(bool isDark, bool isEn) {
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

    final totalPrincipal = savingsAccounts.fold<int>(
      0,
      (total, item) => item['is_settled'] == true
          ? total
          : total + ((item['original_principal'] as num?)?.toInt() ?? 0),
    );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
      children: [
        // Nếu user đã có sổ tiết kiệm, hiển thị tóm tắt và danh sách sổ của user trước
        if (savingsAccounts.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0C4E44), Color(0xFF1B6B5E)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0C4E44).withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEn ? 'Total Savings Deposits' : 'Tổng tiền gửi tiết kiệm',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${activeSavings.length} ${isEn ? 'active' : 'sổ hoạt động'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  money(totalPrincipal),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (activeSavings.isNotEmpty) ...[
            Text(
              isEn ? 'Your Active Deposits' : 'Sổ tiết kiệm của bạn',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            for (final item in activeSavings) ...[
              SavingsAccountCard(item: item, onTap: () => showSavingsDetail(item)),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
          ],

          if (settledSavings.isNotEmpty) ...[
            Text(
              isEn ? 'Settled Deposits' : 'Sổ đã tất toán',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in settledSavings) ...[
              SavingsAccountCard(item: item, onTap: () => showSavingsDetail(item)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
          ],

          Text(
            isEn ? 'New Savings Products' : 'Gói sản phẩm tiết kiệm',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // --- CARD 1: Tiết kiệm Online (Ảnh mẫu) ---
        _buildProductCard(
          isDark: isDark,
          title: isEn ? 'Online Savings' : 'Tiết kiệm Online',
          bullets: isEn
              ? [
                  'Flexible deposit terms',
                  'Attractive interest rates',
                  'Easy deposit and withdrawal procedures',
                ]
              : [
                  'Kỳ hạn gửi linh hoạt',
                  'Lãi suất ưu đãi',
                  'Thủ tục gửi và rút dễ dàng',
                ],
          buttonText: isEn ? 'Open account' : 'Mở tài khoản',
          onTapButton: () => _startOpenSavings(type: 'TERM'),
          illustration: const PiggyBankIllustration(),
        ),

        const SizedBox(height: 16),

        // --- CARD 2: Tích lũy Online (Ảnh mẫu) ---
        _buildProductCard(
          isDark: isDark,
          title: isEn ? 'Online Accumulation' : 'Tích lũy Online',
          bullets: isEn
              ? [
                  'Profitable accumulation',
                  'Attractive interest rates',
                  'Easy target milestones',
                ]
              : [
                  'Tích lũy sinh lời',
                  'Lãi suất ưu đãi',
                  'Mục tiêu dễ dàng',
                ],
          buttonText: isEn ? 'Open account' : 'Mở tài khoản',
          onTapButton: () => _startOpenSavings(type: 'ACCUMULATED'),
          illustration: const AccumulationIllustration(),
        ),

        // Theo yêu cầu của user: "còn cái kia thì khỏi" (Chứng chỉ tiền gửi) => KHÔNG HIỂN THỊ
      ],
    );
  }

  // --- WIDGET CARD SẢN PHẨM (Khung viền, chữ, button pill xanh đậm, hình minh họa góc phải) ---
  Widget _buildProductCard({
    required bool isDark,
    required String title,
    required List<String> bullets,
    required String buttonText,
    required VoidCallback onTapButton,
    required Widget illustration,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2825) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bên trái: Tiêu đề, các gạch đầu dòng, nút "Mở tài khoản"
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 10),
                for (final bullet in bullets) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                            height: 1.3,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bullet,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Nút "Mở tài khoản" (Pill xanh đậm)
                InkWell(
                  onTap: onTapButton,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C4E44),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0C4E44).withOpacity(0.28),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Bên phải: Minh họa chuẩn
          illustration,
        ],
      ),
    );
  }

  // --- TAB 0: THANH TOÁN (Tài khoản thanh toán & số dư khả dụng) ---
  Widget _buildPaymentTab(bool isDark, bool isEn) {
    final balance = (sourceAccount?['balance'] as num?)?.toInt() ?? 0;
    final accountNumber = sourceAccount?['account_number']?.toString() ?? '...';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0C4E44), Color(0xFF1B6B5E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0C4E44).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEn ? 'Payment Account' : 'Tài khoản thanh toán',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'VND',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                accountNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEn ? 'Available Balance' : 'Số dư khả dụng',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                money(balance),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransferPage()),
                  );
                },
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  isEn ? 'Transfer' : 'Chuyển tiền',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C4E44),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- TAB 2: TIỀN VAY ---
  Widget _buildLoanTab(bool isDark, bool isEn) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2825) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C4E44).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.real_estate_agent_outlined,
                  color: Color(0xFF0C4E44),
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isEn ? 'No Active Loans' : 'Quý khách chưa có khoản vay nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? 'Explore consumer & mortgage loans with preferential rates at NF Bank.'
                    : 'Gói vay tiêu dùng, thế chấp ưu đãi lãi suất chỉ từ 5.5%/năm tại NF Bank.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- FORM MỞ SỔ TIẾT KIỆM (Hiện khi bấm "Mở tài khoản" trên card) ---
  Widget _buildOpenForm(bool isDark, bool isEn) {
    final isAccumulated = openFormProductType == 'ACCUMULATED';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              onPressed: () => setState(() => showOpenForm = false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                isAccumulated
                    ? (isEn ? 'Open Accumulation Savings' : 'Mở sổ Tích lũy Online')
                    : (isEn ? 'Open Term Savings' : 'Mở sổ Tiết kiệm Online'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Thẻ thông tin gói
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0C4E44), Color(0xFF1B6B5E)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAccumulated ? 'Tích lũy Sinh lời' : 'Tiết kiệm Linh hoạt',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$interestRate%/năm',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                sourceAccount == null
                    ? 'Nguồn tiền: Tài khoản thanh toán'
                    : 'Nguồn tiền: ${sourceAccount!['account_number']} (Số dư: ${money(sourceAccount!['balance'])})',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2825) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chọn kỳ hạn
              DropdownButtonFormField<int>(
                initialValue: termMonths,
                dropdownColor: isDark ? const Color(0xFF1E2825) : Colors.white,
                decoration: fieldDecoration('Kỳ hạn gửi'),
                items: products
                    .map(
                      (product) => DropdownMenuItem<int>(
                        value: (product['term_months'] as num).toInt(),
                        child: Text(
                          '${product['term_months']} tháng · Lãi suất ${product['interest_rate']}%/năm',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
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
              const SizedBox(height: 14),

              // Nhập số tiền gửi
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                onChanged: (_) => setState(() => savingsRequestID = null),
                decoration: fieldDecoration('Số tiền gửi (Tối thiểu 5.000.000 VND)')
                    .copyWith(suffixText: 'VND'),
              ),

              if (parsedAmount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  moneyInVietnameseWords(parsedAmount),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF0C4E44),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Chips gợi ý số tiền
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [5000000, 10000000, 20000000, 50000000, 100000000]
                    .map(
                      (value) => ActionChip(
                        label: Text(
                          money(value).replaceAll(' VND', ''),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF0C4E44),
                          ),
                        ),
                        backgroundColor: isDark
                            ? Colors.white12
                            : const Color(0xFF0C4E44).withOpacity(0.08),
                        onPressed: () {
                          amount.text = formatCurrencyInput(value);
                          setState(() => savingsRequestID = null);
                        },
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 14),

              // Chỉ thị khi đến hạn
              DropdownButtonFormField<String>(
                initialValue: maturityInstruction,
                dropdownColor: isDark ? const Color(0xFF1E2825) : Colors.white,
                decoration: fieldDecoration('Khi đến hạn'),
                items: const [
                  DropdownMenuItem(
                    value: 'PAYOUT',
                    child: Text('Tất toán về tài khoản thanh toán'),
                  ),
                  DropdownMenuItem(
                    value: 'RENEW_PRINCIPAL',
                    child: Text('Tái tục tiền gốc (Lãi về TK thanh toán)'),
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

              const SizedBox(height: 16),

              // Bảng tính lãi dự kiến
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF162522)
                      : const Color(0xFF0C4E44).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    DetailRow('Tiền lãi dự kiến', money(expectedInterest)),
                    const SizedBox(height: 6),
                    DetailRow(
                      'Tổng nhận khi đáo hạn',
                      money(parsedAmount + expectedInterest),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              FilledButton(
                onPressed: loading ? null : review,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0C4E44),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  loading ? 'Đang xử lý...' : 'Xác nhận mở sổ',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MINH HỌA 1: HEO VÀNG TIẾT KIỆM (PIGGY BANK ILLUSTRATION)
// ============================================================================
class PiggyBankIllustration extends StatelessWidget {
  const PiggyBankIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 104,
      child: CustomPaint(
        size: const Size(116, 104),
        painter: _PiggyBankPainter(),
      ),
    );
  }
}

class _PiggyBankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Nền bo cong màu xanh mint nhạt
    final bgPaint = Paint()..color = const Color(0xFFD6ECE7);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.38),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // 2. Thẻ biểu đồ cột (bên trái phía trên)
    final cardPaint = Paint()..color = const Color(0xFF285C74);
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.16, size.width * 0.36, size.height * 0.30),
      const Radius.circular(6),
    );
    canvas.drawRRect(cardRect, cardPaint);

    // Các cột biểu đồ
    final barWhite = Paint()..color = Colors.white;
    final barTeal = Paint()..color = const Color(0xFF4FD1C5);
    final barMuted = Paint()..color = Colors.white60;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.30, 4, size.height * 0.12),
        const Radius.circular(2),
      ),
      barMuted,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.18, size.height * 0.24, 4, size.height * 0.18),
        const Radius.circular(2),
      ),
      barWhite,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.24, size.height * 0.28, 4, size.height * 0.14),
        const Radius.circular(2),
      ),
      barMuted,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.30, size.height * 0.20, 4, size.height * 0.22),
        const Radius.circular(2),
      ),
      barTeal,
    );

    // 3. Mũi tên cam hướng lên
    final arrowPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;
    final arrowPath = Path();
    arrowPath.moveTo(size.width * 0.36, size.height * 0.42);
    arrowPath.lineTo(size.width * 0.52, size.height * 0.28);
    arrowPath.lineTo(size.width * 0.58, size.height * 0.32);
    arrowPath.lineTo(size.width * 0.64, size.height * 0.18);
    arrowPath.lineTo(size.width * 0.48, size.height * 0.20);
    arrowPath.lineTo(size.width * 0.54, size.height * 0.24);
    arrowPath.lineTo(size.width * 0.38, size.height * 0.38);
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);

    // 4. Đồng xu vàng rơi
    _drawCoin(canvas, Offset(size.width * 0.88, size.height * 0.18), 11);
    _drawCoin(canvas, Offset(size.width * 0.86, size.height * 0.40), 10);

    // 5. Thân chú heo vàng (chubby piggy bank)
    final pigBodyPaint = Paint()..color = const Color(0xFFFFDF7A);

    // Thân heo
    final bodyCenter = Offset(size.width * 0.66, size.height * 0.74);
    canvas.drawOval(
      Rect.fromCenter(center: bodyCenter, width: size.width * 0.58, height: size.height * 0.52),
      pigBodyPaint,
    );

    // Tai heo
    final earPath = Path();
    earPath.moveTo(size.width * 0.65, size.height * 0.52);
    earPath.quadraticBezierTo(size.width * 0.70, size.height * 0.38, size.width * 0.78, size.height * 0.47);
    earPath.close();
    canvas.drawPath(earPath, Paint()..color = const Color(0xFFFFCA28));

    // Mõm heo
    final snoutCenter = Offset(size.width * 0.38, size.height * 0.74);
    canvas.drawOval(
      Rect.fromCenter(center: snoutCenter, width: size.width * 0.18, height: size.height * 0.24),
      Paint()..color = const Color(0xFFF59E0B),
    );
    // Lỗ mũi heo
    final nostrilPaint = Paint()..color = const Color(0xFF92400E);
    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.71), 2.5, nostrilPaint);
    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.77), 2.5, nostrilPaint);

    // Mắt heo
    final eyePaint = Paint()..color = const Color(0xFF451A03);
    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.63), 3, eyePaint);
    canvas.drawCircle(Offset(size.width * 0.53, size.height * 0.62), 1, Paint()..color = Colors.white);
  }

  void _drawCoin(Canvas canvas, Offset center, double radius) {
    final coinPaint = Paint()..color = const Color(0xFFFBBF24);
    final coinBorder = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final innerBorder = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius, coinPaint);
    canvas.drawCircle(center, radius, coinBorder);
    canvas.drawCircle(center, radius * 0.65, innerBorder);
    // Hoa văn tâm đồng xu
    final starPaint = Paint()..color = const Color(0xFFB45309);
    canvas.drawCircle(center, 2.2, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// MINH HỌA 2: ĐIỆN THOẠI TÍCH LŨY (ACCUMULATION ILLUSTRATION)
// ============================================================================
class AccumulationIllustration extends StatelessWidget {
  const AccumulationIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 104,
      child: CustomPaint(
        size: const Size(116, 104),
        painter: _AccumulationPainter(),
      ),
    );
  }
}

class _AccumulationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Nền bo cong màu kem/beige nhạt
    final bgPaint = Paint()..color = const Color(0xFFF5EFE4);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.38),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // 2. Mũi tên xanh dương xoay vòng tuần hoàn (circular arrows)
    final arrowPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    // Mũi tên góc trên bên phải
    final topArrowPath = Path();
    topArrowPath.moveTo(size.width * 0.64, size.height * 0.16);
    topArrowPath.arcToPoint(
      Offset(size.width * 0.86, size.height * 0.40),
      radius: Radius.circular(size.width * 0.3),
      clockwise: true,
    );
    topArrowPath.lineTo(size.width * 0.94, size.height * 0.38);
    topArrowPath.lineTo(size.width * 0.84, size.height * 0.50);
    topArrowPath.lineTo(size.width * 0.76, size.height * 0.38);
    topArrowPath.close();
    canvas.drawPath(topArrowPath, arrowPaint);

    // Mũi tên góc dưới bên trái
    final bottomArrowPath = Path();
    bottomArrowPath.moveTo(size.width * 0.40, size.height * 0.88);
    bottomArrowPath.arcToPoint(
      Offset(size.width * 0.20, size.height * 0.64),
      radius: Radius.circular(size.width * 0.3),
      clockwise: true,
    );
    bottomArrowPath.lineTo(size.width * 0.12, size.height * 0.66);
    bottomArrowPath.lineTo(size.width * 0.22, size.height * 0.54);
    bottomArrowPath.lineTo(size.width * 0.28, size.height * 0.66);
    bottomArrowPath.close();
    canvas.drawPath(bottomArrowPath, arrowPaint);

    // 3. Điện thoại nghiêng 3D
    canvas.save();
    canvas.translate(size.width * 0.52, size.height * 0.54);
    canvas.rotate(-0.35); // Góc nghiêng

    final phoneWidth = size.width * 0.44;
    final phoneHeight = size.height * 0.68;
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: phoneWidth, height: phoneHeight),
      const Radius.circular(12),
    );

    // Viền vỏ điện thoại màu xanh ngọc
    final phoneBorderPaint = Paint()..color = const Color(0xFF34D399);
    canvas.drawRRect(phoneRect, phoneBorderPaint);

    // Màn hình điện thoại trắng sáng
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: phoneWidth - 6, height: phoneHeight - 6),
      const Radius.circular(9),
    );
    canvas.drawRRect(screenRect, Paint()..color = const Color(0xFFF0FDF4));

    // Khe nhét tiền (slot)
    final slotRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -phoneHeight * 0.15), width: phoneWidth * 0.64, height: 4.5),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(slotRect, Paint()..color = const Color(0xFF047857));

    // Đồng xu đang trượt vào khe nhét tiền
    _drawCoin(canvas, Offset(0, -phoneHeight * 0.15), 11);

    canvas.restore();

    // 4. Đồng xu vàng phía trên
    _drawCoin(canvas, Offset(size.width * 0.84, size.height * 0.16), 10);
  }

  void _drawCoin(Canvas canvas, Offset center, double radius) {
    final coinPaint = Paint()..color = const Color(0xFFFBBF24);
    final coinBorder = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final innerBorder = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius, coinPaint);
    canvas.drawCircle(center, radius, coinBorder);
    canvas.drawCircle(center, radius * 0.65, innerBorder);
    // Hoa văn tâm đồng xu
    final starPaint = Paint()..color = const Color(0xFFB45309);
    canvas.drawCircle(center, 2.2, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

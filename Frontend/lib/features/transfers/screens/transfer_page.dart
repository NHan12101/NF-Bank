import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../models/account_resolution.dart';
import '../models/recent_recipient.dart';
import '../models/transfer_receipt.dart';
import '../services/transfer_repository.dart';
import '../services/transfer_persist_service.dart';
import 'qr_scanner_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/language_controller.dart';
import '../widgets/recent_recipients_sheet.dart';
import '../widgets/transaction_pin_sheet.dart';
import '../widgets/transfer_receipt_view.dart';
import '../widgets/transfer_ui_components.dart';

export '../widgets/recent_recipients_sheet.dart';
export '../widgets/transaction_pin_sheet.dart'
    show showTransactionPINSheet, TransactionPINInput, TransactionPINSheet;
export '../widgets/transfer_receipt_view.dart';
export '../widgets/transfer_ui_components.dart';

typedef _SourceAccountCard = SourceAccountCard;
typedef _BankSelector = BankSelector;
typedef _RecentRecipientsButton = RecentRecipientsButton;
typedef _RecentRecipientsSheet = RecentRecipientsSheet;
typedef _PartyTile = PartyTile;
typedef _BottomActions = BottomActions;
typedef _RecipientPreview = RecipientPreview;
typedef _InfoRow = InfoRow;
typedef _TemplateCard = TemplateCard;
typedef _SavedRecipientsSheet = SavedRecipientsSheet;
typedef _ReceiptHeader = ReceiptHeader;
typedef _ReceiptParty = ReceiptParty;
typedef _ReceiptRow = ReceiptRow;

enum _TransferStep { details, confirmation, receipt }

class TransferPage extends StatefulWidget {
  const TransferPage({
    super.key,
    this.preFilledAccount,
    this.preFilledAmount,
    this.preFilledDescription,
  });

  final String? preFilledAccount;
  final int? preFilledAmount;
  final String? preFilledDescription;

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _form = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _repository = const TransferRepository();
  final _bankRepository = const BankRepository();
  final _receiptBoundaryKey = GlobalKey();

  _TransferStep _step = _TransferStep.details;
  SessionUser? _user;
  Map<String, dynamic>? _sourceAccount;
  String _senderAvatarURL = '';
  AccountResolution? _recipient;
  List<RecentRecipient> _recentRecipients = const [];
  TransferReceipt? _receipt;
  String? _idempotencyKey;
  String? _resolutionError;
  String _defaultDescription = 'Chuyen khoan';
  Timer? _resolveDebounce;
  int _resolutionRequest = 0;
  bool _resolving = false;
  bool? _hasTransactionPin;
  bool _loading = false;
  bool _savingReceipt = false;
  int _dailyTransferLimit = 50000000;

  final _persist = const TransferPersistService();
  List<SavedRecipient> _savedRecipients = [];
  List<TransferTemplate> _templates = [];

  int get _parsedAmount =>
      int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadSourceAccount();
    _loadRecentRecipients();
    _loadDefaultDescription();
    _loadTransactionPINStatus();
    _loadPersistedData();

    // Prefill fields from QR scan if available
    if (widget.preFilledAccount != null) {
      _account.text = widget.preFilledAccount!;
      _onAccountChanged(widget.preFilledAccount!);
    }
    if (widget.preFilledAmount != null && widget.preFilledAmount! > 0) {
      _amount.text = formatCurrencyInput(widget.preFilledAmount!);
    }
    if (widget.preFilledDescription != null && widget.preFilledDescription!.isNotEmpty) {
      _description.text = widget.preFilledDescription!;
    }
  }

  Future<void> _loadPersistedData() async {
    final results = await Future.wait([
      _persist.getSavedRecipients(),
      _persist.getTemplates(),
    ]);
    if (!mounted) return;
    setState(() {
      _savedRecipients = results[0] as List<SavedRecipient>;
      _templates = results[1] as List<TransferTemplate>;
    });
  }

  void _applyTemplate(TransferTemplate template) {
    setState(() {
      _account.text = template.accountNumber;
      _amount.text = formatCurrencyInput(template.amount);
      _description.text = template.description;
      _onAccountChanged(template.accountNumber);
    });
    showMessage(context, 'Đã áp dụng mẫu chuyển tiền "${template.name}"');
  }

  Future<void> _deleteTemplate(String id) async {
    try {
      await _persist.deleteTemplate(id);
      await _loadPersistedData();
      if (mounted) showMessage(context, 'Đã xóa mẫu chuyển tiền');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _saveRecipientContact(AccountResolution recipient) async {
    final controller = TextEditingController(text: recipient.accountName);
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu vào danh bạ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: fieldDecoration('Tên danh bạ gợi nhớ'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (nickname == null || nickname.isEmpty) return;

    try {
      final saved = SavedRecipient(
        accountNumber: recipient.accountNumber,
        accountName: recipient.accountName,
        nickname: nickname,
      );
      await _persist.saveRecipient(saved);
      await _loadPersistedData();
      if (mounted) showMessage(context, 'Đã lưu vào danh bạ thụ hưởng');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _showSavedRecipients() async {
    final selected = await showModalBottomSheet<SavedRecipient>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedRecipientsSheet(
        recipients: _savedRecipients,
        onDelete: (recipient) async {
          try {
            await _persist.deleteRecipient(recipient.accountNumber);
            await _loadPersistedData();
            if (mounted) showMessage(context, 'Đã xóa khỏi danh bạ');
          } catch (e) {
            if (mounted) showMessage(context, '$e', error: true);
          }
        },
      ),
    );

    if (selected != null) {
      setState(() {
        _account.text = selected.accountNumber;
        _onAccountChanged(selected.accountNumber);
      });
    }
  }

  Future<void> _saveAsTemplate(TransferReceipt receipt, AccountResolution? recipient) async {
    final defaultName = recipient?.accountName ?? 'Mẫu chuyển tiền';
    final controller = TextEditingController(text: defaultName);
    
    final templateName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu làm mẫu chuyển tiền'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: fieldDecoration('Tên mẫu chuyển khoản'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (templateName == null || templateName.isEmpty) return;

    try {
      final template = TransferTemplate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: templateName,
        accountNumber: recipient?.accountNumber ?? _account.text,
        accountName: recipient?.accountName ?? 'Thụ hưởng',
        amount: receipt.amount,
        description: receipt.description,
      );
      await _persist.saveTemplate(template);
      await _loadPersistedData();
      if (mounted) showMessage(context, 'Đã lưu mẫu chuyển khoản thành công!');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    _account.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultDescription() async {
    final userName = await TokenStorage.getUserName();
    final normalizedName = removeVietnameseDiacritics(userName);
    final description = normalizedName.isEmpty
        ? 'Chuyen khoan'
        : '$normalizedName chuyen khoan';
    if (!mounted) return;
    _defaultDescription = description;
    if (_description.text.trim().isEmpty) {
      _description.text = description;
    }
  }

  Future<void> _loadSourceAccount() async {
    try {
      final results = await Future.wait([
        TokenStorage.getUser(),
        _bankRepository.accounts(),
        _bankRepository.profile(),
      ]);
      final user = results[0] as SessionUser?;
      final accounts = results[1] as List<Map<String, dynamic>>;
      final profile = results[2] as Map<String, dynamic>;
      Map<String, dynamic>? source;
      for (final account in accounts) {
        if (account['account_type']?.toString() == 'PAYMENT') {
          source = account;
          break;
        }
      }
      source ??= accounts.isEmpty ? null : accounts.first;
      final limit = (profile['daily_transfer_limit'] as num?)?.toInt() ?? 50000000;
      if (mounted) {
        setState(() {
          _user = user;
          _sourceAccount = source;
          _senderAvatarURL = profile['avatar_url']?.toString().trim() ?? '';
          _dailyTransferLimit = limit;
        });
      }
    } on ApiException {
      // Người dùng vẫn có thể nhập giao dịch; backend sẽ kiểm tra số dư.
    }
  }

  Future<void> _loadRecentRecipients() async {
    try {
      final transactions = await _bankRepository.transactions();
      if (mounted) {
        setState(() {
          _recentRecipients = recentRecipientsFromTransactions(transactions);
        });
      }
    } on ApiException {
      // Danh sách chuyển nhanh là tiện ích phụ, không chặn giao dịch mới.
    }
  }

  Future<void> _loadTransactionPINStatus() async {
    try {
      final hasPIN = await _repository.hasTransactionPin();
      if (mounted) setState(() => _hasTransactionPin = hasPIN);
    } on ApiException {
      // Trạng thái sẽ được thử lại ngay trước khi xác nhận giao dịch.
    }
  }

  void _onAccountChanged(String value) {
    _resolveDebounce?.cancel();
    final accountNumber = value.trim();
    final request = ++_resolutionRequest;
    setState(() {
      _recipient = null;
      _resolutionError = null;
      _resolving = false;
    });

    if (!RegExp(r'^[0-9]{12}$').hasMatch(accountNumber)) return;
    _resolveDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _resolveRecipient(accountNumber, request),
    );
  }

  Future<AccountResolution?> _resolveRecipient(
    String accountNumber,
    int request, {
    bool showMessageOnError = false,
  }) async {
    if (mounted) {
      setState(() {
        _resolving = true;
        _resolutionError = null;
      });
    }
    try {
      final recipient = await _repository.resolveAccount(accountNumber);
      if (!mounted ||
          request != _resolutionRequest ||
          _account.text.trim() != accountNumber) {
        return null;
      }
      setState(() => _recipient = recipient);
      return recipient;
    } on ApiException catch (error) {
      if (mounted && request == _resolutionRequest) {
        setState(() => _resolutionError = error.message);
        if (showMessageOnError) {
          showMessage(context, error.message, error: true, transaction: true);
        }
      }
      return null;
    } finally {
      if (mounted && request == _resolutionRequest) {
        setState(() => _resolving = false);
      }
    }
  }

  Future<void> _review() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final accountNumber = _account.text.trim();
      var recipient = _recipient;
      if (recipient == null || recipient.accountNumber != accountNumber) {
        recipient = await _resolveRecipient(
          accountNumber,
          ++_resolutionRequest,
          showMessageOnError: true,
        );
      }
      if (recipient == null) return;
      if (!mounted) return;
      setState(() {
        _recipient = recipient;
        _idempotencyKey = TransferRepository.createIdempotencyKey();
        _step = _TransferStep.confirmation;
      });
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message, error: true, transaction: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _authorizeAndSubmit() async {
    bool hasPIN;
    try {
      hasPIN = _hasTransactionPin ?? await _repository.hasTransactionPin();
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message, error: true, transaction: true);
      }
      return;
    }

    if (!mounted) return;
    final pinResult = await showTransactionPINSheet(
      context,
      createPIN: !hasPIN,
    );
    if (pinResult == null || !mounted) return;

    setState(() => _loading = true);
    try {
      if (!hasPIN) {
        await _repository.setupTransactionPin(
          pinResult.pin,
          pinResult.confirmPIN!,
        );
        _hasTransactionPin = true;
      }
      await _submit(pinResult.pin);
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message, error: true, transaction: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit(String transactionPIN) async {
    final recipient = _recipient;
    final requestID = _idempotencyKey;
    if (recipient == null || requestID == null) return;

    final receipt = await _repository.transfer(
      accountNumber: recipient.accountNumber,
      amount: _parsedAmount,
      description: _description.text.trim(),
      idempotencyKey: requestID,
      transactionPin: transactionPIN,
    );
    if (!mounted) return;
    final updatedRecent = [
      RecentRecipient(
        accountNumber: recipient.accountNumber,
        accountName: recipient.accountName,
      ),
      ..._recentRecipients.where(
        (item) => item.accountNumber != recipient.accountNumber,
      ),
    ].take(10).toList(growable: false);
    setState(() {
      _receipt = receipt;
      _recentRecipients = updatedRecent;
      _step = _TransferStep.receipt;
    });
  }

  Future<void> _showRecentRecipients() async {
    if (_recentRecipients.isEmpty) return;
    final selected = await showModalBottomSheet<RecentRecipient>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _RecentRecipientsSheet(recipients: _recentRecipients),
    );
    if (selected == null || !mounted) return;

    _resolveDebounce?.cancel();
    final request = ++_resolutionRequest;
    _account.text = selected.accountNumber;
    setState(() {
      _recipient = null;
      _resolutionError = null;
      _resolving = false;
    });
    await _resolveRecipient(
      selected.accountNumber,
      request,
      showMessageOnError: true,
    );
  }

  void _reset() {
    _account.clear();
    _amount.clear();
    _description.text = _defaultDescription;
    _resolveDebounce?.cancel();
    _resolutionRequest++;
    setState(() {
      _step = _TransferStep.details;
      _recipient = null;
      _receipt = null;
      _idempotencyKey = null;
      _resolutionError = null;
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    final canPop = Navigator.canPop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (!canPop && _step == _TransferStep.details) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1F0D33), const Color(0xFF12071F)]
                    : [const Color(0xFF562875), const Color(0xFF3B1554)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF562875).withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Image.asset('assets/images/logo_transparent.png', height: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Money Transfer 24/7' : 'Chuyển tiền Napas 24/7',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isEn ? 'Fast, secure & free transfers' : 'Chuyển tiền siêu tốc, an toàn & miễn phí',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_step != _TransferStep.details) ...[
          PageTitle(switch (_step) {
            _TransferStep.details => '',
            _TransferStep.confirmation => isEn ? 'Confirm Transaction' : 'Xác nhận thông tin',
            _TransferStep.receipt => isEn ? 'Transaction Completed' : 'Giao dịch hoàn tất',
          }, subtitle: _subtitle),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 4),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_step) {
                _TransferStep.details => _detailsCard(),
                _TransferStep.confirmation => _confirmationCard(),
                _TransferStep.receipt => _receiptCard(),
              },
            ),
          ),
        ),
      ],
    );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF562875),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(isEn ? 'Money Transfer' : 'Chuyển tiền', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: content,
      );
    }

    return content;
  }

  String get _subtitle {
    final isEn = LanguageController.instance.isEnglish;
    return switch (_step) {
      _TransferStep.details => isEn ? 'Internal NF Bank transfer.' : 'Chuyển khoản nội bộ NF Bank.',
      _TransferStep.confirmation => isEn ? 'Please double check your transfer details.' : 'Kiểm tra chính xác thông tin giao dịch.',
      _TransferStep.receipt => isEn ? 'Payment recorded in NF Bank system.' : 'Tiền đã được ghi nhận trong hệ thống NF Bank.',
    };
  }

  Widget _detailsCard() {
    final isEn = LanguageController.instance.isEnglish;
    return KeyedSubtree(
      key: const ValueKey('details'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _transferSection(
              title: isEn ? 'Transfer Source' : 'Nguồn chuyển tiền',
              icon: Icons.account_balance_wallet_outlined,
              child: _SourceAccountCard(account: _sourceAccount),
            ),
            if (_templates.isNotEmpty) ...[
              const SizedBox(height: 10),
              _transferSection(
                title: isEn ? 'Quick Transfer Templates' : 'Mẫu chuyển tiền nhanh',
                icon: Icons.flash_on_rounded,
                child: SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tmpl = _templates[index];
                      return _TemplateCard(
                        template: tmpl,
                        onTap: () => _applyTemplate(tmpl),
                        onDelete: () => _deleteTemplate(tmpl.id),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _transferSection(
              title: isEn ? 'Transfer To' : 'Chuyển đến',
              icon: Icons.south_west_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BankSelector(),
                  if (_recentRecipients.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _RecentRecipientsButton(
                      count: _recentRecipients.length,
                      onTap: _showRecentRecipients,
                    ),
                  ],
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _account,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        fieldDecoration(
                          isEn ? 'Account Number' : 'Số tài khoản',
                          hint: isEn ? 'Enter 12 digits' : 'Nhập 12 chữ số',
                        ).copyWith(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          counterText: '',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const QRScannerPage()),
                                  );
                                },
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              IconButton(
                                icon: const Icon(Icons.contact_page_outlined, size: 20),
                                onPressed: _showSavedRecipients,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                tooltip: isEn ? 'Saved Contacts' : 'Danh bạ thụ hưởng',
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                    onChanged: _onAccountChanged,
                    validator: (value) =>
                        RegExp(r'^[0-9]{12}$').hasMatch(value?.trim() ?? '')
                        ? null
                        : (isEn ? 'Account number must be 12 digits' : 'Số tài khoản phải gồm 12 chữ số'),
                  ),
                  if (_resolving) ...[
                    const SizedBox(height: 7),
                    const LinearProgressIndicator(minHeight: 2),
                  ] else if (_recipient != null) ...[
                    const SizedBox(height: 8),
                    _RecipientPreview(
                      recipient: _recipient!,
                      onSaveContact: () => _saveRecipientContact(_recipient!),
                    ),
                  ] else if (_resolutionError != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      _resolutionError!,
                      style: const TextStyle(
                        color: Color(0xFFFF8A80),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            _transferSection(
              title: isEn ? 'Transfer Amount' : 'Số tiền chuyển',
              icon: Icons.payments_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    style: const TextStyle(
                      color: Color(0xFFF7941D),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: fieldDecoration(
                      isEn ? 'Amount' : 'Số tiền',
                    ).copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      suffixText: 'VND',
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (_) => setState(() {}),
                    validator: (_) {
                      if (_parsedAmount < 10000) {
                        return isEn ? 'Minimum amount is 10,000 VND' : 'Số tiền tối thiểu là 10.000 VND';
                      }
                      if (_parsedAmount > _dailyTransferLimit) {
                        return isEn
                            ? 'Amount exceeds daily limit (Max: ${money(_dailyTransferLimit)})'
                            : 'Số tiền vượt quá hạn mức ngày của bạn (Tối đa: ${money(_dailyTransferLimit)})';
                      }
                      final balance = (_sourceAccount?['balance'] as num?)?.toDouble() ?? 0.0;
                      if (_parsedAmount > balance) {
                        return isEn ? 'Insufficient account balance' : 'Số dư tài khoản không đủ';
                      }
                      return null;
                    },
                  ),
                  if (_parsedAmount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      _amountInWords,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            _transferSection(
              title: isEn ? 'Transfer Description' : 'Nội dung chuyển khoản',
              icon: Icons.edit_note_rounded,
              child: TextFormField(
                controller: _description,
                maxLength: 140,
                decoration: fieldDecoration(
                  isEn ? 'Description' : 'Nội dung',
                  hint: _defaultDescription,
                ).copyWith(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _BottomActions(
              primaryLabel: _loading ? (isEn ? 'Verifying...' : 'Đang xác minh...') : (isEn ? 'Continue' : 'Tiếp tục'),
              onPrimary: _loading ? null : _review,
              showBack: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _transferSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: _panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF562875).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: const Color(0xFF562875)),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF562875)),
            ),
          ],
        ),
        const SizedBox(height: 11),
        child,
      ],
    ),
  );

  Widget _confirmationCard() {
    final recipient = _recipient!;
    return Column(
      key: const ValueKey('confirmation'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Số tiền giao dịch',
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 15),
              ),
              const SizedBox(height: 5),
              Text(
                money(_parsedAmount, recipient.currency),
                style: const TextStyle(
                  color: Color(0xFFF7941D),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _amountInWords,
                style: TextStyle(color: AppTheme.textSecondary(context)),
              ),
              const Divider(height: 24),
              Text(
                'Người chuyển',
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 15),
              ),
              const SizedBox(height: 8),
              _PartyTile(
                name: _user?.fullName ?? 'Người dùng NF Bank',
                accountNumber:
                    _sourceAccount?['account_number']?.toString() ?? '—',
                bankName: 'NF Bank',
                avatarURL: _senderAvatarURL,
              ),
              const SizedBox(height: 14),
              Text(
                'Người nhận',
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 15),
              ),
              const SizedBox(height: 8),
              _PartyTile(
                name: recipient.accountName,
                accountNumber: recipient.accountNumber,
                bankName: recipient.bankName,
                avatarURL: recipient.avatarUrl,
              ),
              const Divider(height: 24),
              _InfoRow(
                'Nội dung chuyển tiền',
                _description.text.trim().isEmpty
                    ? 'Chuyển tiền'
                    : _description.text.trim(),
              ),
              const _InfoRow('Hình thức chuyển tiền', 'Trong NF Bank'),
              Divider(height: 22, color: AppTheme.cardBorder(context)),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: Color(0xFFFFB547),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Kiểm tra chính xác thông tin trước khi xác nhận.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFFFFD58A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _BottomActions(
          primaryLabel: _loading ? 'Đang xử lý...' : 'Xác nhận',
          onPrimary: _loading ? null : _authorizeAndSubmit,
          onBack: _loading
              ? null
              : () => setState(() => _step = _TransferStep.details),
        ),
      ],
    );
  }

  String get _amountInWords {
    if (_parsedAmount <= 0) return '';
    return moneyInVietnameseWords(_parsedAmount);
  }

  BoxDecoration _panelDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF26133B) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? const Color(0xFF3D1F5E) : const Color(0xFFEADBFA)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _receiptCard() {
    final receipt = _receipt!;
    final recipient = _recipient;
    return Column(
      key: const ValueKey('receipt'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: _receiptBoundaryKey,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF562875), Color(0xFF3B1554)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x337C83FD)),
            ),
            child: Column(
              children: [
                const _ReceiptHeader(),
                const SizedBox(height: 22),
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0x2668D391),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF68D391),
                    size: 31,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chuyển khoản thành công',
                  style: TextStyle(
                    color: Color(0xFFB9C4DC),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  money(receipt.amount, receipt.currency),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  moneyInVietnameseWords(receipt.amount),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7F8BA8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.white.withValues(alpha: .08), height: 1),
                const SizedBox(height: 17),
                _ReceiptParty(
                  label: 'NGƯỜI CHUYỂN',
                  name: _user?.fullName ?? 'Người dùng NF Bank',
                  accountNumber:
                      _sourceAccount?['account_number']?.toString() ?? '—',
                  avatarURL: _senderAvatarURL,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: .06),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          size: 17,
                          color: Color(0xFFF7941D),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: .06),
                        ),
                      ),
                    ],
                  ),
                ),
                _ReceiptParty(
                  label: 'NGƯỜI NHẬN',
                  name: recipient?.accountName ?? '—',
                  accountNumber: recipient?.accountNumber ?? '—',
                  avatarURL: recipient?.avatarUrl ?? '',
                ),
                const SizedBox(height: 17),
                Divider(color: Colors.white.withValues(alpha: .08), height: 1),
                const SizedBox(height: 10),
                _ReceiptRow('Mã giao dịch', receipt.referenceCode),
                _ReceiptRow(
                  'Thời gian',
                  receipt.createdAt == null
                      ? '—'
                      : dateTimeText(receipt.createdAt),
                ),
                _ReceiptRow(
                  'Nội dung',
                  receipt.description.isEmpty
                      ? 'Chuyển tiền'
                      : receipt.description,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1468D391),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF68D391),
                        size: 16,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Giao dịch được bảo mật bởi NF Bank',
                        style: TextStyle(
                          color: Color(0xFF91DDB2),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _savingReceipt ? null : _saveReceiptImage,
                icon: _savingReceipt
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 19),
                label: Text(_savingReceipt ? 'Đang lưu...' : 'Lưu ảnh'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _savingReceipt ? null : _reset,
                child: const Text('Giao dịch mới'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _saveAsTemplate(receipt, recipient),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Lưu làm mẫu chuyển tiền'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E2638),
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white10),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveReceiptImage() async {
    if (_savingReceipt) return;
    final pixelRatio = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.5, 2.5).toDouble();
    setState(() => _savingReceipt = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _receiptBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Không tìm thấy vùng biên lai');
      }
      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Không thể tạo ảnh biên lai');
      }

      var hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!hasAccess) {
        throw StateError('Bạn chưa cấp quyền lưu ảnh');
      }
      final reference = _receipt?.referenceCode.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'NF_Bank_${reference ?? DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        showMessage(context, 'Đã lưu ảnh biên lai vào thư viện');
      }
    } on GalException catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Không thể lưu ảnh: ${error.type.message}',
          error: true,
        );
      }
    } on MissingPluginException {
      if (mounted) {
        showMessage(
          context,
          'Tính năng lưu ảnh vừa được cài đặt. Hãy dừng hẳn app và chạy lại flutter run.',
          error: true,
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Không thể lưu ảnh biên lai (${error.code})',
          error: true,
        );
      }
    } catch (error) {
      debugPrint('Save receipt failed: $error');
      if (mounted) {
        showMessage(
          context,
          error is StateError
              ? error.message.toString()
              : 'Không thể lưu ảnh biên lai',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _savingReceipt = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_service.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';
import '../../../transfers/screens/payment_gateway_checkout_page.dart';
import '../../../transfers/services/payment_repository.dart';

void showPaymentInitiateSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const PaymentInitiateSheet(),
  );
}

class PaymentInitiateSheet extends StatefulWidget {
  const PaymentInitiateSheet({super.key});

  @override
  State<PaymentInitiateSheet> createState() => _PaymentInitiateSheetState();
}

class _PaymentInitiateSheetState extends State<PaymentInitiateSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tokenController = TextEditingController();
  final _amountController = TextEditingController();
  final _orderInfoController = TextEditingController();
  final _repo = const PaymentRepository();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenController.dispose();
    _amountController.dispose();
    _orderInfoController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _tokenController.text = data.text!.trim();
      });
    }
  }

  Future<void> _proceedWithToken(String token) async {
    if (token.isEmpty) {
      showMessage(context, 'Vui lòng nhập mã thanh toán', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final session = await _repo.getPaymentSession(token);
      if (!mounted) return;
      Navigator.pop(context); // Close sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentGatewayCheckoutPage(
            token: token,
            initialSession: session,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'Lỗi kết nối phiên thanh toán: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTestInvoice() async {
    final amountVal = int.tryParse(_amountController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final orderInfoVal = _orderInfoController.text.trim();

    if (amountVal <= 0) {
      showMessage(context, 'Số tiền không hợp lệ', error: true);
      return;
    }
    if (orderInfoVal.isEmpty) {
      showMessage(context, 'Vui lòng nhập nội dung hóa đơn', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final token = await _repo.testCreatePayment(
        amount: amountVal,
        orderInfo: orderInfoVal,
      );
      final session = await _repo.getPaymentSession(token);
      if (!mounted) return;
      Navigator.pop(context); // Close sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentGatewayCheckoutPage(
            token: token,
            initialSession: session,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'Lỗi tạo hóa đơn kiểm thử: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF171A27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF6C7CFF),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Nhập mã thanh toán'),
              Tab(text: 'Tạo hóa đơn kiểm thử (Dev)'),
            ],
          ),
          const SizedBox(height: 20),
          _loading
              ? const SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Nhập mã token
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Dán mã phiên thanh toán (Token) nhận từ đối tác để tiếp tục thực hiện thanh toán.',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tokenController,
                                  decoration: fieldDecoration('Mã token thanh toán').copyWith(
                                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: _pasteFromClipboard,
                                icon: const Icon(Icons.paste_rounded),
                                tooltip: 'Dán từ bộ nhớ tạm',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () => _proceedWithToken(_tokenController.text.trim()),
                            child: const Text('Tiếp tục'),
                          ),
                        ],
                      ),
                      // Tab 2: Tạo hóa đơn test
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Tạo nhanh hóa đơn thanh toán giả lập tới TEST_MERCHANT ("Cửa hàng Tiện lợi NF-Mart").',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            decoration: fieldDecoration('Số tiền thanh toán').copyWith(
                              suffixText: 'VND',
                              prefixIcon: const Icon(Icons.payments_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _orderInfoController,
                            decoration: fieldDecoration('Nội dung hóa đơn').copyWith(
                              prefixIcon: const Icon(Icons.description_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _createTestInvoice,
                            child: const Text('Tạo hóa đơn & Thanh toán'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

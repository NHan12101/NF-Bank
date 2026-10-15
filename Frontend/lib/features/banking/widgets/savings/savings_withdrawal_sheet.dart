import 'package:flutter/material.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';
import 'savings_detail_sheet.dart';

class SavingsWithdrawalSheet extends StatefulWidget {
  const SavingsWithdrawalSheet({
    super.key,
    required this.principal,
    required this.startDate,
    required this.demandInterestRate,
  });

  final int principal;
  final DateTime? startDate;
  final double demandInterestRate;

  @override
  State<SavingsWithdrawalSheet> createState() => _SavingsWithdrawalSheetState();
}

class _SavingsWithdrawalSheetState extends State<SavingsWithdrawalSheet> {
  final amount = TextEditingController();
  String? error;

  int get parsedAmount =>
      int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  int get remainingPrincipal => widget.principal - parsedAmount;
  int get accruedDays {
    final startDate = widget.startDate;
    if (startDate == null) return 0;
    final days = DateTime.now().difference(startDate.toLocal()).inDays;
    return days > 0 ? days : 0;
  }

  int get estimatedInterest =>
      (parsedAmount * widget.demandInterestRate / 100 * accruedDays / 365)
          .round();

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  void submit() {
    String? validationError;
    if (parsedAmount < 100000) {
      validationError = 'Số tiền rút tối thiểu là 100.000 VND';
    } else if (parsedAmount > widget.principal) {
      validationError = 'Số tiền rút vượt quá tiền gốc hiện có';
    } else if (remainingPrincipal > 0 && remainingPrincipal < 5000000) {
      validationError =
          'Số dư còn lại phải từ 5.000.000 VND hoặc bạn cần rút toàn bộ';
    }
    if (validationError != null) {
      setState(() => error = validationError);
      return;
    }
    Navigator.pop(context, parsedAmount);
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151D31),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'Rút tiết kiệm trước hạn',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Phần tiền rút trước hạn chỉ hưởng lãi không kỳ hạn theo số ngày thực gửi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9BA8C7),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [CurrencyInputFormatter()],
                onChanged: (_) => setState(() => error = null),
                decoration: fieldDecoration(
                  'Số tiền muốn rút',
                  hint: 'Tối thiểu 100.000',
                ).copyWith(suffixText: 'VND'),
              ),
              if (parsedAmount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  moneyInVietnameseWords(parsedAmount),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  label: Text(
                    'Rút toàn bộ ${money(widget.principal).replaceAll(' VND', '')}',
                  ),
                  onPressed: () {
                    amount.text = formatCurrencyInput(widget.principal);
                    setState(() => error = null);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF11192B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SavingsDetailRow('Số ngày thực gửi', '$accruedDays ngày'),
                    SavingsDetailRow(
                      'Lãi suất không kỳ hạn',
                      '${widget.demandInterestRate}%/năm',
                    ),
                    SavingsDetailRow(
                      'Lãi không kỳ hạn dự kiến',
                      money(estimatedInterest),
                    ),
                    SavingsDetailRow(
                      'Tổng tiền nhận',
                      money(parsedAmount + estimatedInterest),
                    ),
                    SavingsDetailRow(
                      'Tiền gốc còn lại',
                      money(remainingPrincipal < 0 ? 0 : remainingPrincipal),
                    ),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF8A9B),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: parsedAmount > 0 ? submit : null,
                      child: const Text('Tiếp tục'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

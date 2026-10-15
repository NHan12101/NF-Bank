import 'package:flutter/material.dart';

import '../../../../shared/utils/formatters.dart';
import '../common/transaction_tile.dart';
import 'savings_detail_sheet.dart';

class SavingsReviewSheet extends StatelessWidget {
  const SavingsReviewSheet({
    super.key,
    required this.amount,
    required this.expectedInterest,
    required this.sourceAccount,
    required this.termMonths,
    required this.interestRate,
    required this.maturityInstruction,
  });

  final int amount;
  final int expectedInterest;
  final Map<String, dynamic>? sourceAccount;
  final int termMonths;
  final double interestRate;
  final String maturityInstruction;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF151D31),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Xác nhận mở sổ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            DetailRow(
              'Tài khoản nguồn',
              sourceAccount?['account_number'] ?? 'PAYMENT',
            ),
            DetailRow('Số tiền gửi', money(amount)),
            DetailRow('Kỳ hạn', '$termMonths tháng'),
            DetailRow('Lãi suất', '$interestRate%/năm'),
            DetailRow('Tiền lãi dự kiến', money(expectedInterest)),
            DetailRow('Tổng tiền đáo hạn', money(amount + expectedInterest)),
            DetailRow(
              'Khi đến hạn',
              maturityInstructionLabel(maturityInstruction),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tiền sẽ được trích ngay sau khi bạn xác thực mã PIN giao dịch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9BA8C7), fontSize: 12),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Quay lại'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Xác nhận'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

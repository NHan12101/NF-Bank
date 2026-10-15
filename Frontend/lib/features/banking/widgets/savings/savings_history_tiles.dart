import 'package:flutter/material.dart';

import '../../../../shared/utils/formatters.dart';

class SavingsMaturityHistoryTile extends StatelessWidget {
  const SavingsMaturityHistoryTile({super.key, required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final renewed = event['outcome']?.toString() == 'RENEWED';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11192B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            renewed ? Icons.autorenew_rounded : Icons.check_circle_outline,
            size: 20,
            color: renewed ? const Color(0xFF9EA4FF) : const Color(0xFF68D391),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  renewed
                      ? 'Kỳ ${event['cycle_number']} · Đã tái tục'
                      : 'Kỳ ${event['cycle_number']} · Đã tất toán',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${shortDate(event['period_start'])} – ${shortDate(event['period_end'])}'
                  ' · Lãi ${money(event['interest'])}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SavingsWithdrawalHistoryTile extends StatelessWidget {
  const SavingsWithdrawalHistoryTile({super.key, required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final full = event['is_full_withdrawal'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11192B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 20,
            color: Color(0xFFFFB86B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  full ? 'Tất toán trước hạn' : 'Rút một phần',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${dateTimeText(event['processed_at'])} · Gốc ${money(event['amount'])}'
                  ' · Lãi ${money(event['interest'])}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

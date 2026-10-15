import 'package:flutter/material.dart';

import '../../../../shared/utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx});

  final Map<String, dynamic> tx;

  @override
  Widget build(BuildContext context) {
    final incoming = tx['direction'] == 'IN';
    final type = tx['type']?.toString() ?? '';
    final counterparty = tx['counterparty_name']?.toString() ?? '';
    final color = incoming ? const Color(0xFF68D391) : Colors.white;
    final amount = money(tx['amount'], tx['currency']?.toString() ?? 'VND');
    final title = switch (type) {
      'SAVINGS_DEPOSIT' => 'Gửi tiết kiệm',
      'SAVINGS_INTEREST' => 'Lãi tiền gửi tiết kiệm',
      'SAVINGS_MATURITY' => 'Tất toán sổ tiết kiệm',
      'SAVINGS_EARLY_INTEREST' => 'Lãi rút tiết kiệm trước hạn',
      'SAVINGS_EARLY_WITHDRAWAL' => 'Rút tiết kiệm trước hạn',
      _ when counterparty.isNotEmpty => counterparty,
      _ when tx['description']?.toString().isNotEmpty == true =>
        tx['description'].toString(),
      _ => type.isEmpty ? 'Giao dịch' : type,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        foregroundColor: color,
        child: Icon(
          type.startsWith('SAVINGS_')
              ? Icons.savings_outlined
              : incoming
              ? Icons.south_west_rounded
              : Icons.north_east_rounded,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        '${tx['description'] ?? ''}\n${dateTimeText(tx['created_at'])}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${incoming ? '+' : '-'}$amount',
        style: TextStyle(fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60)),
        const Spacer(),
        Flexible(
          child: Text(
            value?.toString() ?? '—',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

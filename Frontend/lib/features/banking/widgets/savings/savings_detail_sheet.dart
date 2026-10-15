import 'package:flutter/material.dart';

import '../../../../shared/utils/formatters.dart';
import 'savings_history_tiles.dart';

String maturityInstructionLabel(String value) =>
    value == 'RENEW_PRINCIPAL' ? 'Tái tục tiền gốc' : 'Tất toán về tài khoản';

class SavingsDetailRow extends StatelessWidget {
  const SavingsDetailRow(this.label, this.value, {super.key});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            value?.toString() ?? '—',
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFFE8ECF7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class SavingsDetailSheet extends StatelessWidget {
  const SavingsDetailSheet({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final settled =
        item['is_settled'] == true || item['status']?.toString() == 'CLOSED';
    final earlyClosed =
        item['closure_reason']?.toString() == 'EARLY_WITHDRAWAL';
    final renewalCount = (item['renewal_count'] as num?)?.toInt() ?? 0;
    final history =
        (item['maturity_history'] as List?)
            ?.whereType<Map>()
            .map((event) => Map<String, dynamic>.from(event))
            .toList() ??
        const <Map<String, dynamic>>[];
    final withdrawalHistory =
        (item['withdrawal_history'] as List?)
            ?.whereType<Map>()
            .map((event) => Map<String, dynamic>.from(event))
            .toList() ??
        const <Map<String, dynamic>>[];
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF151D31),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
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
                'Chi tiết sổ tiết kiệm',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Flexible(
                fit: FlexFit.loose,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    SavingsDetailRow(
                      'Trạng thái',
                      settled
                          ? earlyClosed
                                ? 'Đã rút trước hạn'
                                : 'Đã tất toán'
                          : 'Đang hoạt động',
                    ),
                    SavingsDetailRow('Số tài khoản', item['account_number']),
                    SavingsDetailRow(
                      'Tiền gốc',
                      money(item['original_principal']),
                    ),
                    SavingsDetailRow('Kỳ hạn', '${item['term_months']} tháng'),
                    SavingsDetailRow(
                      'Lãi suất',
                      '${item['interest_rate']}%/năm',
                    ),
                    SavingsDetailRow(
                      'Ngày bắt đầu kỳ',
                      shortDate(item['start_date']),
                    ),
                    SavingsDetailRow(
                      'Ngày đáo hạn',
                      shortDate(item['end_date']),
                    ),
                    if (!earlyClosed) ...[
                      SavingsDetailRow(
                        'Tiền lãi dự kiến',
                        money(item['expected_interest']),
                      ),
                      SavingsDetailRow(
                        'Tổng tiền đáo hạn',
                        money(item['maturity_amount']),
                      ),
                    ],
                    SavingsDetailRow(
                      'Chỉ thị đáo hạn',
                      maturityInstructionLabel(
                        item['maturity_instruction']?.toString() ?? 'PAYOUT',
                      ),
                    ),
                    if (renewalCount > 0)
                      SavingsDetailRow('Số lần tái tục', '$renewalCount lần'),
                    if (item['last_matured_at'] != null)
                      SavingsDetailRow(
                        'Xử lý gần nhất',
                        dateTimeText(item['last_matured_at']),
                      ),
                    if (item['closed_at'] != null)
                      SavingsDetailRow(
                        'Ngày đóng sổ',
                        dateTimeText(item['closed_at']),
                      ),
                    if (history.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lịch sử đáo hạn',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final event in history)
                        SavingsMaturityHistoryTile(event: event),
                    ],
                    if (withdrawalHistory.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lịch sử rút trước hạn',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final event in withdrawalHistory)
                        SavingsWithdrawalHistoryTile(event: event),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (!settled) ...[
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Rút trước hạn',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: settled ? 1 : 5,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Đóng'),
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
}

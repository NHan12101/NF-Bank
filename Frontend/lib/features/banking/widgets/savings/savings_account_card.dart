import 'package:flutter/material.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';

class SavingsAccountCard extends StatelessWidget {
  const SavingsAccountCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settled =
        item['is_settled'] == true || item['status']?.toString() == 'CLOSED';
    final earlyClosed =
        item['closure_reason']?.toString() == 'EARLY_WITHDRAWAL';
    final renewalCount = (item['renewal_count'] as num?)?.toInt() ?? 0;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C83FD).withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: Color(0xFF9EA4FF),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      money(item['original_principal']),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item['term_months']} tháng · ${item['interest_rate']}%/năm',
                      style: const TextStyle(
                        color: Color(0xFF9BA8C7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      settled
                          ? '${earlyClosed ? 'Rút trước hạn' : 'Tất toán'} '
                                '${shortDate(item['closed_at'] ?? item['last_matured_at'])}'
                          : 'Đáo hạn ${shortDate(item['end_date'])}'
                                '${renewalCount > 0 ? ' · Đã tái tục $renewalCount lần' : ''}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (settled
                                  ? const Color(0xFF9BA8C7)
                                  : const Color(0xFF68D391))
                              .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      settled
                          ? earlyClosed
                                ? 'Đã rút trước hạn'
                                : 'Đã tất toán'
                          : 'Đang hoạt động',
                      style: TextStyle(
                        color: settled
                            ? const Color(0xFF9BA8C7)
                            : const Color(0xFF68D391),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
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

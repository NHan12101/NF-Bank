import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/language_controller.dart';
import '../../../shared/utils/formatters.dart';
import '../models/account_resolution.dart';
import '../services/transfer_persist_service.dart';
import 'transfer_receipt_view.dart';

class SourceAccountCard extends StatelessWidget {
  const SourceAccountCard({super.key, required this.account});

  final Map<String, dynamic>? account;

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    final accountNumber = account?['account_number']?.toString() ??
        (isEn ? 'Loading...' : 'Đang tải...');
    final currency = account?['currency']?.toString() ?? 'VND';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF7C83FD).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 20,
            color: Color(0xFF9EA4FF),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isEn ? 'PAYMENT' : 'THANH TOÁN'} · $accountNumber',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF9EA4FF)
                      : const Color(0xFF6C7CFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                account == null ? '—' : money(account!['balance'], currency),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ],
    );
  }
}

class BankSelector extends StatelessWidget {
  const BankSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const BankMark(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Bank' : 'Ngân hàng',
                  style:
                      const TextStyle(color: Color(0xFF8D98B4), fontSize: 12),
                ),
                const SizedBox(height: 3),
                const Text(
                  'NF Bank',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF562875),
          ),
        ],
      ),
    );
  }
}

class PartyTile extends StatelessWidget {
  const PartyTile({
    super.key,
    required this.name,
    required this.accountNumber,
    required this.bankName,
    required this.avatarURL,
  });

  final String name;
  final String accountNumber;
  final String bankName;
  final String avatarURL;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ProfileAvatar(name: name, avatarURL: avatarURL),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              accountNumber,
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 13,
              ),
            ),
            Text(
              bankName,
              style: TextStyle(
                color: AppTheme.textTertiary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class BottomActions extends StatelessWidget {
  const BottomActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
    this.showBack = true,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: showBack ? 390 : 340),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: Color(0xFF7C83FD)),
                  foregroundColor: const Color(0xFFB7BBFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Quay lại',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: showBack ? 3 : 1,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                backgroundColor: const Color(0xFF6D74F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                primaryLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class RecipientPreview extends StatelessWidget {
  const RecipientPreview({
    super.key,
    required this.recipient,
    this.onSaveContact,
  });

  final AccountResolution recipient;
  final VoidCallback? onSaveContact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: const Color(0xFF4FD1C5).withValues(alpha: 0.22),
        ),
      ),
    ),
    child: Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(
              name: recipient.accountName,
              avatarURL: recipient.avatarUrl,
            ),
            const Positioned(
              right: -3,
              bottom: -3,
              child: Icon(
                Icons.verified_rounded,
                size: 16,
                color: Color(0xFF4FD1C5),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipient.accountName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Đã xác thực chủ tài khoản',
                style: TextStyle(color: Color(0xFF6EDDD3), fontSize: 12),
              ),
            ],
          ),
        ),
        if (onSaveContact != null)
          IconButton(
            icon: const Icon(
              Icons.bookmark_add_outlined,
              color: Color(0xFF4FD1C5),
              size: 20,
            ),
            onPressed: onSaveContact,
            tooltip: 'Lưu vào danh bạ',
          ),
      ],
    ),
  );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.avatarURL,
  });

  final String name;
  final String avatarURL;

  @override
  Widget build(BuildContext context) {
    final normalizedURL = avatarURL.trim();
    final initial = name.trim().isEmpty ? 'N' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF8F95FF), width: 1.5),
      ),
      child: CircleAvatar(
        radius: 19.5,
        backgroundColor: const Color(0xFF293352),
        backgroundImage: normalizedURL.startsWith('https://')
            ? NetworkImage(normalizedURL)
            : null,
        child: normalizedURL.startsWith('https://')
            ? null
            : Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFFB7BBFF),
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary(context)),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  final TransferTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF171A27)
              : Colors.black.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  money(template.amount),
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {},
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white30
                      : Colors.black38,
                ),
                onPressed: onDelete,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                splashRadius: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

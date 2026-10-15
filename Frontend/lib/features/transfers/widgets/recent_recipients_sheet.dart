import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/language_controller.dart';
import '../models/recent_recipient.dart';
import '../services/transfer_persist_service.dart';

class RecentRecipientsButton extends StatelessWidget {
  const RecentRecipientsButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFFB7BBFF) : const Color(0xFF6C7CFF);
    final iconColor =
        isDark ? const Color(0xFF9EA4FF) : const Color(0xFF6C7CFF);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn ? 'Recent Recipients' : 'Người nhận gần đây',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(color: Color(0xFF77839E), fontSize: 11),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF77839E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentRecipientsSheet extends StatelessWidget {
  const RecentRecipientsSheet({super.key, required this.recipients});

  final List<RecentRecipient> recipients;

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    return FractionallySizedBox(
      heightFactor: .72,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF151D31)
              : Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(top: BorderSide(color: Color(0x337C83FD))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 9),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'Recent Recipients' : 'Người nhận gần đây',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEn
                                ? 'Select an account to transfer quickly'
                                : 'Chọn tài khoản để chuyển nhanh',
                            style: const TextStyle(
                              color: Color(0xFF8D98B4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isEn ? 'Close' : 'Đóng',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.cardBorder(context)),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                  itemCount: recipients.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 54,
                    color: AppTheme.cardBorder(context),
                  ),
                  itemBuilder: (context, index) {
                    final recipient = recipients[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C83FD).withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: Color(0xFF9EA4FF),
                        ),
                      ),
                      title: Text(
                        recipient.accountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        recipient.accountNumber,
                        style: const TextStyle(
                          color: Color(0xFF8D98B4),
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.north_east_rounded,
                        size: 18,
                        color: Color(0xFF4FD1C5),
                      ),
                      onTap: () => Navigator.pop(context, recipient),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedRecipientsSheet extends StatelessWidget {
  const SavedRecipientsSheet({
    super.key,
    required this.recipients,
    required this.onDelete,
  });

  final List<SavedRecipient> recipients;
  final void Function(SavedRecipient) onDelete;

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF171A27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isEn ? 'Saved Recipients' : 'Danh bạ thụ hưởng',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (recipients.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  isEn
                      ? 'Saved contacts is empty. Tap Save when entering an account to add.'
                      : 'Danh bạ trống. Bấm nút Lưu khi nhập tài khoản để thêm.',
                  style: const TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: recipients.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final item = recipients[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .15),
                      child: Text(
                        item.nickname.isNotEmpty
                            ? item.nickname[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      item.nickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      '${item.accountName} - ${item.accountNumber}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFFF5C72),
                            size: 20,
                          ),
                          onPressed: () {
                            onDelete(item);
                          },
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white30,
                        ),
                      ],
                    ),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

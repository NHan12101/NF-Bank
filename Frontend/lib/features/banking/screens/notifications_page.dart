import 'package:flutter/material.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.onUnreadCountChanged});

  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _repo = BankRepository();
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      items = await _repo.notifications();
      widget.onUnreadCountChanged?.call(
        items.where((item) => item['is_read'] != true).length,
      );
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> markAll() async {
    try {
      await _repo.markAllNotificationsRead();
      await load(showLoading: false);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> markRead(Map<String, dynamic> item) async {
    try {
      final id = (item['id'] as num?)?.toInt();
      if (id == null) {
        throw const ApiException('Thông báo không hợp lệ');
      }
      await _repo.markNotificationRead(id);
      await load(showLoading: false);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => AsyncPage(
    loading: loading,
    error: error,
    onRetry: load,
    child: ListView(
      children: [
        PageTitle(
          'Thông báo',
          subtitle:
              '${items.where((item) => item['is_read'] != true).length} chưa đọc',
          trailing: TextButton.icon(
            onPressed: markAll,
            icon: const Icon(Icons.done_all),
            label: const Text('Đọc tất cả'),
          ),
        ),
        const SizedBox(height: 18),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.notifications_none,
            title: 'Chưa có thông báo',
            message: 'Thông báo biến động số dư sẽ xuất hiện tại đây.',
          )
        else
          for (final item in items) ...[
            SurfaceCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: item['is_read'] == true
                      ? Colors.white10
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.notifications_outlined),
                ),
                title: Text(
                  item['title']?.toString() ?? 'Thông báo',
                  style: TextStyle(
                    fontWeight: item['is_read'] == true
                        ? FontWeight.w500
                        : FontWeight.w800,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${item['content'] ?? ''}\n${dateTimeText(item['created_at'])}',
                  ),
                ),
                onTap: item['is_read'] == true ? null : () => markRead(item),
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    ),
  );
}

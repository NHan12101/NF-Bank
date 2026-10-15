import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.onUnreadCountChanged});

  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _repo = BankRepository();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  // Tab lọc: 0: Khuyến mại, 1: Quan trọng, 2: Biến động, 3: Tin khác, 4: Tin dịch vụ
  int _selectedTab = 2; // Mặc định mở tab Biến động như ảnh 1

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'ALL'; // ALL, UNREAD, READ

  final List<String> _tabs = [
    'Khuyến mại',
    'Quan trọng',
    'Biến động',
    'Tin khác',
    'Tin dịch vụ',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final fetched = await _repo.notifications();
      if (mounted) {
        setState(() {
          _items = fetched;
        });
        widget.onUnreadCountChanged?.call(
          _items.where((item) => item['is_read'] != true).length,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await _repo.markAllNotificationsRead();
      await _load(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
            backgroundColor: Color(0xFF0C4E44),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    try {
      final id = (item['id'] as num?)?.toInt();
      if (id != null) {
        await _repo.markNotificationRead(id);
        await _load(showLoading: false);
      }
    } catch (_) {}
  }

  void _showSettingsSheet() {
    final isDark = ThemeController.instance.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2825) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cài đặt thông báo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C4E44).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.done_all_rounded, color: Color(0xFF0C4E44)),
              ),
              title: const Text('Đánh dấu tất cả là đã đọc'),
              subtitle: const Text('Xóa số lượng thông báo chưa đọc'),
              onTap: () {
                Navigator.pop(ctx);
                _markAll();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.blue),
              ),
              title: const Text('Thông báo biến động số dư'),
              subtitle: const Text('Bật nhận thông báo OTT tức thì qua ứng dụng'),
              trailing: Switch(
                value: true,
                activeColor: const Color(0xFF0C4E44),
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final isDark = ThemeController.instance.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2825) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lọc thông báo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFilterOption('ALL', 'Tất cả thông báo'),
            _buildFilterOption('UNREAD', 'Chỉ thông báo chưa đọc'),
            _buildFilterOption('READ', 'Thông báo đã đọc'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String key, String title) {
    final isSelected = _filterType == key;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF0C4E44) : null,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0C4E44))
          : null,
      onTap: () {
        setState(() => _filterType = key);
        Navigator.pop(context);
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    // Nếu tab Khuyến mại và danh sách rỗng, cung cấp thông báo khuyến mại mẫu chuẩn như ảnh 2
    List<Map<String, dynamic>> list = List.from(_items);

    if (_selectedTab == 0) {
      // Khuyến mại
      list = list.where((it) {
        final type = it['type']?.toString().toUpperCase() ?? '';
        final title = (it['title'] ?? '').toString().toLowerCase();
        final content = (it['content'] ?? '').toString().toLowerCase();
        return type == 'PROMOTION' ||
            title.contains('khuyến mại') ||
            title.contains('ưu đãi') ||
            title.contains('quà') ||
            content.contains('ưu đãi') ||
            content.contains('tri ân');
      }).toList();

      // Nếu chưa có tin khuyến mại nào, hiển thị tin mẫu chuẩn ngân hàng như Screenshot 2
      if (list.isEmpty && _searchQuery.isEmpty) {
        list.add({
          'id': 99901,
          'type': 'PROMOTION',
          'title': 'Trao trọn yêu thương cùng NF Bank SmartBanking',
          'content':
              '🌟 Gửi lời chúc cùng món quà tích lũy tinh tế đến người phụ nữ bạn trân quý với sản phẩm vàng 24K Kim Gia Bảo, trọng lượng từ 0,1 chỉ, trong BST "Vẹn tròn hương sắc" của Bảo Tín Mạnh Hải:\n\n'
              '🌸 Hoa Đào - Tình duyên viên mãn, yêu thương đong đầy, những khởi đầu tươi đẹp luôn tìm đến.\n'
              '🌸 Hoa Lan Kèn - Công danh rộng mở, sự nghiệp thăng hoa, rạng rỡ từng bước chuyển mình.\n'
              '🌸 Hoa Sen - Tâm an trí sáng, thanh thuần vạn nẻo, dung dưỡng nguồn năng lượng tích cực an vui.\n\n'
              'Khám phá ngay trên ứng dụng NF Bank SmartBanking!',
          'created_at': '2026-10-14T15:57:20Z',
          'is_read': false,
          'has_banner': true,
        });
      }
    } else if (_selectedTab == 1) {
      // Quan trọng (Bảo mật, Cảnh báo đăng nhập, OTP, PIN)
      list = list.where((it) {
        final type = it['type']?.toString().toUpperCase() ?? '';
        final title = (it['title'] ?? '').toString().toLowerCase();
        return type == 'SECURITY' ||
            title.contains('bảo mật') ||
            title.contains('cảnh báo') ||
            title.contains('đăng nhập') ||
            title.contains('quan trọng') ||
            title.contains('pin');
      }).toList();
    } else if (_selectedTab == 2) {
      // Biến động (Số dư, Nạp, Chuyển, Nhận)
      list = list.where((it) {
        final type = it['type']?.toString().toUpperCase() ?? '';
        final title = (it['title'] ?? '').toString().toLowerCase();
        return type == 'BALANCE_FLUCTUATION' ||
            title.contains('biến động') ||
            title.contains('số dư') ||
            title.contains('chuyển') ||
            title.contains('nhận tiền') ||
            title.contains('rút tiền');
      }).toList();
    } else if (_selectedTab == 4) {
      // Tin dịch vụ
      list = list.where((it) {
        final title = (it['title'] ?? '').toString().toLowerCase();
        return title.contains('tiết kiệm') ||
            title.contains('thẻ') ||
            title.contains('dịch vụ');
      }).toList();
    } else {
      // Tin khác
      list = list.where((it) {
        final type = it['type']?.toString().toUpperCase() ?? '';
        return type != 'BALANCE_FLUCTUATION' &&
            type != 'PROMOTION' &&
            type != 'SECURITY';
      }).toList();
    }

    // Lọc theo trạng thái đọc
    if (_filterType == 'UNREAD') {
      list = list.where((it) => it['is_read'] != true).toList();
    } else if (_filterType == 'READ') {
      list = list.where((it) => it['is_read'] == true).toList();
    }

    // Lọc theo từ khóa tìm kiếm
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((it) {
        final t = (it['title'] ?? '').toString().toLowerCase();
        final c = (it['content'] ?? '').toString().toLowerCase();
        return t.contains(q) || c.contains(q);
      }).toList();
    }

    return list;
  }

  Map<String, List<Map<String, dynamic>>> _groupItemsByDate(
      List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final item in items) {
      DateTime dt = DateTime.now();
      try {
        if (item['created_at'] != null) {
          dt = DateTime.parse(item['created_at'].toString()).toLocal();
        }
      } catch (_) {}

      final dateKey =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      map.putIfAbsent(dateKey, () => []).add(item);
    }
    return map;
  }

  String _formatTime(dynamic dateStr) {
    try {
      if (dateStr == null) return '';
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final isEn = LanguageController.instance.isEnglish;

    final filteredItems = _getFilteredItems();
    final groupedItems = _groupItemsByDate(filteredItems);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1716) : const Color(0xFFF6F9F8),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF162522), const Color(0xFF0F1716)]
                : [const Color(0xFFE2F3F0), const Color(0xFFF6F9F8)],
            stops: const [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // --- Header Bar (Back, Title "Thông báo", Settings Icon) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: 48),
                    Text(
                      isEn ? 'Notifications' : 'Thông báo',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                      onPressed: _showSettingsSheet,
                    ),
                  ],
                ),
              ),

              // --- Horizontal Scrollable Filter Chips / Tabs ---
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedTab == index;
                    return InkWell(
                      onTap: () => setState(() => _selectedTab = index),
                      borderRadius: BorderRadius.circular(22),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0C4E44)
                              : (isDark ? Colors.white.withOpacity(0.06) : Colors.transparent),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFF4B635F)),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // --- Search Bar + Filter Button Row ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C2B28) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: isEn ? 'Search' : 'Tìm kiếm',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: isDark ? Colors.white38 : Colors.grey[500],
                              size: 22,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filter Icon Button
                    InkWell(
                      onTap: _showFilterSheet,
                      borderRadius: BorderRadius.circular(23),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C2B28) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: _filterType != 'ALL'
                              ? const Color(0xFFF7941D)
                              : (isDark ? Colors.white : const Color(0xFF0C4E44)),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // --- Content: Empty State OR List with Date Headers ---
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0C4E44),
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () => _load(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0C4E44),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          )
                        : filteredItems.isEmpty
                            // --- Cụm minh họa Trống (Empty State) Chuẩn Ảnh 1 ---
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Minh họa hình chuông pastel kèm bong bóng & ngôi sao lấp lánh
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 140,
                                            height: 140,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF172C27)
                                                  : const Color(0xFFE2F1ED),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Container(
                                            width: 96,
                                            height: 96,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1E3A34)
                                                  : const Color(0xFFCEEAE3),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.notifications_rounded,
                                              size: 54,
                                              color: isDark
                                                  ? const Color(0xFF78B5A7)
                                                  : const Color(0xFF80BCB0),
                                            ),
                                          ),
                                          // Bong bóng tin nhắn nhỏ có dấu gạch
                                          Positioned(
                                            right: 18,
                                            top: 22,
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF294D45)
                                                    : const Color(0xFF6DAEA0),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.remove,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          // Ngôi sao lấp lánh nhỏ bên trái
                                          Positioned(
                                            left: 24,
                                            top: 36,
                                            child: Icon(
                                              Icons.auto_awesome,
                                              size: 16,
                                              color: isDark
                                                  ? const Color(0xFF8DCAC0)
                                                  : const Color(0xFF90C9BF),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 28),
                                      // Thông điệp chuẩn ảnh 1
                                      Text(
                                        isEn
                                            ? 'You currently have no notifications from NF Bank'
                                            : 'Quý khách hiện chưa có thông báo từ ngân hàng NF Bank',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          height: 1.4,
                                          color: isDark
                                              ? Colors.white60
                                              : const Color(0xFF4B635F),
                                        ),
                                      ),
                                      const SizedBox(height: 40),
                                    ],
                                  ),
                                ),
                              )
                            // --- Danh sách thông báo phân nhóm theo ngày Chuẩn Ảnh 2 ---
                            : RefreshIndicator(
                                color: const Color(0xFF0C4E44),
                                onRefresh: () => _load(showLoading: false),
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 30),
                                  itemCount: groupedItems.keys.length,
                                  itemBuilder: (context, groupIdx) {
                                    final dateKey =
                                        groupedItems.keys.elementAt(groupIdx);
                                    final dayItems = groupedItems[dateKey]!;

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Ngày tháng (e.g. 14/10/2026)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              20, 14, 20, 8),
                                          child: Text(
                                            dateKey,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF1F2937),
                                            ),
                                          ),
                                        ),

                                        // Các Card thông báo trong ngày
                                        ...dayItems.map((item) {
                                          final timeStr =
                                              _formatTime(item['created_at']);
                                          final isRead = item['is_read'] == true;
                                          final title = item['title']?.toString() ??
                                              'Thông báo';
                                          final content =
                                              item['content']?.toString() ?? '';
                                          final hasBanner =
                                              item['has_banner'] == true;

                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1A2724)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.04),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              onTap: isRead
                                                  ? null
                                                  : () => _markRead(item),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Hàng trên: Giờ + Menu 3 chấm
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          timeStr,
                                                          style: TextStyle(
                                                            fontSize: 12.5,
                                                            color: isDark
                                                                ? Colors.white38
                                                                : Colors.grey[500],
                                                          ),
                                                        ),
                                                        PopupMenuButton<String>(
                                                          icon: Icon(
                                                            Icons
                                                                .more_vert_rounded,
                                                            size: 18,
                                                            color: isDark
                                                                ? Colors.white38
                                                                : Colors.grey[500],
                                                          ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(),
                                                          onSelected: (val) {
                                                            if (val == 'read') {
                                                              _markRead(item);
                                                            } else if (val ==
                                                                'copy') {
                                                              Clipboard.setData(
                                                                  ClipboardData(
                                                                      text:
                                                                          '$title\n$content'));
                                                              ScaffoldMessenger.of(
                                                                      context)
                                                                  .showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                      'Đã sao chép nội dung'),
                                                                  duration: Duration(
                                                                      seconds:
                                                                          1),
                                                                ),
                                                              );
                                                            }
                                                          },
                                                          itemBuilder: (ctx) => [
                                                            if (!isRead)
                                                              const PopupMenuItem(
                                                                value: 'read',
                                                                child: Text(
                                                                    'Đánh dấu đã đọc'),
                                                              ),
                                                            const PopupMenuItem(
                                                              value: 'copy',
                                                              child: Text(
                                                                  'Sao chép nội dung'),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),

                                                    // Tiêu đề thông báo
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        if (!isRead)
                                                          Container(
                                                            width: 8,
                                                            height: 8,
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 6,
                                                                    right: 8),
                                                            decoration:
                                                                const BoxDecoration(
                                                              color: Color(
                                                                  0xFF0C4E44),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                          ),
                                                        Expanded(
                                                          child: Text(
                                                            title,
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                              color: isDark
                                                                  ? Colors.white
                                                                  : const Color(
                                                                      0xFF1F2937),
                                                              height: 1.3,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    // Banner khuyến mại (nếu có)
                                                    if (hasBanner) ...[
                                                      const SizedBox(height: 12),
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                16),
                                                        child: Container(
                                                          height: 180,
                                                          width: double.infinity,
                                                          decoration:
                                                              const BoxDecoration(
                                                            gradient:
                                                                LinearGradient(
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                              colors: [
                                                                Color(
                                                                    0xFFEAF5F2),
                                                                Color(
                                                                    0xFFD3ECE5),
                                                              ],
                                                            ),
                                                          ),
                                                          child: Stack(
                                                            alignment: Alignment
                                                                .center,
                                                            children: [
                                                              Positioned(
                                                                right: -20,
                                                                bottom: -20,
                                                                child: Icon(
                                                                  Icons
                                                                      .card_giftcard_rounded,
                                                                  size: 160,
                                                                  color: const Color(
                                                                          0xFF0C4E44)
                                                                      .withOpacity(
                                                                          0.08),
                                                                ),
                                                              ),
                                                              Column(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Container(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            10),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .white,
                                                                      shape:
                                                                          BoxShape
                                                                              .circle,
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          color: Colors.black.withOpacity(0.08),
                                                                          blurRadius: 10,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: Image.asset(
                                                                      'assets/images/logo_transparent.png',
                                                                      height:
                                                                          36,
                                                                      fit: BoxFit
                                                                          .contain,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          10),
                                                                  const Text(
                                                                    'NF BANK SMARTBANKING',
                                                                    style:
                                                                        TextStyle(
                                                                      color: Color(
                                                                          0xFF0C4E44),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      letterSpacing:
                                                                          1.1,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  const Text(
                                                                    'VẸN TRÒN HƯƠNG SẮC',
                                                                    style:
                                                                        TextStyle(
                                                                      color: Color(
                                                                          0xFF1E3A34),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900,
                                                                      fontSize:
                                                                          16,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],

                                                    const SizedBox(height: 10),

                                                    // Nội dung thông báo
                                                    Text(
                                                      content,
                                                      style: TextStyle(
                                                        fontSize: 13.8,
                                                        height: 1.45,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : const Color(
                                                                0xFF374151),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

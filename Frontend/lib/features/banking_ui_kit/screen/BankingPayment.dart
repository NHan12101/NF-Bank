import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../model/BankingModel.dart';
import 'BankingPaymentDetails.dart';
import '../utils/BankingColors.dart';
import '../utils/BankingDataGenerator.dart';

class BankingPayment extends StatefulWidget {
  static var tag = "/BankingPayment";

  const BankingPayment({Key? key}) : super(key: key);

  @override
  _BankingPaymentState createState() => _BankingPaymentState();
}

class _BankingPaymentState extends State<BankingPayment> {
  late List<BankingPaymentModel> mList;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    mList = bankingPaymentList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        final isDark = ThemeController.instance.isDarkMode;
        final isEn = LanguageController.instance.isEnglish;

        final filteredList = mList.where((item) {
          if (searchQuery.isEmpty) return true;
          return (item.title ?? '').toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF140824) : const Color(0xFFF6F5FA),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 24),

                // TPBank Top Header Banner
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1F0D33), const Color(0xFF12071F)]
                          : [const Color(0xFF562875), const Color(0xFF3B1554)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF562875).withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Image.asset('assets/images/logo_transparent.png', height: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Bills & Top Up' : 'Thanh toán & Nạp tiền',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isEn ? 'Fast bill payments with 0% fee' : 'Thanh toán hóa đơn tự động, 0% phí',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Input
                TextField(
                  onChanged: (val) => setState(() => searchQuery = val),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: isEn ? 'Search bill or service...' : 'Tìm kiếm dịch vụ thanh toán...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF562875)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF26133B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  isEn ? 'All Payment Services' : 'Danh mục dịch vụ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF562875),
                  ),
                ),
                const SizedBox(height: 12),

                // Grid View of Bill Categories
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: filteredList.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.9,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    return InkWell(
                      onTap: () {
                        BankingPaymentDetails(headerText: item.title).launch(context);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF26133B) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (item.color ?? const Color(0xFF562875)).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                item.img!,
                                height: 28,
                                width: 28,
                                color: item.color ?? const Color(0xFF562875),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.title!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

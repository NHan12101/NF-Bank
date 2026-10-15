import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../model/BankingModel.dart';
import '../utils/BankingDataGenerator.dart';

class BankingRateInfo extends StatefulWidget {
  static var tag = "/BankingRateInfo";

  const BankingRateInfo({Key? key}) : super(key: key);

  @override
  _BankingRateInfoState createState() => _BankingRateInfoState();
}

class _BankingRateInfoState extends State<BankingRateInfo> {
  late List<BankingRateInfoModel> mList1;

  @override
  void initState() {
    super.initState();
    mList1 = bankingRateInformationList();
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

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF140824) : const Color(0xFFF6F5FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF562875),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              isEn ? 'Exchange Rates & Info' : 'Thông tin Tỷ giá Ngoại tệ',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner header
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF562875), Color(0xFF3B1554)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_exchange_rounded, color: Color(0xFFF7941D), size: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Live Exchange Rates' : 'Tỷ giá Ngân hàng TPBank',
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEn ? 'Updated continuously for 20+ currencies' : 'Cập nhật liên tục 24/7 thị trường tài chính',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Table Card Container
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF26133B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF562875).withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                isEn ? 'Currency' : 'Ngoại tệ',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF562875)),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                isEn ? 'Buy Rate' : 'Mua vào',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF562875)),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                isEn ? 'Sell Rate' : 'Bán ra',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF7941D)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Data Rows
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: mList1.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = mList1[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(item.flag!, height: 26, width: 26, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        item.currency!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.buy!,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.sell!,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF7941D)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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

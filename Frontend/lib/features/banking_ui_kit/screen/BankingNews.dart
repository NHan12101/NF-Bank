import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../model/BankingModel.dart';
import '../utils/BankingDataGenerator.dart';

class BankingNews extends StatefulWidget {
  static var tag = "/BankingNews";

  const BankingNews({Key? key}) : super(key: key);

  @override
  _BankingNewsState createState() => _BankingNewsState();
}

class _BankingNewsState extends State<BankingNews> {
  late List<BankingShareInfoModel> mList1;

  @override
  void initState() {
    super.initState();
    mList1 = bankingNewsList();
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
              isEn ? 'Banking News' : 'Tin tức ngân hàng',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: mList1.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26133B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'TPBank offers special gifts for new digital account openings'
                          : 'TPBank dành tặng nhiều phần quà hấp dẫn cho khách hàng mở tài khoản mới',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF562875),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(mList1[index].icon, height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEn
                          ? 'Enjoy 0% transfer fee, instant online savings with attractive interest rates, and seamless payments 24/7.'
                          : 'Tận hưởng miễn 100% phí chuyển tiền, mở tiết kiệm online lãi suất cao và thanh toán tiện lợi 24/7.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

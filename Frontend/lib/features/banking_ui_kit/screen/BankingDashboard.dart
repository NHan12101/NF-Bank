import 'package:flutter/material.dart';
import '../utils/BankingColors.dart';
import '../utils/TPBankBottomBar.dart';

import 'BankingHome1.dart';
import 'BankingMenu.dart';
import 'BankingPayment.dart';
import '../../transfers/screens/transfer_page.dart';
import '../../transfers/screens/qr_scanner_page.dart';
import '../../../core/services/session_heartbeat_service.dart';

class BankingDashboard extends StatefulWidget {
  static var tag = "/BankingDashboard";

  const BankingDashboard({Key? key}) : super(key: key);

  @override
  _BankingDashboardState createState() => _BankingDashboardState();
}

class _BankingDashboardState extends State<BankingDashboard> {
  int selectedIndex = 0;
  late List<Widget> pages;

  @override
  void initState() {
    super.initState();
    SessionHeartbeatService.start();
    selectedIndex = 0;
    pages = [
      BankingHome1(onSelectTab: _onItemTapped),
      const BankingPayment(),
      const SizedBox.shrink(), // QR page mở qua Navigator modal để tiết kiệm tài nguyên Camera
      const TransferPage(),
      const BankingMenu(),
    ];
  }

  @override
  void dispose() {
    SessionHeartbeatService.stop();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _openQRScanner();
      return;
    }
    setState(() {
      selectedIndex = index;
    });
  }

  void _openQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Banking_app_Background,
      extendBody: true,
      bottomNavigationBar: TPBankBottomBar(
        currentIndex: selectedIndex,
        onTap: _onItemTapped,
        onCenterQRTap: _openQRScanner,
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: selectedIndex == 2 ? 0 : selectedIndex,
          children: pages,
        ),
      ),
    );
  }
}

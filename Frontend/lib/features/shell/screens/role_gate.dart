import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../admin/screens/admin_shell.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/smart_otp_activation_screen.dart';
import '../../banking_ui_kit/screen/BankingDashboard.dart';
import '../../transfers/services/transfer_repository.dart';

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late final Future<Widget> _targetScreenFuture = _determineTargetScreen();

  Future<Widget> _determineTargetScreen() async {
    final user = await TokenStorage.getUser();
    if (user == null) return const LoginScreen();
    if (user.role == 'admin' || user.role == 'super_admin') {
      return AdminShell(user: user);
    }

    // Kiểm tra trạng thái Smart OTP (PIN 4 số)
    try {
      const repository = TransferRepository();
      final hasPin = await repository.hasTransactionPin();
      final isDeviceActivated = await TokenStorage.isSmartOtpActivatedOnDevice(user.id);

      if (!hasPin || !isDeviceActivated) {
        return SmartOtpActivationScreen(
          user: user,
          isNewPin: !hasPin,
        );
      }
    } catch (_) {}

    return BankingDashboard();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
        future: _targetScreenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data ?? BankingDashboard();
        },
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nf_bank/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('shows login screen for signed-out users', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    expect(find.text('NFBank'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsAtLeastNWidgets(1));
  });
}


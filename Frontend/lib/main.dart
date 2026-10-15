import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/network/api_service.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/language_controller.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/shell/screens/role_gate.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  ApiService.onSessionExpired = () async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  };

  // Nạp theme trước để tránh giật/nhấp nháy màu giữa Splash Native và Flutter
  await ThemeController.instance.init();

  runApp(const NfBankApp(isLoggedIn: false));
}

class NfBankApp extends StatelessWidget {
  const NfBankApp({super.key, required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'NF Bank',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.themeMode,
          locale: LanguageController.instance.isEnglish
              ? const Locale('en', 'US')
              : const Locale('vi', 'VN'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('vi', 'VN'),
            Locale('en', 'US'),
          ],
          home: AppSplashScreen(isLoggedIn: isLoggedIn),
        );
      },
    );
  }
}

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key, required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
    _startLoadingAndNavigate();
  }

  Future<void> _startLoadingAndNavigate() async {
    final splashTimer = Future.delayed(const Duration(milliseconds: 1000));

    // Thực hiện tải cấu hình, giao diện, ngôn ngữ và xóa session cũ trong lúc đang chạy Splash
    await Future.wait([
      dotenv.load(fileName: '.env'),
      ThemeController.instance.init(),
      LanguageController.instance.init(),
      TokenStorage.clearAuth(),
      splashTimer,
    ]);

    if (mounted) {
      try {
        precacheImage(const AssetImage('assets/images/logo_transparent.png'), context);
      } catch (_) {}

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => widget.isLoggedIn ? const RoleGate() : const LoginScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/images/logo_transparent.png',
              width: 190,
              height: 190,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}

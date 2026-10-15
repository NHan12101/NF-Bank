 import 'dart:async';
import 'dart:ui' as ui;
 
 import 'package:flutter/material.dart';
 import 'package:flutter/rendering.dart';
 import 'package:flutter/services.dart';
 import 'package:gal/gal.dart';
 import 'package:nb_utils/nb_utils.dart';
 
 import '../../../core/network/api_service.dart';
 import '../../../core/services/bank_repository.dart';
 import '../../../core/services/biometric_service.dart';
 import '../../../core/storage/token_storage.dart';
 import '../../../core/theme/language_controller.dart';
 import '../../../core/theme/theme_controller.dart';
 import '../../../shared/widgets/common.dart';
 import '../../shell/screens/role_gate.dart';
 import '../../transfers/services/transfer_repository.dart';
 import '../services/auth_service.dart';
 import '../services/phone_auth_service.dart';
 import 'register_screen.dart';
 
 import '../../transfers/screens/qr_scanner_page.dart';
 import '../../transfers/widgets/user_receive_qr_dialog.dart';
 import '../../banking/screens/user_pages.dart' show NotificationsPage;
 import '../../banking_ui_kit/screen/BankingLocation.dart';
 import '../../banking_ui_kit/screen/BankingRateInfo.dart';
 import '../../banking_ui_kit/screen/BankingContact.dart';
 
 class LoginScreen extends StatefulWidget {
   const LoginScreen({super.key});
 
   @override
   State<LoginScreen> createState() => _LoginScreenState();
 }
 
 class _LoginScreenState extends State<LoginScreen> {
  static const _validPrefixes = {
    '032', '033', '034', '035', '036', '037', '038', '039',
    '086', '096', '097', '098',
    '081', '082', '083', '084', '085', '087', '088', '091', '094',
    '070', '076', '077', '078', '079', '089', '090', '093',
    '052', '055', '056', '058', '092',
    '059', '099',
  };

  String? _validatePhone(String? value) {
    if (_lastUserName != null && !_isSwitchingAccount && _lastUserPhone != null && _lastUserPhone!.isNotEmpty) {
      return null;
    }
    final isEn = LanguageController.instance.isEnglish;
    final val = (value ?? '').trim();
    if (val.isEmpty) {
      return isEn ? 'Please enter phone number' : 'Vui lòng nhập số điện thoại';
    }
    if (val.length >= 3) {
      final prefix = val.substring(0, 3);
      if (!_validPrefixes.contains(prefix)) {
        return isEn ? 'Invalid carrier prefix, please check again' : 'Đầu số không đúng vui lòng kiểm tra lại';
      }
    }
    if (val.length != 10) {
      return isEn ? 'Phone number must be 10 digits' : 'Số điện thoại phải bao gồm 10 chữ số';
    }
    return null;
  }
   final _form = GlobalKey<FormState>();
   final _phone = TextEditingController();
   final _password = TextEditingController();
   final _totp = TextEditingController();
   final _otp = TextEditingController();
   final _auth = AuthService();
   final _phoneAuth = PhoneAuthService();
   LoginStep? _step;
   String? _verificationId;
   String? _lastUserName;
   String? _lastUserPhone;
   String? _lastUserAccount;
   String? _lastUserQrUrl;
   String? _lastUserQrData;
   bool _loading = false;
   bool _passwordHidden = true;
   bool _biometricLoginEnabled = false;
   bool _isSwitchingAccount = false;
   int _unreadNotificationCount = 0;
   Timer? _otpTimer;
   int _otpCooldown = 60;
 
   @override
   void initState() {
     super.initState();
     _checkBiometricStatus();
     _loadLastUserData();
     _fetchUnreadNotificationCount();
   }
 
   Future<void> _fetchUnreadNotificationCount() async {
     try {
       final token = await TokenStorage.getToken();
       if (token != null && token.isNotEmpty) {
         final list = await const BankRepository().notifications();
         final unread = list.where((item) => item['is_read'] != true).length;
         if (mounted) {
           setState(() {
             _unreadNotificationCount = unread;
           });
         }
       } else {
         if (mounted) {
           setState(() {
             _unreadNotificationCount = 0;
           });
         }
       }
     } catch (_) {
       if (mounted) {
         setState(() {
           _unreadNotificationCount = 0;
         });
       }
     }
   }
 
   Future<void> _loadLastUserData() async {
     final results = await Future.wait([
       TokenStorage.getLastUserName(),
       TokenStorage.getLastUserPhone(),
       TokenStorage.getLastUserAccount(),
       TokenStorage.getLastUserQrUrl(),
       TokenStorage.getLastUserQrData(),
       TokenStorage.getToken(),
     ]);
 
     final name = results[0];
     final phone = results[1];
     var account = results[2];
     var qrUrl = results[3];
     var qrData = results[4];
     final token = results[5];
     if (token != null && token.isNotEmpty && (account == null || !account.startsWith('9704') || qrUrl == null || qrUrl.isEmpty)) {
       try {
         final qrResult = await const TransferRepository().getMyStaticQR();
         final fetchedQrData = qrResult['qr_data']?.toString() ?? '';
         final fetchedQrUrl = qrResult['qr_url']?.toString() ?? '';
         final extractedAccount = _extractAccountNumber(fetchedQrData);
 
         if (extractedAccount.isNotEmpty) {
           account = extractedAccount;
           qrUrl = fetchedQrUrl;
           qrData = fetchedQrData;
           await TokenStorage.saveUserQR(
             qrData: fetchedQrData,
             qrUrl: fetchedQrUrl,
             accountNumber: extractedAccount,
           );
         }
       } catch (_) {}
     }
 
     if ((account == null || !account.startsWith('9704')) && qrData != null && qrData.isNotEmpty) {
       final extracted = _extractAccountNumber(qrData);
       if (extracted.isNotEmpty) {
         account = extracted;
         await TokenStorage.saveUserQR(
           qrData: qrData,
           qrUrl: qrUrl ?? '',
           accountNumber: extracted,
         );
       }
     }
 
     if (mounted) {
       setState(() {
         _lastUserName = name;
         _lastUserPhone = phone;
         _lastUserAccount = (account != null && account.startsWith('9704')) ? account : null;
         _lastUserQrUrl = qrUrl;
        _lastUserQrData = qrData;
         if (phone != null && phone.isNotEmpty) {
           _phone.text = phone;
         }
       });
     }
   }
 
   Future<void> _fetchAndSaveStaticQR([String? tokenOverride]) async {
     try {
       final token = tokenOverride ?? await TokenStorage.getToken();
       final qrResult = await const TransferRepository().getMyStaticQR(tokenOverride: token);
       final qrData = qrResult['qr_data']?.toString() ?? '';
       final qrUrl = qrResult['qr_url']?.toString() ?? '';
       final accNumber = _extractAccountNumber(qrData);
 
       await TokenStorage.saveUserQR(
         qrData: qrData,
         qrUrl: qrUrl,
         accountNumber: accNumber,
       );
     } catch (_) {}
   }
 
   String _extractAccountNumber(String qrData) {
     try {
       final idx38 = qrData.indexOf('38');
       if (idx38 == -1) return '';
       final len38 = int.tryParse(qrData.substring(idx38 + 2, idx38 + 4)) ?? 0;
       final val38 = qrData.substring(idx38 + 4, idx38 + 4 + len38);
 
       final idx01 = val38.indexOf('01');
       if (idx01 == -1) return '';
       final len01 = int.tryParse(val38.substring(idx01 + 2, idx01 + 4)) ?? 0;
       final val01 = val38.substring(idx01 + 4, idx01 + 4 + len01);
 
       final idxSub01 = val01.lastIndexOf('01');
       if (idxSub01 == -1) return '';
       final lenSub01 = int.tryParse(val01.substring(idxSub01 + 2, idxSub01 + 4)) ?? 0;
       return val01.substring(idxSub01 + 4, idxSub01 + 4 + lenSub01);
     } catch (_) {
       return '';
     }
   }
 
   @override
   void dispose() {
     _otpTimer?.cancel();
     _phone.dispose();
     _password.dispose();
     _totp.dispose();
     _otp.dispose();
     super.dispose();
   }

   void _startOtpTimer() {
     _otpTimer?.cancel();
     if (mounted) setState(() => _otpCooldown = 60);
     _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
       if (_otpCooldown <= 1) {
         timer.cancel();
         if (mounted) setState(() => _otpCooldown = 0);
       } else {
         if (mounted) setState(() => _otpCooldown--);
       }
     });
   }

   Future<void> _resendOtp() async {
     if (_otpCooldown > 0 || _loading) return;
     await _run(() async {
       _otp.clear();
       _verificationId = await _phoneAuth.sendCode(_phone.text.trim());
       _startOtpTimer();
       toast(LanguageController.instance.isEnglish
           ? 'New OTP code sent to your phone'
           : 'Mã OTP mới đã được gửi tới số điện thoại của bạn');
     });
   }
 
   Future<void> _checkBiometricStatus() async {
     final supported = await BiometricService.isDeviceSupported();
     if (mounted) {
       setState(() {
         _biometricLoginEnabled = supported;
       });
     }
   }
 
   Future<void> _biometricLogin() async {
     debugPrint('[DEBUG_BIO] _biometricLogin called');
     if (_loading || _step != null) {
       debugPrint('[DEBUG_BIO] loading=$_loading, step=$_step -> returning');
       return;
     }
     setState(() => _loading = true);
     final isEn = LanguageController.instance.isEnglish;
     try {
       final credentials = await BiometricService.getLoginCredentials();
       debugPrint('[DEBUG_BIO] credentials: $credentials');
 
       if (credentials == null || credentials['phone'] == null || credentials['password'] == null || credentials['password']!.isEmpty) {
         debugPrint('[DEBUG_BIO] Credentials missing or password empty');
         if (mounted) {
           final msg = isEn
               ? 'No saved fingerprint data. Please log in with password once to enable fingerprint login.'
               : 'Chưa có dữ liệu vân tay. Vui lòng nhập mật khẩu 1 lần để lưu sinh trắc học.';
           showMessage(context, msg, error: true);
           toast(msg);
           setState(() {
             _isSwitchingAccount = true;
             if (_lastUserPhone != null && _lastUserPhone!.isNotEmpty) {
               _phone.text = _lastUserPhone!;
             }
           });
         }
         return;
       }
 
       debugPrint('[DEBUG_BIO] Calling BiometricService.authenticate...');
       final authenticated = await BiometricService.authenticate(
         reason: isEn
             ? 'Touch the fingerprint sensor on power button to log in to NF Bank'
             : 'Chạm vào cảm biến vân tay ở nút nguồn để đăng nhập NF Bank',
       );
       debugPrint('[DEBUG_BIO] BiometricService.authenticate result: $authenticated');
 
       if (authenticated) {
         _phone.text = credentials['phone'] ?? '';
         _password.text = credentials['password'] ?? '';
         debugPrint('[DEBUG_BIO] Auth succeeded! Calling _login(isBiometric: true) with phone=${_phone.text}');
         await _login(isBiometric: true);
       } else if (mounted) {
         final err = BiometricService.lastError ?? (isEn ? 'Biometric authentication was cancelled' : 'Xác thực vân tay chưa thành công hoặc đã bị hủy');
         debugPrint('[DEBUG_BIO] Auth failed with: $err');
         showMessage(context, err, error: true);
         toast(err);
       }
     } finally {
       if (mounted) {
         setState(() => _loading = false);
       }
     }
   }
 
   Future<void> _run(Future<void> Function() action) async {
     setState(() => _loading = true);
     try {
       await action();
     } on ApiException catch (error) {
       debugPrint('[DEBUG_LOGIN] ApiException: ${error.message}');
       if (mounted) showMessage(context, error.message, error: true);
     } catch (error) {
       debugPrint('[DEBUG_LOGIN] Catch error: $error');
       if (mounted) showMessage(context, error.toString(), error: true);
     } finally {
       if (mounted) setState(() => _loading = false);
     }
   }
 
   Future<void> _login({String? totp, bool isBiometric = false}) async {
     debugPrint('[DEBUG_LOGIN] _login called. phone=${_phone.text}, passLen=${_password.text.length}, isBiometric=$isBiometric');
     if (_lastUserName != null && _lastUserName!.isNotEmpty && !_isSwitchingAccount) {
       if (_phone.text.isEmpty && _lastUserPhone != null && _lastUserPhone!.isNotEmpty) {
         _phone.text = _lastUserPhone!;
       }
     }
     if (!isBiometric && _step == null && _form.currentState != null && !_form.currentState!.validate()) {
       debugPrint('[DEBUG_LOGIN] Form validation failed -> returning');
       return;
     }
 
     final phoneToSave = _phone.text.trim().isNotEmpty
         ? _phone.text.trim()
         : (_lastUserPhone ?? '');
     if (phoneToSave.isNotEmpty && _password.text.isNotEmpty) {
       await BiometricService.saveLoginCredentials(phoneToSave, _password.text);
       await BiometricService.setLoginEnabled(true);
     }
 
     debugPrint('[DEBUG_LOGIN] Calling _auth.login API...');
     await _run(() async {
       final res = await _auth.login(
         _phone.text,
         _password.text,
         totpCode: totp ?? '',
         isBiometric: isBiometric,
       );
       debugPrint('[DEBUG_LOGIN] _auth.login result step: ${res.step}');
 
       if (res.step == LoginStep.totpRequired) {
         setState(() => _step = LoginStep.totpRequired);
       } else if (res.step == LoginStep.otpRequired) {
         debugPrint('[DEBUG_LOGIN] OTP required -> sending SMS code');
         _otp.clear();
         _verificationId = await _phoneAuth.sendCode(res.phone ?? _phone.text);
         if (mounted) {
           setState(() => _step = LoginStep.otpRequired);
           _startOtpTimer();
         }
       } else {
         debugPrint('[DEBUG_LOGIN] Login SUCCESS -> opening app');
         await _fetchAndSaveStaticQR();
         await _loadLastUserData();
         _openApp();
       }
     });
   }
 
   Future<void> _confirmSms() async {
     if (_verificationId == null) return;
     await _run(() async {
       final idToken = await _phoneAuth.verifyCode(_verificationId!, _otp.text);
       await _auth.confirmLogin(_phone.text, idToken);
       await _fetchAndSaveStaticQR();
       await _loadLastUserData();
       _openApp();
     });
   }
 
   void _openApp() {
     final phoneToSave = _phone.text.trim().isNotEmpty
         ? _phone.text.trim()
         : (_lastUserPhone ?? '');
     if (phoneToSave.isNotEmpty && _password.text.isNotEmpty) {
       BiometricService.saveLoginCredentials(phoneToSave, _password.text);
       BiometricService.setLoginEnabled(true);
     }
     Navigator.of(context).pushAndRemoveUntil(
       MaterialPageRoute(builder: (_) => const RoleGate()),
       (_) => false,
     );
   }
 
   Future<void> _showResetPassword() async {
     await showDialog<void>(
       context: context,
       builder: (dialogContext) => _ResetPasswordDialog(
         initialPhone: _phone.text,
         phoneAuth: _phoneAuth,
         auth: _auth,
       ),
     );
   }
 
   void _showReceiveQRModal() {
     final isEn = LanguageController.instance.isEnglish;
     final name = _lastUserName;
     final account = _lastUserAccount;
     final qrUrl = _lastUserQrUrl;
 
     if (name == null || name.isEmpty || account == null || !account.startsWith('9704') || qrUrl == null || qrUrl.isEmpty) {
       showMessage(
         context,
         isEn
             ? 'No saved QR code found. Please log in once to save your QR code.'
             : 'Chưa có thông tin mã QR. Vui lòng đăng nhập 1 lần để hệ thống tự động lưu mã QR nhận tiền.',
         error: true,
       );
       return;
     }
 
     UserReceiveQRDialog.show(
       context,
       userName: name,
       userAccount: account,
       qrData: _lastUserQrData,
       qrUrl: qrUrl,
     );
   }
 
   String _getGreeting(bool isEn) {
     final hour = DateTime.now().hour;
     if (hour >= 5 && hour < 11) {
       return isEn ? 'Have a nice morning 👏' : 'Chúc bạn một ngày tốt lành 👏';
     } else if (hour >= 11 && hour < 13) {
       return isEn ? 'Have a nice noon 👏' : 'Chúc bạn buổi trưa tốt lành 👏';
     } else if (hour >= 13 && hour < 18) {
       return isEn ? 'Have a nice afternoon 👏' : 'Chúc bạn buổi chiều vui vẻ 👏';
     } else {
       return isEn ? 'Have a nice evening 👏' : 'Chúc bạn buổi tối tốt lành 👏';
     }
   }
 
   Future<void> _openNotificationsWithSecurity() async {
     final isEn = LanguageController.instance.isEnglish;
     var token = await TokenStorage.getToken();
     final credentials = await BiometricService.getLoginCredentials();
     final hasSession = (token != null && token.isNotEmpty) || (credentials != null) || (_lastUserPhone != null && _lastUserPhone!.isNotEmpty);
 
     if (!hasSession) {
       _showLoginRequiredDialog(isEn);
       return;
     }
 
     final authenticated = await BiometricService.authenticate(
       reason: isEn
           ? 'Touch fingerprint sensor to view personal notifications'
           : 'Xác thực vân tay / FaceID để xem thông báo cá nhân',
     );
 
     if (!authenticated) {
       if (mounted && BiometricService.lastError != null) {
         showMessage(context, BiometricService.lastError!, error: true);
       }
       return;
     }
 
     // Nếu chưa có Token JWT hợp lệ nhưng có tài khoản đã lưu -> Đăng nhập ngầm lấy Token
     if (token == null || token.isEmpty) {
       if (credentials != null && credentials['phone'] != null && credentials['password'] != null) {
         _phone.text = credentials['phone']!;
         _password.text = credentials['password']!;
         await _login(isBiometric: true);
         token = await TokenStorage.getToken();
       }
     }
 
     if (!mounted) return;
 
     if (token != null && token.isNotEmpty) {
       await Navigator.push(
         context,
          MaterialPageRoute(
            builder: (_) => NotificationsPage(
              onUnreadCountChanged: (count) {
                if (mounted) {
                  setState(() {
                    _unreadNotificationCount = count;
                  });
                }
              },
            ),
          ),
       );
       _fetchUnreadNotificationCount();
     }
   }
 
   void _showLoginRequiredDialog(bool isEn) {
     showDialog<void>(
       context: context,
       builder: (dialogContext) {
         final isDark = ThemeController.instance.isDarkMode;
         return AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           backgroundColor: isDark ? const Color(0xFF26133B) : Colors.white,
           title: Row(
             children: [
               const Icon(Icons.lock_outline_rounded, color: Color(0xFF562875), size: 28),
               const SizedBox(width: 10),
               Expanded(
                 child: Text(
                   isEn ? 'Authentication Required' : 'Bảo mật thông báo',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                     color: isDark ? Colors.white : const Color(0xFF562875),
                   ),
                 ),
               ),
             ],
           ),
           content: Text(
             isEn
                 ? 'Please log in to your NFBank account to view personal notifications and balance changes.'
                 : 'Để bảo vệ thông tin tài chính cá nhân, vui lòng đăng nhập tài khoản NFBank để xem thông báo và biến động số dư.',
             style: TextStyle(
               fontSize: 14,
               color: isDark ? Colors.white70 : Colors.black87,
             ),
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(dialogContext),
               child: Text(
                 isEn ? 'Close' : 'Đóng',
                 style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
               ),
             ),
             ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: const Color(0xFF562875),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               ),
               onPressed: () {
                 Navigator.pop(dialogContext);
                 if (_biometricLoginEnabled) {
                   _biometricLogin();
                 }
               },
               child: Text(
                 isEn ? 'Log in now' : 'Đăng nhập ngay',
                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
               ),
             ),
           ],
         );
       },
     );
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
         final displayName = (_lastUserName != null && _lastUserName!.isNotEmpty)
             ? _lastUserName!
             : 'DAO THANH NHAN';
 
         return Scaffold(
           resizeToAvoidBottomInset: false,
           body: Container(
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
                 colors: isDark
                     ? [const Color(0xFF1F0D33), const Color(0xFF12071F)]
                     : [const Color(0xFFEDE6F7), const Color(0xFFDCCDF3), const Color(0xFFC2A8E5)],
               ),
             ),
             child: SafeArea(
               child: Column(
                 children: [
                   // --- TOP BAR (Logo + Language Pill + Notification Bell) ---
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                     child: Row(
                       children: [
                         // NFBank Logo
                         Row(
                           children: [
                             Image.asset('assets/images/logo_transparent.png', height: 32, fit: BoxFit.contain),
                             const SizedBox(width: 8),
                             Text(
                               'NFBank',
                               style: TextStyle(
                                 fontSize: 24,
                                 fontWeight: FontWeight.bold,
                                 color: isDark ? Colors.white : const Color(0xFF562875),
                                 letterSpacing: 0.5,
                               ),
                             ),
                           ],
                         ),
                         const Spacer(),
 
                         // Language Selector Pill
                         InkWell(
                           onTap: () => LanguageController.instance.toggleLanguage(),
                           borderRadius: BorderRadius.circular(20),
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                             decoration: BoxDecoration(
                               color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.8),
                               borderRadius: BorderRadius.circular(20),
                               boxShadow: [
                                 BoxShadow(
                                   color: Colors.black.withOpacity(0.04),
                                   blurRadius: 6,
                                   offset: const Offset(0, 2),
                                 ),
                               ],
                             ),
                             child: Row(
                               children: [
                                 Text(isEn ? '🇬🇧 EN' : '🇻🇳 VN', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                 const SizedBox(width: 4),
                                 Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF562875)),
                               ],
                             ),
                           ),
                         ),
                         const SizedBox(width: 10),
 
                         // Light / Dark Theme Toggle Button
                         InkWell(
                           onTap: () => ThemeController.instance.toggleTheme(!isDark),
                           borderRadius: BorderRadius.circular(20),
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                             decoration: BoxDecoration(
                               color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.8),
                               borderRadius: BorderRadius.circular(20),
                               boxShadow: [
                                 BoxShadow(
                                   color: Colors.black.withOpacity(0.04),
                                   blurRadius: 6,
                                   offset: const Offset(0, 2),
                                 ),
                               ],
                             ),
                             child: Icon(
                               isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                               size: 18,
                               color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF562875),
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
 
                   // Main Card Content (Positioned exactly 24px above Quick Action Bar)
                   Expanded(
                     child: Align(
                       alignment: Alignment.bottomCenter,
                       child: SingleChildScrollView(
                         padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
                         child: ConstrainedBox(
                           constraints: const BoxConstraints(maxWidth: 420),
                           child: Form(
                             key: _form,
                             child: Container(
                               padding: const EdgeInsets.all(24),
                               decoration: BoxDecoration(
                                 color: isDark
                                     ? const Color(0xFF26133B)
                                     : Colors.white.withOpacity(0.92),
                                 borderRadius: BorderRadius.circular(32),
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.black.withOpacity(0.12),
                                     blurRadius: 25,
                                     offset: const Offset(0, 10),
                                   ),
                                 ],
                               ),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.stretch,
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   // --- Top Card Row: Greeting + Name + QR Code Box ---
                                   // --- Top Card Row: Greeting + Switch Icon + QR Code on Top Line; Name on 2nd Line ---
                                   Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       // Line 1: Header / Greeting
                                       Text(
                                         (_lastUserName == null || _lastUserName!.isEmpty || _isSwitchingAccount)
                                             ? (isEn ? 'Log In' : 'Đăng nhập')
                                             : _getGreeting(isEn),
                                         style: TextStyle(
                                           fontSize: (_lastUserName == null || _lastUserName!.isEmpty || _isSwitchingAccount) ? 22 : 15,
                                           fontWeight: FontWeight.bold,
                                           color: isDark ? Colors.white : const Color(0xFF1F0D33),
                                         ),
                                       ),
                                       if (_lastUserName != null && _lastUserName!.isNotEmpty && !_isSwitchingAccount) ...[
                                         const SizedBox(height: 4),
 
                                         // Line 2: Display Name + Switch Account Button Box on the same row (bottom aligned)
                                         Row(
                                           crossAxisAlignment: CrossAxisAlignment.end,
                                           children: [
                                           Expanded(
                                             child: Text(
                                               displayName,
                                               maxLines: 2,
                                               overflow: TextOverflow.ellipsis,
                                               style: TextStyle(
                                                 fontSize: 21,
                                                 fontWeight: FontWeight.bold,
                                                 color: isDark ? Colors.white : const Color(0xFF1F0D33),
                                                 letterSpacing: 0.3,
                                               ),
                                             ),
                                           ),
                                           const SizedBox(width: 8),
 
                                           // Switch Account Button Box
                                           InkWell(
                                             onTap: () {
                                               setState(() {
                                                 _isSwitchingAccount = !_isSwitchingAccount;
                                                 if (_isSwitchingAccount) {
                                                   _phone.clear();
                                                   _password.clear();
                                                 } else {
                                                   if (_lastUserPhone != null) {
                                                     _phone.text = _lastUserPhone!;
                                                   }
                                                 }
                                               });
                                             },
                                             borderRadius: BorderRadius.circular(12),
                                             child: Container(
                                               padding: const EdgeInsets.all(8),
                                               decoration: BoxDecoration(
                                                 color: isDark ? Colors.white : const Color(0xFFF3EDF9),
                                                 borderRadius: BorderRadius.circular(12),
                                                 border: Border.all(color: isDark ? Colors.white : const Color(0xFF562875).withOpacity(0.15)),
                                               ),
                                               child: const Icon(Icons.switch_account_rounded, size: 23, color: Color(0xFF562875)),
                                             ),
                                           ),
                                         ],
                                       ),
                                       ],
                                     ],
                                   ),
                                   const SizedBox(height: 24),
 
                                   // --- Input Fields (Phone / Password / Quick Login) ---
                                   if (_step == null) ...[
                                     if (_lastUserName == null || _lastUserName!.isEmpty || _isSwitchingAccount) ...[
                                       // === MODE B: Đăng nhập bằng tài khoản mới / Đổi tài khoản ===
                                       TextFormField(
                                          controller: _phone,
                                          keyboardType: TextInputType.phone,
                                          maxLength: 10,
                                          enableInteractiveSelection: false,
                                          contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                          ],
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                          decoration: InputDecoration(
                                            labelText: isEn ? 'Phone number' : 'Số điện thoại',
                                            labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF666666)),
                                            prefixIcon: Icon(Icons.phone_iphone_rounded, color: isDark ? Colors.white : const Color(0xFF562875)),
                                            filled: true,
                                            fillColor: isDark ? const Color(0xFF1E0E30) : const Color(0xFFF5F2F8),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide.none,
                                            ),
                                            counterText: '',
                                          ),
                                          validator: _validatePhone,
                                        ),
                                       const SizedBox(height: 14),
                                       TextFormField(
                                         controller: _password,
                                         obscureText: _passwordHidden,
                                         style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                         decoration: InputDecoration(
                                           labelText: isEn ? 'Password' : 'Mật khẩu',
                                           labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF666666)),
                                           prefixIcon: Icon(Icons.lock_outline_rounded, color: isDark ? Colors.white : const Color(0xFF562875)),
                                           filled: true,
                                           fillColor: isDark ? const Color(0xFF1E0E30) : const Color(0xFFF5F2F8),
                                           border: OutlineInputBorder(
                                             borderRadius: BorderRadius.circular(16),
                                             borderSide: BorderSide.none,
                                           ),
                                           suffixIcon: IconButton(
                                             onPressed: () => setState(() => _passwordHidden = !_passwordHidden),
                                             icon: Icon(
                                               _passwordHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                               color: isDark ? Colors.white : const Color(0xFF562875),
                                             ),
                                           ),
                                         ),
                                         validator: (value) => (value?.length ?? 0) < 6
                                             ? (isEn ? 'Password must be at least 6 characters' : 'Mật khẩu tối thiểu 6 ký tự')
                                             : null,
                                       ),
                                       const SizedBox(height: 8),
                                       const SizedBox(height: 16),
 
                                       // Nút "Đăng nhập"
                                       Container(
                                         width: double.infinity,
                                         height: 54,
                                         decoration: BoxDecoration(
                                           borderRadius: BorderRadius.circular(28),
                                           gradient: const LinearGradient(
                                             colors: [Color(0xFF9C3CE6), Color(0xFF562875)],
                                           ),
                                           boxShadow: [
                                             BoxShadow(
                                               color: const Color(0xFF562875).withOpacity(0.35),
                                               blurRadius: 12,
                                               offset: const Offset(0, 4),
                                             ),
                                           ],
                                         ),
                                         child: ElevatedButton(
                                           onPressed: _loading ? null : _login,
                                           style: ElevatedButton.styleFrom(
                                             backgroundColor: Colors.transparent,
                                             shadowColor: Colors.transparent,
                                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                           ),
                                           child: Text(
                                             isEn ? 'Log In' : 'Đăng nhập',
                                             style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                           ),
                                         ),
                                       ),
                                       const SizedBox(height: 8),
 
                                       // Row chứa nút "<- Quay lại" bên trái và "Quên mật khẩu?" bên phải
                                       Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           if (_lastUserName != null && _lastUserName!.isNotEmpty)
                                             TextButton.icon(
                                               onPressed: () {
                                                 setState(() {
                                                   _isSwitchingAccount = false;
                                                   if (_lastUserPhone != null) _phone.text = _lastUserPhone!;
                                                 });
                                               },
                                               icon: Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF562875)),
                                               label: Text(
                                                 isEn ? 'Back' : 'Quay lại',
                                                 style: TextStyle(color: isDark ? Colors.white : const Color(0xFF562875), fontWeight: FontWeight.bold),
                                               ),
                                             )
                                           else
                                             const SizedBox(),
                                           TextButton(
                                             onPressed: _showResetPassword,
                                             child: Text(
                                               isEn ? 'Forgot password?' : 'Quên mật khẩu?',
                                               style: TextStyle(color: isDark ? Colors.white : const Color(0xFF562875), fontWeight: FontWeight.bold),
                                             ),
                                           ),
                                         ],
                                       ),
 
                                       // Nút mở tài khoản online
                                       Center(
                                         child: TextButton(
                                           onPressed: _loading
                                               ? null
                                               : () => Navigator.push(
                                                   context,
                                                   MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                                 ),
                                           child: Text(
                                             isEn ? "Don't have an account? Open online now" : 'Bạn chưa có tài khoản? Mở online ngay',
                                             style: TextStyle(color: isDark ? Colors.white : const Color(0xFF562875), fontWeight: FontWeight.bold),
                                           ),
                                         ),
                                       ),
                                     ] else ...[
                                       // === MODE A: Quick Login (Đăng nhập nhanh bằng vân tay, XÓA ô mật khẩu & XÓA Quên mật khẩu & XÓA Đăng nhập bằng tài khoản khác) ===
                                       Container(
                                         height: 54,
                                         decoration: BoxDecoration(
                                           borderRadius: BorderRadius.circular(28),
                                           gradient: const LinearGradient(
                                             colors: [Color(0xFF9C3CE6), Color(0xFF562875)],
                                           ),
                                           boxShadow: [
                                             BoxShadow(
                                               color: const Color(0xFF562875).withOpacity(0.35),
                                               blurRadius: 12,
                                               offset: const Offset(0, 4),
                                             ),
                                           ],
                                         ),
                                         child: ElevatedButton(
                                           onPressed: _loading ? null : _biometricLogin,
                                           style: ElevatedButton.styleFrom(
                                             backgroundColor: Colors.transparent,
                                             shadowColor: Colors.transparent,
                                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                           ),
                                           child: _loading
                                               ? const SizedBox(
                                                   width: 24,
                                                   height: 24,
                                                   child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                 )
                                               : Row(
                                                   mainAxisAlignment: MainAxisAlignment.center,
                                                   children: [
                                                     const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
                                                     const SizedBox(width: 8),
                                                     Text(
                                                       isEn ? 'Log in with Fingerprint' : 'Đăng nhập bằng vân tay',
                                                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                                     ),
                                                   ],
                                                 ),
                                         ),
                                       ),
                                       const SizedBox(height: 14),
                                     ],
                                   ] else if (_step == LoginStep.otpRequired) ...[
                                     Text(
                                       isEn ? 'OTP Verification' : 'Xác thực mã OTP',
                                       style: TextStyle(
                                         fontSize: 18,
                                         fontWeight: FontWeight.bold,
                                         color: isDark ? Colors.white : const Color(0xFF1F0D33),
                                       ),
                                     ),
                                     const SizedBox(height: 6),
                                     Text(
                                       isEn
                                           ? 'Please enter the 6-digit OTP code sent via SMS to ${_phone.text}'
                                           : 'Vui lòng nhập mã SMS OTP 6 số đã được gửi tới số điện thoại ${_phone.text}',
                                       style: TextStyle(
                                         fontSize: 13,
                                         color: isDark ? Colors.white70 : const Color(0xFF666666),
                                         height: 1.4,
                                       ),
                                     ),
                                     const SizedBox(height: 16),
                                     TextFormField(
                                       controller: _otp,
                                       keyboardType: TextInputType.number,
                                       maxLength: 6,
                                       autofocus: true,
                                       style: TextStyle(
                                         fontSize: 20,
                                         letterSpacing: 8,
                                         fontWeight: FontWeight.bold,
                                         color: isDark ? Colors.white : Colors.black87,
                                       ),
                                       textAlign: TextAlign.center,
                                       decoration: InputDecoration(
                                         hintText: '******',
                                         counterText: '',
                                         filled: true,
                                         fillColor: isDark ? const Color(0xFF1E0E30) : const Color(0xFFF5F2F8),
                                         border: OutlineInputBorder(
                                           borderRadius: BorderRadius.circular(16),
                                           borderSide: BorderSide.none,
                                         ),
                                       ),
                                     ),
                                     const SizedBox(height: 20),
                                     Container(
                                       width: double.infinity,
                                       height: 54,
                                       decoration: BoxDecoration(
                                         borderRadius: BorderRadius.circular(28),
                                         gradient: const LinearGradient(
                                           colors: [Color(0xFF9C3CE6), Color(0xFF562875)],
                                         ),
                                         boxShadow: [
                                           BoxShadow(
                                             color: const Color(0xFF562875).withOpacity(0.35),
                                             blurRadius: 12,
                                             offset: const Offset(0, 4),
                                           ),
                                         ],
                                       ),
                                       child: ElevatedButton(
                                         onPressed: _loading ? null : _confirmSms,
                                         style: ElevatedButton.styleFrom(
                                           backgroundColor: Colors.transparent,
                                           shadowColor: Colors.transparent,
                                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                         ),
                                         child: _loading
                                             ? const SizedBox(
                                                 width: 24,
                                                 height: 24,
                                                 child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                               )
                                             : Text(
                                                 isEn ? 'Verify & Log In' : 'Xác nhận & Đăng nhập',
                                                 style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                               ),
                                       ),
                                     ),
                                      const SizedBox(height: 12),
                                      Center(
                                        child: TextButton(
                                          onPressed: (_otpCooldown > 0 || _loading) ? null : _resendOtp,
                                          child: Text(
                                            _otpCooldown > 0
                                                ? (isEn ? 'Resend OTP (${_otpCooldown}s)' : 'Gửi lại mã OTP (${_otpCooldown}s)')
                                                : (isEn ? 'Resend OTP' : 'Gửi lại mã OTP'),
                                            style: TextStyle(
                                              color: _otpCooldown > 0
                                                  ? (isDark ? Colors.white38 : Colors.grey)
                                                  : (isDark ? Colors.lightBlueAccent : const Color(0xFF562875)),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Center(
                                        child: TextButton.icon(
                                          onPressed: () {
                                            _otpTimer?.cancel();
                                            setState(() {
                                              _step = null;
                                              _otp.clear();
                                            });
                                          },
                                          icon: Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF562875)),
                                          label: Text(
                                            isEn ? 'Back to login' : 'Quay lại đăng nhập',
                                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF562875), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                   ] else if (_step == LoginStep.totpRequired) ...[
                                     Text(
                                       isEn ? 'Authenticator Code' : 'Mã xác thực Google Authenticator',
                                       style: TextStyle(
                                         fontSize: 18,
                                         fontWeight: FontWeight.bold,
                                         color: isDark ? Colors.white : const Color(0xFF1F0D33),
                                       ),
                                     ),
                                     const SizedBox(height: 6),
                                     Text(
                                       isEn
                                           ? 'Please enter the 6-digit TOTP code from your Google Authenticator app'
                                           : 'Vui lòng nhập mã 6 số từ ứng dụng Google Authenticator (TOTP) của bạn',
                                       style: TextStyle(
                                         fontSize: 13,
                                         color: isDark ? Colors.white70 : const Color(0xFF666666),
                                         height: 1.4,
                                       ),
                                     ),
                                     const SizedBox(height: 16),
                                     TextFormField(
                                       controller: _totp,
                                       keyboardType: TextInputType.number,
                                       maxLength: 6,
                                       autofocus: true,
                                       style: TextStyle(
                                         fontSize: 20,
                                         letterSpacing: 8,
                                         fontWeight: FontWeight.bold,
                                         color: isDark ? Colors.white : Colors.black87,
                                       ),
                                       textAlign: TextAlign.center,
                                       decoration: InputDecoration(
                                         hintText: '******',
                                         counterText: '',
                                         filled: true,
                                         fillColor: isDark ? const Color(0xFF1E0E30) : const Color(0xFFF5F2F8),
                                         border: OutlineInputBorder(
                                           borderRadius: BorderRadius.circular(16),
                                           borderSide: BorderSide.none,
                                         ),
                                       ),
                                     ),
                                     const SizedBox(height: 20),
                                     Container(
                                       width: double.infinity,
                                       height: 54,
                                       decoration: BoxDecoration(
                                         borderRadius: BorderRadius.circular(28),
                                         gradient: const LinearGradient(
                                           colors: [Color(0xFF9C3CE6), Color(0xFF562875)],
                                         ),
                                         boxShadow: [
                                           BoxShadow(
                                             color: const Color(0xFF562875).withOpacity(0.35),
                                             blurRadius: 12,
                                             offset: const Offset(0, 4),
                                           ),
                                         ],
                                       ),
                                       child: ElevatedButton(
                                         onPressed: _loading ? null : () => _login(totp: _totp.text.trim()),
                                         style: ElevatedButton.styleFrom(
                                           backgroundColor: Colors.transparent,
                                           shadowColor: Colors.transparent,
                                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                         ),
                                         child: _loading
                                             ? const SizedBox(
                                                 width: 24,
                                                 height: 24,
                                                 child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                               )
                                             : Text(
                                                 isEn ? 'Verify & Log In' : 'Xác nhận & Đăng nhập',
                                                 style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                               ),
                                       ),
                                     ),
                                     const SizedBox(height: 10),
                                     Center(
                                       child: TextButton.icon(
                                         onPressed: () {
                                           setState(() {
                                             _step = null;
                                             _totp.clear();
                                           });
                                         },
                                         icon: Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF562875)),
                                         label: Text(
                                           isEn ? 'Back to login' : 'Quay lại đăng nhập',
                                           style: TextStyle(color: isDark ? Colors.white : const Color(0xFF562875), fontWeight: FontWeight.bold),
                                         ),
                                       ),
                                     ),
                                   ],
                                 ],
                                 ),
                               ),
                             ),
                           ),
                         ),
                       ),
                     ),

                   // --- QUICK ACTION BAR (QR nhận tiền, Quét mã QR, Thông báo) ---
                   if (_lastUserName != null && _lastUserName!.isNotEmpty && !_isSwitchingAccount)
                     Container(
                       width: double.infinity,
                       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                       decoration: BoxDecoration(
                         color: isDark ? const Color(0xFF1E0E30).withOpacity(0.9) : Colors.white.withOpacity(0.85),
                         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                         border: Border(
                           top: BorderSide(
                             color: isDark ? Colors.white12 : const Color(0xFF562875).withOpacity(0.15),
                             width: 1,
                           ),
                         ),
                       ),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceAround,
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           // Left: QR nhận tiền
                           _buildQuickBarAction(
                             icon: Icons.qr_code_2_rounded,
                             label: isEn ? 'Receive QR' : 'QR nhận tiền',
                             onTap: _showReceiveQRModal,
                             isDark: isDark,
                           ),

                           // Center: Quét mã QR (Nút tròn nhô nổi bật)
                           _buildQuickBarCenterAction(
                             label: isEn ? 'Scan QR' : 'Quét mã QR',
                             onTap: () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (_) => const QRScannerPage()),
                               );
                             },
                             isDark: isDark,
                           ),

                           // Right: Thông báo (Chuông + Badge đỏ)
                           _buildQuickBarAction(
                             icon: Icons.notifications_rounded,
                             label: isEn ? 'Notifications' : 'Thông báo',
                             badgeCount: _unreadNotificationCount > 0
                                 ? (_unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount')
                                 : null,
                             onTap: _openNotificationsWithSecurity,
                             isDark: isDark,
                           ),
                         ],
                       ),
                     ),

                 ],
               ),
             ),
           ),
         );
       },
     );
   }
 
 
 
   Widget _progressOr(String label) => _loading
       ? const SizedBox.square(
           dimension: 20,
           child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
         )
       : Text(label);
 
   Widget _buildQuickBarAction({
     required IconData icon,
     required String label,
     required VoidCallback onTap,
     required bool isDark,
     String? badgeCount,
   }) {
     return InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.circular(16),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           Stack(
             clipBehavior: Clip.none,
             children: [
               Container(
                 width: 44,
                 height: 44,
                 decoration: BoxDecoration(
                   color: isDark
                       ? Colors.white.withOpacity(0.12)
                       : const Color(0xFF562875).withOpacity(0.12),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(
                   icon,
                   color: isDark ? Colors.white : const Color(0xFF562875),
                   size: 24,
                 ),
               ),
               if (badgeCount != null)
                 Positioned(
                   right: -4,
                   top: -2,
                   child: Container(
                     padding: const EdgeInsets.all(3),
                     decoration: const BoxDecoration(
                       color: Colors.redAccent,
                       shape: BoxShape.circle,
                     ),
                     constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                     child: Text(
                       badgeCount,
                       style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                       textAlign: TextAlign.center,
                     ),
                   ),
                 ),
             ],
           ),
           const SizedBox(height: 6),
           Text(
             label,
             style: TextStyle(
               fontSize: 11,
               fontWeight: FontWeight.w600,
               color: isDark ? Colors.white70 : const Color(0xFF444444),
             ),
           ),
         ],
       ),
     );
   }
 
   Widget _buildQuickBarCenterAction({
     required String label,
     required VoidCallback onTap,
     required bool isDark,
   }) {
     return InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.circular(30),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           Container(
             width: 52,
             height: 52,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               gradient: const LinearGradient(
                 colors: [Color(0xFF9C3CE6), Color(0xFF562875)],
               ),
               boxShadow: [
                 BoxShadow(
                   color: const Color(0xFF562875).withOpacity(0.4),
                   blurRadius: 10,
                   offset: const Offset(0, 4),
                 ),
               ],
             ),
             child: const Icon(
               Icons.qr_code_scanner_rounded,
               color: Colors.white,
               size: 28,
             ),
           ),
           const SizedBox(height: 6),
           Text(
             label,
             style: TextStyle(
               fontSize: 11,
               fontWeight: FontWeight.bold,
               color: isDark ? Colors.white : const Color(0xFF562875),
             ),
           ),
         ],
       ),
     );
   }
 
   
 }
 
 class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({
    required this.initialPhone,
    required this.phoneAuth,
    required this.auth,
  });

  final String initialPhone;
  final PhoneAuthService phoneAuth;
  final AuthService auth;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  // Input controllers
  final _phone = TextEditingController();
  final _phoneOtp = TextEditingController();
  final _emailOtp = TextEditingController();
  final _newPassword = TextEditingController();

  // Mode & State variables
  String? _verificationId; // Non-null if SMS OTP sent
  bool _isEmailMode = false; // True if Email OTP sent
  String? _targetEmail;
  String? _maskedEmail;

  String? _phoneErrorText;
  String? _emailOtpErrorText;

  bool _loading = false;
  bool _passHidden = true;

  static const _validPrefixes = {
    '032', '033', '034', '035', '036', '037', '038', '039',
    '086', '096', '097', '098',
    '081', '082', '083', '084', '085', '087', '088', '091', '094',
    '070', '076', '077', '078', '079', '089', '090', '093',
    '052', '055', '056', '058', '092',
    '059', '099',
  };

  @override
  void initState() {
    super.initState();
    _phone.text = widget.initialPhone;
    _phone.addListener(_onPhoneChanged);
    _onPhoneChanged();
  }

  void _onPhoneChanged() {
    final text = _phone.text.trim();
    if (text.length >= 3) {
      final prefix = text.substring(0, 3);
      if (!_validPrefixes.contains(prefix)) {
        if (_phoneErrorText != 'Đầu số không đúng vui lòng kiểm tra lại') {
          setState(() {
            _phoneErrorText = 'Đầu số không đúng vui lòng kiểm tra lại';
          });
        }
        return;
      }
    }
    if (_phoneErrorText != null) {
      setState(() {
        _phoneErrorText = null;
      });
    }
  }

  @override
  void dispose() {
    _phone.removeListener(_onPhoneChanged);
    _phone.dispose();
    _phoneOtp.dispose();
    _emailOtp.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  bool _validatePhoneInput() {
    final rawPhone = _phone.text.trim();
    if (rawPhone.length != 10) {
      setState(() => _phoneErrorText = 'Số điện thoại phải bao gồm 10 chữ số');
      return false;
    }
    if (rawPhone.length >= 3) {
      final prefix = rawPhone.substring(0, 3);
      if (!_validPrefixes.contains(prefix)) {
        setState(() => _phoneErrorText = 'Đầu số không đúng vui lòng kiểm tra lại');
        return false;
      }
    }
    if (_phoneErrorText != null) return false;
    return true;
  }

  // --- Send SMS OTP ---
  Future<void> _sendPhoneCode() async {
    if (!_validatePhoneInput()) return;

    final rawPhone = _phone.text.trim();
    setState(() => _loading = true);
    try {
      final id = await widget.phoneAuth.sendCode(rawPhone);
      setState(() {
        _verificationId = id;
        _isEmailMode = false;
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Send Email OTP by Phone ---
  Future<void> _sendEmailOTPByPhone() async {
    if (!_validatePhoneInput()) return;

    final rawPhone = _phone.text.trim();
    setState(() => _loading = true);
    try {
      final res = await widget.auth.sendEmailOTP(phone: rawPhone);
      final data = res.raw is Map ? (res.raw['data'] as Map<String, dynamic>?) : null;
      final targetEmail = data?['email']?.toString();
      final maskedEmail = data?['masked_email']?.toString() ?? targetEmail;

      setState(() {
        _targetEmail = targetEmail;
        _maskedEmail = maskedEmail;
        _isEmailMode = true;
      });
      if (mounted) {
        showMessage(context, 'Mã OTP đã được gửi về email đăng ký (${maskedEmail ?? ''})');
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Reset Password via SMS ---
  Future<void> _resetPasswordPhone() async {
    final id = _verificationId;
    if (id == null) return;
    if (_newPassword.text.length < 8) {
      showMessage(context, 'Mật khẩu phải có độ dài tối thiểu 8 ký tự', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await widget.phoneAuth.verifyCode(id, _phoneOtp.text.trim());
      await widget.auth.resetPassword(
        _phone.text.trim(),
        token,
        _newPassword.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Reset Password via Email ---
  Future<void> _resetPasswordEmail() async {
    final targetEmail = _targetEmail;
    final otp = _emailOtp.text.trim();
    final pass = _newPassword.text;

    if (otp.length != 6) {
      setState(() => _emailOtpErrorText = 'Mã OTP phải gồm 6 chữ số');
      return;
    }
    if (pass.length < 8) {
      showMessage(context, 'Mật khẩu phải có độ dài tối thiểu 8 ký tự', error: true);
      return;
    }
    if (targetEmail == null || targetEmail.isEmpty) {
      showMessage(context, 'Không xác định được email nhận mã OTP', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.auth.resetPasswordWithEmail(targetEmail, otp, pass);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập lại!');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final primaryColor = const Color(0xFF562875);
    final isStep2 = (_verificationId != null || _isEmailMode);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1F0D33) : Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        children: [
          if (isStep2)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : primaryColor),
              onPressed: () {
                setState(() {
                  _verificationId = null;
                  _isEmailMode = false;
                });
              },
            ),
          if (isStep2) const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Khôi phục mật khẩu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : primaryColor,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isStep2) ...[
              Text(
                'Vui lòng nhập số điện thoại đăng ký tài khoản:',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                enableInteractiveSelection: false,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: fieldDecoration('Số điện thoại').copyWith(
                  errorText: _phoneErrorText,
                ),
              ),
              if (_phoneErrorText != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _phoneErrorText!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Chọn phương thức nhận mã xác thực OTP:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              // Option 1: Gửi OTP qua SMS
              GestureDetector(
                onTap: _loading ? null : _sendPhoneCode,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A1545) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.phone_android_rounded, color: primaryColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gửi OTP qua SMS',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Nhận mã OTP qua tin nhắn SĐT',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Gửi OTP qua Email
              GestureDetector(
                onTap: _loading ? null : _sendEmailOTPByPhone,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A1545) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF3B82F6), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gửi OTP qua Email',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gửi mã OTP về email trùng với SĐT',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // STEP 2: ENTER OTP & NEW PASSWORD
              if (!_isEmailMode) ...[
                Text(
                  'Mã OTP đã được gửi đến số ${_phone.text.trim()}',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneOtp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: fieldDecoration('Mã SMS OTP'),
                ),
              ] else ...[
                Text(
                  'Mã OTP đã được gửi đến email: ${_maskedEmail ?? ''}',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailOtp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: fieldDecoration('Mã OTP 6 số từ Email'),
                ),
                if (_emailOtpErrorText != null) ...[
                  const SizedBox(height: 4),
                  Text(_emailOtpErrorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _newPassword,
                obscureText: _passHidden,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: fieldDecoration('Mật khẩu mới').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_passHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                    onPressed: () => setState(() => _passHidden = !_passHidden),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!isStep2)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))
        else ...[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: _loading
                ? null
                : (!_isEmailMode ? _resetPasswordPhone : _resetPasswordEmail),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(120, 44),
            ),
            child: _loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text(
                    'Đổi mật khẩu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ],
    );
  }
}

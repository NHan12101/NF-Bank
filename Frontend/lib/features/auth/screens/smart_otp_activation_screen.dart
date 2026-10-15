import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common.dart';
import '../../shell/screens/role_gate.dart';
import '../../transfers/services/transfer_repository.dart';

class SmartOtpActivationScreen extends StatefulWidget {
  const SmartOtpActivationScreen({
    super.key,
    required this.user,
    required this.isNewPin,
  });

  final SessionUser user;
  final bool isNewPin;

  @override
  State<SmartOtpActivationScreen> createState() => _SmartOtpActivationScreenState();
}

class _SmartOtpActivationScreenState extends State<SmartOtpActivationScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirmingStep = false;
  bool _loading = false;
  final TransferRepository _repository = const TransferRepository();

  void _onKeyPress(String value) {
    if (_loading) return;
    setState(() {
      if (!_isConfirmingStep) {
        if (_pin.length < 4) {
          _pin += value;
          if (_pin.length == 4) {
            if (widget.isNewPin) {
              // Chuyển sang bước nhập lại PIN để xác nhận
              _isConfirmingStep = true;
            } else {
              // Thiết bị mới -> Xác minh PIN với hệ thống ngay
              _submitVerifyPin();
            }
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += value;
          if (_confirmPin.length == 4) {
            _submitSetupPin();
          }
        }
      }
    });
  }

  void _onBackspace() {
    if (_loading) return;
    setState(() {
      if (_isConfirmingStep) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirmingStep = false;
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _submitSetupPin() async {
    final isEn = LanguageController.instance.isEnglish;
    if (_pin != _confirmPin) {
      showMessage(context, isEn ? 'PIN confirmation does not match' : 'Mã PIN nhập lại không khớp. Vui lòng thử lại.', error: true);
      setState(() {
        _confirmPin = '';
      });
      return;
    }

    setState(() => _loading = true);
    try {
      await _repository.setupTransactionPin(_pin, _confirmPin);
      await TokenStorage.setSmartOtpActivatedOnDevice(widget.user.id, true);
      if (!mounted) return;
      showMessage(context, isEn ? 'Smart OTP activated successfully!' : 'Kích hoạt Smart OTP thành công!');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleGate()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString().replaceFirst('Exception: ', ''), error: true);
        setState(() {
          _loading = false;
          _pin = '';
          _confirmPin = '';
          _isConfirmingStep = false;
        });
      }
    }
  }

  Future<void> _submitVerifyPin() async {
    final isEn = LanguageController.instance.isEnglish;
    setState(() => _loading = true);
    try {
      await _repository.verifyTransactionPin(_pin, isNewDevice: true);
      await TokenStorage.setSmartOtpActivatedOnDevice(widget.user.id, true);
      if (!mounted) return;
      showMessage(context, isEn ? 'Smart OTP device activated successfully!' : 'Kích hoạt Smart OTP trên thiết bị thành công!');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleGate()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        final errMsg = e.toString().replaceFirst('Exception: ', '');
        showMessage(context, errMsg, error: true);
        setState(() {
          _loading = false;
          _pin = '';
        });

        // Nếu tài khoản bị khóa tự động, xóa token và quay về màn hình đăng nhập
        if (errMsg.contains('bị khóa') || errMsg.contains('locked')) {
          await TokenStorage.clearAuth();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RoleGate()),
              (_) => false,
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final isEn = LanguageController.instance.isEnglish;
    final currentInput = _isConfirmingStep ? _confirmPin : _pin;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0D17) : const Color(0xFFF3F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Image.asset('assets/images/logo_transparent.png', height: 36),
                  const SizedBox(width: 8),
                  Text(
                    'NFBank',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF562875),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF562875).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.shield_rounded, size: 16, color: Color(0xFF562875)),
                        SizedBox(width: 4),
                        Text(
                          'Smart OTP',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF562875)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Shield Lock Icon
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFF562875).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_person_rounded, size: 40, color: Color(0xFF562875)),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      widget.isNewPin
                          ? (_isConfirmingStep
                              ? (isEn ? 'Confirm Smart OTP PIN' : 'Xác nhận Mã PIN Smart OTP')
                              : (isEn ? 'Activate Smart OTP' : 'Kích hoạt Smart OTP'))
                          : (isEn ? 'Activate New Device' : 'Kích hoạt thiết bị mới'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F0D33),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      widget.isNewPin
                          ? (_isConfirmingStep
                              ? (isEn ? 'Please re-enter your 4-digit PIN to confirm.' : 'Vui lòng nhập lại 4 số PIN vừa tạo để xác nhận.')
                              : (isEn ? 'Create a 4-digit Smart OTP PIN to secure your transactions.' : 'Vui lòng tạo Mã PIN Smart OTP 4 số để bảo mật cho mọi giao dịch.'))
                          : (isEn ? 'Please enter your 4-digit Smart OTP PIN to activate this device.' : 'Nhập Mã PIN Smart OTP 4 số để kích hoạt giao dịch trên thiết bị mới này.'),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF666666),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // 4-Digit Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final filled = index < currentInput.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? const Color(0xFF562875)
                                : (isDark ? Colors.white24 : const Color(0xFFDDDDDD)),
                            border: Border.all(
                              color: filled ? const Color(0xFF562875) : (isDark ? Colors.white38 : const Color(0xFFCCCCCC)),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    if (_loading)
                      const CircularProgressIndicator(color: Color(0xFF562875))
                    else
                      const SizedBox(height: 36),
                  ],
                ),
              ),
            ),

            // On-screen Numeric Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151828) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildKeypadRow(['1', '2', '3'], isDark),
                  const SizedBox(height: 12),
                  _buildKeypadRow(['4', '5', '6'], isDark),
                  const SizedBox(height: 12),
                  _buildKeypadRow(['7', '8', '9'], isDark),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72, height: 60),
                      _buildKeypadButton('0', isDark),
                      SizedBox(
                        width: 72,
                        height: 60,
                        child: InkWell(
                          onTap: _onBackspace,
                          borderRadius: BorderRadius.circular(30),
                          child: Center(
                            child: Icon(
                              Icons.backspace_outlined,
                              color: isDark ? Colors.white70 : const Color(0xFF562875),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKeypadButton(key, isDark)).toList(),
    );
  }

  Widget _buildKeypadButton(String label, bool isDark) {
    return SizedBox(
      width: 72,
      height: 60,
      child: InkWell(
        onTap: () => _onKeyPress(label),
        borderRadius: BorderRadius.circular(30),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F0D33),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/api_url.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/name_utils.dart';
import '../../../shared/widgets/common.dart';
import '../services/auth_service.dart';
import '../services/phone_auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _fullNameController = TextEditingController();
  final _phone = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  // Dropdown Selections
  String? _selectedGender;

  // Location Selections
  List<Map<String, dynamic>> _provinces = [];
  Map<String, dynamic>? _selectedProvince;
  Map<String, dynamic>? _selectedWard;
  final _streetController = TextEditingController();

  final _auth = AuthService();
  final _phoneAuth = PhoneAuthService();

  int _currentStep = 1;
  String? _verificationId;
  bool _loading = false;
  bool _passwordHidden = true;
  bool _confirmPasswordHidden = true;
  final _confirmPasswordController = TextEditingController();
  String? _phoneErrorText;
  String? _dobErrorText;
  String? _nameErrorText;
  String? _emailErrorText;
  final _otpFocusNode = FocusNode();
  String? _otpErrorText;
  String? _passwordErrorText;
  String? _confirmPasswordErrorText;
  String? _firebaseIdToken;
  int _resendCountdown = 60;
  Timer? _resendTimer;

  static const _validPrefixes = {
    '032', '033', '034', '035', '036', '037', '038', '039',
    '086', '096', '097', '098',
    '081', '082', '083', '084', '085', '087', '088', '091', '094',
    '070', '076', '077', '078', '079', '089', '090', '093',
    '052', '055', '056', '058', '092',
    '059', '099',
  };

  static const _genders = ['Nam', 'Nữ'];

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhoneChanged);
    _fullNameController.addListener(() => setState(() {}));
    _dobController.addListener(() => setState(() {}));
    _emailController.addListener(_onEmailChanged);
    _addressController.addListener(() => setState(() {}));
    _otp.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    _streetController.addListener(() {
      _updateFullAddress();
      setState(() {});
    });
    _fetchProvinces();
  }

  void _onEmailChanged() {
    if (_emailErrorText != null) {
      setState(() => _emailErrorText = null);
    } else {
      setState(() {});
    }
  }

  void _onPhoneChanged() {
    final text = _phone.text.trim();

    // Check prefix real-time as soon as user types 3 digits or more
    if (text.length >= 3) {
      final prefix = text.substring(0, 3);
      if (!_validPrefixes.contains(prefix)) {
        if (_phoneErrorText != 'Đầu số không đúng định dạng nhà mạng Việt Nam') {
          setState(() {
            _phoneErrorText = 'Đầu số không đúng định dạng nhà mạng Việt Nam';
          });
        }
        return;
      }
    }

    // Clear error if prefix is valid
    if (_phoneErrorText == 'Đầu số không đúng định dạng nhà mạng Việt Nam' ||
        _phoneErrorText == 'Vui lòng nhập số điện thoại') {
      setState(() {
        _phoneErrorText = null;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phone.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _streetController.dispose();
    _password.dispose();
    _confirmPasswordController.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _fetchProvinces() async {
    try {
      final res = await ApiService.get(ApiUrl.provinces);
      if (res.isSuccess && res.data is List) {
        setState(() {
          _provinces = List<Map<String, dynamic>>.from(
            (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching provinces: $e');
    }
  }

  void _updateFullAddress() {
    final street = _streetController.text.trim();
    final parts = <String>[];
    if (street.isNotEmpty) parts.add(street);
    if (_selectedWard != null && _selectedWard!['name'] != null) {
      parts.add(_selectedWard!['name'].toString());
    }
    if (_selectedProvince != null && _selectedProvince!['name'] != null) {
      parts.add(_selectedProvince!['name'].toString());
    }
    _addressController.text = parts.join(', ');
  }

  bool get _isPhoneValid {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return false;
    return _validPrefixes.contains(digits.substring(0, 3));
  }

  bool get _isStep3PasswordValid {
    final pass = _password.text;
    final confirmPass = _confirmPasswordController.text;
    if (pass.length < 8) return false;
    if (pass.contains(' ')) return false;
    if (!pass.contains(RegExp(r'[A-Z]')) || !pass.contains(RegExp(r'[a-z]'))) return false;
    if (!pass.contains(RegExp(r'[0-9]'))) return false;
    if (!pass.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|\\:;"<>,.?/~`]'))) return false;
    if (confirmPass.isEmpty || confirmPass != pass) return false;
    return true;
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final isEn = LanguageController.instance.isEnglish;
    final isDark = ThemeController.instance.isDarkMode;

    DateTime tempPicked = DateTime(2000, 1, 1);
    if (_dobController.text.isNotEmpty) {
      try {
        final parts = _dobController.text.split('/');
        if (parts.length == 3) {
          final d = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final y = int.parse(parts[2]);
          tempPicked = DateTime(y, m, d);
        }
      } catch (_) {}
    }

    final bgColor = isDark ? const Color(0xFF190B28) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 310,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header bar: Hủy | Chọn ngày sinh | Chọn
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        isEn ? 'Cancel' : 'Hủy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Text(
                      isEn ? 'Select Date of Birth' : 'Chọn ngày sinh',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final day = tempPicked.day.toString().padLeft(2, '0');
                        final month = tempPicked.month.toString().padLeft(2, '0');
                        final year = tempPicked.year.toString();

                        int age = now.year - tempPicked.year;
                        if (now.month < tempPicked.month || (now.month == tempPicked.month && now.day < tempPicked.day)) {
                          age--;
                        }

                        final errorMsg = isEn
                            ? 'Quý khách chưa đủ tuổi để mở tài khoản ngân hàng'
                            : 'Quý khách chưa đủ tuổi để mở tài khoản ngân hàng';

                        setState(() {
                          _dobController.text = '$day/$month/$year';
                          if (age < 18) {
                            _dobErrorText = errorMsg;
                          } else {
                            _dobErrorText = null;
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        isEn ? 'Done' : 'Chọn',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cupertino Wheel Date Picker (Năm - Tháng - Ngày)
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    dateOrder: DatePickerDateOrder.ymd,
                    initialDateTime: tempPicked,
                    minimumYear: 1940,
                    maximumYear: 2026,
                    minimumDate: DateTime(1940, 1, 1),
                    maximumDate: DateTime(2026, 12, 31, 23, 59, 59),
                    onDateTimeChanged: (DateTime newDate) {
                      tempPicked = newDate;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleStep1Next() async {
    if (_nameErrorText != null || _dobErrorText != null) return;
    setState(() {
      _phoneErrorText = null;
      _emailErrorText = null;
    });

    final rawPhone = _phone.text.trim();
    final rawEmail = _emailController.text.trim();

    if (rawPhone.length != 10 || !_isPhoneValid) {
      setState(() => _phoneErrorText = 'Số điện thoại phải bao gồm 10 chữ số hợp lệ');
      return;
    }

    if (rawEmail.isEmpty) {
      setState(() => _emailErrorText = 'Vui lòng nhập địa chỉ email');
      return;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(rawEmail)) {
      setState(() => _emailErrorText = 'Địa chỉ email không đúng định dạng');
      return;
    }

    // Call backend /auth/check-phone and /auth/check-email APIs
    setState(() => _loading = true);
    try {
      await ApiService.post(ApiUrl.checkPhone, body: {'phone': rawPhone});
      await ApiService.post(ApiUrl.checkEmail, body: {'email': rawEmail});

      // Phone & Email valid and available -> send Firebase OTP
      final id = await _phoneAuth.sendCode(rawPhone);
      setState(() {
        _verificationId = id;
        _currentStep = 2; // Proceed to Step 2 OTP
        _otpErrorText = null;
        _otp.clear();
      });
      _startResendTimer();
    } on ApiException catch (error) {
      final msg = error.message.toLowerCase();
      if (msg.contains('email')) {
        setState(() => _emailErrorText = error.message);
      } else {
        setState(() => _phoneErrorText = error.message);
      }
    } catch (e) {
      setState(() => _phoneErrorText = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String _maskPhone(String phone) {
    if (phone.length == 10) {
      return '${phone.substring(0, 3)}****${phone.substring(7)}';
    }
    return phone;
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _loading) return;
    final rawPhone = _phone.text.trim();
    setState(() {
      _loading = true;
      _otpErrorText = null;
    });
    try {
      final id = await _phoneAuth.sendCode(rawPhone);
      setState(() => _verificationId = id);
      _startResendTimer();
      if (mounted) showMessage(context, 'Đã gửi lại mã OTP thành công');
    } catch (e) {
      setState(() => _otpErrorText = 'Không thể gửi lại mã OTP. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleStep2VerifyOtp() async {
    if (_loading) return;
    final otpText = _otp.text.trim();
    if (otpText.length != 6) {
      setState(() => _otpErrorText = 'Vui lòng nhập đủ 6 chữ số OTP');
      return;
    }

    setState(() {
      _loading = true;
      _otpErrorText = null;
    });

    try {
      if (_verificationId != null) {
        final token = await _phoneAuth.verifyCode(_verificationId!, otpText);
        setState(() {
          _firebaseIdToken = token;
          _currentStep = 3;
        });
      } else {
        if (otpText == '123456') {
          setState(() {
            _firebaseIdToken = 'AUTO_MOCK_TOKEN';
            _currentStep = 3;
          });
        } else {
          setState(() => _otpErrorText = 'Mã OTP không đúng. Vui lòng thử lại.');
        }
      }
    } catch (e) {
      setState(() => _otpErrorText = 'Mã OTP không chính xác hoặc đã hết hạn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _handleStep3Register() async {
    if (_loading) return;
    final pass = _password.text;
    final confirmPass = _confirmPasswordController.text;

    final hasMinLength = pass.length >= 8;
    final hasUpperAndLower = pass.contains(RegExp(r'[A-Z]')) && pass.contains(RegExp(r'[a-z]'));
    final hasDigit = pass.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = pass.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|\\:;"<>,.?/~`]'));
    final hasNoSpace = pass.isNotEmpty && !pass.contains(' ');

    if (!hasMinLength) {
      setState(() => _passwordErrorText = 'Mật khẩu phải có độ dài tối thiểu 8 ký tự');
      return;
    }
    if (!hasNoSpace) {
      setState(() => _passwordErrorText = 'Mật khẩu không được chứa khoảng trắng');
      return;
    }
    if (!hasUpperAndLower) {
      setState(() => _passwordErrorText = 'Mật khẩu phải có ít nhất 1 chữ hoa (A-Z) & 1 chữ thường (a-z)');
      return;
    }
    if (!hasDigit) {
      setState(() => _passwordErrorText = 'Mật khẩu phải có ít nhất 1 chữ số (0-9)');
      return;
    }
    if (!hasSpecialChar) {
      setState(() => _passwordErrorText = 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt');
      return;
    }
    if (pass != confirmPass) {
      setState(() => _confirmPasswordErrorText = 'Mật khẩu nhập lại không khớp nhau');
      return;
    }

    setState(() {
      _loading = true;
      _passwordErrorText = null;
      _confirmPasswordErrorText = null;
    });

    try {
      await _auth.register(
        fullName: _fullNameController.text.trim(),
        phone: _phone.text.trim(),
        password: pass,
        idToken: _firebaseIdToken ?? 'AUTO_MOCK_TOKEN',
        email: _emailController.text.trim(),
        gender: _selectedGender,
        dateOfBirth: _dobController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _currentStep = 4;
        });
      }
    } on ApiException catch (e) {
      setState(() => _passwordErrorText = e.message);
    } catch (e) {
      setState(() => _passwordErrorText = 'Đăng ký thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildStep3PasswordSection(bool isDark, bool isEn) {
    final passText = _password.text;
    final confirmText = _confirmPasswordController.text;

    final hasMinLength = passText.length >= 8;
    final hasUpperAndLower = passText.contains(RegExp(r'[A-Z]')) && passText.contains(RegExp(r'[a-z]'));
    final hasDigit = passText.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = passText.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|\\:;"<>,.?/~`]'));
    final hasNoSpace = passText.isNotEmpty && !passText.contains(' ');

    final isConfirmNotEmpty = confirmText.isNotEmpty;
    final isPasswordMismatch = isConfirmNotEmpty && (confirmText != passText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn ? 'Create Password' : 'Tạo mật khẩu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 20),

        // Password field
        Text(
          isEn ? 'Password' : 'Mật khẩu',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        _buildCustomInputField(
          isDark: isDark,
          hasError: _passwordErrorText != null,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _passwordHidden = !_passwordHidden),
            child: Icon(
              _passwordHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: const Color(0xFF94A3B8),
            ),
          ),
          child: TextField(
            controller: _password,
            obscureText: _passwordHidden,
            maxLength: 32,
            inputFormatters: [LengthLimitingTextInputFormatter(32)],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: _cleanInputDecoration(
              hintText: isEn ? 'Enter password' : 'Nhập mật khẩu',
            ),
            onChanged: (_) {
              if (_passwordErrorText != null) {
                setState(() => _passwordErrorText = null);
              }
            },
          ),
        ),
        if (_passwordErrorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _passwordErrorText!,
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

        const SizedBox(height: 18),

        // Confirm password field
        Text(
          isEn ? 'Confirm Password' : 'Nhập lại mật khẩu',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        _buildCustomInputField(
          isDark: isDark,
          hasError: isPasswordMismatch || _confirmPasswordErrorText != null,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _confirmPasswordHidden = !_confirmPasswordHidden),
            child: Icon(
              _confirmPasswordHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: const Color(0xFF94A3B8),
            ),
          ),
          child: TextField(
            controller: _confirmPasswordController,
            obscureText: _confirmPasswordHidden,
            maxLength: 32,
            inputFormatters: [LengthLimitingTextInputFormatter(32)],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: _cleanInputDecoration(
              hintText: isEn ? 'Re-enter password' : 'Nhập lại mật khẩu',
            ),
            onChanged: (_) {
              if (_confirmPasswordErrorText != null) {
                setState(() => _confirmPasswordErrorText = null);
              }
            },
          ),
        ),
        if (isPasswordMismatch) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isEn ? 'Passwords do not match' : 'Mật khẩu nhập lại không khớp nhau',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ] else if (_confirmPasswordErrorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _confirmPasswordErrorText!,
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

        const SizedBox(height: 24),

        // Real-time Requirements Box matching design screenshot
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF26133B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? 'Password must include:' : 'Mật khẩu phải bao gồm:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              _buildRequirementBulletRow(
                isMet: hasMinLength,
                text: isEn ? 'At least 8 characters.' : 'Có độ dài tối thiểu 8 ký tự.',
                isDark: isDark,
              ),
              _buildRequirementBulletRow(
                isMet: hasUpperAndLower,
                text: isEn
                    ? 'At least 1 uppercase (A-Z) & 1 lowercase (a-z).'
                    : 'Có ít nhất 1 ký tự viết hoa (A-Z) & 1 ký tự viết thường (a-z).',
                isDark: isDark,
              ),
              _buildRequirementBulletRow(
                isMet: hasDigit,
                text: isEn ? 'At least 1 digit (0-9).' : 'Có ít nhất 1 chữ số (0-9).',
                isDark: isDark,
              ),
              _buildRequirementBulletRow(
                isMet: hasSpecialChar,
                text: isEn
                    ? "At least 1 special character (!, @, #, \$, %, ^, &, *, (, ), _, +, -, =, {, }, [, ], |, \\, :, ;, \", ', <, >, ,, ., ?, /, ~, `)."
                    : "Có ít nhất 1 ký tự đặc biệt (!, @, #, \$, %, ^, &, *, (, ), _, +, -, =, {, }, [, ], |, \\, :, ;, \", ', <, >, ,, ., ?, /, ~, `).",
                isDark: isDark,
              ),
              _buildRequirementBulletRow(
                isMet: hasNoSpace,
                text: isEn ? 'Do not use spaces.' : 'Không sử dụng dấu cách.',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementBulletRow({required bool isMet, required String text, required bool isDark}) {
    final activeColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final inactiveColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
              color: isMet ? activeColor : inactiveColor,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
                color: isMet ? activeColor : inactiveColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4SuccessSection(bool isDark, bool isEn) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          // Success Animated Check Icon Badge
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.12),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title & Subtitle
          Text(
            isEn ? 'Registration Successful!' : 'Đăng ký tài khoản thành công!',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isEn
                  ? 'Please log in again to continue.'
                  : 'Vui lòng đăng nhập lại để tiếp tục.',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInputSection(bool isDark, bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn ? 'OTP Verification' : 'Xác thực mã OTP',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: isEn
                    ? 'An OTP code has been sent via SMS to '
                    : 'Mã OTP đã được gửi qua SMS đến số điện thoại ',
              ),
              TextSpan(
                text: _maskPhone(_phone.text.trim().isEmpty ? '0987654321' : _phone.text.trim()),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
              TextSpan(
                text: isEn
                    ? '. Please enter the 6-digit code below:'
                    : '. Vui lòng kiểm tra và nhập mã 6 số bên dưới:',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Native overlay TextField for 0ms input latency
        SizedBox(
          height: 56,
          child: Stack(
            children: [
              // Visible 6 Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final text = _otp.text.trim();
                  final char = index < text.length ? text[index] : '';
                  final isFocused = _otpFocusNode.hasFocus &&
                      (index == text.length || (index == 5 && text.length == 6));

                  return Container(
                    width: 48,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: char.isNotEmpty || isFocused
                          ? (isDark ? const Color(0xFF3B1F5E) : const Color(0xFFEFF6FF))
                          : (isDark ? const Color(0xFF26133B) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFocused
                            ? const Color(0xFF6366F1)
                            : (char.isNotEmpty
                                ? const Color(0xFF6366F1).withOpacity(0.5)
                                : (isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                        width: isFocused ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      char,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  );
                }),
              ),

              // Invisible overlay TextField directly capturing touch & typing without grey box
              Positioned.fill(
                child: Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _otp,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
                    cursorColor: Colors.transparent,
                    style: const TextStyle(color: Colors.transparent, fontSize: 1),
                    decoration: const InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (val) {
                      if (val.length == 6 && !_loading) {
                        _handleStep2VerifyOtp();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_otpErrorText != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _otpErrorText!,
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

        const SizedBox(height: 24),

        Center(
          child: _resendCountdown > 0
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEn
                          ? 'Resend code in ${_resendCountdown}s'
                          : 'Gửi lại mã sau ${_resendCountdown}s',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _resendOtp,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEn ? 'Resend OTP Code' : 'Gửi lại mã OTP',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCustomInputField({
    required Widget child,
    Widget? suffixIcon,
    bool isDark = false,
    bool hasError = false,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF26133B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasError
              ? Colors.redAccent
              : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          width: hasError ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: child),
          if (suffixIcon != null) ...[
            const SizedBox(width: 8),
            suffixIcon,
          ],
        ],
      ),
    );
  }

  InputDecoration _cleanInputDecoration({String? hintText}) {
    return InputDecoration(
      isDense: true,
      filled: false,
      fillColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      counterText: '',
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: Color(0xFF94A3B8),
      ),
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

        final bgColor = isDark ? const Color(0xFF12071F) : const Color(0xFFF8FAFC);

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // --- TOP BAR ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F0D33) : Colors.white,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_currentStep == 4) {
                            Navigator.pop(context);
                          } else if (_currentStep > 1) {
                            setState(() => _currentStep--);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isEn ? 'Open Online Account' : 'Đăng ký tài khoản',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance for back icon
                    ],
                  ),
                ),

                // --- STEP CONTENT AREA ---
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_currentStep == 1) ...[
                            // Header: Thông tin cá nhân
                            Text(
                              isEn ? 'Personal Information' : 'Thông tin cá nhân',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Field 1: Họ và tên
                            _buildCustomInputField(
                              isDark: isDark,
                              hasError: _nameErrorText != null,
                              suffixIcon: _fullNameController.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () => _fullNameController.clear(),
                                      child: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF94A3B8)),
                                    )
                                  : null,
                              child: TextField(
                                controller: _fullNameController,
                                textCapitalization: TextCapitalization.characters,
                                maxLength: 50,
                                inputFormatters: [
                                  _NameInputFormatter(
                                    onInvalidPaste: (hasError) {
                                      if (hasError) {
                                        if (_nameErrorText != 'Khách hàng vui lòng nhập đúng định dạng') {
                                          setState(() => _nameErrorText = 'Khách hàng vui lòng nhập đúng định dạng');
                                        }
                                      } else {
                                        if (_nameErrorText != null) {
                                          setState(() => _nameErrorText = null);
                                        }
                                      }
                                    },
                                  ),
                                  LengthLimitingTextInputFormatter(50),
                                ],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                                decoration: _cleanInputDecoration(hintText: isEn ? 'Full Name' : 'Họ và tên'),
                              ),
                            ),
                            if (_nameErrorText != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _nameErrorText!,
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

                            // Field 2: Số điện thoại
                            _buildCustomInputField(
                              isDark: isDark,
                              hasError: _phoneErrorText != null,
                              suffixIcon: _phone.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () => _phone.clear(),
                                      child: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF94A3B8)),
                                    )
                                  : null,
                              child: TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                enableInteractiveSelection: false,
                                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                                decoration: _cleanInputDecoration(hintText: isEn ? 'Phone Number' : 'Số điện thoại'),
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

                            // Field 3: Ngày sinh
                            GestureDetector(
                              onTap: _selectDateOfBirth,
                              child: _buildCustomInputField(
                                isDark: isDark,
                                hasError: _dobErrorText != null,
                                suffixIcon: Icon(Icons.calendar_today_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF1E3A8A)),
                                child: TextField(
                                  controller: _dobController,
                                  enabled: false,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                  decoration: _cleanInputDecoration(hintText: isEn ? 'Date of Birth (DD/MM/YYYY)' : 'Ngày sinh (DD/MM/YYYY)'),
                                ),
                              ),
                            ),
                            if (_dobErrorText != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _dobErrorText!,
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

                            // Field 4: Giới tính (Nằm ngang: Giới tính - [♂ Nam] [♀ Nữ])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Text(
                                    isEn ? 'Gender:' : 'Giới tính:',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedGender = 'Nam'),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _selectedGender == 'Nam'
                                              ? (isDark ? const Color(0xFF3B1F5E) : const Color(0xFFEFF6FF))
                                              : (isDark ? const Color(0xFF26133B) : Colors.white),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: _selectedGender == 'Nam'
                                                ? const Color(0xFF6366F1)
                                                : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                            width: _selectedGender == 'Nam' ? 1.8 : 1.2,
                                          ),
                                           boxShadow: [
                                             BoxShadow(
                                               color: Colors.black.withOpacity(0.04),
                                               blurRadius: 10,
                                               offset: const Offset(0, 3),
                                             ),
                                           ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.male_rounded,
                                              size: 20,
                                              color: _selectedGender == 'Nam'
                                                  ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5))
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isEn ? 'Male' : 'Nam',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: _selectedGender == 'Nam' ? FontWeight.bold : FontWeight.w500,
                                                color: _selectedGender == 'Nam'
                                                    ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedGender = 'Nữ'),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _selectedGender == 'Nữ'
                                              ? (isDark ? const Color(0xFF3B1F5E) : const Color(0xFFEFF6FF))
                                              : (isDark ? const Color(0xFF26133B) : Colors.white),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: _selectedGender == 'Nữ'
                                                ? const Color(0xFF6366F1)
                                                : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                            width: _selectedGender == 'Nữ' ? 1.8 : 1.2,
                                          ),
                                           boxShadow: [
                                             BoxShadow(
                                               color: Colors.black.withOpacity(0.04),
                                               blurRadius: 10,
                                               offset: const Offset(0, 3),
                                             ),
                                           ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.female_rounded,
                                              size: 20,
                                              color: _selectedGender == 'Nữ'
                                                  ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5))
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isEn ? 'Female' : 'Nữ',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: _selectedGender == 'Nữ' ? FontWeight.bold : FontWeight.w500,
                                                color: _selectedGender == 'Nữ'
                                                    ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Field 5: Email
                            _buildCustomInputField(
                              isDark: isDark,
                              hasError: _emailErrorText != null,
                              suffixIcon: _emailController.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () => _emailController.clear(),
                                      child: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF94A3B8)),
                                    )
                                  : null,
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                maxLength: 50,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(50),
                                ],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                                decoration: _cleanInputDecoration(hintText: isEn ? 'Email Address' : 'Email'),
                              ),
                            ),
                            if (_emailErrorText != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _emailErrorText!,
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

                            // Field 6: Địa chỉ thường trú (Tích hợp 3 trong 1: Tỉnh/TP -> Phường/Xã -> Số nhà/Tên đường)
                            GestureDetector(
                              onTap: () {
                                _openUnifiedLocationPicker(
                                  context: context,
                                  isDark: isDark,
                                  isEn: isEn,
                                );
                              },
                              child: _buildCustomInputField(
                                isDark: isDark,
                                suffixIcon: _addressController.text.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedProvince = null;
                                            _selectedWard = null;
                                            _streetController.clear();
                                            _addressController.clear();
                                          });
                                        },
                                        child: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF94A3B8)),
                                      )
                                    : const Icon(Icons.location_on_outlined, size: 22, color: Color(0xFF94A3B8)),
                                child: Text(
                                  _addressController.text.isNotEmpty
                                      ? _addressController.text
                                      : (isEn ? 'Address' : 'Địa chỉ thường trú'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _addressController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                    color: _addressController.text.isNotEmpty
                                        ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                          ] else if (_currentStep == 2) ...[
                            _buildOtpInputSection(isDark, isEn),
                          ] else if (_currentStep == 3) ...[
                            _buildStep3PasswordSection(isDark, isEn),
                          ] else ...[
                            _buildStep4SuccessSection(isDark, isEn),
                          ],

                          const Spacer(),
                          const SizedBox(height: 16),

                          // Step indicator 1/4 aligned top-right of Next button
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '$_currentStep/4',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ),

                          // Bottom Action Button: Tiếp tục / Hoàn tất đăng ký / Đăng nhập bằng SĐT
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: (_currentStep == 1 && _isPhoneValid && _phoneErrorText == null && _emailErrorText == null && _dobErrorText == null && _nameErrorText == null && !_loading)
                                  ? _handleStep1Next
                                  : (_currentStep == 2 && _otp.text.trim().length == 6 && !_loading)
                                      ? _handleStep2VerifyOtp
                                      : (_currentStep == 3 && _isStep3PasswordValid && !_loading)
                                          ? _handleStep3Register
                                          : (_currentStep == 4)
                                              ? () => Navigator.pop(context, _phone.text.trim())
                                              : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1), // Periwinkle lavender blue
                                disabledBackgroundColor: isDark
                                    ? Colors.white12
                                    : const Color(0xFFC5CEE0),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: isDark
                                    ? Colors.white38
                                    : const Color(0xFF8F9BB3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: (_currentStep == 1 ? _isPhoneValid : (_currentStep == 2 ? _otp.text.trim().length == 6 : (_currentStep == 3 ? _isStep3PasswordValid : true))) ? 2 : 0,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _currentStep == 4
                                          ? (isEn ? 'Continue' : 'Tiếp tục')
                                          : (_currentStep == 3
                                              ? (isEn ? 'Complete Registration' : 'Hoàn tất đăng ký')
                                              : (_currentStep == 2 ? (isEn ? 'Verify & Continue' : 'Xác thực & Tiếp tục') : (isEn ? 'Continue' : 'Tiếp tục'))),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openUnifiedLocationPicker({
    required BuildContext context,
    required bool isDark,
    required bool isEn,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _UnifiedLocationPickerBottomSheet(
          initialProvinces: _provinces,
          selectedProvince: _selectedProvince,
          selectedWard: _selectedWard,
          initialStreet: _streetController.text,
          isDark: isDark,
          isEn: isEn,
          onLocationSelected: (province, ward, street) {
            setState(() {
              _selectedProvince = province;
              _selectedWard = ward;
              _streetController.text = street;
              final parts = <String>[];
              if (street.isNotEmpty) parts.add(street);
              if (ward['name'] != null) parts.add(ward['name'].toString());
              if (province['name'] != null) parts.add(province['name'].toString());
              _addressController.text = parts.join(', ');
            });
          },
        );
      },
    );
  }
}

class _UnifiedLocationPickerBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialProvinces;
  final Map<String, dynamic>? selectedProvince;
  final Map<String, dynamic>? selectedWard;
  final String? initialStreet;
  final Function(Map<String, dynamic> province, Map<String, dynamic> ward, String street) onLocationSelected;
  final bool isDark;
  final bool isEn;

  const _UnifiedLocationPickerBottomSheet({
    required this.initialProvinces,
    required this.selectedProvince,
    required this.selectedWard,
    this.initialStreet,
    required this.onLocationSelected,
    required this.isDark,
    required this.isEn,
  });

  @override
  State<_UnifiedLocationPickerBottomSheet> createState() => _UnifiedLocationPickerBottomSheetState();
}

class _UnifiedLocationPickerBottomSheetState extends State<_UnifiedLocationPickerBottomSheet> {
  int _step = 1; // 1: Province, 2: Ward, 3: Street
  Map<String, dynamic>? _currentProvince;
  Map<String, dynamic>? _currentWard;
  List<Map<String, dynamic>> _currentWards = [];
  bool _loadingWards = false;

  final _searchController = TextEditingController();
  final _detailStreetController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialStreet != null) {
      _detailStreetController.text = widget.initialStreet!;
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _detailStreetController.dispose();
    super.dispose();
  }

  Future<void> _selectProvince(Map<String, dynamic> province) async {
    setState(() {
      _currentProvince = province;
      _step = 2;
      _loadingWards = true;
      _searchController.clear();
      _searchQuery = '';
    });

    try {
      final res = await ApiService.get(ApiUrl.wards(province['code'].toString()));
      if (res.isSuccess && res.data is List) {
        setState(() {
          _currentWards = List<Map<String, dynamic>>.from(
            (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching wards in bottom sheet: $e');
    } finally {
      if (mounted) setState(() => _loadingWards = false);
    }
  }

  void _selectWard(Map<String, dynamic> ward) {
    setState(() {
      _currentWard = ward;
      _step = 3;
    });
  }

  void _backStep() {
    setState(() {
      if (_step == 3) {
        _step = 2;
      } else if (_step == 2) {
        _step = 1;
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  void _confirmSelection() {
    if (_currentProvince != null && _currentWard != null) {
      widget.onLocationSelected(
        _currentProvince!,
        _currentWard!,
        _detailStreetController.text.trim(),
      );
      Navigator.pop(context);
    }
  }

  String _getCanonicalFirstLetter(String name) {
    if (name.trim().isEmpty) return '';
    final first = name.trim().substring(0, 1).toUpperCase();
    const map = {
      'À': 'A', 'Á': 'A', 'Ả': 'A', 'Ã': 'A', 'Ạ': 'A', 'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ẳ': 'A', 'Ẵ': 'A', 'Ặ': 'A', 'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ẩ': 'A', 'Ẫ': 'A', 'Ậ': 'A',
      'Đ': 'Đ',
      'È': 'E', 'É': 'E', 'Ẻ': 'E', 'Ẽ': 'E', 'Ẹ': 'E', 'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ể': 'E', 'Ễ': 'E', 'Ệ': 'E',
      'Ì': 'I', 'Í': 'I', 'Ỉ': 'I', 'Ĩ': 'I', 'Ị': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ỏ': 'O', 'Õ': 'O', 'Ọ': 'O', 'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ổ': 'O', 'Ỗ': 'O', 'Ộ': 'O', 'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ở': 'O', 'Ỡ': 'O', 'Ợ': 'O',
      'Ù': 'U', 'Ú': 'U', 'Ủ': 'U', 'Ũ': 'U', 'Ụ': 'U', 'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ử': 'U', 'Ữ': 'U', 'Ự': 'U',
      'Ỳ': 'Y', 'Ý': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y', 'Ỵ': 'Y',
    };
    return map[first] ?? first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isEn = widget.isEn;
    final bgColor = isDark ? const Color(0xFF190B28) : Colors.white;
    final searchBgColor = isDark ? const Color(0xFF26133B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final currentItems = _step == 1 ? widget.initialProvinces : _currentWards;
    final searchHint = _step == 1
        ? (isEn ? 'Search Province / City' : 'Tìm kiếm Tỉnh/Thành phố')
        : (isEn
            ? 'Search Ward / Commune'
            : 'Tìm kiếm Phường/Xã ở ${_currentProvince?['name'] ?? ''}');

    final filtered = currentItems.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    filtered.sort((a, b) {
      final nameA = (a['name'] ?? '').toString();
      final nameB = (b['name'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    String headerTitle = '';
    if (_step == 1) {
      headerTitle = isEn ? 'Select Province / City' : 'Chọn Tỉnh / Thành phố';
    } else if (_step == 2) {
      headerTitle = '${_currentProvince?['name'] ?? ''} › ${isEn ? 'Select Ward' : 'Chọn Phường/Xã/Đặc khu'}';
    } else {
      headerTitle = '${_currentProvince?['name'] ?? ''} › ${_currentWard?['name'] ?? ''}';
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white30 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_step > 1)
                  IconButton(
                    onPressed: _backStep,
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                    ),
                  )
                else
                  const SizedBox(width: 8),

                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headerTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_step < 3) ...[
            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: searchBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        maxLength: 50,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(50),
                        ],
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF94A3B8)),
                      )
                    else
                      const Icon(Icons.search_rounded, size: 22, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loadingWards
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Không tìm thấy kết quả',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final name = (item['name'] ?? '').toString();
                            final currentLetter = _getCanonicalFirstLetter(name);

                            final isFirstInGroup = index == 0 ||
                                _getCanonicalFirstLetter((filtered[index - 1]['name'] ?? '').toString()) != currentLetter;

                            final isSelected = _step == 1
                                ? (widget.selectedProvince != null && widget.selectedProvince!['code'] == item['code'])
                                : (widget.selectedWard != null && widget.selectedWard!['code'] == item['code']);

                            return InkWell(
                              onTap: () {
                                if (_step == 1) {
                                  _selectProvince(item);
                                } else {
                                  _selectWard(item);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 36,
                                      child: isFirstInGroup
                                          ? Text(
                                              currentLetter,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                    color: isSelected
                                                        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A))
                                                        : textColor,
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                size: 20,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
            ),
          ] else ...[
            // Step 3: Detail Street Address
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: searchBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Street Address / House No. (Optional)' : 'Số nhà, tên đường (tùy chọn)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF562875),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _detailStreetController,
                      autofocus: true,
                      maxLength: 50,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                      ],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: isEn ? 'e.g. 123 Nguyen Trai Street' : 'Nhập địa chỉ chi tiết...',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    isEn ? 'Confirm' : 'Xác nhận',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NameInputFormatter extends TextInputFormatter {
  final Function(bool hasInvalidPastedChar) onInvalidPaste;

  _NameInputFormatter({required this.onInvalidPaste});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if (newText.isEmpty) {
      onInvalidPaste(false);
      return newValue;
    }

    final invalidRegExp = RegExp(
      r'[^a-zA-ZÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴàáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ\s]',
    );

    final addedLength = newText.length - oldValue.text.length;
    final hasInvalid = invalidRegExp.hasMatch(newText);

    if (hasInvalid) {
      if (addedLength > 1) {
        onInvalidPaste(true);
      } else {
        onInvalidPaste(false);
      }
      final cleanText = newText.replaceAll(invalidRegExp, '');
      final formatted = _removeVietnameseAndUppercase(cleanText);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } else {
      onInvalidPaste(false);
      final formatted = _removeVietnameseAndUppercase(newText);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  static String _removeVietnameseAndUppercase(String text) {
    const vietnameseMap = {
      'a': 'àáảãạăằắẳẵặâầấẩẫậ',
      'A': 'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬ',
      'd': 'đ',
      'D': 'Đ',
      'e': 'èéẻẽẹêềếểễệ',
      'E': 'ÈÉẺẼẸÊỀẾỂỄỆ',
      'i': 'ìíỉĩị',
      'I': 'ÌÍỈĨỊ',
      'o': 'òóỏõọôồốổỗộơờớởỡợ',
      'O': 'ÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢ',
      'u': 'ùúủũụưừứửữự',
      'U': 'ÙÚỦŨỤƯỪỨỬỮỰ',
      'y': 'ỳýỷỹỵ',
      'Y': 'ỲÝỶỸỴ',
    };

    String result = text;
    for (var entry in vietnameseMap.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        result = result.replaceAll(entry.value[i], entry.key);
      }
    }
    return result.toUpperCase();
  }
}

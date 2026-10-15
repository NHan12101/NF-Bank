import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/bank_repository.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/language_controller.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/phone_auth_service.dart';
import '../widgets/common/common_dialogs.dart';
import '../widgets/profile/password_change_dialog.dart';
import '../widgets/profile/settings_group.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onLogout, this.onAvatarChanged});

  final Future<void> Function() onLogout;
  final ValueChanged<String>? onAvatarChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _repo = BankRepository();
  bool loading = true;
  String? error;
  Map<String, dynamic> profile = {};
  final address = TextEditingController();
  final date = TextEditingController();
  final imagePicker = ImagePicker();
  String avatarUrl = '';
  Uint8List? selectedAvatarBytes;
  XFile? selectedAvatarFile;
  bool pickingAvatar = false;
  bool savingProfile = false;
  String gender = '';
  int dailyTransferLimit = 50000000;
  int initialDailyTransferLimit = 50000000;

  ImageProvider<Object>? get avatarImage {
    final bytes = selectedAvatarBytes;
    if (bytes != null) return MemoryImage(bytes);
    if (avatarUrl.isNotEmpty) return NetworkImage(avatarUrl);
    return null;
  }

  bool biometricSupported = false;
  bool biometricLoginEnabled = false;
  bool biometricTxEnabled = false;

  @override
  void initState() {
    super.initState();
    load();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final supported = await BiometricService.isDeviceSupported();
    final loginEnabled = await BiometricService.isLoginEnabled();
    final txEnabled = await BiometricService.isTxEnabled();
    if (mounted) {
      setState(() {
        biometricSupported = supported;
        biometricLoginEnabled = supported && loginEnabled;
        biometricTxEnabled = supported && txEnabled;
      });
    }
  }

  Future<void> toggleBiometricLogin(bool enabled) async {
    if (!biometricSupported) return;
    if (enabled) {
      final password = await showDialog<String>(
        context: context,
        builder: (context) => const PasswordPromptDialog(),
      );
      if (password == null || password.trim().isEmpty) return;

      final success = await BiometricService.authenticate(
        reason: 'Xác thực sinh trắc học để kích hoạt đăng nhập nhanh',
      );
      if (success) {
        final phoneVal = (profile['phone']?.toString() ??
                profile['phone_number']?.toString() ??
                '')
            .trim();
        final finalPhone = phoneVal.isNotEmpty
            ? phoneVal
            : (await TokenStorage.getLastUserPhone() ?? '');
        await BiometricService.saveLoginCredentials(
          finalPhone,
          password.trim(),
        );
        await BiometricService.setLoginEnabled(true);
        setState(() => biometricLoginEnabled = true);
        if (mounted) {
          showMessage(context, 'Đã bật đăng nhập bằng sinh trắc học');
        }
      }
    } else {
      await BiometricService.clearLoginCredentials();
      await BiometricService.setLoginEnabled(false);
      setState(() => biometricLoginEnabled = false);
      if (mounted) showMessage(context, 'Đã tắt đăng nhập bằng sinh trắc học');
    }
  }

  Future<void> toggleBiometricTx(bool enabled) async {
    if (!biometricSupported) return;
    if (enabled) {
      final pin = await showDialog<String>(
        context: context,
        builder: (context) => const PinPromptDialog(),
      );
      if (pin == null || pin.length < 4 || pin.length > 6) return;

      final success = await BiometricService.authenticate(
        reason: 'Xác thực sinh trắc học để liên kết PIN giao dịch',
      );
      if (success) {
        await BiometricService.saveTransactionPin(pin);
        await BiometricService.setTxEnabled(true);
        setState(() => biometricTxEnabled = true);
        if (mounted) {
          showMessage(context, 'Đã bật xác thực giao dịch bằng sinh trắc học');
        }
      }
    } else {
      await BiometricService.clearTransactionPin();
      await BiometricService.setTxEnabled(false);
      setState(() => biometricTxEnabled = false);
      if (mounted) {
        showMessage(context, 'Đã tắt xác thực giao dịch bằng sinh trắc học');
      }
    }
  }

  @override
  void dispose() {
    address.dispose();
    date.dispose();
    super.dispose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      profile = await _repo.profile();
      address.text = profile['address']?.toString() ?? '';
      avatarUrl = profile['avatar_url']?.toString() ?? '';
      date.text = profile['date_of_birth']?.toString().split('T').first ?? '';
      gender = profile['gender']?.toString() ?? '';
      final limit =
          (profile['daily_transfer_limit'] as num?)?.toInt() ?? 50000000;
      dailyTransferLimit = limit;
      initialDailyTransferLimit = limit;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (savingProfile) return;
    setState(() => savingProfile = true);
    try {
      final avatarFile = selectedAvatarFile;
      if (avatarFile != null) {
        final bytes = selectedAvatarBytes ?? await avatarFile.readAsBytes();
        avatarUrl = await _repo.uploadAvatar(
          bytes: bytes,
          filename: avatarFile.name,
        );
        selectedAvatarFile = null;
        widget.onAvatarChanged?.call(avatarUrl);
      }
      await _repo.updateProfile({
        'address': address.text.trim(),
        'gender': gender,
        'date_of_birth': date.text.trim().isEmpty
            ? null
            : '${date.text.trim()}T00:00:00Z',
      });
      if (dailyTransferLimit != initialDailyTransferLimit) {
        await _repo.updateDailyTransferLimit(dailyTransferLimit);
      }
      if (mounted) {
        showMessage(context, 'Đã cập nhật hồ sơ');
      }
      await load(showLoading: false);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => savingProfile = false);
    }
  }

  Future<void> showAvatarSource() async {
    if (pickingAvatar) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF151D31)
              : Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: const Border(top: BorderSide(color: Color(0x337C83FD))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chọn ảnh đại diện',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF9EA4FF),
                  ),
                  title: const Text('Chụp ảnh'),
                  subtitle: const Text('Sử dụng camera của thiết bị'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF4FD1C5),
                  ),
                  title: const Text('Chọn từ thư viện'),
                  subtitle: const Text('Sử dụng ảnh có sẵn trên thiết bị'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (source != null) await pickAvatar(source);
  }

  Future<void> pickAvatar(ImageSource source) async {
    setState(() => pickingAvatar = true);
    try {
      final file = await imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        if (mounted) {
          showMessage(
            context,
            'Ảnh vượt quá 8 MB, vui lòng chọn ảnh khác',
            error: true,
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        selectedAvatarFile = file;
        selectedAvatarBytes = bytes;
      });
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Không thể mở camera hoặc thư viện ảnh',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => pickingAvatar = false);
    }
  }

  Future<void> changePassword() async {
    final draft = await showDialog<PasswordChangeDraft>(
      context: context,
      builder: (dialogContext) => const PasswordChangeDialog(),
    );
    if (draft == null || !mounted) return;

    final phone = profile['phone']?.toString() ?? '';
    if (phone.isEmpty) {
      showMessage(
        context,
        'Không tìm thấy số điện thoại của tài khoản',
        error: true,
      );
      return;
    }

    bool showingLoading = false;
    void showLoading(String message) {
      if (showingLoading) {
        Navigator.pop(context);
        showingLoading = false;
      }
      showingLoading = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LoadingDialog(message: message),
      ).then((_) => showingLoading = false);
    }

    void dismissLoading() {
      if (showingLoading && mounted) {
        Navigator.pop(context);
        showingLoading = false;
      }
    }

    try {
      showLoading('Đang gửi mã OTP...');
      final phoneAuth = PhoneAuthService();
      final verificationID = await phoneAuth.sendCode(phone);
      dismissLoading();

      if (!mounted) return;
      showMessage(
        context,
        'Đã gửi mã OTP về số điện thoại ${maskPhone(phone)}',
      );

      String idToken;
      if (verificationID.startsWith('AUTO:')) {
        showLoading('Đang xác thực tự động...');
        idToken = await phoneAuth.verifyCode(verificationID, '');
        dismissLoading();
      } else {
        final smsCode = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => OTPVerifyDialog(phone: phone),
        );
        if (smsCode == null || !mounted) return;

        showLoading('Đang xác thực mã OTP...');
        idToken = await phoneAuth.verifyCode(verificationID, smsCode);
        dismissLoading();
      }

      if (!mounted) return;
      showLoading('Đang cập nhật mật khẩu mới...');

      await AuthService().changePassword(
        draft.oldPassword,
        draft.newPassword,
        idToken,
      );

      final isBioEnabled = await BiometricService.isLoginEnabled();
      if (isBioEnabled) {
        await BiometricService.saveLoginCredentials(phone, draft.newPassword);
      }

      dismissLoading();

      if (mounted) {
        showMessage(
          context,
          'Đổi mật khẩu thành công. Vui lòng đăng nhập lại!',
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) await widget.onLogout();
      }
    } on ApiException catch (error) {
      dismissLoading();
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      dismissLoading();
    }
  }

  Future<void> confirmLogout() async {
    final isEn = LanguageController.instance.isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151D31),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x337C83FD)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEn ? 'Log Out' : 'Đăng xuất',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  isEn
                      ? 'Are you sure you want to log out of NF Bank?'
                      : 'Bạn có chắc muốn đăng xuất khỏi NF Bank?',
                  style: const TextStyle(
                    color: Color(0xFF9BA8C7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          foregroundColor: const Color(0xFFB7C0D7),
                          side: const BorderSide(color: Color(0xFF36425D)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: Text(isEn ? 'Cancel' : 'Hủy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          backgroundColor: const Color(0xFF6D74F7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: Text(
                          isEn ? 'Log Out' : 'Đăng xuất',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) await widget.onLogout();
  }

  void _showLimitAdjustmentSheet() {
    int tempLimit = dailyTransferLimit;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isEn = LanguageController.instance.isEnglish;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF151D31)
                  : Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: const Border(top: BorderSide(color: Color(0x337C83FD))),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEn
                          ? 'Daily Transfer Limit'
                          : 'Hạn mức chuyển tiền ngày',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEn
                          ? 'Select maximum allowed transfer limit per day.'
                          : 'Chọn hạn mức giao dịch tối đa được phép chuyển khoản trong một ngày.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      money(tempLimit),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7C83FD),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: tempLimit.toDouble(),
                      min: 10000000,
                      max: 100000000,
                      divisions: 18,
                      activeColor: const Color(0xFF7C83FD),
                      onChanged: (val) {
                        setModalState(() {
                          tempLimit = val.toInt();
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '10tr',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .38),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '50tr',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .38),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '100tr',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .38),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        setState(() {
                          dailyTransferLimit = tempLimit;
                        });
                        await save();
                      },
                      child: Text(
                        isEn ? 'Confirm Changes' : 'Xác nhận thay đổi',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditProfileSheet() {
    final tempAddress = TextEditingController(text: address.text);
    final tempDate = TextEditingController(text: date.text);
    String tempGender = gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isEn = LanguageController.instance.isEnglish;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF151D31)
                    : Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: const Border(top: BorderSide(color: Color(0x337C83FD))),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isEn ? 'Edit Information' : 'Chỉnh sửa thông tin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: tempAddress,
                        decoration: fieldDecoration(
                          isEn ? 'Address' : 'Địa chỉ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tempGender.isEmpty ? null : tempGender,
                        decoration: fieldDecoration(
                          isEn ? 'Gender' : 'Giới tính',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'male',
                            child: Text(isEn ? 'Male' : 'Nam'),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text(isEn ? 'Female' : 'Nữ'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text(isEn ? 'Other' : 'Khác'),
                          ),
                        ],
                        onChanged: (value) =>
                            setModalState(() => tempGender = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tempDate,
                        readOnly: true,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        onTap: () async {
                          final isEn = LanguageController.instance.isEnglish;
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(tempDate.text) ??
                                DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            locale: isEn
                                ? const Locale('en', 'US')
                                : const Locale('vi', 'VN'),
                          );
                          if (selected != null) {
                            setModalState(() {
                              tempDate.text =
                                  selected.toString().split('T').first;
                            });
                          }
                        },
                        decoration: fieldDecoration(
                          isEn ? 'Date of birth' : 'Ngày sinh',
                          hint: isEn
                              ? 'Select date of birth'
                              : 'Chọn ngày sinh',
                        ).copyWith(
                          suffixIcon: const Icon(Icons.calendar_month_rounded),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() {
                            address.text = tempAddress.text;
                            date.text = tempDate.text;
                            gender = tempGender;
                          });
                          await save();
                        },
                        child: Text(
                          isEn ? 'Save Information' : 'Lưu thông tin',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageController.instance.isEnglish;
    return AsyncPage(
      loading: loading,
      error: error,
      onRetry: load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: showAvatarSource,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF7C83FD),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? const Icon(Icons.person, size: 46)
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D74F7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0F172A),
                              width: 2.5,
                            ),
                          ),
                          child: pickingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile['full_name']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile['phone'] ?? ''} · ${profile['role'] ?? ''}',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: showAvatarSource,
                  child: Text(
                    isEn ? 'Change avatar' : 'Đổi ảnh đại diện',
                    style: const TextStyle(
                      color: Color(0xFF9EA4FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsGroup(
            title: isEn ? 'Personal Information' : 'Thông tin cá nhân',
            children: [
              SettingsTile(
                icon: Icons.location_on_outlined,
                title: isEn ? 'Address' : 'Địa chỉ',
                subtitle: address.text.isEmpty
                    ? (isEn ? 'Not updated' : 'Chưa cập nhật')
                    : address.text,
                onTap: _showEditProfileSheet,
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Icons.face_outlined,
                title: isEn ? 'Gender' : 'Giới tính',
                subtitle: gender == 'male'
                    ? (isEn ? 'Male' : 'Nam')
                    : gender == 'female'
                    ? (isEn ? 'Female' : 'Nữ')
                    : gender == 'other'
                    ? (isEn ? 'Other' : 'Khác')
                    : (isEn ? 'Not updated' : 'Chưa cập nhật'),
                onTap: _showEditProfileSheet,
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Icons.cake_outlined,
                title: isEn ? 'Date of birth' : 'Ngày sinh',
                subtitle: date.text.isEmpty
                    ? (isEn ? 'Not updated' : 'Chưa cập nhật')
                    : date.text,
                onTap: _showEditProfileSheet,
              ),
            ],
          ),
          SettingsGroup(
            title: isEn ? 'Transaction Limit' : 'Hạn mức giao dịch',
            children: [
              SettingsTile(
                icon: Icons.speed_rounded,
                title: isEn
                    ? 'Daily transfer limit'
                    : 'Hạn mức chuyển tiền ngày',
                subtitle: isEn
                    ? 'Tap to adjust transfer limit'
                    : 'Chạm để điều chỉnh hạn mức chuyển tiền',
                trailing: Text(
                  money(dailyTransferLimit),
                  style: const TextStyle(
                    color: Color(0xFF9EA4FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                onTap: _showLimitAdjustmentSheet,
              ),
            ],
          ),
          SettingsGroup(
            title: isEn ? 'Security' : 'Bảo mật',
            children: [
              if (biometricSupported) ...[
                const Divider(height: 1, indent: 56),
                SettingsTile(
                  icon: Icons.fingerprint_rounded,
                  title: isEn
                      ? 'Biometric login'
                      : 'Đăng nhập bằng sinh trắc học',
                  subtitle: isEn
                      ? 'Quick unlock without password'
                      : 'Mở khoá nhanh không cần mật khẩu',
                  trailing: Switch(
                    value: biometricLoginEnabled,
                    activeColor: const Color(0xFF7C83FD),
                    onChanged: toggleBiometricLogin,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                SettingsTile(
                  icon: Icons.security_rounded,
                  title: isEn
                      ? 'Fingerprint transaction verification'
                      : 'Xác thực giao dịch bằng vân tay',
                  subtitle: isEn
                      ? 'Confirm without entering PIN'
                      : 'Xác nhận không cần nhập mã PIN',
                  trailing: Switch(
                    value: biometricTxEnabled,
                    activeColor: const Color(0xFF7C83FD),
                    onChanged: toggleBiometricTx,
                  ),
                ),
              ],
            ],
          ),
          SettingsGroup(
            title: isEn ? 'Settings & Account' : 'Tài khoản & Cài đặt',
            children: [
              SettingsTile(
                icon: Icons.language_rounded,
                title: isEn ? 'Language' : 'Ngôn ngữ',
                subtitle: isEn ? 'English 🇬🇧' : 'Tiếng Việt 🇻🇳',
                trailing: Text(
                  isEn ? '🇬🇧 EN' : '🇻🇳 VI',
                  style: const TextStyle(
                    color: Color(0xFF9EA4FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  LanguageController.instance.toggleLanguage();
                },
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: isEn ? 'Change password' : 'Đổi mật khẩu',
                subtitle: isEn
                    ? 'Change login password'
                    : 'Thay đổi mật khẩu đăng nhập',
                onTap: changePassword,
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Icons.logout_rounded,
                title: isEn ? 'Log out' : 'Đăng xuất',
                subtitle: isEn
                    ? 'Log out from this device'
                    : 'Đăng xuất khỏi thiết bị này',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFFF8A9B),
                ),
                onTap: confirmLogout,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

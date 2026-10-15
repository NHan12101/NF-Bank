import 'package:flutter/material.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';

class LoadingDialog extends StatelessWidget {
  const LoadingDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF151D31),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x337C83FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF7C83FD),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class PasswordPromptDialog extends StatefulWidget {
  const PasswordPromptDialog({super.key});

  @override
  State<PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<PasswordPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xác nhận mật khẩu'),
    content: Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vui lòng nhập mật khẩu tài khoản của bạn để lưu thông tin đăng nhập sinh trắc học.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            obscureText: true,
            decoration: fieldDecoration('Mật khẩu của bạn'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Xác nhận'),
      ),
    ],
  );
}

class PinPromptDialog extends StatefulWidget {
  const PinPromptDialog({super.key});

  @override
  State<PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends State<PinPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xác nhận mã PIN'),
    content: Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vui lòng nhập mã PIN giao dịch để kích hoạt sinh trắc học.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: fieldDecoration('Mã PIN').copyWith(counterText: ''),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Xác nhận'),
      ),
    ],
  );
}

class OTPVerifyDialog extends StatefulWidget {
  const OTPVerifyDialog({super.key, required this.phone});

  final String phone;

  @override
  State<OTPVerifyDialog> createState() => _OTPVerifyDialogState();
}

class _OTPVerifyDialogState extends State<OTPVerifyDialog> {
  final otp = TextEditingController();

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xác nhận OTP'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nhập mã gồm 6 số đã gửi tới ${maskPhone(widget.phone)}.',
              style: const TextStyle(color: Color(0xFF9BA8C7)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otp,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: fieldDecoration('Mã OTP').copyWith(
                counterText: '',
                prefixIcon: const Icon(Icons.sms_outlined),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!RegExp(r'^\d{6}$').hasMatch(otp.text.trim())) {
            showMessage(context, 'Mã OTP phải gồm đúng 6 số', error: true);
            return;
          }
          Navigator.pop(context, otp.text.trim());
        },
        child: const Text('Xác nhận'),
      ),
    ],
  );
}

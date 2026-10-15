import 'package:flutter/material.dart';

import '../../../../shared/widgets/common.dart';

class PasswordChangeDraft {
  const PasswordChangeDraft(this.oldPassword, this.newPassword);

  final String oldPassword;
  final String newPassword;
}

class PasswordChangeDialog extends StatefulWidget {
  const PasswordChangeDialog({super.key});

  @override
  State<PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<PasswordChangeDialog> {
  final old = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    old.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đổi mật khẩu'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: old,
              obscureText: _obscureOld,
              decoration: fieldDecoration('Mật khẩu hiện tại').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOld
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscureOld = !_obscureOld),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: _obscureNew,
              decoration: fieldDecoration('Mật khẩu mới').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: _obscureConfirm,
              decoration: fieldDecoration('Nhập lại mật khẩu mới').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sau bước này, mã OTP sẽ được gửi tới số điện thoại của bạn.',
              style: TextStyle(color: Color(0xFF9BA8C7), fontSize: 12),
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
          if (old.text.isEmpty) {
            showMessage(
              context,
              'Vui lòng nhập mật khẩu hiện tại',
              error: true,
            );
            return;
          }
          if (next.text.length < 8) {
            showMessage(
              context,
              'Mật khẩu mới phải có ít nhất 8 ký tự',
              error: true,
            );
            return;
          }
          if (next.text != confirm.text) {
            showMessage(context, 'Mật khẩu nhập lại không khớp', error: true);
            return;
          }
          Navigator.pop(context, PasswordChangeDraft(old.text, next.text));
        },
        child: const Text('Gửi mã OTP'),
      ),
    ],
  );
}

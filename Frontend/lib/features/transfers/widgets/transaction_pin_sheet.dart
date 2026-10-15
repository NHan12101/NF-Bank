import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/biometric_service.dart';

Future<TransactionPINInput?> showTransactionPINSheet(
  BuildContext context, {
  required bool createPIN,
  String actionLabel = 'chuyển tiền',
}) => showModalBottomSheet<TransactionPINInput>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  isDismissible: false,
  enableDrag: false,
  builder: (_) =>
      TransactionPINSheet(createPIN: createPIN, actionLabel: actionLabel),
);

class TransactionPINInput {
  const TransactionPINInput(this.pin, this.confirmPIN);

  final String pin;
  final String? confirmPIN;
}

class TransactionPINSheet extends StatefulWidget {
  const TransactionPINSheet({
    super.key,
    required this.createPIN,
    required this.actionLabel,
  });

  final bool createPIN;
  final String actionLabel;

  @override
  State<TransactionPINSheet> createState() => _TransactionPINSheetState();
}

class _TransactionPINSheetState extends State<TransactionPINSheet> {
  String _pin = '';
  String _confirmPIN = '';
  String? _error;
  int _step = 1;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    if (widget.createPIN) return;
    final supported = await BiometricService.isDeviceSupported();
    final enabled = await BiometricService.isTxEnabled();
    final pin = await BiometricService.getTransactionPin();
    if (mounted) {
      setState(() {
        _biometricEnabled = supported && enabled && pin != null;
      });
      if (_biometricEnabled) {
        Future.delayed(
          const Duration(milliseconds: 350),
          _authenticateBiometric,
        );
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    final savedPin = await BiometricService.getTransactionPin();
    if (savedPin == null) return;
    final authenticated = await BiometricService.authenticate(
      reason: 'Xác thực sinh trắc học để xác nhận giao dịch',
    );
    if (authenticated && mounted) {
      setState(() {
        _pin = savedPin;
      });
      _continue();
    }
  }

  bool get _isConfirmStep => widget.createPIN && _step == 2;
  String get _currentPIN => _isConfirmStep ? _confirmPIN : _pin;

  void _continue() {
    final error = validatePIN(
      _currentPIN,
      rejectWeak: widget.createPIN && _step == 1,
    );
    if (error != null) {
      setState(() => _error = error);
      HapticFeedback.mediumImpact();
      return;
    }
    if (widget.createPIN && _step == 1) {
      setState(() {
        _step = 2;
        _error = null;
      });
      return;
    }
    if (_isConfirmStep && _confirmPIN != _pin) {
      setState(() => _error = 'Hai mã PIN chưa trùng khớp');
      HapticFeedback.mediumImpact();
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.pop(
      context,
      TransactionPINInput(_pin, widget.createPIN ? _confirmPIN : null),
    );
  }

  void _typeDigit(String digit) {
    if (_currentPIN.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_isConfirmStep) {
        _confirmPIN += digit;
      } else {
        _pin += digit;
      }
      _error = null;
    });
  }

  void _deleteDigit() {
    if (_currentPIN.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_isConfirmStep) {
        _confirmPIN = _confirmPIN.substring(0, _confirmPIN.length - 1);
      } else {
        _pin = _pin.substring(0, _pin.length - 1);
      }
      _error = null;
    });
  }

  void _backToFirstStep() {
    setState(() {
      _step = 1;
      _confirmPIN = '';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF151D31)
          : Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: const Border(top: BorderSide(color: Color(0x33562875))),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 7),
                _header(),
                const SizedBox(height: 7),
                if (widget.createPIN) _stepIndicator(),
                const SizedBox(height: 13),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(_step),
                    children: [
                      Text(
                        _isConfirmStep
                            ? 'Nhập lại mã PIN vừa tạo'
                            : widget.createPIN
                            ? 'Tạo mã PIN giao dịch'
                            : 'Xác thực giao dịch',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _isConfirmStep
                            ? 'Hai mã PIN phải hoàn toàn giống nhau.'
                            : widget.createPIN
                            ? 'Nhập 4 số bảo mật để bảo vệ mọi giao dịch.'
                            : 'Vui lòng nhập mã PIN Smart OTP 4 số để xác nhận ${widget.actionLabel}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9BA8C7),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _pinDots(),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 28,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: _error == null
                          ? const SizedBox.shrink()
                          : Text(
                              _error!,
                              key: ValueKey(_error),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFF8A9B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
                _keypad(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: const Color(0xFF6D74F7),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF29334C),
                      disabledForegroundColor: const Color(0xFF77839E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _currentPIN.length == 4 ? _continue : null,
                    child: Text(
                      widget.createPIN && _step == 1
                          ? 'Tiếp tục'
                          : widget.createPIN
                          ? 'Tạo PIN và ${widget.actionLabel}'
                          : 'Xác nhận ${widget.actionLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Stack(
    alignment: Alignment.center,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_isConfirmStep)
            IconButton(
              onPressed: _backToFirstStep,
              color: const Color(0xFF9EA4FF),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 48),
          IconButton(
            onPressed: () => Navigator.pop(context),
            color: const Color(0xFF9BA8C7),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      IgnorePointer(
        child: Text(
          widget.createPIN ? 'Thiết lập PIN' : 'Xác thực PIN',
          style: const TextStyle(
            color: Color(0xFF9EA4FF),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );

  Widget _stepIndicator() => Row(
    children: [
      const Expanded(child: StepPill(active: true, label: '1  Tạo PIN')),
      const SizedBox(width: 8),
      Expanded(
        child: StepPill(active: _step == 2, label: '2  Xác nhận'),
      ),
    ],
  );

  Widget _pinDots() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(4, (index) {
      final filled = index < _currentPIN.length;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: filled
              ? const Color(0xFF7C83FD).withValues(alpha: 0.12)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            width: 1.7,
            color: filled ? const Color(0xFF9EA4FF) : const Color(0xFF4A5874),
          ),
        ),
        child: Center(
          child: AnimatedScale(
            scale: filled ? 1 : 0,
            duration: const Duration(milliseconds: 140),
            child: Container(
              width: 23,
              height: 23,
              decoration: const BoxDecoration(
                color: Color(0xFF7C83FD),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }),
  );

  Widget _keypad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [_biometricEnabled ? 'biometrics' : '', '0', 'delete'],
    ];
    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: key.isEmpty
                        ? const SizedBox(height: 46)
                        : KeypadButton(
                            label: (key == 'delete' || key == 'biometrics')
                                ? null
                                : key,
                            icon: key == 'delete'
                                ? Icons.backspace_outlined
                                : key == 'biometrics'
                                    ? Icons.fingerprint_rounded
                                    : null,
                            onTap: key == 'delete'
                                ? _deleteDigit
                                : key == 'biometrics'
                                    ? _authenticateBiometric
                                    : () => _typeDigit(key),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class StepPill extends StatelessWidget {
  const StepPill({super.key, required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: active
          ? const Color(0xFF7C83FD).withValues(alpha: 0.14)
          : const Color(0xFF1D2740),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: active ? const Color(0xFF7C83FD) : const Color(0xFF303C59),
      ),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: active ? const Color(0xFFB7BBFF) : const Color(0xFF77839E),
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  );
}

class KeypadButton extends StatelessWidget {
  const KeypadButton({super.key, required this.onTap, this.label, this.icon});

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF202A43),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: const Color(0x337C83FD),
      child: SizedBox(
        height: 46,
        child: Center(
          child: icon != null
              ? Icon(icon, size: 20, color: const Color(0xFF9BA8C7))
              : Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    ),
  );
}

String? validatePIN(String? value, {required bool rejectWeak}) {
  final pin = value ?? '';
  if (!RegExp(r'^[0-9]{4,6}$').hasMatch(pin)) {
    return 'PIN phải gồm từ 4 đến 6 chữ số';
  }
  if (!rejectWeak) return null;
  const weakPINs = {
    '0000',
    '1111',
    '2222',
    '3333',
    '4444',
    '5555',
    '6666',
    '7777',
    '8888',
    '9999',
    '0123',
    '1234',
    '2345',
    '3456',
    '4567',
    '5678',
    '6789',
    '9876',
    '8765',
    '7654',
    '6543',
    '5432',
    '4321',
    '3210',
    '000000',
    '111111',
    '222222',
    '333333',
    '444444',
    '555555',
    '666666',
    '777777',
    '888888',
    '999999',
    '012345',
    '123456',
    '234567',
    '345678',
    '456789',
    '987654',
    '876543',
    '765432',
    '654321',
  };
  return weakPINs.contains(pin) ? 'PIN quá dễ đoán, hãy chọn mã khác' : null;
}

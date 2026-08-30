import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_widgets.dart';

class OtpInputWidget extends StatefulWidget {
  const OtpInputWidget({
    super.key,
    required this.length,
    required this.onCompleted,
    this.onChanged,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpInputWidget> createState() => OtpInputWidgetState();
}

class OtpInputWidgetState extends State<OtpInputWidget> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) setState(() {});
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
  }

  String get otp => _controllers.map((c) => c.text.trim()).join();

  void _handlePaste(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    for (int i = 0; i < widget.length; i++) {
      if (i < digits.length) {
        _controllers[i].text = digits[i];
      } else {
        _controllers[i].clear();
      }
    }

    final targetFocus = (digits.length >= widget.length ? widget.length - 1 : digits.length).clamp(0, widget.length - 1);
    _focusNodes[targetFocus].requestFocus();

    final currentOtp = otp;
    widget.onChanged?.call(currentOtp);
    if (currentOtp.length == widget.length) {
      widget.onCompleted(currentOtp);
    }
    setState(() {});
  }

  void _onChanged(String value, int index) {
    final cleanDigits = value.replaceAll(RegExp(r'[^0-9]'), '');

    // 1. Full paste or multi-digit input
    if (cleanDigits.length >= widget.length) {
      _handlePaste(cleanDigits);
      return;
    }

    // 2. Single box typing or replacement
    if (cleanDigits.isNotEmpty) {
      final newChar = cleanDigits[cleanDigits.length - 1];
      _controllers[index].text = newChar;
      _controllers[index].selection = const TextSelection.collapsed(offset: 1);

      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    } else {
      _controllers[index].clear();
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }

    final currentOtp = otp;
    widget.onChanged?.call(currentOtp);
    if (currentOtp.length == widget.length) {
      widget.onCompleted(currentOtp);
    }
    setState(() {});
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      final currentOtp = otp;
      widget.onChanged?.call(currentOtp);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        const spacing = 6.0;
        final boxW = ((maxW - spacing * (widget.length - 1)) / widget.length).clamp(36.0, 48.0);
        final boxH = (boxW * 1.18).clamp(48.0, 56.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            final hasValue = _controllers[index].text.isNotEmpty;
            final isFocused = _focusNodes[index].hasFocus;
            return Container(
              width: boxW,
              height: boxH,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : spacing / 2,
                right: index == widget.length - 1 ? 0 : spacing / 2,
              ),
              decoration: BoxDecoration(
                color: hasValue ? const Color(0xFFFCEBEB) : kAuthCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused
                      ? kAuthRed
                      : hasValue
                          ? kAuthRed.withValues(alpha: 0.5)
                          : kAuthBorder,
                  width: isFocused ? 1.6 : 1.2,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: kAuthRed.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: KeyboardListener(
                focusNode: FocusNode(skipTraversal: true),
                onKeyEvent: (event) => _onKeyEvent(event, index),
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6, // allow paste
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: kAuthText,
                    letterSpacing: 0,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                  cursorColor: kAuthRed,
                  onChanged: (v) => _onChanged(v, index),
                  onTap: () {
                    _controllers[index].selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _controllers[index].text.length,
                    );
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

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
    _focusNodes.first.requestFocus();
  }

  String get otp => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    // Handle paste of full OTP
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
      for (int i = 0; i < widget.length; i++) {
        if (i < digits.length) {
          _controllers[i].text = digits[i];
        } else if (i == index) {
          _controllers[i].clear();
        }
      }
      // Move focus to last filled or next
      final next = (index + digits.length).clamp(0, widget.length - 1);
      _focusNodes[next].requestFocus();
      if (digits.length >= widget.length - index) {
        // Try to unfocus last
        _focusNodes[widget.length - 1].unfocus();
      }
    } else {
      if (value.isNotEmpty && index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else if (value.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    final newOtp = otp;
    widget.onChanged?.call(newOtp);
    if (newOtp.length == widget.length && !newOtp.contains(RegExp(r'[^0-9]'))) {
      widget.onCompleted(newOtp);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: fit 6 boxes within available width (AuthCard inner ~302px)
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        const spacing = 6.0;
        final boxW = ((maxW - spacing * (6 - 1)) / 6).clamp(36.0, 48.0);
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
              // Select all on tap for easy replace
              _controllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controllers[index].text.length,
              );
            },
          ),
        );
          }),
        );
      },
    );
  }
}

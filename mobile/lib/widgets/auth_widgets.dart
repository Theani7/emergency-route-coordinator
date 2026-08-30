import 'dart:ui';

import '../widgets/skeleton_widgets.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kAuthBg = Color(0xFFF7F7F5);
final Color kAuthCard =
    kIsWeb ? const Color(0xBDFFFFFF) : const Color(0x8CFFFFFF);
const kAuthBorder = Color(0xFFD3D1C7);
const kAuthText = Color(0xFF1A1A18);
const kAuthMuted = Color(0xFF5F5E5A);
const kAuthFaint = Color(0xFF8A8880);
const kAuthIcon = Color(0xFFB4B2A9);
const kAuthRed = Color(0xFFE24B4A);
const kAuthRedDark = Color(0xFFC93B3A);
const kAuthRedPressed = Color(0xFFB2322F);
const kAuthRedBadgeText = Color(0xFF791F1F);
const kAuthRedBadgeBg = Color(0xFFFCEBEB);
const kAuthRedLink = Color(0xFFA32D2D);

const kGlassBorder = Color(0xB8FFFFFF);
const kGlassOverlay = Color(0x66FFFFFF);

final Color kGlassTint =
    kIsWeb ? const Color(0xF2FFFFFF) : const Color(0xE6FFFFFF);

const double kGlassBlur = 60.0;

const kAuthBlue = Color(0xFF2E6FD8);
const kAuthBlueTint = Color(0xFFEAF1FC);
const kAuthGreen = Color(0xFF2F9E63);
const kAuthGreenText = Color(0xFF1F7A44);
const kAuthGreenBg = Color(0xFFE8F5EC);
const kAuthOrange = Color(0xFFE8833A);
const kAuthOrangeTint = Color(0xFFFDF1E7);
const kAuthNeutralTint = Color(0xFFF2F1ED);
const kAuthInk = Color(0xFF1D1D1B);

const kCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x1A1A1A18),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
  BoxShadow(
    color: Color(0x0D1A1A18),
    blurRadius: 3,
    offset: Offset(0, 1),
  ),
];

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 16,
    this.blur,
    this.padding,
    this.tint,
    this.borderColor = kGlassBorder,
    this.shadows = kCardShadow,
  });

  final Widget child;
  final double radius;
  final double? blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final Color borderColor;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final sigma = blur ?? kGlassBlur;
    final fill = tint ?? kGlassTint;
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: child,
    );
    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: panel,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: panel,
      ),
    );
  }
}

class FrostedAppBarBackdrop extends StatelessWidget {
  const FrostedAppBarBackdrop({super.key, this.blur});

  final double? blur;

  @override
  Widget build(BuildContext context) {
    final tint = Container(color: kGlassTint);
    if (kIsWeb) return tint;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur ?? kGlassBlur,
          sigmaY: blur ?? kGlassBlur,
        ),
        child: tint,
      ),
    );
  }
}

class FrostedBar extends StatelessWidget {
  const FrostedBar({super.key, required this.child, this.blur, this.borderRadius});

  final Widget child;
  final double? blur;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final tint = Container(
      decoration: BoxDecoration(
        color: kGlassTint,
        borderRadius: borderRadius,
      ),
      child: child,
    );
    if (kIsWeb) return tint;
    
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur ?? kGlassBlur,
          sigmaY: blur ?? kGlassBlur,
        ),
        child: tint,
      ),
    );
  }
}

class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: kAuthBg,
      child: child,
    );
  }
}

class AuthBadge extends StatelessWidget {
  const AuthBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kAuthRedBadgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kAuthRed,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'EMERGENCY RESPONSE NETWORK',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.88,
                color: kAuthRedBadgeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthEmblem extends StatelessWidget {
  const AuthEmblem({super.key, this.icon = Icons.medical_services_rounded});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: kAuthRed,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 40, color: Colors.white),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 18,
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class AuthEmptyState extends StatelessWidget {
  const AuthEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: kAuthRedBadgeBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 28, color: kAuthRedLink),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kAuthText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: text.copyWith(
                fontSize: 13,
                height: 1.4,
                color: kAuthMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.onToggleObscure,
    this.helper,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? helper;
  final String? Function(String?) validator;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();
  bool _eyeHover = false;
  bool _eyePressed = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    final focused = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: text.copyWith(fontSize: 13, color: kAuthMuted),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: kAuthCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused ? kAuthRed : kAuthBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 12),
              Icon(
                widget.icon,
                size: 18,
                color: kAuthIcon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  validator: widget.validator,
                  style: text.copyWith(fontSize: 15, color: kAuthText),
                  cursorColor: kAuthRed,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    errorStyle: text.copyWith(
                      fontSize: 12,
                      color: kAuthRedDark,
                    ),
                    errorMaxLines: 2,
                  ),
                ),
              ),
              if (widget.onToggleObscure != null) ...[
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _eyeHover = true),
                  onExit: (_) => setState(() => _eyeHover = false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _eyePressed = true),
                    onTapUp: (_) {
                      setState(() => _eyePressed = false);
                      widget.onToggleObscure!();
                    },
                    onTapCancel: () => setState(() => _eyePressed = false),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                        widget.obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 18,
                        color:
                            _eyeHover || _eyePressed ? kAuthMuted : kAuthIcon,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ],
          ),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              widget.helper!,
              style: text.copyWith(fontSize: 11.5, color: kAuthFaint),
            ),
          ),
        ],
      ],
    );
  }
}

class AuthDropdownField extends StatefulWidget {
  const AuthDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  State<AuthDropdownField> createState() => _AuthDropdownFieldState();
}

class _AuthDropdownFieldState extends State<AuthDropdownField> {
  final _focus = FocusNode();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    final focused = _focus.hasFocus || _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: text.copyWith(fontSize: 13, color: kAuthMuted),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: kAuthCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused ? kAuthRed : kAuthBorder,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              focusNode: _focus,
              initialValue: widget.value,
              isExpanded: true,
              onChanged: (v) {
                setState(() => _open = false);
                widget.onChanged(v);
              },
              dropdownColor: kAuthCard,
              borderRadius: BorderRadius.circular(10),
              elevation: 2,
              style: text.copyWith(fontSize: 15, color: kAuthText),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: kAuthIcon,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(left: 12, right: 8),
              ),
              items: widget.items,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kAuthRedBadgeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAuthRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 17, color: kAuthRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: text.copyWith(
                fontSize: 12.5,
                color: kAuthRedBadgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color:
                _pressed ? kAuthRedPressed : (_hover ? kAuthRedDark : kAuthRed),
          ),
          child: ElevatedButton(
            onPressed: widget.loading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: widget.loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: SkeletonLoadingIndicator(size: 18),
                  )
                : Text(
                    widget.label,
                    style: text.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.01,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: text.copyWith(fontSize: 13.5, color: kAuthMuted),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: kAuthRedLink,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: text.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

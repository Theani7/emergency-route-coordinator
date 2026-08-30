import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email, required this.otp});

  final String email;
  final String otp;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final auth = AuthService(api);
      await auth.resetPassword(widget.email, widget.otp, _newPassCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset successful! Please login.', style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: kAuthGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // Pop to login
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      String msg = 'Reset failed. Try again.';
      try {
        final dioErr = e as dynamic;
        final data = dioErr.response?.data;
        if (data is Map && data['detail'] != null) msg = data['detail'].toString();
      } catch (_) {}
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kAuthText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Password', style: text.copyWith(fontWeight: FontWeight.w600, color: kAuthText)),
        centerTitle: true,
      ),
      body: GlassBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: kAuthGreenBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.verified_user_outlined, size: 32, color: kAuthGreenText),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Create new password',
                        style: text.copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: kAuthText),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'OTP verified for ${widget.email}. Choose a strong 8+ character password.',
                        style: text.copyWith(fontSize: 13.5, color: kAuthMuted, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      AuthCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthField(
                              controller: _newPassCtrl,
                              label: 'New Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure1,
                              onToggleObscure: () => setState(() => _obscure1 = !_obscure1),
                              validator: (v) {
                                if (v == null || v.length < 8) return 'At least 8 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            AuthField(
                              controller: _confirmCtrl,
                              label: 'Confirm Password',
                              icon: Icons.lock_reset_rounded,
                              obscure: _obscure2,
                              onToggleObscure: () => setState(() => _obscure2 = !_obscure2),
                              validator: (v) {
                                if (v != _newPassCtrl.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              AuthErrorBanner(message: _error!),
                            ],
                            const SizedBox(height: 24),
                            AuthPrimaryButton(
                              loading: _loading,
                              label: 'Reset Password',
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kAuthNeutralTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kAuthBorder.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 18, color: kAuthMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Password must be 8+ chars. You will be logged out of all devices.',
                                style: text.copyWith(fontSize: 12, color: kAuthMuted, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

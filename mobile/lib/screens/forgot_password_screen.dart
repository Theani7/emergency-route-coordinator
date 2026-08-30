import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/auth_widgets.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  String? _successDetail;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _successDetail = null;
    });
    try {
      final api = context.read<ApiService>();
      final authService = AuthService(api);
      await authService.forgotPassword(_emailCtrl.text.trim());
      if (!mounted) return;
      // Show OTP hint in dev mode if returned
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(email: _emailCtrl.text.trim()),
        ),
      );
    } catch (e) {
      String msg = 'Failed to send OTP. Try again.';
      if (e.toString().contains('429')) {
        msg = 'Please wait before requesting again.';
      }
      // Try to extract detail from DioException
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
        title: Text('Forgot Password', style: text.copyWith(fontWeight: FontWeight.w600, color: kAuthText)),
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
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: kAuthRedBadgeBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 32, color: kAuthRed),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Reset your password',
                        style: text.copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: kAuthText),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email and we\'ll send a 6-digit OTP to reset your password.',
                        style: text.copyWith(fontSize: 13.5, color: kAuthMuted, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      AuthCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthField(
                              controller: _emailCtrl,
                              label: 'Email',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Email required';
                                if (!v.contains('@')) return 'Enter valid email';
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              AuthErrorBanner(message: _error!),
                            ],
                            if (_successDetail != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kAuthGreenBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: kAuthGreen.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: kAuthGreenText),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_successDetail!, style: text.copyWith(fontSize: 12, color: kAuthGreenText))),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            AuthPrimaryButton(
                              loading: _loading,
                              label: 'Send OTP',
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'OTP expires in 10 minutes • Check spam folder',
                              textAlign: TextAlign.center,
                              style: text.copyWith(fontSize: 11.5, color: kAuthFaint),
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

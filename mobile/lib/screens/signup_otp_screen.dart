import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/otp_input_widget.dart';

class SignupOtpScreen extends StatefulWidget {
  const SignupOtpScreen({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.vehicleNumber,
    this.assignedZone,
  });

  final String name;
  final String email;
  final String password;
  final String role;
  final String? vehicleNumber;
  final String? assignedZone;

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen> {
  final _otpKey = GlobalKey<OtpInputWidgetState>();
  String _otp = '';
  bool _loading = false;
  bool _verifying = false;
  String? _error;
  bool _canResend = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _canResend = false;
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verifyAndRegister() async {
    if (_otp.length != 6) {
      setState(() => _error = 'Enter 6-digit OTP');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final authService = AuthService(api);
      // Verify OTP first
      await authService.verifySignupOtp(email: widget.email, otp: _otp);
      // Then register with OTP
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.register(
        name: widget.name,
        email: widget.email,
        password: widget.password,
        role: widget.role,
        vehicleNumber: widget.vehicleNumber,
        assignedZone: widget.assignedZone,
        otp: _otp,
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created! Welcome ${widget.name}', style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: kAuthGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Pop to login (auth will auto-navigate via GoRouter)
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        // authProvider.error contains detail
        setState(() => _error = context.read<AuthProvider>().error ?? 'Registration failed');
      }
    } catch (e) {
      String msg = 'Invalid OTP. Try again.';
      try {
        final dioErr = e as dynamic;
        final data = dioErr.response?.data;
        if (data is Map && data['detail'] != null) msg = data['detail'].toString();
      } catch (_) {}
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final auth = AuthService(api);
      await auth.sendSignupOtp(email: widget.email, name: widget.name);
      _otpKey.currentState?.clear();
      setState(() => _otp = '');
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP resent to ${widget.email}', style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: kAuthText,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      String msg = 'Failed to resend. Wait 60s.';
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
        title: Text('Verify Email', style: text.copyWith(fontWeight: FontWeight.w600, color: kAuthText)),
        centerTitle: true,
      ),
      body: GlassBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(color: kAuthBlueTint, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.mark_email_read_outlined, size: 32, color: kAuthBlue),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Verify your email', textAlign: TextAlign.center, style: text.copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: kAuthText)),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: text.copyWith(fontSize: 13.5, color: kAuthMuted, height: 1.5),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit code to\n'),
                          TextSpan(text: widget.email, style: text.copyWith(fontWeight: FontWeight.w600, color: kAuthText)),
                          TextSpan(text: '\nEnter it to complete registration as ${widget.role}.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    AuthCard(
                      child: Column(
                        children: [
                          Text('Enter OTP', style: text.copyWith(fontSize: 13, color: kAuthMuted)),
                          const SizedBox(height: 14),
                          OtpInputWidget(
                            key: _otpKey,
                            length: 6,
                            onChanged: (v) => setState(() => _otp = v),
                            onCompleted: (v) {
                              setState(() => _otp = v);
                              _verifyAndRegister();
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            AuthErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: 24),
                          AuthPrimaryButton(
                            loading: _verifying,
                            label: 'Verify & Create Account',
                            onPressed: _verifyAndRegister,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Didn't receive code? ", style: text.copyWith(fontSize: 13, color: kAuthMuted)),
                              _canResend
                                  ? TextButton(
                                      onPressed: _loading ? null : _resend,
                                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                      child: Text('Resend', style: text.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: kAuthBlue)),
                                    )
                                  : Text('Resend in ${_secondsLeft}s', style: text.copyWith(fontSize: 13, color: kAuthFaint)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('OTP expires in 10 minutes • 5 attempts max', style: text.copyWith(fontSize: 11.5, color: kAuthFaint)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text('Edit details', style: text.copyWith(fontSize: 13)),
                      style: TextButton.styleFrom(foregroundColor: kAuthMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

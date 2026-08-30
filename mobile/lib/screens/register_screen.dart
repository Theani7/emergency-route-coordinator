import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/server_config_service.dart';
import '../widgets/auth_widgets.dart';
import 'signup_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  final _serverConfig = ServerConfigService();
  String _role = 'driver';
  String? _serverUrl;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final url = await _serverConfig.getApiBaseUrl();
    if (!mounted) return;
    setState(() {
      _serverUrl = url.contains('10.0.2.2') ? '' : url;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    // First send signup OTP
    try {
      final api = context.read<ApiService>();
      final authService = AuthService(api);
      if (_serverUrl != null && _serverUrl!.isNotEmpty) {
        final auth = context.read<AuthProvider>();
        await auth.configureServer(_serverUrl!);
      }
      // Show loading via dialog? Use provider loading not needed - use local
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sending OTP to $email...'), backgroundColor: kAuthText, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
      await authService.sendSignupOtp(email: email, name: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignupOtpScreen(
            name: name,
            email: email,
            password: _passCtrl.text,
            role: _role,
            vehicleNumber: _role == 'driver' ? _vehicleCtrl.text.trim() : null,
            assignedZone: _role == 'officer' ? _zoneCtrl.text.trim() : null,
          ),
        ),
      );
    } catch (e) {
      String msg = 'Failed to send OTP. Try again.';
      try {
        final dioErr = e as dynamic;
        final data = dioErr.response?.data;
        if (data is Map && data['detail'] != null) msg = data['detail'].toString();
        else if (data is String) msg = data;
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kAuthRed, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        );
        context.read<AuthProvider>().setError(msg);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _vehicleCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final text = GoogleFonts.inter();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              hoverColor: kAuthBorder.withValues(alpha: 0.4),
                              foregroundColor: kAuthMuted,
                            ),
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              size: 22,
                              color: kAuthMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Register',
                            style: text.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: kAuthText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: AuthEmblem(icon: Icons.person_add_alt_1_rounded),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: text.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.24,
                          color: kAuthText,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Register as Driver or Traffic Officer',
                        textAlign: TextAlign.center,
                        style: text.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: kAuthMuted,
                        ),
                      ),
                      const SizedBox(height: 32),
                      AuthCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthField(
                              controller: _nameCtrl,
                              label: 'Full Name',
                              icon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().length < 2
                                  ? 'Name required (min 2 chars)'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AuthField(
                              controller: _emailCtrl,
                              label: 'Email',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                                  v == null || v.isEmpty || !v.contains('@')
                                      ? 'Valid email required'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            AuthField(
                              controller: _passCtrl,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePass,
                              onToggleObscure: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                              helper: 'Min 8 characters',
                              validator: (v) => v == null || v.length < 8
                                  ? 'Password must be at least 8 characters'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AuthField(
                              controller: _confirmCtrl,
                              label: 'Confirm Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscureConfirm,
                              onToggleObscure: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                              validator: (v) => v != _passCtrl.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AuthDropdownField(
                              label: 'Role',
                              icon: Icons.badge_outlined,
                              value: _role,
                              items: const [
                                DropdownMenuItem(
                                  value: 'driver',
                                  child: Text('Driver'),
                                ),
                                DropdownMenuItem(
                                  value: 'officer',
                                  child: Text('Traffic Officer'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _role = v ?? 'driver'),
                            ),
                            if (_role == 'driver') ...[
                              const SizedBox(height: 16),
                              AuthField(
                                controller: _vehicleCtrl,
                                label: 'Vehicle Number',
                                icon: Icons.local_shipping_outlined,
                                helper: 'e.g. BA 1 KHA 1234',
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Vehicle number required for drivers'
                                    : null,
                              ),
                            ],
                            if (_role == 'officer') ...[
                              const SizedBox(height: 16),
                              AuthField(
                                controller: _zoneCtrl,
                                label: 'Assigned Zone',
                                icon: Icons.map_outlined,
                                helper: 'e.g. New Baneshwor',
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Assigned zone required for officers'
                                    : null,
                              ),
                            ],
                            if (auth.error != null) ...[
                              const SizedBox(height: 16),
                              AuthErrorBanner(message: auth.error!),
                            ],
                            const SizedBox(height: 24),
                            AuthPrimaryButton(
                              loading: auth.loading,
                              label: 'Register',
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthFooterLink(
                        question: 'Already have an account? ',
                        action: 'Sign In',
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 12),
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

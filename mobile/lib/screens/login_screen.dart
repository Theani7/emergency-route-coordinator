import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/firebase_auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'register_screen.dart';

import '../services/server_config_service.dart';
import 'forgot_password_screen.dart';
import 'registration_pending_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _serverConfig = ServerConfigService();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showServerDialog() async {
    final currentUrl = await _serverConfig.getApiBaseUrl();
    if (!mounted) return;
    final ctrl = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Server Configuration',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backend API URL:',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[300]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'https://...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            Text('Presets:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Live Cloud (Render)', style: TextStyle(fontSize: 11)),
                  onPressed: () => ctrl.text = 'https://sajiloroute-api.onrender.com',
                ),
                ActionChip(
                  label: const Text('Localhost (PC)', style: TextStyle(fontSize: 11)),
                  onPressed: () => ctrl.text = 'http://localhost:8000',
                ),
                ActionChip(
                  label: const Text('Android VM (10.0.2.2)', style: TextStyle(fontSize: 11)),
                  onPressed: () => ctrl.text = 'http://10.0.2.2:8000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isNotEmpty && mounted) {
                final auth = context.read<AuthProvider>();
                await auth.configureServer(url);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save & Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showApprovalStatusDialog({
    required BuildContext context,
    required bool isPending,
    required String email,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          isPending ? Icons.hourglass_top_rounded : Icons.cancel_outlined,
          color: isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
          size: 40,
        ),
        title: Text(
          isPending ? 'Account Pending Approval' : 'Registration Rejected',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        content: Text(
          isPending
              ? 'Your account is currently pending administrator approval. Please wait for confirmation before logging in.'
              : 'Your registration request was rejected by an administrator.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFFCBD5E1),
            height: 1.4,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (isPending) ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Dismiss',
                style: GoogleFonts.inter(color: Colors.grey[400]),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegistrationPendingScreen(
                      name: '',
                      email: email,
                      role: '',
                    ),
                  ),
                );
              },
              child: Text(
                'View Status',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ] else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AuthBadge(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.dns_outlined, size: 20, color: kAuthMuted),
                            tooltip: 'Server Settings',
                            visualDensity: VisualDensity.compact,
                            onPressed: _showServerDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Center(child: AuthEmblem()),
                      const SizedBox(height: 24),
                      Text(
                        'Ambulance coordination',
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
                        'Driver & Traffic Officer Portal',
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
                              controller: _emailCtrl,
                              label: 'Email',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Email required'
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
                              validator: (v) => v == null || v.length < 6
                                  ? 'Password required'
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(top: 8, left: 8, right: 0),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: kAuthRedLink,
                                  ),
                                ),
                              ),
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 16),
                              AuthErrorBanner(message: auth.error!),
                            ],
                            const SizedBox(height: 24),
                            AuthPrimaryButton(
                              loading: auth.loading,
                              label: 'Sign In',
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }
                                final email = _emailCtrl.text.trim();
                                final success = await auth.login(
                                  email,
                                  _passCtrl.text,
                                );
                                if (!success && mounted) {
                                  final err = (auth.error ?? '').toLowerCase();
                                  if (err.contains('pending') || err.contains('approval')) {
                                    _showApprovalStatusDialog(
                                      context: context,
                                      isPending: true,
                                      email: email,
                                    );
                                  } else if (err.contains('rejected')) {
                                    _showApprovalStatusDialog(
                                      context: context,
                                      isPending: false,
                                      email: email,
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Expanded(child: Divider(color: kAuthBorder, thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('or', style: text.copyWith(fontSize: 12, color: kAuthMuted)),
                                ),
                                const Expanded(child: Divider(color: kAuthBorder, thickness: 1)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _GoogleSignInButton(
                              onPressed: () async {
                                final fbAuth = FirebaseAuthService();
                                try {
                                  final cred = await fbAuth.signInWithGoogle();
                                  if (cred != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Welcome ${cred.user?.displayName ?? cred.user?.email}', style: GoogleFonts.inter(fontSize: 13)),
                                        backgroundColor: kAuthText,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                    // Navigate based on Firestore role or default to driver
                                    // For now, go to driver home; Firestore doc will store role
                                    if (context.mounted) {
                                      // Use GoRouter if available, else push
                                      // AuthProvider will handle custom backend; Firebase user is separate
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Google sign-in failed: $e'), backgroundColor: kAuthRed),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthFooterLink(
                        question: "Don't have an account? ",
                        action: 'Register',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
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

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Image.asset('assets/google-icon.png', width: 20, height: 20),
      label: Text('Continue with Google', style: text.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: kAuthText)),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: kAuthText,
        side: const BorderSide(color: kAuthBorder),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

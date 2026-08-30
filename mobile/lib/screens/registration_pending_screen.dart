import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class RegistrationPendingScreen extends StatelessWidget {
  const RegistrationPendingScreen({
    super.key,
    this.name = '',
    this.email = '',
    this.role = '',
  });

  final String name;
  final String email;
  final String role;

  String get _formattedRole {
    final r = role.trim().toLowerCase();
    if (r == 'driver') return 'Ambulance Driver';
    if (r == 'officer') return 'Traffic Officer';
    if (r == 'admin') return 'System Administrator';
    if (role.trim().isNotEmpty) {
      return role[0].toUpperCase() + role.substring(1);
    }
    return 'Registered User';
  }

  IconData get _roleIcon {
    final r = role.trim().toLowerCase();
    if (r == 'driver') return Icons.emergency_rounded;
    if (r == 'officer') return Icons.traffic_rounded;
    return Icons.badge_outlined;
  }

  void _backToSignIn(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
          onPressed: () => _backToSignIn(context),
        ),
        title: Text(
          'Approval Status',
          style: text.copyWith(fontWeight: FontWeight.w600, color: kAuthText),
        ),
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

                    // Icon badge with amber tint
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: kAuthOrangeTint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          size: 32,
                          color: kAuthOrange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pill status badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: kAuthOrangeTint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: kAuthOrange.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: kAuthOrange,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PENDING APPROVAL',
                              style: text.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: kAuthOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      'Registration Submitted',
                      textAlign: TextAlign.center,
                      style: text.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: kAuthText,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Your account has been registered and is pending administrator confirmation. Once approved, you can sign in immediately.',
                      textAlign: TextAlign.center,
                      style: text.copyWith(
                        fontSize: 13.5,
                        color: kAuthMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // AuthCard with application details
                    AuthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.assignment_turned_in_outlined,
                                size: 16,
                                color: kAuthMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'APPLICATION DETAILS',
                                style: text.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: kAuthMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: kAuthBorder, height: 1),
                          const SizedBox(height: 14),

                          // Name Row
                          if (name.trim().isNotEmpty) ...[
                            _buildDetailRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Full Name',
                              value: name.trim(),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Email Row
                          if (email.trim().isNotEmpty) ...[
                            _buildDetailRow(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email Address',
                              value: email.trim(),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Role Row
                          _buildDetailRow(
                            icon: _roleIcon,
                            label: 'Requested Role',
                            value: _formattedRole,
                            valueBadge: true,
                          ),
                          const SizedBox(height: 12),

                          // Status Row
                          _buildDetailRow(
                            icon: Icons.timer_outlined,
                            label: 'Account Status',
                            value: 'Pending Review',
                            statusColor: kAuthOrange,
                          ),
                          const SizedBox(height: 18),

                          // Information Note Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kAuthNeutralTint,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: kAuthBorder.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: kAuthBlue,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'What happens next?',
                                        style: text.copyWith(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: kAuthText,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "An administrator will verify your credentials. Once confirmed, you'll be able to sign in with your password.",
                                        style: text.copyWith(
                                          fontSize: 12,
                                          color: kAuthMuted,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Back to Sign In Button
                          AuthPrimaryButton(
                            loading: false,
                            label: 'Back to Sign In',
                            onPressed: () => _backToSignIn(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Footer support prompt
                    Center(
                      child: Text(
                        'Questions about your account? Contact support at support@sajiloroute.com',
                        textAlign: TextAlign.center,
                        style: text.copyWith(
                          fontSize: 11.5,
                          color: kAuthFaint,
                        ),
                      ),
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool valueBadge = false,
    Color? statusColor,
  }) {
    final text = GoogleFonts.inter();

    return Row(
      children: [
        Icon(icon, size: 16, color: kAuthIcon),
        const SizedBox(width: 8),
        Text(
          label,
          style: text.copyWith(
            fontSize: 13,
            color: kAuthMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: valueBadge
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kAuthBlueTint,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: kAuthBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      value,
                      style: text.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kAuthBlue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : (statusColor != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              value,
                              style: text.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        value,
                        style: text.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kAuthText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
          ),
        ),
      ],
    );
  }
}

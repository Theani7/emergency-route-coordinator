import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    const bgColor = Color(0xFF0D1322);
    const cardBg = Color(0xFF161F30);
    const borderColor = Color(0xFF26354D);
    const textMuted = Color(0xFF94A3B8);
    const textFaint = Color(0xFF64748B);
    const amberAccent = Color(0xFFF59E0B);
    const amberBg = Color(0x26F59E0B);
    const amberBorder = Color(0x4DF59E0B);
    const infoBg = Color(0xFF0C2137);
    const infoBorder = Color(0xFF1E3A5F);
    const infoCyan = Color(0xFF38BDF8);
    const buttonRed = Color(0xFFE11D48);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon badge with glowing background
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: amberBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: amberBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: amberAccent.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 40,
                        color: amberAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pill status badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: amberBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: amberBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: amberAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PENDING APPROVAL',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Registration Submitted',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'Your account has been registered and is pending administrator confirmation. Once approved, you can log in immediately.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Registration Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 16,
                              color: textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'APPLICATION DETAILS',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: borderColor, height: 1),
                        const SizedBox(height: 14),

                        // Name Row (if available)
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
                          statusColor: amberAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Informative Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: infoBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: infoBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: infoCyan,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "What happens next?",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "An administrator will verify your credentials. Once confirmed, you'll be able to sign in with your password.",
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF93C5FD),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Back to Sign In Button
                  ElevatedButton(
                    onPressed: () => _backToSignIn(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Back to Sign In'),
                  ),
                  const SizedBox(height: 16),

                  // Secondary action / help
                  Center(
                    child: Text(
                      'Questions about your account? Contact dispatch support.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textFaint,
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
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool valueBadge = false,
    Color? statusColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
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
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
                              style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
          ),
        ),
      ],
    );
  }
}

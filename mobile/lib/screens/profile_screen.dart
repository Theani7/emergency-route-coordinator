import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../services/profile_service.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/auth_widgets.dart';

const _kGreenBadgeBg = Color(0xFFE8F5EC);
const _kGreenBadgeText = Color(0xFF1F7A44);
const _kGreen = Color(0xFF2F9E63);
const _kBlue = Color(0xFF2E6FD8);
const _kBlueTint = Color(0xFFEAF1FC);
const _kOrange = Color(0xFFE8833A);
const _kOrangeTint = Color(0xFFFDF1E7);
const _kNeutralTint = Color(0xFFF2F1ED);
const _kScrim = Color(0x3D1A1A18);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final user = auth.user;
    final profile = profileProvider.profile;
    final name = profile?.name ?? user?.name ?? '';
    final email = profile?.email ?? user?.email ?? '';
    final role = profile?.role ?? user?.role.name ?? '';

    final text = GoogleFonts.inter();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          'My account',
          style: text.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
            color: kAuthFaint,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Profile',
          style: text.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: kAuthText,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        if (profileProvider.loading && profile == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: SkeletonProfile(),
          )
        else ...[
          _identityCard(text, name, email, role),
          const SizedBox(height: 12),
          _detailsCard(text, profile, role),
          const SizedBox(height: 20),
          _sectionLabel(text, 'Settings'),
          const SizedBox(height: 8),
          _settingsCard(text, role),
          const SizedBox(height: 20),
          _sectionLabel(text, 'Support'),
          const SizedBox(height: 8),
          _supportCard(text),
          if (profileProvider.success != null) ...[
            const SizedBox(height: 12),
            _successBanner(text, profileProvider.success!),
          ],
          if (profileProvider.error != null) ...[
            const SizedBox(height: 12),
            AuthErrorBanner(message: profileProvider.error!),
          ],
          const SizedBox(height: 20),
          _LogoutButton(onPressed: () => _confirmLogout(context, auth)),
        ],
      ],
    );
  }

  Widget _identityCard(TextStyle text, String name, String email, String role) {
    final initial = name.isEmpty ? 'D' : name[0].toUpperCase();
    return GlassSurface(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kAuthRedBadgeBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kAuthRed.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(
                initial,
                style: text.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: kAuthRedLink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: text.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kAuthText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: text.copyWith(fontSize: 13, color: kAuthMuted),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAuthRedBadgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kAuthRed.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    _roleLabel(role),
                    style: text.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: kAuthRedBadgeText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(TextStyle text, ProfileModel? profile, String role) {
    final rows = <Widget>[
      _detailRow(
        text,
        icon: Icons.mail_outline_rounded,
        tint: _kBlueTint,
        iconColor: _kBlue,
        label: 'Email',
        value: profile?.email ?? '',
      ),
      _divider(),
      _detailRow(
        text,
        icon: Icons.badge_outlined,
        tint: _kOrangeTint,
        iconColor: _kOrange,
        label: 'Role',
        value: _roleLabel(profile?.role ?? role),
      ),
    ];
    if (profile?.vehicleNumber != null) {
      rows.addAll([
        _divider(),
        _detailRow(
          text,
          icon: Icons.local_shipping_outlined,
          tint: _kNeutralTint,
          iconColor: kAuthMuted,
          label: 'Vehicle',
          value: profile!.vehicleNumber!,
        ),
      ]);
    }
    if (profile?.assignedZone != null) {
      rows.addAll([
        _divider(),
        _detailRow(
          text,
          icon: Icons.location_on_outlined,
          tint: _kGreenBadgeBg,
          iconColor: _kGreenBadgeText,
          label: 'Assigned zone',
          value: profile!.assignedZone!,
        ),
      ]);
    }
    return Container(
      decoration: BoxDecoration(
        color: kAuthCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAuthBorder),
      ),
      child: Column(children: rows),
    );
  }

  Widget _detailRow(
    TextStyle text, {
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.copyWith(fontSize: 11.5, color: kAuthFaint),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: text.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: kAuthText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        thickness: 1,
        color: kAuthBorder,
        indent: 16,
        endIndent: 16,
      );

  Widget _sectionLabel(TextStyle text, String label) {
    return Row(
      children: [
        Text(
          label,
          style: text.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: kAuthText,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: kAuthBorder, height: 1)),
      ],
    );
  }

  Widget _settingsCard(TextStyle text, String role) {
    final isOfficer = role == 'officer';
    return Container(
      decoration: BoxDecoration(
        color: kAuthCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAuthBorder),
      ),
      child: Column(
        children: [
          _tile(
            text,
            icon: Icons.edit_outlined,
            title: 'Edit name',
            subtitle: 'Update your display name',
            onTap: () => _showEditNameDialog(context),
          ),
          _divider(),
          _tile(
            text,
            icon: Icons.lock_outline_rounded,
            title: 'Change password',
            subtitle: 'At least 8 characters',
            onTap: () => _showChangePasswordDialog(context),
          ),
          if (!isOfficer) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Consumer<SettingsProvider>(builder: (_, s, __) {
                return Row(
                  children: [
                    _tileIcon(Icons.traffic_rounded, _kNeutralTint, kAuthMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show traffic overlay',
                            style: text.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: kAuthText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Live traffic on the map',
                            style: text.copyWith(
                              fontSize: 12,
                              color: kAuthFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.showTrafficOverlay,
                      onChanged: (v) => s.setShowTrafficOverlay(v),
                      activeThumbColor: Colors.white,
                      activeTrackColor: kAuthRed,
                      inactiveThumbColor: kAuthCard,
                      inactiveTrackColor: const Color(0xFFE0DED6),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _supportCard(TextStyle text) {
    return Container(
      decoration: BoxDecoration(
        color: kAuthCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAuthBorder),
      ),
      child: Column(
        children: [
          _tile(
            text,
            icon: Icons.help_outline_rounded,
            title: 'Help & support',
            subtitle: 'Contact dispatch and user guide',
            onTap: () => _showHelpDialog(context),
          ),
          _divider(),
          _tile(
            text,
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Version and project details',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    TextStyle text, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            _tileIcon(icon, _kNeutralTint, kAuthMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: kAuthText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.copyWith(fontSize: 12, color: kAuthFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: kAuthIcon),
          ],
        ),
      ),
    );
  }

  Widget _tileIcon(IconData icon, Color tint, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }

  Widget _successBanner(TextStyle text, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kGreenBadgeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreen.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 17,
            color: _kGreenBadgeText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: text.copyWith(
                fontSize: 12.5,
                color: _kGreenBadgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'driver':
        return 'Driver';
      case 'officer':
        return 'Traffic officer';
      case 'admin':
        return 'Admin';
      default:
        return role.isEmpty ? '—' : role[0].toUpperCase() + role.substring(1);
    }
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    final text = GoogleFonts.inter();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: _kScrim,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          decoration: BoxDecoration(
            color: (isDark ? kAuthInk : Colors.white).withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.3))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: isDark ? 0.3 : 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: kAuthRed, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Log out of your account?',
                style: text.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "You'll need your credentials to sign back in.",
                style: text.copyWith(
                  fontSize: 15,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    auth.logout();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kAuthRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    'Log out',
                    style: text.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: text.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final auth = context.read<AuthProvider>();
    final current = profileProvider.profile?.name ?? auth.user?.name ?? '';
    final ctrl = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();
    final text = GoogleFonts.inter();

    showDialog(
      context: context,
      barrierColor: _kScrim,
      builder: (ctx) => _styledDialog(
        title: 'Edit name',
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            style: text.copyWith(fontSize: 15, color: kAuthText),
            cursorColor: kAuthRed,
            decoration: _fieldDecoration('Name'),
            validator: (v) {
              final name = v?.trim() ?? '';
              if (name.isEmpty) return 'Enter your name';
              if (name.length < 2) return 'At least 2 characters';
              return null;
            },
          ),
        ),
        actions: [
          _dialogButton('Cancel', kAuthMuted, () => Navigator.pop(ctx)),
          _dialogButton('Save', kAuthRedLink, () {
            final name = ctrl.text.trim();
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx);
            profileProvider.updateName(name).then((ok) {
              if (ok && ctx.mounted) auth.updateLocalName(name);
            });
          }),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final text = GoogleFonts.inter();

    showDialog(
      context: context,
      barrierColor: _kScrim,
      builder: (ctx) => _styledDialog(
        title: 'Change password',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                style: text.copyWith(fontSize: 15, color: kAuthText),
                cursorColor: kAuthRed,
                decoration: _fieldDecoration('Current password'),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                style: text.copyWith(fontSize: 15, color: kAuthText),
                cursorColor: kAuthRed,
                decoration: _fieldDecoration('New password'),
                validator: (v) => (v == null || v.length < 8)
                    ? 'At least 8 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                style: text.copyWith(fontSize: 15, color: kAuthText),
                cursorColor: kAuthRed,
                decoration: _fieldDecoration('Confirm new password'),
                validator: (v) =>
                    v != newCtrl.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          _dialogButton('Cancel', kAuthMuted, () => Navigator.pop(ctx)),
          _dialogButton('Update', kAuthRedLink, () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx);
            profileProvider.changePassword(
              currentPassword: currentCtrl.text,
              newPassword: newCtrl.text,
            );
          }),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    final text = GoogleFonts.inter();
    showDialog(
      context: context,
      barrierColor: _kScrim,
      builder: (ctx) => _styledDialog(
        title: 'Help & support',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ambulance coordination system',
              style: text.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: kAuthText,
              ),
            ),
            const SizedBox(height: 12),
            _contactRow(
              text,
              icon: Icons.phone_outlined,
              label: 'Dispatch center',
              value: '102',
            ),
            const SizedBox(height: 8),
            _contactRow(
              text,
              icon: Icons.mail_outline_rounded,
              label: 'Technical support',
              value: 'support@ambulance.gov.np',
            ),
            const SizedBox(height: 14),
            Text(
              'User guide',
              style: text.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: kAuthText,
              ),
            ),
            const SizedBox(height: 6),
            _bullet(text, 'Use the Trips tab to view live ambulance positions'),
            _bullet(text, 'Accept emergency alerts from the Alerts tab'),
            _bullet(text, 'Activate an emergency from the home tab'),
            _bullet(text, 'Update your profile from this screen'),
          ],
        ),
        actions: [
          _dialogButton('Close', kAuthRedLink, () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final text = GoogleFonts.inter();
    showDialog(
      context: context,
      barrierColor: _kScrim,
      builder: (ctx) => _styledDialog(
        title: 'About',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI-driven traffic ambulance coordination system',
              style: text.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: kAuthText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: text.copyWith(fontSize: 12, color: kAuthFaint),
            ),
            const SizedBox(height: 10),
            Text(
              'A final year project implementing real-time ambulance '
              'coordination with AI-powered route optimization for '
              'Kathmandu Valley.',
              style: text.copyWith(
                fontSize: 13,
                color: kAuthMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Features',
              style: text.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: kAuthText,
              ),
            ),
            const SizedBox(height: 6),
            _bullet(text, 'AI incident prediction'),
            _bullet(text, 'Real-time GPS tracking'),
            _bullet(text, 'Route optimization with OSRM'),
            _bullet(text, 'Traffic officer coordination'),
            _bullet(text, 'Junction clearance management'),
          ],
        ),
        actions: [
          _dialogButton('Close', kAuthRedLink, () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  Dialog _styledDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    final text = GoogleFonts.inter();
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassSurface(
        radius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: text.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: kAuthText,
              ),
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    final text = GoogleFonts.inter();
    OutlineInputBorder makeBorder(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: text.copyWith(fontSize: 13, color: kAuthMuted),
      floatingLabelStyle: text.copyWith(fontSize: 12, color: kAuthRed),
      border: makeBorder(kAuthBorder),
      enabledBorder: makeBorder(kAuthBorder),
      focusedBorder: makeBorder(kAuthRed),
      errorBorder: makeBorder(kAuthRed),
      focusedErrorBorder: makeBorder(kAuthRed),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      errorStyle: text.copyWith(fontSize: 12, color: kAuthRedDark),
    );
  }

  TextButton _dialogButton(String label, Color color, VoidCallback onPressed) {
    final text = GoogleFonts.inter();
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: const Size(0, 40),
      ),
      child: Text(
        label,
        style: text.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _contactRow(
    TextStyle text, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kAuthIcon),
        const SizedBox(width: 10),
        Text(
          label,
          style: text.copyWith(fontSize: 13, color: kAuthMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: text.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kAuthText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bullet(TextStyle text, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: kAuthRed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: text.copyWith(fontSize: 13, color: kAuthMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _hover = false;
  bool _pressed = false;

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
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color:
                _pressed ? kAuthRedPressed : (_hover ? kAuthRedDark : kAuthRed),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout_rounded,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: text.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/emergency_provider.dart';
import '../models/emergency_model.dart';
import '../providers/live_ambulance_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/route_utils.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/directions_panel.dart';
import '../widgets/ambulance_map.dart';
import '../widgets/emergency_button.dart';
import 'emergency_activate_screen.dart';
import 'navigation_screen.dart';
import 'driver_updates_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

const _kGreenBadgeBg = Color(0xFFE8F5EC);
const _kGreenBadgeText = Color(0xFF1F7A44);
const _kBlue = Color(0xFF2E6FD8);
const _kGreen = Color(0xFF2F9E63);
const _kOrange = Color(0xFFE8833A);
const _kNeutralTint = Color(0xFFF2F1ED);
const _kBlueTint = Color(0xFFEAF1FC);
const _kOrangeTint = Color(0xFFFDF1E7);

class StatusColors {
  final Color bg;
  final Color fg;
  final Color border;
  const StatusColors({
    required this.bg,
    required this.fg,
    required this.border,
  });
}

StatusColors _statusColors(String display, {bool emergency = false}) {
  if (emergency) {
    return const StatusColors(
      bg: kAuthRedBadgeBg,
      fg: kAuthRedBadgeText,
      border: kAuthRed,
    );
  }
  switch (display) {
    case 'On Duty':
      return const StatusColors(
        bg: _kBlueTint,
        fg: _kBlue,
        border: _kBlue,
      );
    case 'Offline':
      return const StatusColors(
        bg: _kNeutralTint,
        fg: kAuthMuted,
        border: kAuthBorder,
      );
    default:
      return const StatusColors(
        bg: _kGreenBadgeBg,
        fg: _kGreenBadgeText,
        border: _kGreen,
      );
  }
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedIndex = 0;
  String _driverStatus = 'Available';
  bool _locationPermissionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loc = context.read<DriverLocationProvider>();
      final emergency = context.read<EmergencyProvider>();
      final notifications = context.read<NotificationProvider>();
      final chat = context.read<ChatProvider>();
      await _requestLocationPermission(loc);
      await emergency.restoreActiveSession();
      await notifications.setMode(driver: true);
      await chat.loadSessions();
      if (emergency.isEmergencyActive && emergency.activeEmergency != null) {
        final started = await loc.startTracking(
          emergency.activeEmergency!.id,
          onTick: emergency.refreshActiveEmergency,
        );
        if (!started && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission required for live tracking'),
            ),
          );
        }
        if (mounted) setState(() => _driverStatus = 'Busy');
      }
      await emergency.loadHistory();
    });
  }

  Future<void> _requestLocationPermission(
      DriverLocationProvider loc) async {
    if (_locationPermissionChecked) return;
    _locationPermissionChecked = true;

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: kAuthRed),
            SizedBox(width: 10),
            Text('Location Access'),
          ],
        ),
        content: const Text(
          'Sajiloroute needs your location to track ambulance trips '
          'and assist traffic officers in clearing your route. '
          'Please allow location access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final ok = await loc.init();
              if (ok) {
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } else {
                if (ctx.mounted) Navigator.of(ctx).pop(false);
              }
            },
            icon: const Icon(Icons.my_location),
            label: const Text('Allow'),
          ),
        ],
      ),
    );

    if (granted != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can enable location later in settings.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyProvider>();
    final location = context.watch<DriverLocationProvider>();
    final notifs = context.watch<NotificationProvider>();
    final chat = context.watch<ChatProvider>();
    final active = emergency.activeEmergency;
    final now = DateTime.now();
    bool isToday(DateTime dt) =>
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final todayTrips = emergency.history
        .where((h) =>
            isToday(h.startedAt) || (h.endedAt != null && isToday(h.endedAt!)))
        .length;

    final pages = <Widget>[
      _buildHomePage(context, emergency, location, active, todayTrips, notifs),
      _buildMapPage(context, emergency, location, active),
      const DriverUpdatesScreen(),
      const ChatScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: GlassBackdrop(
        child: Stack(
          children: [
            SafeArea(
              top: true,
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.012),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_selectedIndex),
                  child: pages[_selectedIndex],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 110,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        kAuthBg.withValues(alpha: 0.0),
                        kAuthBg.withValues(alpha: 0.8),
                        kAuthBg,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
          child: FrostedBar(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: kGlassBorder.withValues(alpha: 0.2)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  )
                ],
              ),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                  _navItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  _navItem(
                    index: 1,
                    icon: Icons.map_outlined,
                    selectedIcon: Icons.map_rounded,
                    label: 'Map',
                  ),
                  _navItem(
                    index: 2,
                    icon: Icons.notifications_outlined,
                    selectedIcon: Icons.notifications_rounded,
                    label: 'Alerts',
                    badgeCount: notifs.unreadCount,
                  ),
                  _navItem(
                    index: 3,
                    icon: Icons.chat_bubble_outline_rounded,
                    selectedIcon: Icons.chat_bubble_rounded,
                    label: 'Chat',
                    badgeCount: chat.totalUnread,
                  ),
                  _navItem(
                    index: 4,
                    icon: Icons.person_outlined,
                    selectedIcon: Icons.person_rounded,
                    label: 'Profile',
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

  Widget _navItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final active = _selectedIndex == index;
    final text = GoogleFonts.inter();
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        hoverColor: kAuthBorder.withValues(alpha: 0.3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  active ? selectedIcon : icon,
                  size: 21,
                  color: active ? kAuthRedLink : kAuthInk,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: kAuthRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: text.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: text.copyWith(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? kAuthRedLink : kAuthInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage(
    BuildContext context,
    EmergencyProvider emergency,
    DriverLocationProvider location,
    dynamic active,
    int todayTrips,
    NotificationProvider notifs,
  ) {
    final text = GoogleFonts.inter();
    final auth = context.watch<AuthProvider>();
    final driverName = auth.user?.name.trim() ?? '';
    final firstName =
        driverName.isEmpty ? 'Driver' : driverName.split(' ').first;
    return RefreshIndicator(
      onRefresh: () async {
        await emergency.restoreActiveSession();
        await notifs.load();
        await emergency.loadHistory();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver dashboard',
                      style: text.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                        color: kAuthFaint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_greetingPrefix(DateTime.now())}, $firstName',
                      style: text.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: kAuthText,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kAuthRedBadgeBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kAuthRed.withValues(alpha: 0.25)),
                  boxShadow: kCardShadow,
                ),
                child: Center(
                  child: Text(
                    firstName.isEmpty ? 'D' : firstName[0].toUpperCase(),
                    style: text.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kAuthRedLink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Builder(builder: (context) {
                      final colors = _statusColors(
                        _driverStatus,
                        emergency: emergency.isEmergencyActive,
                      );
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          emergency.isEmergencyActive
                              ? Icons.local_hospital_rounded
                              : _driverStatus == 'Offline'
                                  ? Icons.power_settings_new
                                  : _driverStatus == 'On Duty'
                                      ? Icons.work_outline
                                      : Icons.check_circle_rounded,
                          size: 20,
                          color: colors.fg,
                        ),
                      );
                    }),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My status',
                            style: text.copyWith(
                              fontSize: 12.5,
                              color: kAuthFaint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Builder(builder: (context) {
                            final colors = _statusColors(
                              _driverStatus,
                              emergency: emergency.isEmergencyActive,
                            );
                            final label = emergency.isEmergencyActive
                                ? 'Busy'
                                : _driverStatus;
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                label,
                                key: ValueKey(label),
                                style: text.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: colors.fg,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!emergency.isEmergencyActive) ...[
                  const SizedBox(height: 12),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Row(
                      children: [
                        _statusPill(
                          icon: Icons.check_circle_outline,
                          label: 'Available',
                          active: _driverStatus == 'Available',
                          onTap: () => _setStatus('Available', 'available'),
                          activeColors: _statusColors('Available'),
                        ),
                        const SizedBox(width: 8),
                        _statusPill(
                          icon: Icons.work_outline,
                          label: 'On duty',
                          active: _driverStatus == 'On Duty',
                          onTap: () => _setStatus('On Duty', 'on_duty'),
                          activeColors: _statusColors('On Duty'),
                        ),
                        const SizedBox(width: 8),
                        _statusPill(
                          icon: Icons.offline_bolt_outlined,
                          label: 'Offline',
                          active: _driverStatus == 'Offline',
                          onTap: () => _setStatus('Offline', 'offline'),
                          activeColors: _statusColors('Offline'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                icon: Icons.local_shipping,
                label: 'Active emergency',
                value: emergency.isEmergencyActive ? 'Yes' : 'No',
                iconColor: emergency.isEmergencyActive ? kAuthRed : kAuthMuted,
                tint: emergency.isEmergencyActive
                    ? kAuthRedBadgeBg
                    : _kNeutralTint,
              ),
              const SizedBox(width: 12),
              _statCard(
                icon: Icons.check_circle,
                label: "Today's trips",
                value: '$todayTrips',
                iconColor: _kBlue,
                tint: _kBlueTint,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                icon: Icons.notifications,
                label: 'Notifications',
                value: '${notifs.unreadCount}',
                iconColor: notifs.unreadCount > 0 ? _kOrange : kAuthMuted,
                tint: notifs.unreadCount > 0 ? _kOrangeTint : _kNeutralTint,
              ),
              const SizedBox(width: 12),
              _statCard(
                icon: Icons.speed,
                label: 'Speed',
                value: active != null
                    ? '${location.speedKmh != null ? location.speedKmh!.toStringAsFixed(0) : "—"} km/h'
                    : '— km/h',
                iconColor: _kGreen,
                tint: _kGreenBadgeBg,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (emergency.isEmergencyActive && active != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAuthRedBadgeBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kAuthRed.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emergency, size: 20, color: kAuthRed),
                      const SizedBox(width: 8),
                      Text(
                        'Active emergency',
                        style: text.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kAuthRedBadgeText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: kAuthRed.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 6),
                  _infoRow('Destination', active.destination),
                  _infoRow('ETA', '${formatEta(active.etaMinutes)} min'),
                  _infoRow('Type', active.incidentType ?? 'general'),
                  _infoRow('Priority', active.priorityLevel ?? 'standard'),
                  if (active.patientName != null)
                    _infoRow('Patient', active.patientName!),
                  if (active.hospitalName != null)
                    _infoRow('Hospital', active.hospitalName!),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Text(
                'Quick actions',
                style: text.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: kAuthText,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Divider(color: kAuthBorder, height: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!emergency.isEmergencyActive)
            EmergencyButton(
              loading: emergency.loading,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EmergencyActivateScreen()),
                );
                if (!context.mounted) return;
                if (emergency.isEmergencyActive &&
                    emergency.activeEmergency != null) {
                  await context.read<DriverLocationProvider>().startTracking(
                        emergency.activeEmergency!.id,
                        onTick: emergency.refreshActiveEmergency,
                      );
                  if (!context.mounted) return;
                  setState(() => _driverStatus = 'Busy');
                }
              },
            ),
          if (emergency.isEmergencyActive) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation),
                label: const Text('Open Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                onPressed: active != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NavigationScreen(),
                          ),
                        );
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.list),
                    label: const Text('Directions'),
                    style: _outlineStyle(),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => DirectionsPanel(
                        routePolyline: active?.routePolyline,
                        totalEtaMinutes: active?.etaMinutes,
                        routeSteps: active?.routeSteps,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('End emergency'),
                    style: _outlineStyle(
                      foregroundColor: kAuthRed,
                      borderColor: kAuthRed.withValues(alpha: 0.4),
                    ),
                    onPressed: emergency.loading
                        ? null
                        : () async {
                            final confirmed =
                                await _confirmEndEmergency(context);
                            if (!confirmed || !context.mounted) return;
                            final ok = await emergency.endEmergency();
                            if (!context.mounted) return;
                            if (ok) {
                              context
                                  .read<DriverLocationProvider>()
                                  .stopTracking();
                              setState(() => _driverStatus = 'Available');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    emergency.error ??
                                        'Failed to end emergency',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Trip progress',
              style: text.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kAuthText.withValues(alpha: 0.7),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            _stageTracker(context, emergency, active),
          ],
        ],
      ),
    );
  }

  Future<bool> _confirmEndEmergency(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('End emergency?'),
            content: const Text(
              'Are you sure you want to end this emergency? Location tracking will stop.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.stop),
                label: const Text('End emergency'),
                style: FilledButton.styleFrom(
                  backgroundColor: kAuthRed,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _greetingPrefix(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _setStatus(String display, String api) async {
    final previous = _driverStatus;
    setState(() => _driverStatus = display);
    final ok = await context.read<AuthProvider>().updateAmbulanceStatus(api);
    if (!mounted) return;
    if (!ok) {
      setState(() => _driverStatus = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't sync status — check your connection"),
        ),
      );
    }
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required StatusColors activeColors,
  }) {
    final text = GoogleFonts.inter();
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: activeColors.bg.withValues(alpha: 0.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 40,
          decoration: BoxDecoration(
            color: active ? activeColors.bg : kAuthCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? activeColors.border : kAuthBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? activeColors.fg : kAuthFaint,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: text.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active ? activeColors.fg : kAuthFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color tint,
  }) {
    final text = GoogleFonts.inter();
    return Expanded(
      child: GlassSurface(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: text.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: kAuthText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: text.copyWith(fontSize: 11, color: kAuthFaint),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _outlineStyle({
    Color? foregroundColor,
    Color? borderColor,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor ?? kAuthText,
      backgroundColor: kAuthCard,
      side: BorderSide(color: borderColor ?? kAuthBorder),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  Widget _buildMapPage(
    BuildContext context,
    EmergencyProvider emergency,
    DriverLocationProvider location,
    dynamic active,
  ) {
    return Column(
      children: [
        if (emergency.isEmergencyActive)
          Container(
            width: double.infinity,
            color: kAuthRed,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.navigation, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En route — ETA ${formatEta(active?.etaMinutes)} min',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              AmbulanceMap(
                ambulanceLat: location.lat,
                ambulanceLon: location.lon,
                destLat: active?.destLat,
                destLon: active?.destLon,
                routePolyline: active?.routePolyline,
                showTrafficOverlay: true,
                showCurrentLocation: true,
                currentLocationLat: location.lat,
                currentLocationLon: location.lon,
              ),
              if (emergency.isEmergencyActive && active != null)
                Positioned(
                  bottom: 104,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.navigation),
                          label: const Text('Start Navigation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NavigationScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.list, size: 18),
                              label: const Text('Directions'),
                              style: _outlineStyle(),
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => DirectionsPanel(
                                  routePolyline: active?.routePolyline,
                                  totalEtaMinutes: active?.etaMinutes,
                                  routeSteps: active?.routeSteps,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.stop, size: 18),
                              label: const Text('End'),
                              style: _outlineStyle(
                                foregroundColor: kAuthRed,
                                borderColor: kAuthRed.withValues(alpha: 0.4),
                              ),
                              onPressed: emergency.loading
                                  ? null
                                  : () async {
                                      final confirmed =
                                          await _confirmEndEmergency(context);
                                      if (!confirmed || !context.mounted) {
                                        return;
                                      }
                                      final ok = await emergency.endEmergency();
                                      if (!context.mounted) return;
                                      if (ok) {
                                        context
                                            .read<DriverLocationProvider>()
                                            .stopTracking();
                                        setState(
                                            () => _driverStatus = 'Available');
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              emergency.error ??
                                                  'Failed to end emergency',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (!emergency.isEmergencyActive)
                Positioned(
                  bottom: 104,
                  left: 16,
                  right: 16,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.emergency),
                      label: const Text('Activate emergency'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAuthRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EmergencyActivateScreen()),
                        );
                        if (!context.mounted) return;
                        if (emergency.isEmergencyActive &&
                            emergency.activeEmergency != null) {
                          await context
                              .read<DriverLocationProvider>()
                              .startTracking(
                                emergency.activeEmergency!.id,
                                onTick: emergency.refreshActiveEmergency,
                              );
                          if (!context.mounted) return;
                          setState(() => _driverStatus = 'Busy');
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    final text = GoogleFonts.inter();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: text.copyWith(color: kAuthFaint, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: kAuthText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageTracker(
    BuildContext context,
    EmergencyProvider emergency,
    EmergencyModel active,
  ) {
    const steps = <({String stage, String label, IconData icon})>[
      (
        stage: 'arrived_patient',
        label: 'Arrived at Patient',
        icon: Icons.place
      ),
      (
        stage: 'patient_picked_up',
        label: 'Patient Picked Up',
        icon: Icons.person_pin,
      ),
      (
        stage: 'arrived_hospital',
        label: 'Reached Hospital',
        icon: Icons.local_hospital,
      ),
    ];
    final currentIndex = steps.indexWhere((s) => s.stage == active.tripStage);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAuthBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Container(
                height: 14,
                width: 2,
                margin: const EdgeInsets.only(left: 19),
                color: i <= currentIndex ? _kGreen : kAuthBorder,
              ),
            _stageRow(context, emergency, steps[i], i, currentIndex),
          ],
        ],
      ),
    );
  }

  Widget _stageRow(
    BuildContext context,
    EmergencyProvider emergency,
    ({String stage, String label, IconData icon}) step,
    int index,
    int currentIndex,
  ) {
    final done = currentIndex >= 0 && index < currentIndex;
    final active = index == currentIndex;
    final Color fg = done
        ? _kGreenBadgeText
        : active
            ? kAuthRedBadgeText
            : kAuthText.withValues(alpha: 0.65);
    final text = GoogleFonts.inter();

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: emergency.loading
          ? null
          : () => context.read<EmergencyProvider>().updateTripStage(step.stage),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? _kGreen
                    : active
                        ? kAuthRed
                        : Colors.transparent,
                border: active || done
                    ? null
                    : Border.all(color: kAuthBorder, width: 1.5),
              ),
              child: Icon(
                done ? Icons.check : step.icon,
                size: 15,
                color: done || active ? Colors.white : fg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                step.label,
                style: text.copyWith(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
            if (active)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: kAuthRedBadgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kAuthRed.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'In progress',
                  style: text.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kAuthRedBadgeText,
                  ),
                ),
              )
            else if (done)
              Text(
                'Done',
                style: text.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kGreenBadgeText,
                ),
              )
            else
              Icon(Icons.chevron_right, size: 18, color: kAuthBorder),
          ],
        ),
      ),
    );
  }
}

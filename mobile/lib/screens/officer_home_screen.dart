import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/junction_provider.dart';
import '../providers/live_ambulance_provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';
import '../services/gps_service.dart';
import '../services/api_service.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/auth_widgets.dart';
import 'officer_map_screen.dart';
import 'officer_history_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

const _kBlue = Color(0xFF2E6FD8);
const _kGreen = Color(0xFF2F9E63);
const _kOrange = Color(0xFFE8833A);
const _kNeutralTint = Color(0xFFF2F1ED);
const _kBlueTint = Color(0xFFEAF1FC);
const _kOrangeTint = Color(0xFFFDF1E7);

class OfficerHomeScreen extends StatefulWidget {
  const OfficerHomeScreen({super.key});

  @override
  State<OfficerHomeScreen> createState() => _OfficerHomeScreenState();
}

class _OfficerHomeScreenState extends State<OfficerHomeScreen> {
  int _selectedIndex = 0;
  LiveAmbulanceProvider? _live;
  Timer? _locationTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _live ??= context.read<LiveAmbulanceProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<NotificationProvider>().setMode(driver: false);
      if (!mounted) return;
      context.read<LiveAmbulanceProvider>().startPolling();
      context.read<JunctionProvider>().loadClearanceHistory();
      await context.read<ChatProvider>().loadSessions();
      _startLocationTracking();
    });
  }

  Future<void> _pushCurrentLocation() async {
    try {
      final position = await GpsTrackingService.bestPosition();
      if (position != null && mounted) {
        final api = context.read<ApiService>();
        await api.post('/api/v1/profile/location', data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
      }
    } catch (_) {}
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _pushCurrentLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pushCurrentLocation();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _live?.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifs = context.watch<NotificationProvider>();
    final live = context.watch<LiveAmbulanceProvider>();
    final junctions = context.watch<JunctionProvider>();
    final chat = context.watch<ChatProvider>();

    final pages = <Widget>[
      SafeArea(
          top: true,
          bottom: false,
          child: _buildHomePage(context, live, notifs, junctions)),
      const OfficerMapScreen(),
      _buildAlertsPage(context, notifs),
      const ChatScreen(),
      const OfficerHistoryScreen(),
      const SafeArea(top: true, bottom: false, child: ProfileScreen()),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: GlassBackdrop(
        child: Stack(
          children: [
            AnimatedSwitcher(
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
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
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
                    icon: Icons.warning_amber_outlined,
                    selectedIcon: Icons.warning_amber_rounded,
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
                    icon: Icons.history_outlined,
                    selectedIcon: Icons.history_rounded,
                    label: 'History',
                  ),
                  _navItem(
                    index: 5,
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
    LiveAmbulanceProvider live,
    NotificationProvider notifs,
    JunctionProvider junctions,
  ) {
    final text = GoogleFonts.inter();
    final auth = context.watch<AuthProvider>();
    final officerName = auth.user?.name.trim() ?? '';
    final firstName =
        officerName.isEmpty ? 'Officer' : officerName.split(' ').first;
    final activeAmbulances = live.ambulances.length;
    final activeEmergencies =
        live.ambulances.where((a) => a.status == 'emergency').length;
    final clearedToday = junctions.clearanceHistory.length;

    return RefreshIndicator(
      onRefresh: () async {
        await live.refresh();
        await notifs.load();
        await junctions.loadClearanceHistory();
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
                      'Dispatch desk',
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
                    firstName.isEmpty ? 'O' : firstName[0].toUpperCase(),
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
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        activeEmergencies > 0 ? kAuthRedBadgeBg : _kNeutralTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    activeEmergencies > 0
                        ? Icons.emergency_rounded
                        : Icons.local_shipping_rounded,
                    size: 20,
                    color: activeEmergencies > 0 ? kAuthRed : kAuthMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live operations',
                        style: text.copyWith(
                          fontSize: 12.5,
                          color: kAuthFaint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeEmergencies > 0
                            ? '$activeAmbulances ambulances • '
                                '$activeEmergencies emergency'
                            : 'No active emergencies',
                        style: text.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: activeEmergencies > 0
                              ? kAuthRedBadgeText
                              : kAuthMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                icon: Icons.local_shipping_rounded,
                label: 'Active ambulances',
                value: '$activeAmbulances',
                iconColor: _kBlue,
                tint: _kBlueTint,
              ),
              const SizedBox(width: 12),
              _statCard(
                icon: Icons.emergency_rounded,
                label: 'Emergencies',
                value: '$activeEmergencies',
                iconColor: kAuthRed,
                tint: kAuthRedBadgeBg,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                icon: Icons.traffic_rounded,
                label: 'Junctions cleared',
                value: '$clearedToday',
                iconColor: _kGreen,
                tint: kAuthGreenBg,
              ),
              const SizedBox(width: 12),
              _statCard(
                icon: Icons.notifications_rounded,
                label: 'Pending alerts',
                value: '${notifs.unreadCount}',
                iconColor: notifs.unreadCount > 0 ? _kOrange : kAuthMuted,
                tint: notifs.unreadCount > 0 ? _kOrangeTint : _kNeutralTint,
              ),
            ],
          ),
          const SizedBox(height: 16),
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
              const Expanded(child: Divider(color: kAuthBorder, height: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  text,
                  icon: Icons.map_rounded,
                  iconColor: _kBlue,
                  tint: _kBlueTint,
                  label: 'Live map',
                  sub: 'Track fleet & clear junctions',
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCard(
                  text,
                  icon: Icons.chat_bubble_rounded,
                  iconColor: _kOrange,
                  tint: _kOrangeTint,
                  label: 'Open chat',
                  sub: 'Message drivers & officers',
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
              ),
            ],
          ),
          if (notifs.unreadCount > 0) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Recent alerts',
                  style: text.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: kAuthText,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 2),
                  child: Text(
                    'View all',
                    style: text.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kAuthRedLink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...notifs.notifications.take(3).map(
                  (n) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    color: n.isAcknowledged
                        ? null
                        : Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.emergency_rounded,
                        color: n.isAcknowledged
                            ? Theme.of(context).colorScheme.outline
                            : kAuthRed,
                      ),
                      title: Text(
                        n.title,
                        style: text.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: kAuthText,
                        ),
                      ),
                      subtitle: Text(
                        n.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.copyWith(
                          fontSize: 13,
                          color: kAuthMuted,
                        ),
                      ),
                      trailing: _alertActions(
                        context,
                        notifs,
                        n,
                        text,
                      ),
                    ),
                  ),
                ),
          ],
          if (live.ambulances.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Active ambulances',
                  style: text.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: kAuthText,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Divider(color: kAuthBorder, height: 1)),
              ],
            ),
            const SizedBox(height: 8),
            ...live.ambulances.map(
              (a) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kAuthRedBadgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 18,
                      color: kAuthRed,
                    ),
                  ),
                  title: Text(
                    a.vehicleNumber,
                    style: text.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: kAuthText,
                    ),
                  ),
                  subtitle: Text(
                    'To: ${a.destination}',
                    style: text.copyWith(fontSize: 13, color: kAuthMuted),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${a.etaMinutes?.toStringAsFixed(0) ?? "?"} min',
                        style: text.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: kAuthRed,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      Text(
                        '${a.speedKmh?.toStringAsFixed(0) ?? "?"} km/h',
                        style: text.copyWith(
                          fontSize: 11,
                          color: kAuthFaint,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsPage(BuildContext context, NotificationProvider notifs) {
    final text = GoogleFonts.inter();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: const FrostedAppBarBackdrop(),
        shape: const Border(bottom: BorderSide(color: kAuthBorder)),
        title: Text(
          'Alerts',
          style: text.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: kAuthText,
          ),
        ),
      ),
      body: GlassBackdrop(
        child: notifs.loading
            ? const SkeletonList(itemCount: 6)
            : notifs.notifications.isEmpty
                ? const AuthEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No alerts yet',
                    hint: 'Emergency alerts appear here as soon as a driver '
                        'starts a trip.',
                  )
                : RefreshIndicator(
                    onRefresh: notifs.load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: notifs.notifications.length,
                      itemBuilder: (_, i) {
                        final n = notifs.notifications[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: n.isAcknowledged
                              ? null
                              : Theme.of(context).colorScheme.errorContainer,
                          child: ListTile(
                            leading: Icon(
                              Icons.emergency_rounded,
                              color: n.isAcknowledged
                                  ? Theme.of(context).colorScheme.outline
                                  : kAuthRed,
                            ),
                            title: Text(
                              n.title,
                              style: text.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: kAuthText,
                              ),
                            ),
                            subtitle: Text(
                              n.message,
                              style: text.copyWith(
                                fontSize: 13,
                                color: kAuthMuted,
                              ),
                            ),
                            trailing: _alertActions(
                              context,
                              notifs,
                              n,
                              text,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _alertActions(
    BuildContext context,
    NotificationProvider notifs,
    NotificationModel n,
    TextStyle text,
  ) {
    if (n.isAcknowledged) {
      final isEmergency = n.notificationType == 'emergency_alert';
      final action = n.acknowledgment ?? (isEmergency ? 'ack' : 'ack');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: action == 'accept'
              ? kAuthGreen.withValues(alpha: 0.12)
              : action == 'reject'
                  ? kAuthRed.withValues(alpha: 0.1)
                  : kAuthBorder.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          action == 'accept'
              ? 'Accepted'
              : action == 'reject'
                  ? 'Rejected'
                  : 'Acknowledged',
          style: text.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: action == 'accept'
                ? kAuthGreen
                : action == 'reject'
                    ? kAuthRed
                    : kAuthMuted,
          ),
        ),
      );
    }

    if (n.notificationType == 'emergency_alert') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => notifs.acknowledge(n.id, action: 'accept'),
            style: TextButton.styleFrom(
              foregroundColor: kAuthGreen,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Accept',
              style: text.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kAuthGreen,
              ),
            ),
          ),
          TextButton(
            onPressed: () => notifs.acknowledge(n.id, action: 'reject'),
            style: TextButton.styleFrom(
              foregroundColor: kAuthRed,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Reject',
              style: text.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kAuthRed,
              ),
            ),
          ),
        ],
      );
    }

    return TextButton(
      onPressed: () => notifs.acknowledge(n.id),
      style: TextButton.styleFrom(
        foregroundColor: kAuthRedLink,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'ACK',
        style: text.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _greetingPrefix(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _actionCard(
    TextStyle text, {
    required IconData icon,
    required Color iconColor,
    required Color tint,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassSurface(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: text.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kAuthText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: text.copyWith(fontSize: 11, color: kAuthFaint),
            ),
          ],
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
            Container(
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
}
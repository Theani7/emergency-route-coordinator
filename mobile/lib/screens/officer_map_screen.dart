import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import '../models/live_ambulance_model.dart';
import '../providers/junction_provider.dart';
import '../providers/live_ambulance_provider.dart';
import '../services/junction_service.dart';
import '../services/gps_service.dart';
import '../utils/route_utils.dart';
import '../widgets/ambulance_map.dart';
import '../widgets/auth_widgets.dart';

class OfficerMapScreen extends StatefulWidget {
  const OfficerMapScreen({super.key});

  @override
  State<OfficerMapScreen> createState() => _OfficerMapScreenState();
}

class _OfficerMapScreenState extends State<OfficerMapScreen> {
  LiveAmbulanceModel? _selected;
  JunctionPoint? _selectedJunction;
  bool _showRoutePanel = false;
  double? _officerLat;
  double? _officerLon;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JunctionProvider>().loadKathmanduJunctions();
      _startLocationTracking();
    });
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final position = await GpsTrackingService.bestPosition();
      if (position != null && mounted) {
        setState(() {
          _officerLat = position.latitude;
          _officerLon = position.longitude;
        });
      }
    } catch (_) {}
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _updateCurrentLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _updateCurrentLocation();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveAmbulanceProvider>();
    final junctions = context.watch<JunctionProvider>();
    final ambulances = live.ambulances;

    if (_selected != null &&
        !ambulances.any((a) => a.ambulanceId == _selected!.ambulanceId)) {
      _selected = null;
    }
    final selected =
        _selected ?? (ambulances.isNotEmpty ? ambulances.first : null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    AmbulanceMap(
                      ambulanceLat: selected?.latitude,
                      ambulanceLon: selected?.longitude,
                      destLat: selected?.destLat,
                      destLon: selected?.destLon,
                      routePolyline: selected?.routePolyline,
                      officerLat: _officerLat,
                      officerLon: _officerLon,
                      currentLocationLat: _officerLat,
                      currentLocationLon: _officerLon,
                      showCurrentLocation: true,
                      showTrafficOverlay: true,
                      extraAmbulances: ambulances
                          .where(
                              (a) => a.ambulanceId != selected?.ambulanceId)
                          .map(
                            (a) => LiveAmbulanceMarker(
                              lat: a.latitude,
                              lon: a.longitude,
                              label: a.vehicleNumber,
                              routePolyline: a.routePolyline,
                              destLat: a.destLat,
                              destLon: a.destLon,
                            ),
                          )
                          .toList(),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassSurface(
                            radius: 14,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: kAuthRedBadgeBg,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.map_rounded,
                                    size: 16,
                                    color: kAuthRedLink,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live map',
                                      style: GoogleFonts.inter().copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: kAuthText,
                                      ),
                                    ),
                                    Text(
                                      ambulances.isEmpty
                                          ? 'No active ambulances'
                                          : '${ambulances.length} ambulance'
                                              '${ambulances.length == 1 ? '' : 's'} active',
                                      style: GoogleFonts.inter().copyWith(
                                        fontSize: 11,
                                        color: ambulances.isEmpty
                                            ? kAuthMuted
                                            : kAuthFaint,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_officerLat != null && _officerLon != null) ...[
                            const SizedBox(height: 8),
                            GlassSurface(
                              radius: 14,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: kAuthBlueTint,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(
                                      Icons.my_location_rounded,
                                      size: 16,
                                      color: kAuthBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your location',
                                        style: GoogleFonts.inter().copyWith(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: kAuthText,
                                        ),
                                      ),
                                      Text(
                                        '${_officerLat!.toStringAsFixed(4)}, '
                                        '${_officerLon!.toStringAsFixed(4)}',
                                        style: GoogleFonts.inter().copyWith(
                                          fontSize: 11,
                                          color: kAuthFaint,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            GlassSurface(
                              radius: 14,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kAuthBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Acquiring GPS...',
                                    style: GoogleFonts.inter().copyWith(
                                      fontSize: 11,
                                      color: kAuthFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected != null) ...[
                            Material(
                              color: kAuthCard,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: kAuthBorder),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _showRoutePanel = !_showRoutePanel;
                                  });
                                },
                                customBorder: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    _showRoutePanel
                                        ? Icons.close_rounded
                                        : Icons.route_rounded,
                                    size: 20,
                                    color: kAuthMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Material(
                            color: kAuthCard,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: kAuthBorder),
                            ),
                            child: InkWell(
                              onTap: live.refresh,
                              customBorder: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                  color: kAuthMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (live.error != null)
                      Positioned(
                        top: 66,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: kAuthOrangeTint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kAuthOrange.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: kAuthOrange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  live.error!,
                                  style: GoogleFonts.inter().copyWith(
                                    fontSize: 12.5,
                                    color: kAuthText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_showRoutePanel && selected != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildRouteControlPanel(selected, junctions),
                      ),
                  ],
                ),
              ),
              if (ambulances.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: ambulances.length,
                    itemBuilder: (_, i) {
                      final a = ambulances[i];
                      final isSelected = selected?.ambulanceId == a.ambulanceId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _ambulanceChip(a, isSelected),
                      );
                    },
                  ),
                ),
              ],
              if (selected != null && !_showRoutePanel)
                _buildDirectionsCard(selected),
              if (!_showRoutePanel)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                  child: GlassSurface(
                    radius: 16,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        DropdownButtonFormField<JunctionPoint>(
                          initialValue: _selectedJunction,
                          decoration: const InputDecoration(
                            labelText: 'Kathmandu junction to clear',
                            border: OutlineInputBorder(),
                          ),
                          items: junctions.junctions
                              .map(
                                (j) => DropdownMenuItem(
                                  value: j,
                                  child: Text(j.name),
                                ),
                              )
                              .toList(),
                          onChanged: (j) =>
                              setState(() => _selectedJunction = j),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: junctions.loading ||
                                    _selectedJunction == null
                                ? null
                                : () => context
                                    .read<JunctionProvider>()
                                    .clearJunction(
                                      junction: _selectedJunction!,
                                      emergencySessionId:
                                          selected?.emergencySessionId,
                                    ),
                            icon: const Icon(Icons.traffic_rounded),
                            label: const Text('Mark junction cleared'),
                          ),
                        ),
                        if (junctions.message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  junctions.message!.endsWith('marked cleared')
                                      ? Icons.check_circle_rounded
                                      : Icons.error_outline_rounded,
                                  size: 14,
                                  color: junctions.message!
                                          .endsWith('marked cleared')
                                      ? kAuthGreen
                                      : kAuthRed,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    junctions.message!,
                                    style: GoogleFonts.inter().copyWith(
                                      fontSize: 12,
                                      color: junctions.message!
                                              .endsWith('marked cleared')
                                          ? kAuthGreenText
                                          : kAuthRedBadgeText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ambulanceChip(LiveAmbulanceModel a, bool isSelected) {
    final text = GoogleFonts.inter();
    return InkWell(
      onTap: () => setState(() => _selected = a),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? kAuthRedBadgeBg : kAuthCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? kAuthRed : kAuthBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_shipping_rounded,
              size: 14,
              color: kAuthRed,
            ),
            const SizedBox(width: 6),
            Text(
              a.vehicleNumber,
              style: text.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isSelected ? kAuthRedBadgeText : kAuthMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionsCard(LiveAmbulanceModel a) {
    final text = GoogleFonts.inter();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GlassSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kAuthRedBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    size: 20,
                    color: kAuthRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${a.vehicleNumber} • EMERGENCY',
                        style: text.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: kAuthRedBadgeText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'To: ${a.destination}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.copyWith(
                          fontSize: 12.5,
                          color: kAuthMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: kAuthBorder.withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    text,
                    label: 'ETA',
                    value: '${formatEta(a.etaMinutes)} min',
                    color: kAuthBlue,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: kAuthBorder.withValues(alpha: 0.6),
                ),
                Expanded(
                  child: _statTile(
                    text,
                    label: 'Speed',
                    value: '${a.speedKmh?.toStringAsFixed(0) ?? "?"} km/h',
                    color: kAuthGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: kAuthFaint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Clear the route corridor and prioritize this '
                    'ambulance at intersections.',
                    style: text.copyWith(
                      fontSize: 12,
                      height: 1.35,
                      color: kAuthFaint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteControlPanel(
    LiveAmbulanceModel ambulance,
    JunctionProvider junctions,
  ) {
    final routePoints = parseRoutePolyline(ambulance.routePolyline);
    final totalDistance = _calculateRouteDistance(routePoints);
    final junctionsOnRoute =
        _findJunctionsOnRoute(junctions.junctions, routePoints);

    return GlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kAuthBlueTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  size: 18,
                  color: kAuthBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shortest route corridor',
                      style: GoogleFonts.inter().copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kAuthText,
                      ),
                    ),
                    Text(
                      '${totalDistance.toStringAsFixed(1)} km • ${routePoints.length} waypoints',
                      style: GoogleFonts.inter().copyWith(
                        fontSize: 11.5,
                        color: kAuthFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kAuthRedBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${formatEta(ambulance.etaMinutes)} min',
                  style: GoogleFonts.inter().copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kAuthRedBadgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Junctions to clear (${junctionsOnRoute.length})',
            style: GoogleFonts.inter().copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kAuthText,
            ),
          ),
          const SizedBox(height: 8),
          if (junctionsOnRoute.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: kAuthNeutralTint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'No junctions along this route',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter().copyWith(
                  fontSize: 12,
                  color: kAuthFaint,
                ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: junctionsOnRoute.map((j) {
                    final isSelected = _selectedJunction?.name == j.name;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedJunction = j),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? kAuthRedBadgeBg
                                : kAuthNeutralTint.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isSelected ? kAuthRed : kAuthBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.traffic_rounded,
                                size: 16,
                                color: isSelected
                                    ? kAuthRed
                                    : kAuthMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  j.name,
                                  style:
                                      GoogleFonts.inter().copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? kAuthRedBadgeText
                                            : kAuthText,
                                      ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: kAuthRed,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Selected',
                                    style: GoogleFonts.inter()
                                        .copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: junctions.loading || _selectedJunction == null
                  ? null
                  : () => context.read<JunctionProvider>().clearJunction(
                        junction: _selectedJunction!,
                        emergencySessionId: ambulance.emergencySessionId,
                      ),
              icon: junctions.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                junctions.loading
                    ? 'Clearing...'
                    : 'Mark selected junction cleared',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAuthRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (junctions.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    junctions.message!.endsWith('marked cleared')
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 14,
                    color: junctions.message!.endsWith('marked cleared')
                        ? kAuthGreen
                        : kAuthRed,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      junctions.message!,
                      style: GoogleFonts.inter().copyWith(
                        fontSize: 12,
                        color: junctions.message!.endsWith('marked cleared')
                            ? kAuthGreenText
                            : kAuthRedBadgeText,
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

  double _calculateRouteDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final dx = (a.longitude - b.longitude) * 111320 *
          _cosDeg((a.latitude + b.latitude) / 2);
      final dy = (a.latitude - b.latitude) * 110540;
      total += _sqrt(dx * dx + dy * dy);
    }
    return total / 1000;
  }

  List<JunctionPoint> _findJunctionsOnRoute(
    List<JunctionPoint> allJunctions,
    List<LatLng> routePoints,
  ) {
    if (routePoints.isEmpty || allJunctions.isEmpty) return [];
    const thresholdMeters = 500;
    return allJunctions.where((j) {
      for (final p in routePoints) {
        final dx = (p.longitude - j.lon) *
            111320 *
            _cosDeg((p.latitude + j.lat) / 2);
        final dy = (p.latitude - j.lat) * 110540;
        final dist = _sqrt(dx * dx + dy * dy);
        if (dist < thresholdMeters) return true;
      }
      return false;
    }).toList();
  }

  double _cosDeg(double deg) {
    const pi = 3.141592653589793;
    return _cos(deg * pi / 180);
  }

  double _cos(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  Widget _statTile(
    TextStyle text, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: text.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: text.copyWith(fontSize: 11, color: kAuthFaint),
        ),
      ],
    );
  }
}

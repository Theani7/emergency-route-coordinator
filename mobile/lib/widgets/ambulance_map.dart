
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import '../core/map_cache.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/kathmandu.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/traffic_service.dart';
import '../utils/route_utils.dart';

class AmbulanceMap extends StatefulWidget {
  final double? ambulanceLat;
  final double? ambulanceLon;
  final double? destLat;
  final double? destLon;
  final String? routePolyline;
  final List<LiveAmbulanceMarker> extraAmbulances;
  final bool showKathmanduHospitals;
  final bool showTrafficOverlay;
  final double? officerLat;
  final double? officerLon;
  final double? currentLocationLat;
  final double? currentLocationLon;
  final bool showCurrentLocation;
  final TileProvider? tileProvider;

  const AmbulanceMap({
    super.key,
    this.ambulanceLat,
    this.ambulanceLon,
    this.destLat,
    this.destLon,
    this.routePolyline,
    this.extraAmbulances = const [],
    this.showKathmanduHospitals = true,
    this.showTrafficOverlay = true,
    this.officerLat,
    this.officerLon,
    this.currentLocationLat,
    this.currentLocationLon,
    this.showCurrentLocation = false,
    this.tileProvider,
  });

  @override
  State<AmbulanceMap> createState() => _AmbulanceMapState();
}

class LiveAmbulanceMarker {
  final double lat;
  final double lon;
  final String label;
  final String? routePolyline;
  final double? destLat;
  final double? destLon;

  LiveAmbulanceMarker({
    required this.lat,
    required this.lon,
    required this.label,
    this.routePolyline,
    this.destLat,
    this.destLon,
  });
}

class _AmbulanceMapState extends State<AmbulanceMap>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<CircleMarker> _trafficCircles = [];
  bool _mapReady = false;
  Timer? _pulseTimer;
  double _pulseRadius = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitToContent();
      if (widget.showTrafficOverlay) _loadTraffic();
    });
    if (widget.showCurrentLocation) {
      _startPulseAnimation();
    }
  }

  void _startPulseAnimation() {
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) {
        setState(() {
          _pulseRadius = (_pulseRadius + 1.5) % 28;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  void centerOnCurrentLocation() {
    final lat = widget.currentLocationLat ?? widget.officerLat;
    final lon = widget.currentLocationLon ?? widget.officerLon;
    if (lat != null && lon != null) {
      try {
        _mapController.move(
          LatLng(lat, lon),
          16.0,
        );
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  Future<void> _loadTraffic() async {
    if (!mounted) return;
    try {
      final svc = TrafficService(context.read<ApiService>());
      final pts = await svc.fetchKathmanduTraffic();
      if (!mounted) return;
      final circles = pts.map((p) {
        final color = _colorForIndex(p.index);
        final radius = 18.0 + p.index * 32.0; // radius in pixels
        return CircleMarker(
          point: LatLng(p.lat, p.lon),
          color: color.withValues(alpha: 0.55),
          radius: radius,
          useRadiusInMeter: false,
        );
      }).toList();
      setState(() => _trafficCircles = circles);
    } catch (e) {
      debugPrint(e.toString());
      if (!mounted) return;
      setState(() => _trafficCircles = []);
    }
  }

  @override
  void didUpdateWidget(covariant AmbulanceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = widget.destLat != oldWidget.destLat ||
        widget.destLon != oldWidget.destLon ||
        widget.routePolyline != oldWidget.routePolyline ||
        widget.ambulanceLat != oldWidget.ambulanceLat ||
        widget.ambulanceLon != oldWidget.ambulanceLon;
    final locationFirstAcquired =
        (oldWidget.currentLocationLat == null && widget.currentLocationLat != null) ||
        (oldWidget.officerLat == null && widget.officerLat != null);

    if (routeChanged || (locationFirstAcquired && widget.ambulanceLat == null)) {
      _fitToContent();
    }
    if (widget.showTrafficOverlay && !oldWidget.showTrafficOverlay) {
      _loadTraffic();
    }
    if (widget.showCurrentLocation && _pulseTimer == null) {
      _startPulseAnimation();
    } else if (!widget.showCurrentLocation && _pulseTimer != null) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
    }
  }

  Future<void> _fitToContent() async {
    final points = <LatLng>[];
    if (widget.ambulanceLat != null && widget.ambulanceLon != null) {
      points.add(LatLng(widget.ambulanceLat!, widget.ambulanceLon!));
    }
    if (widget.destLat != null && widget.destLon != null) {
      points.add(LatLng(widget.destLat!, widget.destLon!));
    }
    for (final a in widget.extraAmbulances) {
      points.add(LatLng(a.lat, a.lon));
      if (a.destLat != null && a.destLon != null) {
        points.add(LatLng(a.destLat!, a.destLon!));
      }
    }
    final currentLat = widget.currentLocationLat ?? widget.officerLat;
    final currentLon = widget.currentLocationLon ?? widget.officerLon;
    if (points.isEmpty && currentLat != null && currentLon != null) {
      points.add(LatLng(currentLat, currentLon));
    }
    if (points.isEmpty) return;

    final center = LatLng(
      widget.ambulanceLat ??
          widget.destLat ??
          currentLat ??
          KathmanduLocation.centerLat,
      widget.ambulanceLon ??
          widget.destLon ??
          currentLon ??
          KathmanduLocation.centerLon,
    );

    const d = Distance();
    bool tooFar = false;
    for (final p in points) {
      if (d.as(LengthUnit.Meter, center, p) > 50000) {
        tooFar = true;
        break;
      }
    }

    for (var i = 0; i < 10 && !_mapReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted || !_mapReady) return;
    try {
      if (tooFar) {
        _mapController.move(center, 14);
        return;
      }
      if (points.length == 1) {
        _mapController.move(points.first, 15.5);
        return;
      }
      var minLat = points.first.latitude;
      var maxLat = points.first.latitude;
      var minLon = points.first.longitude;
      var maxLon = points.first.longitude;
      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(minLat, minLon),
            LatLng(maxLat, maxLon),
          ),
          padding: const EdgeInsets.all(48),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final routePoints = parseRoutePolyline(widget.routePolyline);
    final markers = <Marker>[];

    if (widget.ambulanceLat != null && widget.ambulanceLon != null) {
      markers.add(_marker(
        widget.ambulanceLat!,
        widget.ambulanceLon!,
        Icons.local_shipping,
        Colors.red,
        'Ambulance',
      ));
    }
    if (widget.destLat != null && widget.destLon != null) {
      markers.add(_marker(
        widget.destLat!,
        widget.destLon!,
        Icons.emergency,
        Colors.orange,
        'Incident',
      ));
    }

    for (final a in widget.extraAmbulances) {
      markers.add(
          _marker(a.lat, a.lon, Icons.local_shipping, Colors.red, a.label));
      if (a.destLat != null && a.destLon != null) {
        markers.add(_marker(
          a.destLat!,
          a.destLon!,
          Icons.emergency,
          Colors.orange,
          '${a.label} dest',
        ));
      }
    }
    if (widget.showKathmanduHospitals) {
      for (final h in kathmanduHospitals) {
        markers.add(
            _marker(h.lat, h.lon, Icons.local_hospital, Colors.green, h.name));
      }
    }

    final currentLat = widget.currentLocationLat ?? widget.officerLat;
    final currentLon = widget.currentLocationLon ?? widget.officerLon;

    if (!widget.showCurrentLocation &&
        widget.officerLat != null &&
        widget.officerLon != null) {
      markers.add(_marker(
        widget.officerLat!,
        widget.officerLon!,
        Icons.person_pin_circle,
        const Color(0xFF2E6FD8),
        'You',
      ));
    }

    final circles = <CircleMarker>[];
    if (widget.showCurrentLocation &&
        currentLat != null &&
        currentLon != null) {
      // Google Maps style pulsating accuracy aura
      circles.add(CircleMarker(
        point: LatLng(currentLat, currentLon),
        color: const Color(0xFF4285F4).withValues(alpha: 0.18),
        radius: 18 + _pulseRadius,
        useRadiusInMeter: false,
        borderStrokeWidth: 1.5,
        borderColor: const Color(0xFF4285F4).withValues(alpha: 0.4),
      ));
      // Outer crisp white ring
      circles.add(CircleMarker(
        point: LatLng(currentLat, currentLon),
        color: Colors.white,
        radius: 9.5,
        useRadiusInMeter: false,
      ));
      // Inner solid Google Blue core dot
      circles.add(CircleMarker(
        point: LatLng(currentLat, currentLon),
        color: const Color(0xFF1A73E8),
        radius: 7.0,
        useRadiusInMeter: false,
      ));
    }

    final polylines = <Polyline>[
      if (routePoints.isNotEmpty)
        Polyline(points: routePoints, color: Colors.red, strokeWidth: 5),
      for (final a in widget.extraAmbulances)
        if (parseRoutePolyline(a.routePolyline).isNotEmpty)
          Polyline(
            points: parseRoutePolyline(a.routePolyline),
            color: Colors.blue,
            strokeWidth: 4,
          ),
    ];

    final center = LatLng(
      widget.ambulanceLat ??
          widget.destLat ??
          currentLat ??
          KathmanduLocation.centerLat,
      widget.ambulanceLon ??
          widget.destLon ??
          currentLon ??
          KathmanduLocation.centerLon,
    );

    return SizedBox.expand(
      child: RepaintBoundary(
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
            minZoom: 10,
            maxZoom: 18,
            onMapReady: () => _mapReady = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ambulance.coordination',
              tileProvider:
                  widget.tileProvider ?? CachedTileProvider(store: mapCacheStore),
              errorTileCallback: (tile, error, stackTrace) {
                debugPrint('Tile load error: $error');
              },
            ),
            if ((widget.showTrafficOverlay && _trafficCircles.isNotEmpty) &&
                settings.showTrafficOverlay)
              CircleLayer(circles: _trafficCircles),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            if (circles.isNotEmpty) CircleLayer(circles: circles),
            MarkerLayer(markers: markers),
            if (widget.showCurrentLocation && (currentLat != null && currentLon != null))
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: centerOnCurrentLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A73E8),
                    elevation: 3,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _marker(
    double lat,
    double lon,
    IconData icon,
    Color color,
    String label,
  ) {
    return Marker(
      point: LatLng(lat, lon),
      width: 100,
      height: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _colorForIndex(double i) {
  // green (0) -> yellow (0.5) -> red (1)
  final clamped = i.clamp(0.0, 1.0);
  if (clamped < 0.5) {
    final t = clamped / 0.5;
    return Color.lerp(Colors.green, Colors.yellow, t)!;
  }
  final t = (clamped - 0.5) / 0.5;
  return Color.lerp(Colors.yellow, Colors.red, t)!;
}

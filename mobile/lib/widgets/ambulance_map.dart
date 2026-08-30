
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
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (mounted) {
          setState(() {
            _pulseRadius = (_pulseRadius + 2) % 30;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  void centerOnCurrentLocation() {
    if (widget.currentLocationLat != null &&
        widget.currentLocationLon != null) {
      _mapController.move(
        LatLng(widget.currentLocationLat!, widget.currentLocationLon!),
        15.0,
      );
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
        widget.routePolyline != oldWidget.routePolyline;
    if (routeChanged) _fitToContent();
    if (widget.showTrafficOverlay && !oldWidget.showTrafficOverlay) {
      _loadTraffic();
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
    if (points.isEmpty) return;

    final center = LatLng(
      widget.ambulanceLat ?? widget.destLat ?? KathmanduLocation.centerLat,
      widget.ambulanceLon ?? widget.destLon ?? KathmanduLocation.centerLon,
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
        _mapController.move(points.first, 16);
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

    if (widget.officerLat != null && widget.officerLon != null) {
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
        widget.currentLocationLat != null &&
        widget.currentLocationLon != null) {
      final lat = widget.currentLocationLat!;
      final lon = widget.currentLocationLon!;
      circles.add(CircleMarker(
        point: LatLng(lat, lon),
        color: const Color(0xFF4285F4).withValues(alpha: 0.3),
        radius: 20 + _pulseRadius,
        useRadiusInMeter: false,
        borderStrokeWidth: 2,
        borderColor: const Color(0xFF4285F4),
      ));
      circles.add(CircleMarker(
        point: LatLng(lat, lon),
        color: const Color(0xFF4285F4),
        radius: 8,
        useRadiusInMeter: false,
        borderStrokeWidth: 2,
        borderColor: Colors.white,
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
      widget.ambulanceLat ?? widget.destLat ?? KathmanduLocation.centerLat,
      widget.ambulanceLon ?? widget.destLon ?? KathmanduLocation.centerLon,
    );

    return SizedBox.expand(
      child: RepaintBoundary(
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            minZoom: 12,
            maxZoom: 18,
            onMapReady: () => _mapReady = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ambulance.coordination',
              tileProvider: CachedTileProvider(store: mapCacheStore),
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
            if (widget.showCurrentLocation)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FloatingActionButton.small(
                    heroTag: 'my_location',
                    onPressed: centerOnCurrentLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4285F4),
                    child: const Icon(Icons.my_location),
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
      width: 80,
      height: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
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

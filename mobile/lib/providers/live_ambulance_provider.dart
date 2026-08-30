import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/live_ambulance_model.dart';
import '../services/api_service.dart';
import '../services/gps_service.dart';

class LiveAmbulanceProvider extends ChangeNotifier {
  final ApiService _api;

  List<LiveAmbulanceModel> _ambulances = [];
  bool _loading = false;
  bool _isRefreshing = false;
  String? _error;
  Timer? _pollTimer;

  LiveAmbulanceProvider(this._api);

  List<LiveAmbulanceModel> get ambulances => _ambulances;
  bool get loading => _loading;
  String? get error => _error;

  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    _pollTimer?.cancel();
    refresh();
    _pollTimer = Timer.periodic(interval, (_) => refresh());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.get('/api/v1/gps/live');
      final list = (res.data as List)
          .map((e) => LiveAmbulanceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _ambulances = list;
      _error = null;
    } catch (e) {
      _error = 'Could not load live ambulances';
    }
    _loading = false;
    _isRefreshing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

class DriverLocationProvider extends ChangeNotifier {
  final GpsTrackingService _gpsService;

  double? _lat;
  double? _lon;
  double? _heading;
  double? _speedKmh;
  StreamSubscription<Position>? _sub;
  Timer? _refreshTimer;

  DriverLocationProvider(this._gpsService);

  double? get lat => _lat;
  double? get lon => _lon;
  double? get heading => _heading;
  double? get speedKmh => _speedKmh;
  bool get hasPosition => _lat != null && _lon != null;

  Future<bool> init() async {
    final ok = await _gpsService.requestPermission();
    if (!ok) return false;
    try {
      final pos = await _gpsService.getCurrentPosition();
      if (pos == null) return false;
      _lat = pos.latitude;
      _lon = pos.longitude;
      _heading = pos.heading;
      _speedKmh = pos.speed * 3.6;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startTracking(int sessionId, {VoidCallback? onTick}) async {
    final ok = await _gpsService.startTracking(sessionId);
    _sub?.cancel();
    if (ok) {
      _sub = _gpsService.positionStream.listen((pos) {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _heading = pos.heading;
        _speedKmh = pos.speed * 3.6;
        notifyListeners();
      });
    }
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (ok) {
      _refreshTimer =
          Timer.periodic(const Duration(seconds: 8), (_) => onTick?.call());
    }
    return ok;
  }

  void stopTracking() {
    _gpsService.stopTracking();
    _sub?.cancel();
    _sub = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopTracking();
    _gpsService.dispose();
    super.dispose();
  }
}

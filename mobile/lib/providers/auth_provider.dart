import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/live_service.dart';
import '../services/server_config_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ServerConfigService _serverConfig;
  final LiveService _liveService;
  UserModel? _user;
  bool _loading = false;
  String? _error;

  AuthProvider(this._authService, this._serverConfig, this._liveService);

  Future<void> configureServer(String url) async {
    await _serverConfig.saveApiBaseUrl(url);
    _authService.setBaseUrl(await _serverConfig.getApiBaseUrl());
  }

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null && _user?.token != null;
  bool get loading => _loading;
  String? get error => _error;
  String? get errorMessage => _error;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    _user = await _authService.autoLogin();
    _loading = false;
    notifyListeners();
    if (_user != null) _connectLive();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await _authService.login(email, password);
      if (user.role == UserRole.admin) {
        await _authService.logout();
        _error =
            'Admin accounts use the web dashboard. Use driver or officer credentials here.';
        _loading = false;
        notifyListeners();
        return false;
      }
      _user = user;
      _loading = false;
      notifyListeners();
      _connectLive();
      return true;
    } on DioException catch (e) {
      _error = _messageForDioError(e);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Login failed. Check credentials and try again.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? vehicleNumber,
    String? assignedZone,
    String? otp,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        vehicleNumber: vehicleNumber,
        assignedZone: assignedZone,
        otp: otp,
      );
      _loading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _messageForRegisterError(e);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  String _messageForRegisterError(DioException e) {
    final data = e.response?.data;
    // Backend returns {"detail":"..."} or {"detail":"...","errors":[...]}
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'].toString();
      // Show first validation error if present for field-level clarity
      if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
        final first = (data['errors'] as List).first;
        if (first is Map && first['msg'] != null) {
          final loc = (first['loc'] is List) ? (first['loc'] as List).last.toString() : '';
          return loc.isNotEmpty ? '$loc: ${first['msg']}' : first['msg'].toString();
        }
      }
      return detail;
    }
    if (data is String && data.isNotEmpty) return data;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      final baseUrl = _authService.baseUrl;
      if (baseUrl.contains('10.0.2.2')) {
        return 'Cannot reach server at $baseUrl. On physical phone use your PC IP (e.g. http://192.168.1.79:8000). Check Server Settings (top-right icon).';
      }
      return 'Cannot reach server at $baseUrl. Check Server URL, ensure backend is running (http://localhost:8000/health), and phone/PC are on same Wi-Fi.';
    }
    if (e.response?.statusCode == 400) return data?.toString() ?? 'Registration failed (400). Check email/vehicle format.';
    if (e.response?.statusCode == 422) {
      // Fallback for validation errors without detail map
      return 'Validation failed: ${data?.toString() ?? e.message}';
    }
    return 'Registration failed (${e.response?.statusCode ?? e.type.name}): ${e.message}';
  }

  String _messageForDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    if (data is String && data.isNotEmpty) {
      return data;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      final baseUrl = _authService.baseUrl;
      if (baseUrl.contains('10.0.2.2')) {
        return 'Cannot reach the server at $baseUrl. '
            'On a physical phone, set Server URL to your PC IP, e.g. '
            'http://192.168.18.88:8000';
      }
      return 'Cannot reach the server at $baseUrl. '
          'Check the Server URL, ensure the backend is running, and use the same Wi‑Fi.';
    }
    if (e.response?.statusCode == 401) {
      return 'Invalid email or password.';
    }
    if (e.response?.statusCode == 403) {
      return 'Your account is pending administrator approval or access was denied.';
    }
    if (e.response?.statusCode == 429) {
      return 'Too many login attempts. Please try again later.';
    }
    return 'Login failed (${e.response?.statusCode ?? e.type.name}).';
  }

  Future<void> logout() async {
    _liveService.disconnect();
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  void _connectLive() async {
    final user = _user;
    if (user == null || user.token == null) return;
    _liveService.connect(
      baseUrl: _authService.baseUrl,
      token: user.token!,
      channel: user.role.name,
    );

    // Register FCM token for push notifications (Skip on Web for now)
    if (!kIsWeb) {
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _authService.registerFcmToken(fcmToken);
        }
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          _authService.registerFcmToken(newToken);
        });
      } catch (e) {
        // Ignored if firebase fails to initialize or get token
      }
    }
  }

  Future<bool> updateAmbulanceStatus(String status) async {
    try {
      await _authService.updateAmbulanceStatus(status);
      return true;
    } catch (e) {
      return false;
    }
  }

  void setError(String msg) {
    _error = msg;
    _loading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> updateLocalName(String name) async {
    final user = _user;
    if (user == null) return;
    _user = UserModel(
      id: user.id,
      name: name,
      email: user.email,
      role: user.role,
      token: user.token,
    );
    await _authService.saveName(name);
    notifyListeners();
  }
}

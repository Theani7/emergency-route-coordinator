import 'package:flutter/foundation.dart';

/// API and app constants.
class AppConstants {
  /// Compile-time override: `flutter run --dart-define=API_BASE_URL=http://...`
  static const String compileTimeBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// Production server URL
  static const String productionBaseUrl = 'https://sajiloroute-api.onrender.com';

  /// Local development server URL
  static const String localBaseUrl = 'http://localhost:8000';

  static String get defaultBaseUrl {
    if (compileTimeBaseUrl.isNotEmpty) {
      return compileTimeBaseUrl;
    }
    if (kIsWeb || kDebugMode) {
      return localBaseUrl;
    }
    return productionBaseUrl;
  }

  static String get wsUrl {
    const compileTimeWs = String.fromEnvironment('WS_BASE_URL');
    if (compileTimeWs.isNotEmpty) {
      return compileTimeWs;
    }
    if (kIsWeb || kDebugMode) {
      return 'ws://localhost:8000';
    }
    return 'wss://sajiloroute-api.onrender.com';
  }

  static const String tokenKey = 'access_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String userNameKey = 'user_name';

  static const Duration gpsInterval = Duration(seconds: 5);
}

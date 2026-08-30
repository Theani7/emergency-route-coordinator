import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

class ServerConfigService {
  static const String apiUrlKey = 'api_base_url';

  Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(apiUrlKey);
    if (saved != null &&
        saved.isNotEmpty &&
        !saved.contains('10.0.2.2') &&
        !(kIsWeb && saved.contains('sajiloroute-api.onrender.com'))) {
      return _normalizeHttpUrl(saved);
    }
    return AppConstants.defaultBaseUrl;
  }

  Future<void> saveApiBaseUrl(String url) async {
    final normalized = _normalizeHttpUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiUrlKey, normalized);
  }

  String _normalizeHttpUrl(String url) {
    var value = url.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    return value;
  }
}

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;
  AuthService(this._api);

  String get baseUrl => _api.baseUrl;

  void setBaseUrl(String url) => _api.setBaseUrl(url);

  Future<void> registerFcmToken(String token) async {
    try {
      await _api.patch('/api/v1/profile/me', data: {'fcm_token': token});
    } catch (e) {
      // Ignore failure, we just won't get push notifications
    }
  }

  Future<UserModel> login(String email, String password) async {
    final res = await _api.post('/api/v1/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    final user = UserModel(
      id: data['user_id'] ?? data['id'],
      name: data['name'] ?? '',
      email: email,
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'].toString().toLowerCase(),
        orElse: () => UserRole.driver,
      ),
      token: data['access_token'],
    );
    _api.setToken(user.token);
    await _saveSession(user);
    return user;
  }

  Future<void> sendSignupOtp({required String email, String? name}) async {
    await _api.post('/api/v1/auth/send-signup-otp', data: {'email': email, if (name != null) 'name': name});
  }

  Future<void> verifySignupOtp({required String email, required String otp}) async {
    await _api.post('/api/v1/auth/verify-signup-otp', data: {'email': email, 'otp': otp});
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? vehicleNumber,
    String? assignedZone,
    String? otp,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    };
    if (vehicleNumber != null) data['vehicle_number'] = vehicleNumber;
    if (assignedZone != null) data['assigned_zone'] = assignedZone;
    if (otp != null) data['otp'] = otp;

    await _api.post('/api/v1/auth/register', data: data);

    final loginRes = await _api.post('/api/v1/auth/login', data: {
      'email': email,
      'password': password,
    });
    final loginData = loginRes.data as Map<String, dynamic>;
    final user = UserModel(
      id: loginData['user_id'] ?? loginData['id'],
      name: loginData['name'] ?? name,
      email: email,
      role: UserRole.values.firstWhere(
        (r) => r.name == loginData['role'].toString().toLowerCase(),
        orElse: () => UserRole.driver,
      ),
      token: loginData['access_token'],
    );
    _api.setToken(user.token);
    await _saveSession(user);
    return user;
  }

  Future<UserModel?> autoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    if (token == null) return null;
    _api.setToken(token);
    try {
      final res = await _api.get('/api/v1/auth/me');
      final data = res.data as Map<String, dynamic>;
      return UserModel(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        role: UserRole.values.firstWhere(
          (r) => r.name == data['role'].toString().toLowerCase(),
          orElse: () => UserRole.driver,
        ),
        token: token,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userRoleKey);
    await prefs.remove(AppConstants.userNameKey);
  }

  Future<void> updateAmbulanceStatus(String status) async {
    await _api.patch('/api/v1/ambulances/me/status', data: {'status': status});
  }

  Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userNameKey, name);
  }

  Future<void> forgotPassword(String email) async {
    await _api.post('/api/v1/auth/forgot-password', data: {'email': email});
  }

  Future<void> verifyOtp(String email, String otp) async {
    await _api.post('/api/v1/auth/verify-otp', data: {'email': email, 'otp': otp});
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    await _api.post('/api/v1/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  Future<void> _saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, user.token!);
    await prefs.setInt(AppConstants.userIdKey, user.id);
    await prefs.setString(AppConstants.userRoleKey, user.role.name);
    await prefs.setString(AppConstants.userNameKey, user.name);
  }
}

import 'dart:io';
import 'package:ambulance_coordination/models/user_model.dart';
import 'package:ambulance_coordination/providers/auth_provider.dart';
import 'package:ambulance_coordination/services/api_service.dart';
import 'package:ambulance_coordination/services/auth_service.dart';
import 'package:ambulance_coordination/services/live_service.dart';
import 'package:ambulance_coordination/services/server_config_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class FakeAuthService extends AuthService {
  FakeAuthService(super.api);

  UserModel? loginResult;
  Exception? loginException;
  UserModel? registerResult;
  Exception? registerException;

  @override
  String get baseUrl => 'http://localhost:8000';

  @override
  Future<UserModel> login(String email, String password) async {
    if (loginException != null) {
      throw loginException!;
    }
    return loginResult ??
        UserModel(
          id: 1,
          name: 'Test Driver',
          email: email,
          role: UserRole.driver,
          token: 'token_123',
        );
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? vehicleNumber,
    String? assignedZone,
    String? otp,
  }) async {
    if (registerException != null) {
      throw registerException!;
    }
    return registerResult ??
        UserModel(
          id: 2,
          name: name,
          email: email,
          role: UserRole.driver,
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthService fakeAuthService;
  late ServerConfigService serverConfig;
  late LiveService liveService;
  late AuthProvider authProvider;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_auth_test');
    Hive.init(tempDir.path);
    await Hive.openBox('offline_queue');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() {
    fakeAuthService = FakeAuthService(ApiService());
    serverConfig = ServerConfigService();
    liveService = LiveService();
    authProvider = AuthProvider(fakeAuthService, serverConfig, liveService);
  });

  group('AuthProvider Approval & Error Handling Tests', () {
    test('login preserves 403 pending approval error message', () async {
      fakeAuthService.loginException = DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          statusCode: 403,
          data: {'detail': 'Your account is pending administrator approval.'},
        ),
      );

      final success = await authProvider.login('pending@user.com', 'password123');

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.error, 'Your account is pending administrator approval.');
      expect(authProvider.errorMessage, 'Your account is pending administrator approval.');
    });

    test('login preserves 403 rejected account error message', () async {
      fakeAuthService.loginException = DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          statusCode: 403,
          data: {'detail': 'Your registration request was rejected by an administrator.'},
        ),
      );

      final success = await authProvider.login('rejected@user.com', 'password123');

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.error, 'Your registration request was rejected by an administrator.');
    });

    test('login handles 401 invalid credentials', () async {
      fakeAuthService.loginException = DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          statusCode: 401,
          data: {'detail': 'Invalid email or password'},
        ),
      );

      final success = await authProvider.login('driver@test.com', 'wrongpass');

      expect(success, isFalse);
      expect(authProvider.error, 'Invalid email or password');
    });

    test('successful registration completes without authenticating (pending approval)', () async {
      final success = await authProvider.register(
        name: 'New Driver',
        email: 'newdriver@test.com',
        password: 'password123',
        role: 'driver',
        vehicleNumber: 'BA 2 PA 1234',
        otp: '123456',
      );

      expect(success, isTrue);
      // User is not authenticated yet because account requires admin approval
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.error, isNull);
    });

    test('registration failure captures error message', () async {
      fakeAuthService.registerException = DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/register'),
          statusCode: 400,
          data: {'detail': 'vehicle_number already registered'},
        ),
      );

      final success = await authProvider.register(
        name: 'Duplicate Driver',
        email: 'dup@test.com',
        password: 'password123',
        role: 'driver',
        vehicleNumber: 'BA 2 PA 1234',
      );

      expect(success, isFalse);
      expect(authProvider.error, 'vehicle_number already registered');
    });
  });
}

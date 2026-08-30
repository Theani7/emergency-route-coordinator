import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'package:ambulance_coordination/screens/signup_otp_screen.dart';
import 'package:ambulance_coordination/screens/registration_pending_screen.dart';
import 'package:ambulance_coordination/services/api_service.dart';
import 'package:ambulance_coordination/services/auth_service.dart';
import 'package:ambulance_coordination/services/live_service.dart';
import 'package:ambulance_coordination/services/server_config_service.dart';
import 'package:ambulance_coordination/providers/auth_provider.dart';
import 'package:ambulance_coordination/models/user_model.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService(super.api);

  bool verifyOtpCalled = false;
  bool registerCalled = false;
  String? verifyError;
  String? registerError;

  @override
  String get baseUrl => 'http://localhost:8000';

  @override
  Future<void> verifySignupOtp({required String email, required String otp}) async {
    verifyOtpCalled = true;
    if (verifyError != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/verify-signup-otp'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/verify-signup-otp'),
          statusCode: 400,
          data: {'detail': verifyError},
        ),
      );
    }
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
    registerCalled = true;
    if (registerError != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/register'),
          statusCode: 400,
          data: {'detail': registerError},
        ),
      );
    }
    return UserModel(
      id: 1,
      name: name,
      email: email,
      role: UserRole.driver,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeAuthService fakeAuthService;
  late ServerConfigService serverConfig;
  late LiveService liveService;
  late AuthProvider authProvider;
  late ApiService apiService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_signup_otp_test');
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
    apiService = ApiService();
    fakeAuthService = _FakeAuthService(apiService);
    serverConfig = ServerConfigService();
    liveService = LiveService();
    authProvider = AuthProvider(fakeAuthService, serverConfig, liveService);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<AuthService>.value(value: fakeAuthService),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const MaterialApp(
        home: SignupOtpScreen(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'password123',
          role: 'driver',
          vehicleNumber: 'BA-2-CHA-9999',
        ),
      ),
    );
  }

  group('SignupOtpScreen Tests', () {
    testWidgets('renders OTP entry elements and email target', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('jane@example.com')), findsOneWidget);
      expect(find.text('Verify & Create Account'), findsOneWidget);
    });

    testWidgets('shows validation error when entering incomplete OTP', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      final button = find.text('Verify & Create Account');
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Enter 6-digit OTP'), findsOneWidget);
    });

    testWidgets('successful OTP verification and registration navigates to RegistrationPendingScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '123456');
      await tester.pumpAndSettle();

      expect(fakeAuthService.verifyOtpCalled, isTrue);
      expect(fakeAuthService.registerCalled, isTrue);
      expect(find.byType(RegistrationPendingScreen), findsOneWidget);
      expect(find.text('Registration Submitted'), findsOneWidget);
    });

    testWidgets('displays error message when verification fails with detailed reason', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeAuthService.verifyError = 'Invalid OTP. 4 attempts left.';

      await tester.pumpWidget(createWidgetUnderTest());

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '123456');
      await tester.pumpAndSettle();

      expect(fakeAuthService.verifyOtpCalled, isTrue);
      expect(find.text('Invalid OTP. 4 attempts left.'), findsOneWidget);
    });
  });
}

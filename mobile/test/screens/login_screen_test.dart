import 'dart:io';
import 'package:ambulance_coordination/models/user_model.dart';
import 'package:ambulance_coordination/providers/auth_provider.dart';
import 'package:ambulance_coordination/screens/login_screen.dart';
import 'package:ambulance_coordination/services/api_service.dart';
import 'package:ambulance_coordination/services/auth_service.dart';
import 'package:ambulance_coordination/services/live_service.dart';
import 'package:ambulance_coordination/services/server_config_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService(super.api);

  DioException? loginError;

  @override
  String get baseUrl => 'http://localhost:8000';

  @override
  Future<UserModel> login(String email, String password) async {
    if (loginError != null) {
      throw loginError!;
    }
    return UserModel(
      id: 1,
      name: 'Driver 1',
      email: email,
      role: UserRole.driver,
      token: 'tok_123',
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

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_login_test');
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
    fakeAuthService = _FakeAuthService(ApiService());
    serverConfig = ServerConfigService();
    liveService = LiveService();
    authProvider = AuthProvider(fakeAuthService, serverConfig, liveService);
  });

  Widget createLoginWidget() {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('LoginScreen Pending/Rejected Approval Flow Tests', () {
    testWidgets('shows Account Pending Approval dialog on 403 pending error',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeAuthService.loginError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          statusCode: 403,
          data: {'detail': 'Your account is pending administrator approval.'},
        ),
      );

      await tester.pumpWidget(createLoginWidget());

      // Enter email and password
      final emailFields = find.byType(TextFormField);
      expect(emailFields, findsNWidgets(2));

      await tester.enterText(emailFields.at(0), 'pending@driver.org');
      await tester.enterText(emailFields.at(1), 'securepass123');
      await tester.pump();

      // Tap Sign In
      final signInBtn = find.text('Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('Account Pending Approval'), findsOneWidget);
      expect(
        find.textContaining('currently pending administrator approval'),
        findsOneWidget,
      );
      expect(find.text('View Status'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('shows Registration Rejected dialog on 403 rejected error',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeAuthService.loginError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          statusCode: 403,
          data: {
            'detail':
                'Your registration request was rejected by an administrator.'
          },
        ),
      );

      await tester.pumpWidget(createLoginWidget());

      final emailFields = find.byType(TextFormField);
      await tester.enterText(emailFields.at(0), 'rejected@driver.org');
      await tester.enterText(emailFields.at(1), 'securepass123');
      await tester.pump();

      final signInBtn = find.text('Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Verify rejection dialog
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Registration Rejected'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('rejected by an administrator'),
        ),
        findsOneWidget,
      );
      expect(find.text('OK'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/junction_provider.dart';
import 'providers/live_ambulance_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/driver_home_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/registration_pending_screen.dart';
import 'screens/officer_home_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/ai_service.dart';
import 'services/chat_service.dart';
import 'services/emergency_service.dart';
import 'services/gps_service.dart';
import 'services/junction_service.dart';
import 'services/live_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/server_config_service.dart';
import 'providers/settings_provider.dart';

import 'screens/splash_screen.dart';

import 'core/map_cache.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options (gency-fd12f)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize Google Sign-In for mobile (skip web to avoid DWDS hang - see firebase-auth skill)
    if (!kIsWeb) {
      await GoogleSignIn.instance.initialize();
    }
    // Request permission for iOS (Android 13+ will prompt automatically)
    if (!kIsWeb) {
      await FirebaseMessaging.instance.requestPermission();
    }
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  await Hive.initFlutter();
  await Hive.openBox('offline_queue');
  await initMapCache();
  final api = ApiService();
  final serverConfig = ServerConfigService();
  api.setBaseUrl(await serverConfig.getApiBaseUrl());
  runApp(AmbulanceApp(api: api, serverConfig: serverConfig));
}

class AmbulanceApp extends StatefulWidget {
  const AmbulanceApp(
      {super.key, required this.api, required this.serverConfig});

  final ApiService api;
  final ServerConfigService serverConfig;

  @override
  State<AmbulanceApp> createState() => _AmbulanceAppState();
}

class _AmbulanceAppState extends State<AmbulanceApp> {
  late final GpsTrackingService _gpsService = GpsTrackingService(widget.api);
  late final _authService = AuthService(widget.api);
  late final LiveService _liveService = LiveService();
  late final _authProvider =
      AuthProvider(_authService, widget.serverConfig, _liveService);
  late final _profileService = ProfileService(widget.api);
  bool _splashMinDurationElapsed = false;

  late final _router = GoRouter(
    initialLocation: '/',
    refreshListenable: _authProvider,
    redirect: (context, state) {
      if (_authProvider.loading || !_splashMinDurationElapsed) return null;
      final loggedIn = _authProvider.isAuthenticated;
      final path = state.matchedLocation;
      if (!loggedIn) {
        if (path == '/login' || path == '/register' || path == '/pending' || path == '/forgot-password') return null;
        return '/login';
      }
      if (path == '/login' || path == '/register' || path == '/pending' || path == '/forgot-password' || path == '/') {
        final role = _authProvider.user?.role;
        if (role == UserRole.driver) return '/driver';
        if (role == UserRole.officer) return '/officer';
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PremiumSplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/pending',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RegistrationPendingScreen(
            name: extra?['name'] as String? ?? '',
            email: extra?['email'] as String? ?? '',
            role: extra?['role'] as String? ?? '',
          );
        },
      ),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/driver', builder: (_, __) => const DriverHomeScreen()),
      GoRoute(path: '/officer', builder: (_, __) => const OfficerHomeScreen()),
    ],
  );

  @override
  void initState() {
    super.initState();
    widget.api.onUnauthorized = () {
      _authProvider.logout();
    };
    _authProvider.init();

    // Enforce a minimum display duration for the splash screen animation to play out (2 seconds)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _splashMinDurationElapsed = true;
          // Trigger the router to re-evaluate after time elapsed
          // A tiny hack is to call notifyListeners on the auth provider if it's already done loading.
          if (!_authProvider.loading) {
            // Re-assigning router forces redirect evaluation since the router itself doesn't listen to `_splashMinDurationElapsed`
            _router.go(_router.routerDelegate.currentConfiguration.uri.toString());
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: widget.api),
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(
          create: (_) => EmergencyProvider(
            EmergencyService(widget.api),
            _gpsService,
            AiService(widget.api),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => DriverLocationProvider(_gpsService),
        ),
        ChangeNotifierProvider(
          create: (_) => LiveAmbulanceProvider(widget.api),
        ),
        ChangeNotifierProvider(
          create: (_) => JunctionProvider(JunctionService(widget.api)),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final notifProvider =
                NotificationProvider(NotificationApiService(widget.api));
            _liveService.onNotification = notifProvider.refresh;
            return notifProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final chatProvider = ChatProvider(ChatApiService(widget.api));
            _liveService.onChatMessage = chatProvider.refresh;
            return chatProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(_profileService),
        ),
      ],
      child: MaterialApp.router(
        title: 'Sajiloroute',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

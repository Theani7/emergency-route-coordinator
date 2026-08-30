import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:ambulance_coordination/core/map_cache.dart';
import 'package:ambulance_coordination/widgets/ambulance_map.dart';
import 'package:ambulance_coordination/providers/settings_provider.dart';

final _kTransparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _TestTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_kTransparentPng);
  }
}

void main() {
  setUpAll(() {
    try {
      mapCacheStore = MemCacheStore();
    } catch (_) {}
  });

  testWidgets('AmbulanceMap renders with current location and my_location button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: AmbulanceMap(
              tileProvider: _TestTileProvider(),
              showTrafficOverlay: false,
              showCurrentLocation: true,
              currentLocationLat: 27.7172,
              currentLocationLon: 85.3240,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));

    // Verify FlutterMap is rendered
    expect(find.byType(FlutterMap), findsOneWidget);

    // Verify My Location floating action button is present
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

    // Dispose widget cleanly
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('AmbulanceMap renders when no ambulance is active',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: AmbulanceMap(
              tileProvider: _TestTileProvider(),
              showTrafficOverlay: false,
              showCurrentLocation: true,
              officerLat: 27.7100,
              officerLon: 85.3200,
              currentLocationLat: 27.7100,
              currentLocationLon: 85.3200,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(FlutterMap), findsOneWidget);

    // Dispose widget cleanly
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}

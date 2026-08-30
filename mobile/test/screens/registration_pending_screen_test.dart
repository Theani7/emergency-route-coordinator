import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ambulance_coordination/screens/registration_pending_screen.dart';

void main() {
  group('RegistrationPendingScreen Widget Tests', () {
    testWidgets('renders all details for a registered driver', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationPendingScreen(
            name: 'Ram Bahadur',
            email: 'ram@ambulance.com',
            role: 'driver',
          ),
        ),
      );

      // Verify title & subtitle
      expect(find.text('Registration Submitted'), findsOneWidget);
      expect(
        find.textContaining('pending administrator confirmation'),
        findsOneWidget,
      );

      // Verify status pill badge
      expect(find.text('PENDING APPROVAL'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);

      // Verify details
      expect(find.text('Ram Bahadur'), findsOneWidget);
      expect(find.text('ram@ambulance.com'), findsOneWidget);
      expect(find.text('Ambulance Driver'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);

      // Verify button
      expect(find.text('Back to Sign In'), findsOneWidget);
    });

    testWidgets('renders properly for traffic officer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationPendingScreen(
            name: 'Sita Sharma',
            email: 'sita@traffic.gov.np',
            role: 'officer',
          ),
        ),
      );

      expect(find.text('Registration Submitted'), findsOneWidget);
      expect(find.text('Sita Sharma'), findsOneWidget);
      expect(find.text('sita@traffic.gov.np'), findsOneWidget);
      expect(find.text('Traffic Officer'), findsOneWidget);
    });

    testWidgets('renders with fallback when name/role are empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationPendingScreen(
            email: 'pending_user@example.com',
          ),
        ),
      );

      expect(find.text('Registration Submitted'), findsOneWidget);
      expect(find.text('pending_user@example.com'), findsOneWidget);
      expect(find.text('Registered User'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);
    });
  });
}

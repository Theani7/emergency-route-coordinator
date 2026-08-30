import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ambulance_coordination/widgets/otp_input_widget.dart';

void main() {
  group('OtpInputWidget Tests', () {
    testWidgets('renders correct number of digit boxes', (tester) async {
      String enteredOtp = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputWidget(
              length: 6,
              onCompleted: (v) => enteredOtp = v,
              onChanged: (v) => enteredOtp = v,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('typing 6 digits triggers onCompleted with full OTP', (tester) async {
      String completedOtp = '';
      String changedOtp = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputWidget(
              length: 6,
              onCompleted: (v) => completedOtp = v,
              onChanged: (v) => changedOtp = v,
            ),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '3');
      await tester.pump();
      await tester.enterText(textFields.at(1), '1');
      await tester.pump();
      await tester.enterText(textFields.at(2), '5');
      await tester.pump();
      await tester.enterText(textFields.at(3), '7');
      await tester.pump();
      await tester.enterText(textFields.at(4), '8');
      await tester.pump();
      await tester.enterText(textFields.at(5), '6');
      await tester.pump();

      expect(changedOtp, equals('315786'));
      expect(completedOtp, equals('315786'));
    });

    testWidgets('pasting full 6-digit OTP fills all fields correctly', (tester) async {
      String completedOtp = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputWidget(
              length: 6,
              onCompleted: (v) => completedOtp = v,
            ),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '987654');
      await tester.pump();

      expect(completedOtp, equals('987654'));
    });

    testWidgets('replacing a digit in an existing box updates only that box', (tester) async {
      final key = GlobalKey<OtpInputWidgetState>();
      String changedOtp = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputWidget(
              key: key,
              length: 6,
              onChanged: (v) => changedOtp = v,
              onCompleted: (_) {},
            ),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      // Type 1, 2, 3
      await tester.enterText(textFields.at(0), '1');
      await tester.pump();
      await tester.enterText(textFields.at(1), '2');
      await tester.pump();
      await tester.enterText(textFields.at(2), '3');
      await tester.pump();

      expect(key.currentState?.otp, equals('123'));

      // Replace box 1 ('2') with '9'
      await tester.enterText(textFields.at(1), '29');
      await tester.pump();

      // Box 0 should remain '1', Box 1 becomes '9', Box 2 remains '3'
      expect(key.currentState?.otp, equals('193'));
    });
  });
}

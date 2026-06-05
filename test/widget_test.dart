import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_lms/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
  }

  Future<void> enterCredentials(
    WidgetTester tester, {
    required String id,
    required String password,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), id);
    await tester.enterText(fields.at(1), password);
  }

  testWidgets('shows the login screen', (tester) async {
    await pumpApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to your Smart LMS account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('validates empty credentials', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter your ID'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows an error for invalid credentials', (tester) async {
    await pumpApp(tester);

    await enterCredentials(tester, id: 'wrong', password: 'wrong');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(
      find.text('Invalid ID or password. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('signs in a student and opens the student dashboard', (
    tester,
  ) async {
    await pumpApp(tester);

    await enterCredentials(tester, id: 'student1', password: 'student123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Student Dashboard'), findsOneWidget);
    expect(find.text('Welcome, Student!'), findsOneWidget);
  });

  testWidgets('signs in a teacher and opens the teacher dashboard', (
    tester,
  ) async {
    await pumpApp(tester);

    await enterCredentials(tester, id: 'teacher1', password: 'teacher123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Teacher Dashboard'), findsOneWidget);
    expect(find.text('Welcome, Teacher!'), findsOneWidget);
  });
}

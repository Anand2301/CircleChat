import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_chat/features/authentication/auth_controller.dart';
import 'package:circle_chat/features/authentication/login_screen.dart';
import 'package:circle_chat/features/authentication/register_screen.dart';

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier() {
    state = AuthState(isLoading: false);
  }
}

void main() {
  testWidgets('LoginScreen renders input fields and buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => TestAuthNotifier()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome to CircleChat'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('RegisterScreen renders invitation code field', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => TestAuthNotifier()),
        ],
        child: const MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Join CircleChat'), findsOneWidget);
    expect(find.text('Invitation Code'), findsOneWidget);
    expect(find.text('Complete Registration'), findsOneWidget);
  });
}

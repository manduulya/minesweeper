import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mine_master/main.dart' as app;

// ---------------------------------------------------------------------------
// CONFIGURE THESE before running on your Mac:
// ---------------------------------------------------------------------------
const String _testUsername = 'reviewer';         // your dummy account username
const String _testPassword = 'Review123!';       // your dummy account password
// ---------------------------------------------------------------------------

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Generate App Store screenshots', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // -----------------------------------------------------------------------
    // SCREEN 1 — Login / Landing page
    // -----------------------------------------------------------------------
    await _screenshot(binding, tester, '01_login');

    // -----------------------------------------------------------------------
    // SCREEN 2 — Sign Up page
    // -----------------------------------------------------------------------
    final signUpBtn = find.text('Sign up');
    if (signUpBtn.evaluate().isNotEmpty) {
      await tester.tap(signUpBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await _screenshot(binding, tester, '02_signup');

      // Go back to login
      final backBtn = find.byType(BackButton);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn);
      } else {
        await tester.pageBack();
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    // -----------------------------------------------------------------------
    // Log in with dummy account to reach authenticated screens
    // -----------------------------------------------------------------------
    final usernameField = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText == 'Username'),
    );
    final passwordField = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText == 'Password'),
    );

    if (usernameField.evaluate().isNotEmpty &&
        passwordField.evaluate().isNotEmpty) {
      await tester.enterText(usernameField, _testUsername);
      await tester.enterText(passwordField, _testPassword);
      await tester.pumpAndSettle();

      final loginBtn = find.text('LOGIN');
      if (loginBtn.evaluate().isNotEmpty) {
        await tester.tap(loginBtn);
        // Give the server time to respond
        await tester.pumpAndSettle(const Duration(seconds: 6));
      }
    }

    // -----------------------------------------------------------------------
    // SCREEN 3 — Home screen  (only reached when logged in)
    // -----------------------------------------------------------------------
    final playBtn = find.text('PLAY GAME');
    if (playBtn.evaluate().isNotEmpty) {
      await _screenshot(binding, tester, '03_home');

      // -----------------------------------------------------------------------
      // SCREEN 4 — Game board
      // -----------------------------------------------------------------------
      await tester.tap(playBtn);
      await tester.pumpAndSettle(const Duration(seconds: 4));
      await _screenshot(binding, tester, '04_game');

      // Go back to home
      final backFromGame = find.byType(BackButton);
      if (backFromGame.evaluate().isNotEmpty) {
        await tester.tap(backFromGame);
      } else {
        await tester.pageBack();
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // -----------------------------------------------------------------------
      // SCREEN 5 — Leaderboard
      // -----------------------------------------------------------------------
      final leaderboardBtn = find.text('Leaderboard');
      if (leaderboardBtn.evaluate().isNotEmpty) {
        await tester.tap(leaderboardBtn);
        await tester.pumpAndSettle(const Duration(seconds: 4));
        await _screenshot(binding, tester, '05_leaderboard');
      }
    }
  });
}

/// Helper: scroll to top then capture a screenshot.
Future<void> _screenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  await binding.takeScreenshot(name);
}

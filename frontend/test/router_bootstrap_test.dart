import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/config/app_config.dart';
import 'package:testlabuz_client/app/router/app_router.dart';

void main() {
  group('router bootstrap', () {
    testWidgets('renders the technical root through MaterialApp.router', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.fromApiBaseUrl('https://api.testlabuz.example/api/v1'),
            ),
          ],
          child: const TestLabUzApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TestLabUz'), findsOneWidget);
      expect(find.text('Client foundation'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('does not retain the default counter demo', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.fromApiBaseUrl('https://api.testlabuz.example/api/v1'),
            ),
          ],
          child: const TestLabUzApp(),
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.textContaining('pushed the button'), findsNothing);
    });

    test('does not introduce auth or role routes yet', () {
      expect(AppRoutePaths.all, ['/']);
      expect(AppRoutePaths.all, isNot(contains('/login')));
      expect(AppRoutePaths.all, isNot(contains('/change-password')));
      expect(AppRoutePaths.all, isNot(contains('/platform-owner')));
      expect(AppRoutePaths.all, isNot(contains('/institution-admin')));
      expect(AppRoutePaths.all, isNot(contains('/teacher')));
      expect(AppRoutePaths.all, isNot(contains('/student')));
      expect(AppRoutePaths.all, isNot(contains('/parent')));
    });
  });
}

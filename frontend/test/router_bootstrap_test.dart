import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';

void main() {
  group('router bootstrap and auth guards', () {
    testWidgets('unauthenticated routes only allow login', (tester) async {
      await _expectRoute(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: FakeAuthRepository(),
        expectedText: 'Login',
      );
      await _expectRoute(
        tester,
        initialLocation: AppRoutePaths.changePassword,
        repository: FakeAuthRepository(),
        expectedText: 'Login',
      );
      await _expectRoute(
        tester,
        initialLocation: AppRoutePaths.authenticated,
        repository: FakeAuthRepository(),
        expectedText: 'Login',
      );
    });

    testWidgets('authenticated must-change user is forced to change password', (
      tester,
    ) async {
      await _expectRoute(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: _authenticatedRepository(mustChangePassword: true),
        expectedText: 'Password change is required before normal access.',
      );
      await _expectRoute(
        tester,
        initialLocation: AppRoutePaths.changePassword,
        repository: _authenticatedRepository(mustChangePassword: true),
        expectedText: 'Password change is required before normal access.',
      );
      await _expectRoute(
        tester,
        initialLocation: AppRoutePaths.authenticated,
        repository: _authenticatedRepository(mustChangePassword: true),
        expectedText: 'Password change is required before normal access.',
      );
    });

    testWidgets(
      'authenticated password-complete user reaches transition route',
      (tester) async {
        await _expectRoute(
          tester,
          initialLocation: AppRoutePaths.login,
          repository: _authenticatedRepository(),
          expectedText: 'Authenticated session ready',
        );
        await _expectRoute(
          tester,
          initialLocation: AppRoutePaths.changePassword,
          repository: _authenticatedRepository(),
          expectedText: 'Authenticated session ready',
        );
        await _expectRoute(
          tester,
          initialLocation: AppRoutePaths.authenticated,
          repository: _authenticatedRepository(),
          expectedText: 'Authenticated session ready',
        );
      },
    );

    testWidgets('bootstrapping shows neutral loading without auth flash', (
      tester,
    ) async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      final currentUser = Completer<AuthUser>();
      repository.onCurrentUser = () => currentUser.future;

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: repository,
      );
      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Authenticated session ready'), findsNothing);

      currentUser.complete(_user(loginName: 'teacher01'));
      await tester.pumpAndSettle();

      expect(find.text('Authenticated session ready'), findsOneWidget);
    });

    testWidgets('sign-in success routes by server must-change flag', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      repository.onSignIn = (_, _) async =>
          _user(loginName: 'teacher01', mustChangePassword: true);
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: repository,
      );
      await _submitLogin(tester);

      expect(
        find.text('Password change is required before normal access.'),
        findsOneWidget,
      );

      final passwordCompleteRepository = FakeAuthRepository();
      passwordCompleteRepository.onSignIn = (_, _) async =>
          _user(loginName: 'teacher01');
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: passwordCompleteRepository,
      );
      await _submitLogin(tester);

      expect(find.text('Authenticated session ready'), findsOneWidget);
    });

    testWidgets('transition logout returns to login', (tester) async {
      final repository = _authenticatedRepository();
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.authenticated,
        repository: repository,
      );

      await tester.tap(find.byKey(const Key('authenticatedLogoutButton')));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.text('Login'), findsOneWidget);
    });

    test('does not introduce role-specific route paths yet', () {
      expect(
        AppRoutePaths.all,
        containsAll([
          AppRoutePaths.root,
          AppRoutePaths.login,
          AppRoutePaths.changePassword,
          AppRoutePaths.authenticated,
        ]),
      );
      expect(AppRoutePaths.all, isNot(contains('/platform-owner')));
      expect(AppRoutePaths.all, isNot(contains('/institution-admin')));
      expect(AppRoutePaths.all, isNot(contains('/teacher')));
      expect(AppRoutePaths.all, isNot(contains('/student')));
      expect(AppRoutePaths.all, isNot(contains('/parent')));
    });
  });
}

Future<void> _expectRoute(
  WidgetTester tester, {
  required String initialLocation,
  required FakeAuthRepository repository,
  required String expectedText,
}) async {
  await _pumpApp(
    tester,
    initialLocation: initialLocation,
    repository: repository,
  );
  await tester.pumpAndSettle();

  expect(find.text(expectedText), findsOneWidget);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  required FakeAuthRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appInitialLocationProvider.overrideWithValue(initialLocation),
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('loginField')), 'teacher01');
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

FakeAuthRepository _authenticatedRepository({bool mustChangePassword = false}) {
  return FakeAuthRepository(
    storedToken: 'token-a',
    onCurrentUser: () async =>
        _user(loginName: 'teacher01', mustChangePassword: mustChangePassword),
  );
}

AuthUser _user({
  required String loginName,
  UserRole role = UserRole.teacher,
  bool mustChangePassword = false,
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: role == UserRole.platformOwner ? null : 'institution-1',
    role: role,
    fullName: 'Test User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: mustChangePassword,
    institution: role == UserRole.platformOwner
        ? null
        : const AuthInstitution(
            id: 'institution-1',
            name: 'Example School',
            status: 'active',
            timezone: 'Asia/Tashkent',
          ),
  );
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.storedToken, this.onCurrentUser});

  String? storedToken;
  Future<AuthUser> Function()? onCurrentUser;

  Future<AuthUser> Function(String login, String password)? onSignIn;
  final signInCalls = <({String login, String password})>[];
  var currentUserCalls = 0;
  var signOutCalls = 0;

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    signInCalls.add((login: login, password: password));

    return onSignIn?.call(login, password) ??
        Future.value(_user(loginName: login));
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    return _user(loginName: 'teacher01');
  }

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls += 1;

    return onCurrentUser?.call() ?? Future.value(_user(loginName: 'teacher01'));
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    storedToken = null;
  }

  @override
  Future<String?> readStoredToken() async {
    return storedToken;
  }

  @override
  Future<void> clearToken() async {
    storedToken = null;
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) async {
    storedToken = null;

    return true;
  }
}

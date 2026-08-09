import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/auth/presentation/change_password/change_password_screen.dart';
import 'package:testlabuz_client/features/auth/presentation/login/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders required login controls without role selectors', (
      tester,
    ) async {
      await _pumpAuthWidget(tester, const LoginScreen(), FakeAuthRepository());

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byKey(const Key('signInButton')), findsOneWidget);
      expect(find.textContaining('role', findRichText: true), findsNothing);
      expect(
        find.textContaining('institution', findRichText: true),
        findsNothing,
      );
      expect(_editableText('passwordField').obscureText, isTrue);
    });

    testWidgets('empty submit shows required validation', (tester) async {
      await _pumpAuthWidget(tester, const LoginScreen(), FakeAuthRepository());

      await tester.tap(find.byKey(const Key('signInButton')));
      await tester.pump();

      expect(find.text('Login is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('one missing field shows only its validation', (tester) async {
      await _pumpAuthWidget(tester, const LoginScreen(), FakeAuthRepository());

      await tester.enterText(find.byKey(const Key('loginField')), 'teacher01');
      await tester.tap(find.byKey(const Key('signInButton')));
      await tester.pump();

      expect(find.text('Login is required.'), findsNothing);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets(
      'keyboard submit sends trimmed login without mutating password',
      (tester) async {
        final repository = FakeAuthRepository();
        await _pumpAuthWidget(tester, const LoginScreen(), repository);

        await tester.enterText(
          find.byKey(const Key('loginField')),
          '  teacher01  ',
        );
        await tester.enterText(
          find.byKey(const Key('passwordField')),
          '  secret  ',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(repository.signInCalls.single.login, 'teacher01');
        expect(repository.signInCalls.single.password, '  secret  ');
      },
    );

    testWidgets('loading disables duplicate sign-in submit', (tester) async {
      final repository = FakeAuthRepository();
      final signIn = Completer<AuthUser>();
      repository.onSignIn = (_, _) => signIn.future;
      await _pumpAuthWidget(tester, const LoginScreen(), repository);

      await tester.enterText(find.byKey(const Key('loginField')), 'teacher01');
      await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
      await tester.tap(find.byKey(const Key('signInButton')));
      await tester.tap(find.byKey(const Key('signInButton')));
      await tester.pump();

      expect(repository.signInCalls, hasLength(1));
      expect(_filledButton('signInButton').onPressed, isNull);

      signIn.complete(_user(loginName: 'teacher01'));
      await tester.pumpAndSettle();
    });

    testWidgets('invalid credentials shows safe account error', (tester) async {
      final repository = FakeAuthRepository();
      repository.onSignIn = (_, _) async {
        throw _serverFailure(ApiErrorCodes.invalidCredentials, statusCode: 401);
      };
      await _pumpAuthWidget(tester, const LoginScreen(), repository);

      await _submitLogin(tester, password: 'super-secret');

      expect(find.text('Login or password is incorrect.'), findsOneWidget);
      expect(_visibleTextContaining('super-secret'), findsNothing);
    });

    testWidgets('inactive user error is typed', (tester) async {
      await _expectLoginFailureMessage(
        tester,
        ApiErrorCodes.userInactive,
        statusCode: 403,
        expectedMessage: 'This account is inactive.',
      );
    });

    testWidgets('inactive institution error is typed', (tester) async {
      await _expectLoginFailureMessage(
        tester,
        ApiErrorCodes.institutionInactive,
        statusCode: 403,
        expectedMessage: 'This institution is inactive.',
      );
    });

    testWidgets('rate-limited error is typed', (tester) async {
      await _expectLoginFailureMessage(
        tester,
        ApiErrorCodes.rateLimited,
        statusCode: 429,
        expectedMessage: 'Too many attempts. Please wait and try again.',
      );
    });

    testWidgets('backend field validation maps to login field', (tester) async {
      final repository = FakeAuthRepository();
      repository.onSignIn = (_, _) async {
        throw _serverFailure(
          ApiErrorCodes.validationFailed,
          statusCode: 422,
          fieldErrors: const {
            'login': ['Login format is invalid.'],
          },
        );
      };
      await _pumpAuthWidget(tester, const LoginScreen(), repository);

      await _submitLogin(tester);

      expect(find.text('Login format is invalid.'), findsOneWidget);
      expect(find.text('Check the highlighted fields.'), findsOneWidget);
    });

    testWidgets('transport failure has a safe non-field error', (tester) async {
      final repository = FakeAuthRepository();
      repository.onSignIn = (_, _) async {
        throw _transportFailure();
      };
      await _pumpAuthWidget(tester, const LoginScreen(), repository);

      await _submitLogin(tester);

      expect(
        find.text(
          'Could not reach the server. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ChangePasswordScreen', () {
    testWidgets('renders required fields and obscures values', (tester) async {
      await _pumpAuthWidget(
        tester,
        const ChangePasswordScreen(),
        FakeAuthRepository(),
      );

      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
      expect(find.byKey(const Key('changePasswordButton')), findsOneWidget);
      expect(
        find.text('Password change is required before normal access.'),
        findsOneWidget,
      );
      expect(_editableText('currentPasswordField').obscureText, isTrue);
      expect(_editableText('newPasswordField').obscureText, isTrue);
      expect(_editableText('confirmPasswordField').obscureText, isTrue);
    });

    testWidgets('required validation covers all three fields', (tester) async {
      await _pumpAuthWidget(
        tester,
        const ChangePasswordScreen(),
        FakeAuthRepository(),
      );

      await tester.tap(find.byKey(const Key('changePasswordButton')));
      await tester.pump();

      expect(find.text('Current password is required.'), findsOneWidget);
      expect(find.text('New password is required.'), findsOneWidget);
      expect(find.text('Confirm new password is required.'), findsOneWidget);
    });

    testWidgets('validates mismatch, length, and same-password rules', (
      tester,
    ) async {
      await _pumpAuthWidget(
        tester,
        const ChangePasswordScreen(),
        FakeAuthRepository(),
      );

      await _enterPasswords(tester, current: 'secret-1', next: 'short');
      await tester.tap(find.byKey(const Key('changePasswordButton')));
      await tester.pump();
      expect(
        find.text('New password must be at least 8 characters.'),
        findsOneWidget,
      );

      await _enterPasswords(
        tester,
        current: 'secret-1',
        next: 'secret-1',
        confirmation: 'secret-1',
      );
      await tester.tap(find.byKey(const Key('changePasswordButton')));
      await tester.pump();
      expect(
        find.text('New password must be different from current password.'),
        findsOneWidget,
      );

      await _enterPasswords(
        tester,
        current: 'secret-1',
        next: 'new-secret',
        confirmation: 'different',
      );
      await tester.tap(find.byKey(const Key('changePasswordButton')));
      await tester.pump();
      expect(
        find.text('Confirm new password must match new password.'),
        findsOneWidget,
      );

      await _enterPasswords(
        tester,
        current: 'secret-1',
        next: 'x' * 256,
        confirmation: 'x' * 256,
      );
      await tester.tap(find.byKey(const Key('changePasswordButton')));
      await tester.pump();
      expect(
        find.text('New password must be 255 characters or fewer.'),
        findsOneWidget,
      );
    });

    testWidgets('current password conflict attaches to current field', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      repository.onChangePassword = (_, _, _) async {
        throw _serverFailure(
          ApiErrorCodes.currentPasswordInvalid,
          statusCode: 409,
        );
      };
      await _pumpAuthWidget(tester, const ChangePasswordScreen(), repository);

      await _submitPasswordChange(tester);

      expect(find.text('Current password is incorrect.'), findsWidgets);
    });

    testWidgets('loading blocks duplicate password-change submit', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      final changePassword = Completer<AuthUser>();
      repository.onChangePassword = (_, _, _) => changePassword.future;
      await _pumpAuthWidget(tester, const ChangePasswordScreen(), repository);

      await _enterPasswords(tester);
      await tester.tap(find.byKey(const Key('changePasswordButton')));
      await tester.tap(find.byKey(const Key('changePasswordButton')));
      await tester.pump();

      expect(repository.changePasswordCalls, hasLength(1));
      expect(_filledButton('changePasswordButton').onPressed, isNull);

      changePassword.complete(_user(loginName: 'teacher01'));
      await tester.pumpAndSettle();
    });

    testWidgets('success clears password field values', (tester) async {
      final repository = FakeAuthRepository();
      await _pumpAuthWidget(tester, const ChangePasswordScreen(), repository);

      await _submitPasswordChange(tester);

      expect(_textField('currentPasswordField').controller?.text, isEmpty);
      expect(_textField('newPasswordField').controller?.text, isEmpty);
      expect(_textField('confirmPasswordField').controller?.text, isEmpty);
    });

    testWidgets('refresh retry does not resubmit password mutation', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      repository.onChangePassword = (_, _, _) async {
        throw AuthPasswordChangeSessionRefreshException(_transportFailure());
      };
      await _pumpAuthWidget(tester, const ChangePasswordScreen(), repository);

      await _submitPasswordChange(tester);
      expect(
        find.byKey(const Key('retrySessionRefreshButton')),
        findsOneWidget,
      );
      expect(_textField('currentPasswordField').controller?.text, isEmpty);

      repository.onCurrentUser = () async => _user(loginName: 'teacher01');
      await tester.tap(find.byKey(const Key('retrySessionRefreshButton')));
      await tester.pumpAndSettle();

      expect(repository.changePasswordCalls, hasLength(1));
      expect(repository.currentUserCalls, 1);
    });

    testWidgets('confirmation field keyboard submits', (tester) async {
      final repository = FakeAuthRepository();
      await _pumpAuthWidget(tester, const ChangePasswordScreen(), repository);

      await _enterPasswords(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repository.changePasswordCalls, hasLength(1));
    });
  });

  group('auth form responsive smoke', () {
    testWidgets('login does not overflow on narrow mobile viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAuthWidget(tester, const LoginScreen(), FakeAuthRepository());

      expect(tester.takeException(), isNull);
    });

    testWidgets('change password does not overflow on desktop viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAuthWidget(
        tester,
        const ChangePasswordScreen(),
        FakeAuthRepository(),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpAuthWidget(
  WidgetTester tester,
  Widget child,
  FakeAuthRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump();
  await tester.pump();
}

TextFormField _textField(String key) {
  return testerElement<TextFormField>(find.byKey(Key(key)));
}

EditableText _editableText(String key) {
  return testerElement<EditableText>(
    find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(EditableText),
    ),
  );
}

FilledButton _filledButton(String key) {
  return testerElement<FilledButton>(find.byKey(Key(key)));
}

Finder _visibleTextContaining(String value) {
  return find.byWidgetPredicate((widget) {
    return widget is Text && (widget.data?.contains(value) ?? false);
  });
}

T testerElement<T extends Widget>(Finder finder) {
  final element = finder.evaluate().single;
  return element.widget as T;
}

Future<void> _submitLogin(
  WidgetTester tester, {
  String password = 'secret',
}) async {
  await tester.enterText(find.byKey(const Key('loginField')), 'teacher01');
  await tester.enterText(find.byKey(const Key('passwordField')), password);
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

Future<void> _expectLoginFailureMessage(
  WidgetTester tester,
  String code, {
  required int statusCode,
  required String expectedMessage,
}) async {
  final repository = FakeAuthRepository();
  repository.onSignIn = (_, _) async {
    throw _serverFailure(code, statusCode: statusCode);
  };
  await _pumpAuthWidget(tester, const LoginScreen(), repository);

  await _submitLogin(tester);

  expect(find.text(expectedMessage), findsOneWidget);
}

Future<void> _enterPasswords(
  WidgetTester tester, {
  String current = 'old-secret',
  String next = 'new-secret',
  String? confirmation,
}) async {
  await tester.enterText(
    find.byKey(const Key('currentPasswordField')),
    current,
  );
  await tester.enterText(find.byKey(const Key('newPasswordField')), next);
  await tester.enterText(
    find.byKey(const Key('confirmPasswordField')),
    confirmation ?? next,
  );
}

Future<void> _submitPasswordChange(WidgetTester tester) async {
  await _enterPasswords(tester);
  await tester.tap(find.byKey(const Key('changePasswordButton')));
  await tester.pumpAndSettle();
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

ApiRequestException _serverFailure(
  String code, {
  required int statusCode,
  Map<String, List<String>> fieldErrors = const {},
}) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: statusCode,
      error: ApiErrorResponse(
        message: 'Server rejected the request.',
        code: code,
        fieldErrors: fieldErrors,
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _transportFailure() {
  return ApiRequestException(
    ApiFailure.local(
      kind: ApiFailureKind.connection,
      message: 'Connection failed.',
    ),
  );
}

class FakeAuthRepository implements AuthRepository {
  String? storedToken;
  int tokenVersion = 0;

  Future<AuthUser> Function()? onCurrentUser;
  Future<AuthUser> Function(String login, String password)? onSignIn;
  Future<AuthUser> Function(
    String currentPassword,
    String newPassword,
    String newPasswordConfirmation,
  )?
  onChangePassword;

  final signInCalls = <SignInCall>[];
  final changePasswordCalls = <ChangePasswordCall>[];
  var currentUserCalls = 0;
  var signOutCalls = 0;
  var clearTokenCalls = 0;

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    signInCalls.add(SignInCall(login: login, password: password));

    return onSignIn?.call(login, password) ??
        Future.value(_user(loginName: login));
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) {
    changePasswordCalls.add(
      ChangePasswordCall(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      ),
    );

    return onChangePassword?.call(
          currentPassword,
          newPassword,
          newPasswordConfirmation,
        ) ??
        Future.value(_user(loginName: 'teacher01'));
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
    clearTokenCalls += 1;
    storedToken = null;
    tokenVersion += 1;
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) async {
    if (this.tokenVersion != tokenVersion) {
      return false;
    }

    storedToken = null;
    this.tokenVersion += 1;

    return true;
  }
}

class SignInCall {
  const SignInCall({required this.login, required this.password});

  final String login;
  final String password;
}

class ChangePasswordCall {
  const ChangePasswordCall({
    required this.currentPassword,
    required this.newPassword,
    required this.newPasswordConfirmation,
  });

  final String currentPassword;
  final String newPassword;
  final String newPasswordConfirmation;
}

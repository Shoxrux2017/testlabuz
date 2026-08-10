import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/main.dart' as app;

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _stage1E2ePassword = String.fromEnvironment('STAGE1_E2E_PASSWORD');
const _stage1E2eNewPassword = String.fromEnvironment('STAGE1_E2E_NEW_PASSWORD');
const _authTokenKey = 'auth_access_token';
const _activeInstitutionName = 'E2E Active Institution';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stage 1 auth works end to end against Laravel', (tester) async {
    _assertEnvironment();

    await _clearLocalToken();
    app.main();
    await _waitForLogin(tester);

    final surface = _currentSurface();

    await _expectLoginFailure(
      tester,
      login: 'e2e_unknown_user',
      password: _stage1E2ePassword,
      messageFragment: 'incorrect',
    );
    await _expectNoLocalToken();

    await _expectLoginFailure(
      tester,
      login: 'e2e_inactive_user',
      password: _stage1E2ePassword,
      messageFragment: 'account is inactive',
    );
    await _expectNoLocalToken();

    await _expectLoginFailure(
      tester,
      login: 'e2e_inactive_institution_user',
      password: _stage1E2ePassword,
      messageFragment: 'institution is inactive',
    );
    await _expectNoLocalToken();

    for (final account in _activeAccounts) {
      await _signInExpectEntryAndLogout(
        tester,
        account: account,
        surface: surface,
        verifyRevokedToken: account.loginName == 'e2e_teacher_a',
      );
    }

    await _verifyFirstLoginPasswordChange(tester, surface);
    await _verifySameRoleAccountSwitch(tester, surface);
    await _verifyCrossRoleAccountSwitch(tester, surface);
    await _verifyWrongRoleDirectRoutes(tester, surface);
  });
}

Future<void> _verifyFirstLoginPasswordChange(
  WidgetTester tester,
  _E2eSurface surface,
) async {
  await _signIn(tester, 'e2e_teacher_must_change', _stage1E2ePassword);
  await _waitForRoute(tester, AppRoutePaths.changePassword);
  await _waitUntilFound(tester, find.text('Change password'));

  _goTo(tester, AppRoutePaths.teacher);
  await _waitForRoute(tester, AppRoutePaths.changePassword);
  await _waitUntilFound(tester, find.text('Change password'));

  await _submitPasswordChange(
    tester,
    currentPassword: 'wrong-current-password',
    newPassword: _stage1E2eNewPassword,
  );
  await _waitUntilFound(
    tester,
    find.text('Current password is incorrect.'),
    reason: 'Wrong current password should stay on change-password screen.',
  );
  expect(_currentRoute(tester), AppRoutePaths.changePassword);

  await _submitPasswordChange(
    tester,
    currentPassword: _stage1E2ePassword,
    newPassword: _stage1E2eNewPassword,
  );
  await _waitForEntry(
    tester,
    account: _teacherMustChangeAccount,
    expectation: _teacherMustChangeAccount.expectationFor(surface),
  );

  await _logout(tester);

  await _expectLoginFailure(
    tester,
    login: 'e2e_teacher_must_change',
    password: _stage1E2ePassword,
    messageFragment: 'incorrect',
  );

  await _signInExpectEntryAndLogout(
    tester,
    account: _teacherMustChangeAccount,
    surface: surface,
    password: _stage1E2eNewPassword,
  );
}

Future<void> _verifySameRoleAccountSwitch(
  WidgetTester tester,
  _E2eSurface surface,
) async {
  await _signIn(tester, 'e2e_teacher_a', _stage1E2ePassword);
  await _waitForEntry(
    tester,
    account: _teacherAAccount,
    expectation: _teacherAAccount.expectationFor(surface),
  );
  await _logout(tester);

  await _signIn(tester, 'e2e_teacher_b', _stage1E2ePassword);
  await _waitForEntry(
    tester,
    account: _teacherBAccount,
    expectation: _teacherBAccount.expectationFor(surface),
  );
  expect(find.text('Current user: E2E Teacher A'), findsNothing);
  await _logout(tester);
}

Future<void> _verifyCrossRoleAccountSwitch(
  WidgetTester tester,
  _E2eSurface surface,
) async {
  await _signIn(tester, 'e2e_teacher_a', _stage1E2ePassword);
  await _waitForEntry(
    tester,
    account: _teacherAAccount,
    expectation: _teacherAAccount.expectationFor(surface),
  );
  await _logout(tester);

  await _signIn(tester, 'e2e_student', _stage1E2ePassword);
  await _waitForEntry(
    tester,
    account: _studentAccount,
    expectation: _studentAccount.expectationFor(surface),
  );
  expect(find.text('Current user: E2E Teacher A'), findsNothing);
  expect(find.text('Teacher'), findsNothing);
  await _logout(tester);
}

Future<void> _verifyWrongRoleDirectRoutes(
  WidgetTester tester,
  _E2eSurface surface,
) async {
  await _signIn(tester, 'e2e_teacher_a', _stage1E2ePassword);
  await _waitForEntry(
    tester,
    account: _teacherAAccount,
    expectation: _teacherAAccount.expectationFor(surface),
  );

  _goTo(tester, AppRoutePaths.student);
  await _waitForEntry(
    tester,
    account: _teacherAAccount,
    expectation: _teacherAAccount.expectationFor(surface),
  );
  expect(find.text('Student'), findsNothing);

  _goTo(tester, AppRoutePaths.parent);
  await _waitForEntry(
    tester,
    account: _teacherAAccount,
    expectation: _teacherAAccount.expectationFor(surface),
  );
  expect(find.text('Parent'), findsNothing);

  await _logout(tester);
}

Future<void> _signInExpectEntryAndLogout(
  WidgetTester tester, {
  required _E2eAccount account,
  required _E2eSurface surface,
  String password = _stage1E2ePassword,
  bool verifyRevokedToken = false,
}) async {
  await _signIn(tester, account.loginName, password);
  await _waitForEntry(
    tester,
    account: account,
    expectation: account.expectationFor(surface),
  );

  await _logout(tester, verifyRevokedToken: verifyRevokedToken);
}

Future<void> _signIn(
  WidgetTester tester,
  String loginName,
  String password,
) async {
  await _waitForLogin(tester);
  await _enterText(tester, const Key('loginField'), loginName);
  await _enterText(tester, const Key('passwordField'), password);
  await _tap(tester, const Key('signInButton'));
}

Future<void> _expectLoginFailure(
  WidgetTester tester, {
  required String login,
  required String password,
  required String messageFragment,
}) async {
  await _signIn(tester, login, password);
  await _waitUntilFound(
    tester,
    find.textContaining(messageFragment, findRichText: true),
  );
  expect(_currentRoute(tester), AppRoutePaths.login);
  expect(find.byKey(const Key('entryRoleTitle')), findsNothing);
}

Future<void> _submitPasswordChange(
  WidgetTester tester, {
  required String currentPassword,
  required String newPassword,
}) async {
  await _enterText(tester, const Key('currentPasswordField'), currentPassword);
  await _enterText(tester, const Key('newPasswordField'), newPassword);
  await _enterText(tester, const Key('confirmPasswordField'), newPassword);
  await _tap(tester, const Key('changePasswordButton'));
}

Future<void> _waitForEntry(
  WidgetTester tester, {
  required _E2eAccount account,
  required _ExpectedEntry expectation,
}) async {
  await _waitForRoute(tester, expectation.route);
  await _waitUntilFound(tester, find.byKey(const Key('entryRoleTitle')));

  expect(find.text(expectation.title), findsOneWidget);
  expect(find.text('Current user: ${account.fullName}'), findsOneWidget);
  expect(find.text('Device: ${expectation.surface.label}'), findsOneWidget);

  if (expectation.showsInstitution) {
    expect(find.text('Institution: $_activeInstitutionName'), findsOneWidget);
  } else {
    expect(find.byKey(const Key('entryInstitutionName')), findsNothing);
  }
}

Future<void> _logout(
  WidgetTester tester, {
  bool verifyRevokedToken = false,
}) async {
  final token = verifyRevokedToken ? await _readLocalToken() : null;
  if (verifyRevokedToken) {
    expect(token, isNotNull, reason: 'A logged-in session must store a token.');
  }

  await _tap(tester, const Key('entryLogoutButton'));
  await _waitForLogin(tester);
  await _expectNoLocalToken();
  expect(find.byKey(const Key('entryRoleTitle')), findsNothing);

  if (token != null) {
    await _expectTokenRejected(token);
  }
}

Future<void> _waitForLogin(WidgetTester tester) async {
  await _waitForRoute(tester, AppRoutePaths.login);
  await _waitUntilFound(tester, find.byKey(const Key('loginField')));
}

Future<void> _waitForRoute(WidgetTester tester, String route) async {
  await _pumpUntil(
    tester,
    () => _currentRoute(tester) == route,
    reason: 'Expected current route to be $route.',
  );
}

Future<void> _waitUntilFound(
  WidgetTester tester,
  Finder finder, {
  String? reason,
}) {
  return _pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    reason: reason ?? 'Expected finder to locate at least one widget.',
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String? reason,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) {
      return;
    }
  }

  expect(
    condition(),
    isTrue,
    reason: [
      ?reason,
      'Visible text: ${_visibleTextSnapshot(tester)}',
    ].join(' '),
  );
}

String _visibleTextSnapshot(WidgetTester tester) {
  final values = <String>[];

  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget;
    if (widget is Text) {
      final data = widget.data;
      if (data != null && data.trim().isNotEmpty) {
        values.add(data.trim());
      }
    }
  }

  return values.take(12).join(' | ');
}

Future<void> _enterText(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void _goTo(WidgetTester tester, String route) {
  final context = _routerContext(tester);
  GoRouter.of(context).go(route);
}

String _currentRoute(WidgetTester tester) {
  final context = _routerContext(tester);

  return GoRouter.of(context).routeInformationProvider.value.uri.path;
}

BuildContext _routerContext(WidgetTester tester) {
  return tester.element(find.byType(Scaffold).first);
}

Future<String?> _readLocalToken() {
  return const FlutterSecureStorage().read(key: _authTokenKey);
}

Future<void> _clearLocalToken() {
  return const FlutterSecureStorage().delete(key: _authTokenKey);
}

Future<void> _expectNoLocalToken() async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));

  while (DateTime.now().isBefore(deadline)) {
    if (await _readLocalToken() == null) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  expect(await _readLocalToken(), isNull);
}

Future<void> _expectTokenRejected(String token) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      headers: const {Headers.acceptHeader: Headers.jsonContentType},
      responseType: ResponseType.json,
    ),
  );
  final deadline = DateTime.now().add(const Duration(seconds: 5));

  while (DateTime.now().isBefore(deadline)) {
    try {
      await dio.get<Object?>(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (exception) {
      final response = exception.response;
      final data = response?.data;
      final code = data is Map<String, Object?> ? data['code'] : null;

      if (response?.statusCode == 401 && code == 'authentication_required') {
        return;
      }

      fail('Revoked token returned an unexpected authentication response.');
    }

    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  fail('Revoked token still authenticated after logout.');
}

_E2eSurface _currentSurface() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => _E2eSurface.desktop,
    TargetPlatform.android || TargetPlatform.iOS => _E2eSurface.mobile,
    TargetPlatform.fuchsia => throw StateError(
      'Stage 1 E2E requires desktop or mobile target.',
    ),
  };
}

void _assertEnvironment() {
  if (_apiBaseUrl.isEmpty) {
    throw StateError('API_BASE_URL is required for Stage 1 E2E.');
  }

  if (_stage1E2ePassword.isEmpty) {
    throw StateError('STAGE1_E2E_PASSWORD is required for Stage 1 E2E.');
  }

  if (_stage1E2eNewPassword.isEmpty) {
    throw StateError('STAGE1_E2E_NEW_PASSWORD is required for Stage 1 E2E.');
  }

  if (_stage1E2eNewPassword == _stage1E2ePassword) {
    throw StateError(
      'STAGE1_E2E_NEW_PASSWORD must differ from STAGE1_E2E_PASSWORD.',
    );
  }
}

enum _E2eSurface {
  desktop('desktop'),
  mobile('mobile');

  const _E2eSurface(this.label);

  final String label;
}

class _E2eAccount {
  const _E2eAccount({
    required this.loginName,
    required this.fullName,
    required this.desktop,
    required this.mobile,
  });

  final String loginName;
  final String fullName;
  final _ExpectedEntry desktop;
  final _ExpectedEntry mobile;

  _ExpectedEntry expectationFor(_E2eSurface surface) {
    return switch (surface) {
      _E2eSurface.desktop => desktop,
      _E2eSurface.mobile => mobile,
    };
  }
}

class _ExpectedEntry {
  const _ExpectedEntry({
    required this.route,
    required this.title,
    required this.surface,
    required this.showsInstitution,
  });

  final String route;
  final String title;
  final _E2eSurface surface;
  final bool showsInstitution;
}

const _desktopPlatformOwnerEntry = _ExpectedEntry(
  route: AppRoutePaths.platformOwner,
  title: 'Platform Owner',
  surface: _E2eSurface.desktop,
  showsInstitution: false,
);

const _desktopInstitutionAdminEntry = _ExpectedEntry(
  route: AppRoutePaths.institutionAdmin,
  title: 'Institution Admin',
  surface: _E2eSurface.desktop,
  showsInstitution: true,
);

const _desktopTeacherEntry = _ExpectedEntry(
  route: AppRoutePaths.teacher,
  title: 'Teacher',
  surface: _E2eSurface.desktop,
  showsInstitution: true,
);

const _desktopStudentEntry = _ExpectedEntry(
  route: AppRoutePaths.student,
  title: 'Student',
  surface: _E2eSurface.desktop,
  showsInstitution: true,
);

const _mobileTeacherEntry = _ExpectedEntry(
  route: AppRoutePaths.teacher,
  title: 'Teacher',
  surface: _E2eSurface.mobile,
  showsInstitution: true,
);

const _mobileStudentEntry = _ExpectedEntry(
  route: AppRoutePaths.student,
  title: 'Student',
  surface: _E2eSurface.mobile,
  showsInstitution: true,
);

const _mobileParentEntry = _ExpectedEntry(
  route: AppRoutePaths.parent,
  title: 'Parent',
  surface: _E2eSurface.mobile,
  showsInstitution: true,
);

const _desktopUnsupportedEntry = _ExpectedEntry(
  route: AppRoutePaths.unsupportedDevice,
  title: 'Unsupported device',
  surface: _E2eSurface.desktop,
  showsInstitution: false,
);

const _mobileUnsupportedEntry = _ExpectedEntry(
  route: AppRoutePaths.unsupportedDevice,
  title: 'Unsupported device',
  surface: _E2eSurface.mobile,
  showsInstitution: false,
);

const _teacherAAccount = _E2eAccount(
  loginName: 'e2e_teacher_a',
  fullName: 'E2E Teacher A',
  desktop: _desktopTeacherEntry,
  mobile: _mobileTeacherEntry,
);

const _teacherBAccount = _E2eAccount(
  loginName: 'e2e_teacher_b',
  fullName: 'E2E Teacher B',
  desktop: _desktopTeacherEntry,
  mobile: _mobileTeacherEntry,
);

const _studentAccount = _E2eAccount(
  loginName: 'e2e_student',
  fullName: 'E2E Student',
  desktop: _desktopStudentEntry,
  mobile: _mobileStudentEntry,
);

const _teacherMustChangeAccount = _E2eAccount(
  loginName: 'e2e_teacher_must_change',
  fullName: 'E2E Teacher Must Change',
  desktop: _desktopTeacherEntry,
  mobile: _mobileTeacherEntry,
);

const _activeAccounts = [
  _E2eAccount(
    loginName: 'e2e_platform_owner',
    fullName: 'E2E Platform Owner',
    desktop: _desktopPlatformOwnerEntry,
    mobile: _mobileUnsupportedEntry,
  ),
  _E2eAccount(
    loginName: 'e2e_institution_admin',
    fullName: 'E2E Institution Admin',
    desktop: _desktopInstitutionAdminEntry,
    mobile: _mobileUnsupportedEntry,
  ),
  _teacherAAccount,
  _studentAccount,
  _E2eAccount(
    loginName: 'e2e_parent',
    fullName: 'E2E Parent',
    desktop: _desktopUnsupportedEntry,
    mobile: _mobileParentEntry,
  ),
];

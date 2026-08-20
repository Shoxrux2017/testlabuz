import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/main.dart' as app;

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _stage3Password = String.fromEnvironment('STAGE3_E2E_PASSWORD');
const _firstLoginPassword = String.fromEnvironment(
  'STAGE3_E2E_FIRST_LOGIN_PASSWORD',
);
const _initialUserPassword = String.fromEnvironment(
  'STAGE3_E2E_USER_INITIAL_PASSWORD',
);
const _newUserPassword = String.fromEnvironment('STAGE3_E2E_USER_NEW_PASSWORD');
const _oraclePath = String.fromEnvironment('STAGE3_E2E_ORACLE_PATH');
const _backendContainer = String.fromEnvironment(
  'STAGE3_E2E_BACKEND_CONTAINER',
  defaultValue: 'testlabuz-stage3-e2e-app',
);

const _authTokenKey = 'auth_access_token';
const _targetInstitutionId = '03000000-0000-4000-8000-000000000101';
const _foreignInstitutionId = '03000000-0000-4000-8000-000000000102';
const _emptyInstitutionId = '03000000-0000-4000-8000-000000000104';
const _targetAdminId = '03000000-0000-4000-9000-000000000101';
const _targetInstitutionAdminUserId = '03000000-0000-4000-9000-000000000102';
const _targetTeacherId = '03000000-0000-4000-9000-000000000201';
const _foreignTeacherId = '03000000-0000-4000-9000-000000000204';
const _platformOwnerId = '03000000-0000-4000-9000-000000000108';
const _unknownUserId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';

const _seededTokenSnapshotProgram = r'''
<?php

$action = getenv('STAGE3_TOKEN_SNAPSHOT_ACTION');
$snapshotPath = getenv('STAGE3_TOKEN_SNAPSHOT_PATH');
$allowedActions = ['Capture', 'Compare', 'Remove'];

if (! in_array($action, $allowedActions, true)) {
    throw new RuntimeException('Invalid token-row oracle action.');
}
if (! is_string($snapshotPath) || preg_match('#^/tmp/testlabuz-stage3-token-[a-z-]+\.snapshot$#D', $snapshotPath) !== 1) {
    throw new RuntimeException('Invalid token-row oracle path.');
}

if ($action === 'Remove') {
    if (is_file($snapshotPath) && ! unlink($snapshotPath)) {
        throw new RuntimeException('Token-row oracle cleanup failed.');
    }
    echo 'Stage3LifecycleTokenCleanup: PASS';
    exit(0);
}

require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Support\Facades\DB;

if (
    app()->environment() !== 'testing'
    || DB::scalar('select current_database()') !== 'testlabuz_testing'
    || DB::connection()->getDriverName() !== 'pgsql'
    || DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME) !== 'pgsql'
) {
    throw new RuntimeException('Token-row oracle refused the active runtime.');
}

$columns = [
    'id', 'tokenable_type', 'tokenable_id', 'name', 'token', 'abilities',
    'last_used_at', 'expires_at', 'created_at', 'updated_at',
];
$rows = DB::table('personal_access_tokens')
    ->where('tokenable_id', '03000000-0000-4000-9000-000000000201')
    ->whereIn('name', ['stage3-preservation-a', 'stage3-preservation-b'])
    ->orderBy('name')
    ->orderBy('id')
    ->get($columns);

if ($rows->count() !== 2 || $rows->pluck('name')->all() !== ['stage3-preservation-a', 'stage3-preservation-b']) {
    throw new RuntimeException('The two seeded lifecycle token rows are unavailable.');
}

$canonicalRows = $rows->map(static function (object $row) use ($columns): array {
    $snapshot = [];
    foreach ($columns as $column) {
        $snapshot[$column] = $row->{$column};
    }

    return $snapshot;
})->all();
$snapshotBytes = json_encode($canonicalRows, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

if ($action === 'Capture') {
    if (file_put_contents($snapshotPath, $snapshotBytes, LOCK_EX) !== strlen($snapshotBytes)) {
        throw new RuntimeException('Token-row oracle could not persist its baseline.');
    }
    if (! chmod($snapshotPath, 0600)) {
        throw new RuntimeException('Token-row oracle could not protect its baseline.');
    }
    echo 'Stage3LifecycleTokenBaseline: SAVED';
    exit(0);
}

$baselineBytes = file_get_contents($snapshotPath);
if (! is_string($baselineBytes)) {
    throw new RuntimeException('Token-row oracle baseline is unavailable.');
}
if ($baselineBytes !== $snapshotBytes) {
    throw new RuntimeException('Seeded lifecycle token rows changed.');
}

echo 'Stage3LifecycleTokenComparison: PASS';
''';

const _targetInstitutionName = 'E2E S03 Target Institution';
const _editedInstitutionName = 'E2E S03 Target Institution Edited';
const _foreignInstitutionName = 'E2E S03 Foreign Institution';
const _emptyInstitutionName = 'E2E S03 Empty Institution';
const _editedLifecycleUserName = 'E2E S03 Lifecycle Teacher Edited';

const _createdUsers = [
  _CreatedUserSpec(
    roleLabel: 'Teacher',
    roleCode: 'teacher',
    route: AppRoutePaths.teacher,
    loginName: 'e2e_s03_created_teacher',
    fullName: 'E2E S03 Created Teacher',
    email: 'created-teacher@e2e-s03.invalid',
  ),
  _CreatedUserSpec(
    roleLabel: 'Student',
    roleCode: 'student',
    route: AppRoutePaths.student,
    loginName: 'e2e_s03_created_student',
    fullName: 'E2E S03 Created Student',
    email: 'created-student@e2e-s03.invalid',
  ),
  _CreatedUserSpec(
    roleLabel: 'Parent',
    roleCode: 'parent',
    route: AppRoutePaths.unsupportedDevice,
    loginName: 'e2e_s03_created_parent',
    fullName: 'E2E S03 Created Parent',
    email: 'created-parent@e2e-s03.invalid',
  ),
];

typedef JsonMap = Map<String, Object?>;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Stage 3 institution administration flow uses the real Windows stack',
    (tester) async {
      _assertEnvironment();
      await _configureDesktopView(tester);
      final api = _RealApi();
      final oracle = await _loadOracle();

      await _clearLocalToken();
      app.main();
      await _waitForLogin(tester);
      expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
      expect(find.byKey(const Key('institutionDashboardData')), findsNothing);

      await _verifyProtectedRouteMatrix(api);
      await _verifyEmptyInstitutionBaseline(tester, api, oracle);
      await _signIn(
        tester,
        loginName: 'e2e_s03_target_admin',
        password: _stage3Password,
      );
      await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
      await _waitUntilFound(
        tester,
        find.byKey(const Key('institutionAdminShell')),
      );
      var token = await _requiredLocalToken();

      await _verifyShellSessionAndDashboard(tester, api, token, oracle);
      await _verifyAuthorizationInputAndDisclosure(api, token, oracle);
      await _verifyProfile(tester, api, token, oracle);
      await _verifyUserListAndDetail(tester, api, token, oracle);
      final createdUserIds = <String, String>{};
      for (var index = 0; index < _createdUsers.length; index++) {
        final specification = _createdUsers[index];
        createdUserIds[specification.roleCode] = await _createUser(
          tester,
          api,
          token,
          specification,
        );
        await _verifyDashboardAfterCreates(
          tester,
          api,
          token,
          oracle,
          index + 1,
        );
        await _logout(tester);
        await _verifyCreatedUserFirstLogin(tester, api, specification);
        await _signIn(
          tester,
          loginName: 'e2e_s03_target_admin',
          password: _stage3Password,
        );
        await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
        token = await _requiredLocalToken();
      }

      expect(createdUserIds.keys.toSet(), {'teacher', 'student', 'parent'});
      await _verifyEditAndLifecycle(tester, api, token, oracle);
      await _verifyAssessmentSettings(tester, api, token, oracle);
      await _verifyUnderstandingCategories(tester, api, token, oracle);
      await _verifyMutationUncertaintyAndNoReplay(tester, api, token);
      await _verifyCrossAccountSessionIsolation(tester, api);

      await _logout(tester);
      api.close();
    },
    timeout: const Timeout(Duration(minutes: 22)),
  );

  testWidgets(
    'Stage 3 state persists in a fresh Windows process after backend restart',
    (tester) async {
      _assertEnvironment();
      await _configureDesktopView(tester);
      final api = _RealApi();

      await _clearLocalToken();
      app.main();
      await _waitForLogin(tester);
      await _signIn(
        tester,
        loginName: 'e2e_s03_target_admin',
        password: _stage3Password,
      );
      await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
      final token = await _requiredLocalToken();

      final profile = await _getData(api, '/institution/profile', token);
      expect(profile['name'], _editedInstitutionName);
      expect(profile['contact_email'], 'edited-target@e2e-s03.invalid');

      final dashboard = await _getData(api, '/institution/dashboard', token);
      final dashboardUsers = _map(dashboard['users']);
      expect(dashboardUsers, {'teachers': 10, 'students': 10, 'parents': 10});

      for (final specification in _createdUsers) {
        final created = await _findSingleUser(
          api,
          token,
          specification.loginName,
        );
        expect(created['full_name'], specification.fullName);
        expect(created['email'], specification.email);
        expect(created['is_active'], isTrue);
        expect(created['must_change_password'], isFalse);
      }
      final lifecycleUser = await _getData(
        api,
        '/institution/users/$_targetTeacherId',
        token,
      );
      expect(lifecycleUser['full_name'], _editedLifecycleUserName);
      expect(lifecycleUser['email'], 'edited-lifecycle@e2e-s03.invalid');
      expect(lifecycleUser['phone'], isNull);
      expect(lifecycleUser['is_active'], isTrue);

      _goTo(tester, AppRoutePaths.institutionAdminInstitution);
      await _waitUntilFound(tester, find.text(_editedInstitutionName));
      _goTo(
        tester,
        AppRoutePaths.institutionAdminUserDetailLocation(_targetTeacherId),
      );
      await _waitUntilFound(tester, find.text(_editedLifecycleUserName));

      final settings = await _getData(
        api,
        '/institution/settings/assessment',
        token,
      );
      expect(settings['acceptable_score_difference'], 12.5);
      expect(settings['blitz_timer_start_mode'], 'individual');
      expect(settings['student_result_release_mode'], 'manual_teacher');
      expect(settings['parent_result_release_mode'], 'hidden');
      expect(settings['timezone'], 'Europe/London');

      final categories = await _getCollectionWithoutPagination(
        api,
        '/institution/understanding-categories',
        token,
      );
      expect(categories.map((category) => category['min_score']).toList(), [
        91,
        71,
        51,
        0,
        null,
      ]);
      expect(categories.map((category) => category['max_score']).toList(), [
        100,
        90,
        70,
        50,
        null,
      ]);

      _goTo(tester, AppRoutePaths.institutionAdminSettings);
      await _waitUntilFound(
        tester,
        find.byKey(const Key('assessmentSettingsSummary')),
      );
      await _waitUntilFound(
        tester,
        find.byKey(const Key('understandingCategoriesSummary')),
      );
      expect(find.textContaining('12.5'), findsWidgets);
      expect(find.textContaining('91'), findsWidgets);

      await _logout(tester);
      api.close();
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}

Future<void> _verifyProtectedRouteMatrix(_RealApi api) async {
  for (final request in _institutionRouteMatrix()) {
    final response = await api.request(
      request.method,
      request.path,
      data: request.body,
    );
    _expectError(response, 401, 'authentication_required');
  }

  for (final login in const [
    'e2e_s03_platform_owner',
    'e2e_s03_teacher',
    'e2e_s03_student',
    'e2e_s03_parent',
  ]) {
    final token = await _loginForToken(api, login, _stage3Password);
    for (final request in _institutionRouteMatrix()) {
      final response = await api.request(
        request.method,
        request.path,
        token: token,
        data: request.body,
      );
      _expectError(response, 403, 'forbidden');
    }
  }

  final passwordGateToken = await _loginForToken(
    api,
    'e2e_s03_password_gate_admin',
    _firstLoginPassword,
  );
  _expectError(
    await api.request(
      'GET',
      '/institution/dashboard',
      token: passwordGateToken,
    ),
    403,
    'password_change_required',
  );
  await _expectLoginError(
    api,
    'e2e_s03_inactive_admin',
    _stage3Password,
    'user_inactive',
  );
  await _expectLoginError(
    api,
    'e2e_s03_inactive_institution_admin',
    _stage3Password,
    'institution_inactive',
  );
}

Future<void> _verifyEmptyInstitutionBaseline(
  WidgetTester tester,
  _RealApi api,
  JsonMap oracle,
) async {
  await _signIn(
    tester,
    loginName: 'e2e_s03_empty_admin',
    password: _stage3Password,
  );
  await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionDashboardData')),
  );
  expect(
    _textForKey(tester, 'institutionAdminInstitutionName'),
    'Institution: $_emptyInstitutionName',
  );
  final expectedDashboard = _map(_map(oracle['dashboard'])['empty']);
  expect(_map(_map(oracle['profiles'])['empty'])['id'], _emptyInstitutionId);
  expect(expectedDashboard, {'teachers': 0, 'students': 0, 'parents': 0});
  expect(_textForKey(tester, 'institutionDashboardTeachersValue'), '0');
  expect(_textForKey(tester, 'institutionDashboardStudentsValue'), '0');
  expect(_textForKey(tester, 'institutionDashboardParentsValue'), '0');

  final token = await _requiredLocalToken();
  expect(
    _map((await _getData(api, '/institution/dashboard', token))['users']),
    expectedDashboard,
  );
  final settings = await _getData(
    api,
    '/institution/settings/assessment',
    token,
  );
  expect(settings['acceptable_score_difference'], isNull);
  expect(settings['blitz_timer_start_mode'], isNull);
  expect(settings['student_result_release_mode'], isNull);
  expect(settings['parent_result_release_mode'], isNull);
  expect(
    await _getCollectionWithoutPagination(
      api,
      '/institution/understanding-categories',
      token,
    ),
    isEmpty,
  );

  _goTo(tester, AppRoutePaths.institutionAdminSettings);
  await _waitUntilFound(
    tester,
    find.textContaining('Educational policy status: Not configured.'),
  );
  await _waitUntilFound(
    tester,
    find.text('Understanding category status: Configuration required.'),
  );
  expect(find.text(_targetInstitutionName), findsNothing);
  expect(find.text(_foreignInstitutionName), findsNothing);
  await _logout(tester);
}

Future<void> _verifyShellSessionAndDashboard(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  expect(find.byKey(const Key('institutionAdminNavigation')), findsOneWidget);
  expect(find.text('Dashboard'), findsWidgets);
  expect(find.text('Users'), findsWidgets);
  expect(find.text('Institution'), findsWidgets);
  expect(find.text('Settings'), findsWidgets);
  expect(find.text('Groups'), findsNothing);
  expect(find.text('Relationships'), findsNothing);
  expect(find.text('Reports'), findsNothing);
  expect(_textForKey(tester, 'institutionAdminPageTitle'), 'Dashboard');
  expect(
    _textForKey(tester, 'institutionAdminCurrentUser'),
    'Current user: E2E S03 Target Admin',
  );
  expect(
    _textForKey(tester, 'institutionAdminInstitutionName'),
    'Institution: $_targetInstitutionName',
  );

  final me = await _getData(api, '/auth/me', token);
  _expectExactKeys(me, {
    'id',
    'institution_id',
    'role',
    'full_name',
    'login_name',
    'email',
    'phone',
    'is_active',
    'must_change_password',
    'institution',
  });
  expect(me['id'], _targetAdminId);
  expect(me['institution_id'], _targetInstitutionId);
  expect(me['role'], 'institution_admin');
  final institution = _map(me['institution']);
  _expectExactKeys(institution, {'id', 'name', 'status', 'timezone'});
  expect(institution['name'], _targetInstitutionName);

  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionDashboardData')),
  );
  final expected = _map(_map(oracle['dashboard'])['target']);
  expect(
    _textForKey(tester, 'institutionDashboardTeachersValue'),
    '${expected['teachers']}',
  );
  expect(
    _textForKey(tester, 'institutionDashboardStudentsValue'),
    '${expected['students']}',
  );
  expect(
    _textForKey(tester, 'institutionDashboardParentsValue'),
    '${expected['parents']}',
  );

  final dashboard = await _getData(api, '/institution/dashboard', token);
  _expectExactKeys(dashboard, {'users'});
  expect(_map(dashboard['users']), expected);

  _goTo(tester, AppRoutePaths.institutionAdminUsers);
  await _waitForRoute(tester, AppRoutePaths.institutionAdminUsers);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionUserListSurface')),
  );
  _goTo(tester, AppRoutePaths.institutionAdmin);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionDashboardData')),
  );
  GoRouter.of(_routerContext(tester)).refresh();
  await tester.pump();
  expect(find.byKey(const Key('institutionAdminShell')), findsOneWidget);
}

Future<void> _verifyAuthorizationInputAndDisclosure(
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  _expectError(
    await api.request(
      'GET',
      '/institution/dashboard',
      token: token,
      queryParameters: {'institution_id': _foreignInstitutionId},
    ),
    422,
    'validation_failed',
  );
  _expectError(
    await api.request(
      'GET',
      '/institution/profile',
      token: token,
      data: <String, Object?>{},
    ),
    422,
    'validation_failed',
  );
  _expectError(
    await api.request(
      'GET',
      '/institution/users/$_foreignTeacherId',
      token: token,
    ),
    404,
    'resource_not_found',
  );
  _expectError(
    await api.request(
      'GET',
      '/institution/users/$_unknownUserId',
      token: token,
    ),
    404,
    'resource_not_found',
  );
  for (final hiddenUserId in [
    _targetInstitutionAdminUserId,
    _platformOwnerId,
  ]) {
    _expectError(
      await api.request(
        'GET',
        '/institution/users/$hiddenUserId',
        token: token,
      ),
      404,
      'resource_not_found',
    );
  }
  _expectError(
    await api.request(
      'PATCH',
      '/institution/profile',
      token: token,
      data: {'status': 'inactive', 'institution_id': _foreignInstitutionId},
    ),
    422,
    'validation_failed',
  );
  _expectError(
    await api.request(
      'POST',
      '/institution/users',
      token: token,
      data: {
        'role': 'institution_admin',
        'full_name': 'Forbidden Role',
        'login_name': 'e2e_s03_forbidden_role',
        'password': _initialUserPassword,
      },
    ),
    422,
    'validation_failed',
  );

  final foreignToken = await _loginForToken(
    api,
    'e2e_s03_foreign_admin',
    _stage3Password,
  );
  _expectError(
    await api.request(
      'GET',
      '/institution/users/$_targetTeacherId',
      token: foreignToken,
    ),
    404,
    'resource_not_found',
  );
  final foreignProfile = await _getData(
    api,
    '/institution/profile',
    foreignToken,
  );
  expect(foreignProfile['id'], _foreignInstitutionId);
  expect(foreignProfile['name'], _foreignInstitutionName);

  final profile = await _getData(api, '/institution/profile', token);
  _expectExactKeys(profile, {
    'id',
    'name',
    'type',
    'status',
    'contact_email',
    'contact_phone',
    'address',
    'description',
    'created_at',
    'updated_at',
  });
  expect(profile['id'], _targetInstitutionId);
  expect(profile['name'], _map(_map(oracle['profiles'])['target'])['name']);
  expect(jsonEncode(profile), isNot(contains('password')));
  expect(jsonEncode(profile), isNot(contains('token')));
  expect(jsonEncode(profile), isNot(contains('created_by')));
}

Future<void> _verifyProfile(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  _goTo(tester, AppRoutePaths.institutionAdminInstitution);
  await _waitForRoute(tester, AppRoutePaths.institutionAdminInstitution);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionProfileData')),
  );
  expect(_textForKey(tester, 'institutionAdminPageTitle'), 'Institution');
  expect(
    _textForKey(tester, 'institutionProfileNameValue'),
    _map(_map(oracle['profiles'])['target'])['name'],
  );
  expect(_textForKey(tester, 'institutionProfileTypeValue'), 'School');
  expect(_textForKey(tester, 'institutionProfileStatusValue'), 'Active');

  await _tapKey(tester, 'institutionProfileEditButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionProfileEditForm')),
  );
  await _enterText(
    tester,
    'institutionProfileNameField',
    _editedInstitutionName,
  );
  await _enterText(
    tester,
    'institutionProfileContactEmailField',
    'edited-target@e2e-s03.invalid',
  );
  await _enterText(tester, 'institutionProfileContactPhoneField', '');
  await _enterText(
    tester,
    'institutionProfileAddressField',
    'E2E S03 edited address',
  );
  await _enterText(tester, 'institutionProfileDescriptionField', '');
  await _tapKey(tester, 'institutionProfileSaveButton');
  await _waitUntilFound(tester, find.text(_editedInstitutionName));
  await _waitUntilFound(
    tester,
    find.textContaining('Institution profile updated'),
  );

  final profile = await _getData(api, '/institution/profile', token);
  expect(profile['name'], _editedInstitutionName);
  expect(profile['type'], 'school');
  expect(profile['status'], 'active');
  expect(profile['contact_email'], 'edited-target@e2e-s03.invalid');
  expect(profile['contact_phone'], isNull);
  expect(profile['address'], 'E2E S03 edited address');
  expect(profile['description'], isNull);
}

Future<void> _verifyUserListAndDetail(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  _goTo(tester, AppRoutePaths.institutionAdminUsers);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionUserListData')),
  );
  expect(_textForKey(tester, 'institutionAdminPageTitle'), 'Users');

  final initialOracle = _map(_map(oracle['users'])['default_page_1']);
  final initialItems = _list(initialOracle['items']).map(_map).toList();
  expect(initialItems, hasLength(20));
  expect(_textForKey(tester, 'institutionUserPageStatus'), 'Page 1 of 2');
  expect(_textForKey(tester, 'institutionUserRangeStatus'), '1-20 of 27');
  for (final item in initialItems.take(4)) {
    expect(find.text(item['full_name']! as String), findsOneWidget);
  }

  final secondPageOracle = _map(_map(oracle['users'])['default_page_2']);
  final secondPageItems = _list(secondPageOracle['items']).map(_map).toList();
  await _tapKey(tester, 'institutionUserNextButton');
  await _waitUntilFound(
    tester,
    find.text(secondPageItems.first['full_name']! as String),
  );
  expect(_textForKey(tester, 'institutionUserPageStatus'), 'Page 2 of 2');
  await _tapKey(tester, 'institutionUserPreviousButton');
  await _waitUntilFound(
    tester,
    find.text(initialItems.first['full_name']! as String),
  );

  await _selectDropdown(tester, 'institutionUserRoleFilter', 'Teacher');
  await _waitUntilFound(tester, find.text('E2E S03 Teacher'));
  expect(_textForKey(tester, 'institutionUserRangeStatus'), '1-9 of 9');
  await _selectDropdown(tester, 'institutionUserStatusFilter', 'Inactive');
  await _waitUntilFound(tester, find.text('E2E S03 Member 07'));
  await _tapKey(tester, 'institutionUserClearFiltersButton');
  await _waitUntilFound(
    tester,
    find.text(initialItems.first['full_name']! as String),
  );

  for (final searchCase in const {
    'search_name_case': 'e2E s03 tEaChEr',
    'search_login': 'e2e_s03_teacher',
    'search_email': 'e2e_s03_teacher@e2e-s03.invalid',
    'search_phone': '+998930300201',
  }.entries) {
    await _enterText(tester, 'institutionUserSearchField', searchCase.value);
    await _submitSearch(tester);
    await _waitUntilTextForKeyEquals(
      tester,
      'institutionUserRangeStatus',
      _oracleRange(oracle, searchCase.key),
    );
    expect(find.text('E2E S03 Teacher'), findsOneWidget);
  }

  await _enterText(tester, 'institutionUserSearchField', '% User');
  await _submitSearch(tester);
  await _waitUntilTextForKeyEquals(
    tester,
    'institutionUserRangeStatus',
    _oracleRange(oracle, 'literal_percent'),
  );
  await _waitUntilFound(tester, find.text('E2E S03 Literal % User'));
  expect(find.text('E2E S03 Literal _ User'), findsNothing);
  await _enterText(tester, 'institutionUserSearchField', '_ User');
  await _submitSearch(tester);
  await _waitUntilTextForKeyEquals(
    tester,
    'institutionUserRangeStatus',
    _oracleRange(oracle, 'literal_underscore'),
  );
  await _waitUntilFound(tester, find.text('E2E S03 Literal _ User'));
  expect(find.text('E2E S03 Literal % User'), findsNothing);
  await _enterText(tester, 'institutionUserSearchField', '! User');
  await _submitSearch(tester);
  await _waitUntilTextForKeyEquals(
    tester,
    'institutionUserRangeStatus',
    _oracleRange(oracle, 'literal_escape'),
  );
  await _waitUntilFound(tester, find.text('E2E S03 Literal ! User'));
  expect(find.text('E2E S03 Literal _ User'), findsNothing);
  await _tapKey(tester, 'institutionUserClearFiltersButton');

  final directList = await _getCollection(api, '/institution/users', token);
  expect(
    directList.items.map((item) => item['id']).toList(),
    initialItems.map((item) => item['id']).toList(),
  );
  expect(directList.pagination, _map(initialOracle['pagination']));
  for (final user in directList.items) {
    _expectExactKeys(user, {
      'id',
      'role',
      'full_name',
      'login_name',
      'email',
      'phone',
      'is_active',
      'must_change_password',
      'last_login_at',
      'deactivated_at',
      'created_at',
      'updated_at',
    });
  }

  for (final sortCase in const {
    'sort_full_name_asc': ('full_name', 'asc'),
    'sort_full_name_desc': ('full_name', 'desc'),
    'sort_login_name_asc': ('login_name', 'asc'),
    'sort_login_name_desc': ('login_name', 'desc'),
    'sort_created_at_asc': ('created_at', 'asc'),
    'sort_created_at_desc': ('created_at', 'desc'),
    'sort_updated_at_asc': ('updated_at', 'asc'),
    'sort_updated_at_desc': ('updated_at', 'desc'),
  }.entries) {
    final expectedCase = _map(_map(oracle['users'])[sortCase.key]);
    final actual = await _getCollection(
      api,
      '/institution/users',
      token,
      queryParameters: {
        'page': 1,
        'per_page': 20,
        'sort': sortCase.value.$1,
        'direction': sortCase.value.$2,
      },
    );
    expect(
      actual.items.map((item) => item['id']).toList(),
      _list(expectedCase['items']).map((item) => _map(item)['id']).toList(),
    );
    expect(actual.pagination, _map(expectedCase['pagination']));
  }
  for (final pageSize in [50, 100]) {
    final expectedCase = _map(_map(oracle['users'])['per_page_$pageSize']);
    final actual = await _getCollection(
      api,
      '/institution/users',
      token,
      queryParameters: {
        'page': 1,
        'per_page': pageSize,
        'sort': 'full_name',
        'direction': 'asc',
      },
    );
    expect(actual.items, hasLength(27));
    expect(actual.pagination, _map(expectedCase['pagination']));
  }

  _goTo(
    tester,
    AppRoutePaths.institutionAdminUserDetailLocation(_targetTeacherId),
  );
  await _waitUntilFound(tester, find.text('E2E S03 Teacher'));
  expect(_textForKey(tester, 'institutionAdminPageTitle'), 'User Details');
  expect(_textForKey(tester, 'institutionUserDetailValueRole'), 'Teacher');
  expect(_textForKey(tester, 'institutionUserDetailValueStatus'), 'Active');
  expect(find.text(_targetInstitutionId), findsNothing);

  _goTo(
    tester,
    AppRoutePaths.institutionAdminUserDetailLocation(_foreignTeacherId),
  );
  await _waitUntilFound(tester, find.text('User unavailable'));
  expect(
    _visibleTextSnapshot(tester),
    isNot(contains(_foreignInstitutionName)),
  );
  expect(_visibleTextSnapshot(tester), isNot(contains(_foreignTeacherId)));

  _goTo(
    tester,
    AppRoutePaths.institutionAdminUserDetailLocation(_unknownUserId),
  );
  await _waitUntilFound(tester, find.text('User unavailable'));

  for (final hiddenUserId in [
    _targetInstitutionAdminUserId,
    _platformOwnerId,
  ]) {
    _goTo(
      tester,
      AppRoutePaths.institutionAdminUserDetailLocation(hiddenUserId),
    );
    await _waitUntilFound(tester, find.text('User unavailable'));
    expect(_visibleTextSnapshot(tester), isNot(contains(hiddenUserId)));
  }
}

Future<String> _createUser(
  WidgetTester tester,
  _RealApi api,
  String token,
  _CreatedUserSpec specification,
) async {
  _goTo(tester, AppRoutePaths.institutionAdminUserCreate);
  await _waitForRoute(tester, AppRoutePaths.institutionAdminUserCreate);
  await tester.pumpAndSettle();
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionAdminUserCreateScreen')),
  );
  expect(_textForKey(tester, 'institutionAdminPageTitle'), 'Create User');
  expect(find.text('Institution Admin'), findsWidgets);
  expect(find.text('Platform Owner'), findsNothing);

  await _selectDropdown(
    tester,
    'institutionUserCreateRoleField',
    specification.roleLabel,
  );
  await _enterText(
    tester,
    'institutionUserCreateFullNameField',
    specification.fullName,
  );
  await _enterText(
    tester,
    'institutionUserCreateLoginNameField',
    specification.loginName,
  );
  await _enterText(
    tester,
    'institutionUserCreateEmailField',
    specification.email,
  );
  await _enterText(tester, 'institutionUserCreatePhoneField', '+998909876543');
  await _enterText(
    tester,
    'institutionUserCreatePasswordField',
    _initialUserPassword,
  );
  await _tapKey(tester, 'institutionUserCreateSubmitButton');
  await _waitUntilFound(tester, find.text(specification.fullName));
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionUserCreateSuccessSnackBar')),
  );

  final created = await _findSingleUser(api, token, specification.loginName);
  _expectExactKeys(created, {
    'id',
    'role',
    'full_name',
    'login_name',
    'email',
    'phone',
    'is_active',
    'must_change_password',
    'last_login_at',
    'deactivated_at',
    'created_at',
    'updated_at',
  });
  expect(created['role'], specification.roleCode);
  expect(created['is_active'], isTrue);
  expect(created['must_change_password'], isTrue);

  final createdUserId = created['id']! as String;
  await _waitForRoute(
    tester,
    AppRoutePaths.institutionAdminUserDetailLocation(createdUserId),
  );
  return createdUserId;
}

Future<void> _verifyDashboardAfterCreates(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
  int completedCreates,
) async {
  final initial = _map(_map(oracle['dashboard'])['target']);
  final expected = <String, Object?>{
    'teachers': (initial['teachers']! as int) + (completedCreates >= 1 ? 1 : 0),
    'students': (initial['students']! as int) + (completedCreates >= 2 ? 1 : 0),
    'parents': (initial['parents']! as int) + (completedCreates >= 3 ? 1 : 0),
  };

  _goTo(tester, AppRoutePaths.institutionAdmin);
  await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionDashboardData')),
  );
  expect(
    _textForKey(tester, 'institutionDashboardTeachersValue'),
    '${expected['teachers']}',
  );
  expect(
    _textForKey(tester, 'institutionDashboardStudentsValue'),
    '${expected['students']}',
  );
  expect(
    _textForKey(tester, 'institutionDashboardParentsValue'),
    '${expected['parents']}',
  );
  expect(
    _map((await _getData(api, '/institution/dashboard', token))['users']),
    expected,
  );
}

Future<void> _verifyCreatedUserFirstLogin(
  WidgetTester tester,
  _RealApi api,
  _CreatedUserSpec specification,
) async {
  await _signIn(
    tester,
    loginName: specification.loginName,
    password: _initialUserPassword,
  );
  await _waitForRoute(tester, AppRoutePaths.changePassword);
  expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
  final token = await _requiredLocalToken();
  _expectError(
    await api.request('GET', '/institution/dashboard', token: token),
    403,
    'password_change_required',
  );

  await _submitPasswordChange(
    tester,
    currentPassword: _initialUserPassword,
    newPassword: _newUserPassword,
  );
  await _waitForRoute(tester, specification.route);
  expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
  await _logout(tester);

  await _loginForToken(api, specification.loginName, _newUserPassword);
  await _expectLoginError(
    api,
    specification.loginName,
    _initialUserPassword,
    'invalid_credentials',
  );
}

Future<void> _verifyEditAndLifecycle(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  final retainedToken = await _loginForToken(
    api,
    'e2e_s03_teacher',
    _stage3Password,
  );
  final before = await _getData(
    api,
    '/institution/users/$_targetTeacherId',
    token,
  );
  final lastLoginAt = before['last_login_at'];
  _goTo(
    tester,
    AppRoutePaths.institutionAdminUserDetailLocation(_targetTeacherId),
  );
  await _waitUntilFound(tester, find.text('E2E S03 Teacher'));
  await _tapKey(tester, 'institutionUserEditAction');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionUserEditDialog')),
  );
  await _enterText(
    tester,
    'institutionUserEditFullName',
    _editedLifecycleUserName,
  );
  await _enterText(
    tester,
    'institutionUserEditEmail',
    'edited-lifecycle@e2e-s03.invalid',
  );
  await _enterText(tester, 'institutionUserEditPhone', '');
  await _tapKey(tester, 'institutionUserEditSubmit');
  await _waitUntilFound(tester, find.text(_editedLifecycleUserName));
  await _waitUntilFound(tester, find.textContaining('User updated'));
  await _waitUntilGone(
    tester,
    find.byKey(const Key('institutionUserEditDialog')),
  );

  var current = await _getData(
    api,
    '/institution/users/$_targetTeacherId',
    token,
  );
  expect(current['full_name'], _editedLifecycleUserName);
  expect(current['email'], 'edited-lifecycle@e2e-s03.invalid');
  expect(current['phone'], isNull);
  expect(current['must_change_password'], isFalse);

  await _tapKey(tester, 'institutionUserLifecycleAction');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionUserLifecycleDialog')),
  );
  expect(find.text('Deactivate user'), findsWidgets);
  await _expectSeededTokenRowsUnchanged('active-to-inactive', () async {
    await _tapKey(tester, 'institutionUserLifecycleConfirm');
    await _waitUntilFound(tester, find.text('Inactive'));
    await _waitUntilGone(
      tester,
      find.byKey(const Key('institutionUserLifecycleDialog')),
    );
  });
  await _expectLoginError(
    api,
    'e2e_s03_teacher',
    _stage3Password,
    'user_inactive',
  );

  _expectError(
    await api.request('GET', '/auth/me', token: retainedToken),
    403,
    'user_inactive',
  );
  await _expectSeededTokenRowsUnchanged('repeated-inactive', () async {
    final repeatedInactive = await api.request(
      'POST',
      '/institution/users/$_targetTeacherId/deactivate',
      token: token,
    );
    expect(repeatedInactive.statusCode, 200);
  });

  current = await _getData(api, '/institution/users/$_targetTeacherId', token);
  final deactivatedAt = current['deactivated_at'];
  expect(current['is_active'], isFalse);
  expect(deactivatedAt, isNotNull);
  expect(current['must_change_password'], isFalse);

  await _tapKey(tester, 'institutionUserLifecycleAction');
  await _waitUntilFound(tester, find.text('Activate user'));
  await _expectSeededTokenRowsUnchanged('inactive-to-active', () async {
    await _tapKey(tester, 'institutionUserLifecycleConfirm');
    await _waitUntilFound(tester, find.text('Active'));
    await _waitUntilGone(
      tester,
      find.byKey(const Key('institutionUserLifecycleDialog')),
    );
  });

  current = await _getData(api, '/institution/users/$_targetTeacherId', token);
  expect(current['is_active'], isTrue);
  expect(current['deactivated_at'], isNull);
  expect(current['must_change_password'], isFalse);
  expect(current['last_login_at'], lastLoginAt);
  final retainedIdentity = await _getData(api, '/auth/me', retainedToken);
  expect(retainedIdentity['id'], _targetTeacherId);

  await _expectSeededTokenRowsUnchanged('repeated-active', () async {
    final repeatedActive = await api.request(
      'POST',
      '/institution/users/$_targetTeacherId/activate',
      token: token,
    );
    expect(repeatedActive.statusCode, 200);
  });
  final revokedToken = await _loginForToken(
    api,
    'e2e_s03_teacher',
    _stage3Password,
  );
  final logout = await api.request('POST', '/auth/logout', token: revokedToken);
  expect(logout.statusCode, 204);
  expect(
    (await api.request('GET', '/auth/me', token: revokedToken)).statusCode,
    401,
  );

  final initialCounts = _map(_map(oracle['dashboard'])['target']);
  final expectedCounts = {
    'teachers': (initialCounts['teachers']! as int) + 1,
    'students': (initialCounts['students']! as int) + 1,
    'parents': (initialCounts['parents']! as int) + 1,
  };
  expect(
    _map((await _getData(api, '/institution/dashboard', token))['users']),
    expectedCounts,
  );
}

Future<void> _verifyAssessmentSettings(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  final initial = await _getData(
    api,
    '/institution/settings/assessment',
    token,
  );
  final oracleSettings = _map(_map(oracle['settings'])['target']);
  expect(initial['acceptable_score_difference'], isNull);
  expect(
    initial['blitz_timer_start_mode'],
    oracleSettings['blitz_timer_start_mode'],
  );
  expect(
    initial['student_result_release_mode'],
    oracleSettings['student_result_release_mode'],
  );
  expect(
    initial['parent_result_release_mode'],
    oracleSettings['parent_result_release_mode'],
  );
  expect(initial['timezone'], oracleSettings['timezone']);
  expect(initial['educational_policy_configured'], isFalse);
  _expectExactKeys(initial, {
    'educational_policy_configured',
    'acceptable_score_difference',
    'blitz_timer_start_mode',
    'student_result_release_mode',
    'parent_result_release_mode',
    'timezone',
    'upload_limits',
    'fixed_attempt_rules',
  });
  expect(_map(initial['fixed_attempt_rules']), {
    'homework_normal_attempts': 3,
    'blitz_normal_attempts': 1,
    'blitz_max_additional_exception_attempts': 1,
  });

  _goTo(tester, AppRoutePaths.institutionAdminSettings);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('assessmentSettingsSummary')),
  );
  await _waitUntilFound(
    tester,
    find.byKey(const Key('understandingCategoriesSummary')),
  );
  expect(_textForKey(tester, 'institutionAdminPageTitle'), 'Settings');
  expect(find.text('Homework normal attempts'), findsOneWidget);
  expect(find.text('Blitz normal attempts'), findsOneWidget);
  expect(
    find.text('Maximum additional exception attempts per Student and Blitz'),
    findsOneWidget,
  );

  await _tapKey(tester, 'assessmentSettingsEditButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('assessmentSettingsForm')),
  );
  await _enterText(tester, 'assessmentSettingsScoreDifferenceField', '12.5');
  await _selectDropdown(
    tester,
    'assessmentSettingsTimerModeField',
    'Individual',
  );
  await _selectDropdown(
    tester,
    'assessmentSettingsStudentReleaseField',
    'Teacher-controlled',
  );
  await _selectDropdown(
    tester,
    'assessmentSettingsParentReleaseField',
    'Hidden',
  );
  await _enterText(tester, 'assessmentSettingsTimezoneField', 'Europe/London');
  await _enterText(tester, 'assessmentSettingsLearningLimitField', '20');
  await _enterText(tester, 'assessmentSettingsSubmissionLimitField', '10');
  await _tapKey(tester, 'assessmentSettingsSaveButton');
  await _waitUntilFound(
    tester,
    find.textContaining('Assessment settings saved'),
  );
  await _waitUntilFound(
    tester,
    find.byKey(const Key('assessmentSettingsSummary')),
  );
  expect(
    find.byKey(const Key('understandingCategoriesSummary')),
    findsOneWidget,
  );

  final updated = await _getData(
    api,
    '/institution/settings/assessment',
    token,
  );
  expect(updated['acceptable_score_difference'], 12.5);
  expect(updated['blitz_timer_start_mode'], 'individual');
  expect(updated['student_result_release_mode'], 'manual_teacher');
  expect(updated['parent_result_release_mode'], 'hidden');
  expect(updated['timezone'], 'Europe/London');
  final limits = _map(updated['upload_limits']);
  expect(limits['learning_material_max_mb'], 20);
  expect(limits['student_submission_max_mb'], 10);
  expect(limits['platform_learning_material_max_mb'], 25);
  expect(limits['platform_student_submission_max_mb'], 15);

  _expectError(
    await api.request(
      'PUT',
      '/institution/settings/assessment',
      token: token,
      data: {
        ...updated,
        'homework_normal_attempts': 4,
        'institution_id': _foreignInstitutionId,
      },
    ),
    422,
    'validation_failed',
  );
}

Future<void> _verifyUnderstandingCategories(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  final initial = await _getCollectionWithoutPagination(
    api,
    '/institution/understanding-categories',
    token,
  );
  final oracleCategories = _list(
    _map(oracle['categories'])['target'],
  ).map(_map).toList();
  expect(
    initial.map((item) => item['code']).toList(),
    oracleCategories.map((item) => item['code']).toList(),
  );
  expect(initial, isEmpty);
  for (final category in initial) {
    _expectExactKeys(category, {
      'code',
      'label',
      'min_score',
      'max_score',
      'sort_order',
    });
  }

  await _tapKey(tester, 'understandingCategoriesEditButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('understandingCategoriesForm')),
  );
  expect(
    find.byKey(const Key('understandingCategoryNotCompletedReadOnly')),
    findsOneWidget,
  );
  await _enterText(tester, 'understandingCategoryunderstoodWellMinField', '91');
  await _enterText(
    tester,
    'understandingCategoryunderstoodWellMaxField',
    '100',
  );
  await _enterText(
    tester,
    'understandingCategorypartiallyUnderstoodMinField',
    '71',
  );
  await _enterText(
    tester,
    'understandingCategorypartiallyUnderstoodMaxField',
    '90',
  );
  await _enterText(tester, 'understandingCategoryneedsRevisionMinField', '51');
  await _enterText(tester, 'understandingCategoryneedsRevisionMaxField', '70');
  await _enterText(
    tester,
    'understandingCategoryneedsTeacherSupportMinField',
    '0',
  );
  await _enterText(
    tester,
    'understandingCategoryneedsTeacherSupportMaxField',
    '50',
  );
  await _waitUntilFound(tester, find.textContaining('covered exactly once'));
  await _tapKey(tester, 'understandingCategoriesSaveButton');
  await _waitUntilFound(
    tester,
    find.textContaining('Understanding categories saved'),
  );
  await _waitUntilFound(
    tester,
    find.byKey(const Key('understandingCategoriesSummary')),
  );
  expect(find.byKey(const Key('assessmentSettingsSummary')), findsOneWidget);
  expect(find.textContaining('Not completed'), findsWidgets);
  expect(find.text('No numeric range (null / null).'), findsOneWidget);

  final updated = await _getCollectionWithoutPagination(
    api,
    '/institution/understanding-categories',
    token,
  );
  expect(updated.map((item) => item['code']).toList(), [
    'understood_well',
    'partially_understood',
    'needs_revision',
    'needs_teacher_support',
    'not_completed',
  ]);
  expect(updated.map((item) => item['min_score']).toList(), [
    91,
    71,
    51,
    0,
    null,
  ]);
  expect(updated.map((item) => item['max_score']).toList(), [
    100,
    90,
    70,
    50,
    null,
  ]);

  final foreignToken = await _loginForToken(
    api,
    'e2e_s03_foreign_admin',
    _stage3Password,
  );
  final foreign = await _getCollectionWithoutPagination(
    api,
    '/institution/understanding-categories',
    foreignToken,
  );
  expect(foreign.map((item) => item['min_score']).toList(), [
    90,
    70,
    40,
    0,
    null,
  ]);
}

Future<void> _verifyMutationUncertaintyAndNoReplay(
  WidgetTester tester,
  _RealApi api,
  String token,
) async {
  _goTo(tester, AppRoutePaths.institutionAdminInstitution);
  await _waitUntilFound(tester, find.text(_editedInstitutionName));
  await _tapKey(tester, 'institutionProfileEditButton');
  await _enterText(
    tester,
    'institutionProfileNameField',
    'E2E S03 Unconfirmed Name',
  );

  await _setDedicatedBackendRunning(running: false);
  try {
    await _tapKey(tester, 'institutionProfileSaveButton');
    await _waitUntilFound(
      tester,
      find.textContaining('could not be verified'),
      timeout: const Duration(seconds: 50),
    );
    expect(find.textContaining('saved successfully'), findsNothing);
  } finally {
    await _setDedicatedBackendRunning(running: true);
    await _waitForDedicatedBackend();
  }

  var profile = await _getData(api, '/institution/profile', token);
  expect(profile['name'], _editedInstitutionName);
  await Future<void>.delayed(const Duration(seconds: 2));
  profile = await _getData(api, '/institution/profile', token);
  expect(profile['name'], _editedInstitutionName);

  final reload = find.byKey(const Key('institutionProfileReloadButton'));
  if (reload.evaluate().isNotEmpty) {
    await _tapKey(tester, 'institutionProfileReloadButton');
  } else {
    _goTo(tester, AppRoutePaths.institutionAdmin);
    await _waitUntilFound(
      tester,
      find.byKey(const Key('institutionDashboardData')),
    );
    _goTo(tester, AppRoutePaths.institutionAdminInstitution);
  }
  await _waitUntilFound(tester, find.text(_editedInstitutionName));
  expect(find.text('E2E S03 Unconfirmed Name'), findsNothing);
}

Future<void> _verifyCrossAccountSessionIsolation(
  WidgetTester tester,
  _RealApi api,
) async {
  await _logout(tester);
  await _signIn(
    tester,
    loginName: 'e2e_s03_foreign_admin',
    password: _stage3Password,
  );
  await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionDashboardData')),
  );
  expect(
    _textForKey(tester, 'institutionAdminInstitutionName'),
    'Institution: $_foreignInstitutionName',
  );
  expect(_textForKey(tester, 'institutionDashboardTeachersValue'), '1');
  expect(_textForKey(tester, 'institutionDashboardStudentsValue'), '1');
  expect(_textForKey(tester, 'institutionDashboardParentsValue'), '1');
  expect(find.text(_editedInstitutionName), findsNothing);
  expect(find.text(_editedLifecycleUserName), findsNothing);

  _goTo(tester, AppRoutePaths.institutionAdminSettings);
  await _waitUntilFound(tester, find.textContaining('7'));
  await _waitUntilFound(tester, find.textContaining('90'));
  expect(find.textContaining('12.5'), findsNothing);
  expect(find.textContaining('91'), findsNothing);

  final foreignToken = await _requiredLocalToken();
  final foreignProfile = await _getData(
    api,
    '/institution/profile',
    foreignToken,
  );
  expect(foreignProfile['name'], _foreignInstitutionName);
}

Future<JsonMap> _findSingleUser(
  _RealApi api,
  String token,
  String search,
) async {
  final collection = await _getCollection(
    api,
    '/institution/users',
    token,
    queryParameters: {
      'search': search,
      'page': 1,
      'per_page': 20,
      'sort': 'full_name',
      'direction': 'asc',
    },
  );
  expect(collection.items, hasLength(1));
  expect(collection.pagination['total'], 1);

  return collection.items.single;
}

Future<JsonMap> _getData(_RealApi api, String path, String token) async {
  final response = await api.request('GET', path, token: token);
  expect(
    response.statusCode,
    200,
    reason: 'GET $path failed: ${response.data}',
  );
  final envelope = _map(response.data);
  _expectExactKeys(envelope, {'data'});

  return _map(envelope['data']);
}

Future<_CollectionResponse> _getCollection(
  _RealApi api,
  String path,
  String token, {
  Map<String, Object?>? queryParameters,
}) async {
  final response = await api.request(
    'GET',
    path,
    token: token,
    queryParameters: queryParameters,
  );
  expect(
    response.statusCode,
    200,
    reason: 'GET $path failed: ${response.data}',
  );
  final envelope = _map(response.data);
  _expectExactKeys(envelope, {'data', 'meta'});
  final pagination = _map(_map(envelope['meta'])['pagination']);

  return _CollectionResponse(
    items: _list(envelope['data']).map(_map).toList(),
    pagination: pagination,
  );
}

Future<List<JsonMap>> _getCollectionWithoutPagination(
  _RealApi api,
  String path,
  String token,
) async {
  final response = await api.request('GET', path, token: token);
  expect(
    response.statusCode,
    200,
    reason: 'GET $path failed: ${response.data}',
  );
  final envelope = _map(response.data);
  if (envelope.containsKey('meta')) {
    _expectExactKeys(envelope, {'data', 'meta'});
    expect(_map(envelope['meta']), {'configured': false});
    expect(_list(envelope['data']), isEmpty);
  } else {
    _expectExactKeys(envelope, {'data'});
  }

  return _list(envelope['data']).map(_map).toList();
}

Future<String> _loginForToken(
  _RealApi api,
  String login,
  String password,
) async {
  final response = await api.request(
    'POST',
    '/auth/login',
    data: {'login': login, 'password': password},
  );
  expect(response.statusCode, 200, reason: 'Login failed: ${response.data}');
  final envelope = _map(response.data);
  _expectExactKeys(envelope, {'data'});
  final data = _map(envelope['data']);
  _expectExactKeys(data, {'token', 'token_type', 'user'});
  expect(data['token_type'], 'Bearer');

  return data['token']! as String;
}

Future<void> _expectLoginError(
  _RealApi api,
  String login,
  String password,
  String code,
) async {
  final response = await api.request(
    'POST',
    '/auth/login',
    data: {'login': login, 'password': password},
  );
  _expectError(response, code == 'invalid_credentials' ? 401 : 403, code);
}

void _expectError(Response<Object?> response, int status, String code) {
  expect(
    response.statusCode,
    status,
    reason: '${response.requestOptions.path}: ${response.data}',
  );
  final envelope = _map(response.data);
  expect(envelope['code'], code);
  expect(envelope['errors'], isA<Map<Object?, Object?>>());
  expect(envelope['message'], isA<String>());
  expect(
    envelope.keys.toSet().difference({
      'message',
      'code',
      'errors',
      'request_id',
    }),
    isEmpty,
  );
}

Future<JsonMap> _loadOracle() async {
  final file = File(_oraclePath);
  if (!await file.exists()) {
    throw StateError('The Stage 3 independent oracle artifact is unavailable.');
  }
  final oracle = _map(jsonDecode(await file.readAsString()));
  _expectExactKeys(oracle, {
    'runtime',
    'ids',
    'dashboard',
    'profiles',
    'users',
    'settings',
    'categories',
    'preserved_token_row_metadata',
    'frozen_unrelated_scope',
  });
  expect(_map(oracle['runtime']), {
    'environment': 'testing',
    'database': 'testlabuz_testing',
    'driver': 'pgsql',
    'pdo_driver': 'pgsql',
  });
  expect(_list(oracle['preserved_token_row_metadata']), hasLength(2));
  expect(_map(oracle['frozen_unrelated_scope']), {
    'tables': [
      'institutions',
      'users',
      'institution_settings',
      'institution_understanding_categories',
      'personal_access_tokens',
    ],
    'excluded_institution_ids': [_targetInstitutionId],
    'excluded_user_ids': [
      _targetAdminId,
      '03000000-0000-4000-9000-000000000103',
      '03000000-0000-4000-9000-000000000105',
      '03000000-0000-4000-9000-000000000107',
      _platformOwnerId,
      _targetTeacherId,
      '03000000-0000-4000-9000-000000000202',
      '03000000-0000-4000-9000-000000000203',
    ],
    'excluded_user_logins': [
      'e2e_s03_created_teacher',
      'e2e_s03_created_student',
      'e2e_s03_created_parent',
    ],
    'preserved_seeded_token_rows_included': true,
  });

  return oracle;
}

List<_InstitutionRequest> _institutionRouteMatrix() => const [
  _InstitutionRequest('GET', '/institution/dashboard'),
  _InstitutionRequest('GET', '/institution/profile'),
  _InstitutionRequest('PATCH', '/institution/profile', {'name': 'Denied'}),
  _InstitutionRequest('GET', '/institution/users'),
  _InstitutionRequest('POST', '/institution/users', {
    'role': 'teacher',
    'full_name': 'Denied',
    'login_name': 'denied_user',
    'password': 'Denied-Aa1-password',
  }),
  _InstitutionRequest('GET', '/institution/users/$_targetTeacherId'),
  _InstitutionRequest('PATCH', '/institution/users/$_targetTeacherId', {
    'full_name': 'Denied',
  }),
  _InstitutionRequest(
    'POST',
    '/institution/users/$_targetTeacherId/activate',
    {},
  ),
  _InstitutionRequest(
    'POST',
    '/institution/users/$_targetTeacherId/deactivate',
    {},
  ),
  _InstitutionRequest('GET', '/institution/settings/assessment'),
  _InstitutionRequest('PUT', '/institution/settings/assessment', {}),
  _InstitutionRequest('GET', '/institution/understanding-categories'),
  _InstitutionRequest('PUT', '/institution/understanding-categories', {}),
];

JsonMap _map(Object? value) {
  expect(value, isA<Map<Object?, Object?>>());

  return (value! as Map<Object?, Object?>).map(
    (key, item) => MapEntry(key! as String, item),
  );
}

List<Object?> _list(Object? value) {
  expect(value, isA<List<Object?>>());
  return value! as List<Object?>;
}

String _oracleRange(JsonMap oracle, String userCase) {
  final pagination = _map(_map(_map(oracle['users'])[userCase])['pagination']);
  final total = pagination['total']! as int;
  return total == 0 ? '0-0 of 0' : '1-$total of $total';
}

void _expectExactKeys(JsonMap value, Set<String> expected) {
  expect(value.keys.toSet(), expected);
}

Future<void> _expectSeededTokenRowsUnchanged(
  String snapshotName,
  Future<void> Function() lifecycleCommand,
) async {
  const allowedSnapshotNames = {
    'active-to-inactive',
    'repeated-inactive',
    'inactive-to-active',
    'repeated-active',
  };
  if (!allowedSnapshotNames.contains(snapshotName)) {
    throw StateError('Invalid lifecycle token snapshot name.');
  }

  final snapshotPath = '/tmp/testlabuz-stage3-token-$snapshotName.snapshot';
  await _invokeSeededTokenRowOracle('Capture', snapshotPath);
  try {
    await lifecycleCommand();
    await _invokeSeededTokenRowOracle('Compare', snapshotPath);
  } finally {
    await _invokeSeededTokenRowOracle('Remove', snapshotPath);
  }
}

Future<void> _invokeSeededTokenRowOracle(
  String action,
  String snapshotPath,
) async {
  final process = await Process.start('docker', [
    'exec',
    '-i',
    '-e',
    'STAGE3_TOKEN_SNAPSHOT_ACTION=$action',
    '-e',
    'STAGE3_TOKEN_SNAPSHOT_PATH=$snapshotPath',
    _backendContainer,
    'php',
  ]);
  final standardOutput = process.stdout.transform(utf8.decoder).join();
  final standardError = process.stderr.drain<void>();
  process.stdin.write(_seededTokenSnapshotProgram);
  await process.stdin.close();

  final exitCode = await process.exitCode;
  final output = (await standardOutput).trim();
  await standardError;
  expect(
    exitCode,
    0,
    reason: 'The lifecycle token-row oracle $action action failed.',
  );

  final expectedOutput = switch (action) {
    'Capture' => 'Stage3LifecycleTokenBaseline: SAVED',
    'Compare' => 'Stage3LifecycleTokenComparison: PASS',
    'Remove' => 'Stage3LifecycleTokenCleanup: PASS',
    _ => throw StateError('Invalid lifecycle token-row oracle action.'),
  };
  expect(
    output,
    expectedOutput,
    reason: 'The lifecycle token-row oracle $action result was invalid.',
  );
}

Future<void> _setDedicatedBackendRunning({required bool running}) async {
  final action = running ? 'start' : 'stop';
  final result = await Process.run('docker', [action, _backendContainer]);
  expect(result.exitCode, 0, reason: 'docker $action failed for Stage 3.');
}

Future<void> _waitForDedicatedBackend() async {
  final client = Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
      validateStatus: (_) => true,
    ),
  );
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  try {
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await client.get<Object?>('/auth/me');
        if (response.statusCode != null) return;
      } on DioException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  } finally {
    client.close(force: true);
  }
  fail('The dedicated Stage 3 backend did not become ready after restart.');
}

Future<void> _configureDesktopView(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1800, 1000);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Future<void> _signIn(
  WidgetTester tester, {
  required String loginName,
  required String password,
}) async {
  await _waitForLogin(tester);
  await _enterText(tester, 'loginField', loginName);
  await _enterText(tester, 'passwordField', password);
  await _tapKey(tester, 'signInButton');
}

Future<void> _submitPasswordChange(
  WidgetTester tester, {
  required String currentPassword,
  required String newPassword,
}) async {
  await _enterText(tester, 'currentPasswordField', currentPassword);
  await _enterText(tester, 'newPasswordField', newPassword);
  await _enterText(tester, 'confirmPasswordField', newPassword);
  await _tapKey(tester, 'changePasswordButton');
}

Future<void> _logout(WidgetTester tester) async {
  await _tapKey(tester, 'entryLogoutButton');
  await _waitForLogin(tester);
  await _expectNoLocalToken();
  expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
}

Future<void> _waitForLogin(WidgetTester tester) async {
  await _waitForRoute(tester, AppRoutePaths.login);
  await _waitUntilFound(tester, find.byKey(const Key('loginField')));
}

Future<void> _submitSearch(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

Future<void> _selectDropdown(
  WidgetTester tester,
  String keyName,
  String label,
) async {
  final field = find.byKey(Key(keyName));
  await _waitUntilFound(tester, field);
  await tester.ensureVisible(field.last);
  await tester.tap(field.last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pump();
}

Future<void> _enterText(
  WidgetTester tester,
  String keyName,
  String value,
) async {
  final finder = find.byKey(Key(keyName));
  await _waitUntilFound(tester, finder);
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.enterText(finder.last, value);
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String keyName) async {
  final finder = find.byKey(Key(keyName));
  await _waitUntilFound(tester, finder);
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.pump();
}

String _textForKey(WidgetTester tester, String keyName) {
  final finder = find.byKey(Key(keyName));
  expect(finder, findsWidgets);
  final widget = tester.widget(finder.last);
  if (widget is Text) return widget.data ?? '';
  if (widget is SelectableText) return widget.data ?? '';
  if (widget is Chip && widget.label is Text) {
    return (widget.label as Text).data ?? '';
  }
  throw StateError('Expected Text-bearing widget key $keyName.');
}

Future<void> _waitForRoute(WidgetTester tester, String route) {
  return _pumpUntil(
    tester,
    () => _currentRoute(tester) == route,
    reason: 'Expected route $route.',
  );
}

Future<void> _waitUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) {
  return _pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    timeout: timeout,
    reason: 'Expected a required visible widget.',
  );
}

Future<void> _waitUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) {
  return _pumpUntil(
    tester,
    () => finder.evaluate().isEmpty,
    timeout: timeout,
    reason: 'Expected a transient widget to disappear.',
  );
}

Future<void> _waitUntilTextForKeyEquals(
  WidgetTester tester,
  String keyName,
  String expected, {
  Duration timeout = const Duration(seconds: 30),
}) {
  return _pumpUntil(
    tester,
    () {
      final finder = find.byKey(Key(keyName));
      if (finder.evaluate().isEmpty) return false;
      return _textForKey(tester, keyName) == expected;
    },
    timeout: timeout,
    reason: 'Expected $keyName to equal $expected.',
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  expect(
    condition(),
    isTrue,
    reason: '$reason Visible text: ${_visibleTextSnapshot(tester)}',
  );
}

String _visibleTextSnapshot(WidgetTester tester) {
  final values = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget;
    if (widget is Text && widget.data?.trim().isNotEmpty == true) {
      values.add(widget.data!.trim());
    }
  }
  return values.take(20).join(' | ');
}

void _goTo(WidgetTester tester, String route) {
  GoRouter.of(_routerContext(tester)).go(route);
}

String _currentRoute(WidgetTester tester) =>
    GoRouter.of(_routerContext(tester)).routeInformationProvider.value.uri.path;

BuildContext _routerContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

Future<String> _requiredLocalToken() async {
  final token = await const FlutterSecureStorage().read(key: _authTokenKey);
  expect(token, isNotNull);
  expect(token, isNotEmpty);
  return token!;
}

Future<void> _clearLocalToken() =>
    const FlutterSecureStorage().delete(key: _authTokenKey);

Future<void> _expectNoLocalToken() async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (await const FlutterSecureStorage().read(key: _authTokenKey) == null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(await const FlutterSecureStorage().read(key: _authTokenKey), isNull);
}

void _assertEnvironment() {
  if (!_apiBaseUrl.startsWith('http://127.0.0.1:') ||
      !_apiBaseUrl.endsWith('/api/v1')) {
    throw StateError('Stage 3 E2E requires the guarded loopback API base.');
  }
  if (_stage3Password.isEmpty ||
      _firstLoginPassword.isEmpty ||
      _initialUserPassword.isEmpty ||
      _newUserPassword.isEmpty ||
      _oraclePath.isEmpty) {
    throw StateError('Stage 3 E2E transient inputs are incomplete.');
  }
  final transientPasswords = [
    _stage3Password,
    _firstLoginPassword,
    _initialUserPassword,
    _newUserPassword,
  ];
  if (transientPasswords.toSet().length != transientPasswords.length) {
    throw StateError('Stage 3 E2E transient passwords must be distinct.');
  }
  if (_backendContainer != 'testlabuz-stage3-e2e-app') {
    throw StateError('Stage 3 E2E may control only its dedicated backend.');
  }
  if (Platform.operatingSystem != 'windows') {
    throw StateError('Stage 3 E2E requires the Windows desktop target.');
  }
}

class _CreatedUserSpec {
  const _CreatedUserSpec({
    required this.roleLabel,
    required this.roleCode,
    required this.route,
    required this.loginName,
    required this.fullName,
    required this.email,
  });

  final String roleLabel;
  final String roleCode;
  final String route;
  final String loginName;
  final String fullName;
  final String email;
}

class _RealApi {
  _RealApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _apiBaseUrl,
          headers: const {Headers.acceptHeader: Headers.jsonContentType},
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
        ),
      );

  final Dio _dio;

  Future<Response<Object?>> request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? queryParameters,
    Object? data,
  }) => _dio.request<Object?>(
    path,
    data: data,
    queryParameters: queryParameters,
    options: Options(
      method: method,
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
    ),
  );

  void close() => _dio.close(force: true);
}

class _CollectionResponse {
  const _CollectionResponse({required this.items, required this.pagination});

  final List<JsonMap> items;
  final JsonMap pagination;
}

class _InstitutionRequest {
  const _InstitutionRequest(this.method, this.path, [this.body]);

  final String method;
  final String path;
  final Object? body;
}

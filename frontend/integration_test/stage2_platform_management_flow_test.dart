import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_dashboard_controller.dart';
import 'package:testlabuz_client/main.dart' as app;

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _stage2E2ePassword = String.fromEnvironment('STAGE2_E2E_PASSWORD');
const _stage2AdminInitialPassword = String.fromEnvironment(
  'STAGE2_E2E_ADMIN_INITIAL_PASSWORD',
);
const _stage2AdminNewPassword = String.fromEnvironment(
  'STAGE2_E2E_ADMIN_NEW_PASSWORD',
);
const _stage2OraclePath = String.fromEnvironment('STAGE2_E2E_ORACLE_PATH');
const _stage2BackendContainer = String.fromEnvironment(
  'STAGE2_E2E_BACKEND_CONTAINER',
  defaultValue: 'testlabuz-stage2-e2e-app',
);

const _authTokenKey = 'auth_access_token';
const _targetInstitutionId = '02000000-0000-4000-8000-000000000101';
const _inactiveInstitutionId = '02000000-0000-4000-8000-000000000102';
const _unaffectedInstitutionId = '02000000-0000-4000-8000-000000000103';
const _targetAdminId = '02000000-0000-4000-9000-000000000101';
const _nonAdminTargetId = '02000000-0000-4000-9000-000000000204';
const _unknownId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';

const _targetInstitutionName = 'E2E S02 Target Institution';
const _unaffectedInstitutionName = 'E2E S02 Unaffected Institution';
const _createdInstitutionName = 'E2E S02 Created Institution';
const _editedInstitutionName = 'E2E S02 Created Institution Edited';
const _createdAdminLogin = 'e2e_s02_created_admin';
const _createdAdminName = 'E2E S02 Created Admin';
const _editedAdminName = 'E2E S02 Created Admin Edited';

typedef JsonMap = Map<String, Object?>;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Stage 2 platform management mutation flow uses the real Windows stack',
    (tester) async {
      _assertEnvironment();
      await _configureDesktopView(tester);
      final api = _RealApi();
      final oracle = await _loadStage2Oracle();

      await _clearLocalToken();
      app.main();
      await _waitForLogin(tester);
      expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
      expect(find.byKey(const Key('platformDashboardData')), findsNothing);

      await _verifyUnauthenticatedPlatformMatrix(api);
      await _signIn(
        tester,
        loginName: 'e2e_s02_platform_owner',
        password: _stage2E2ePassword,
      );
      await _waitForRoute(tester, AppRoutePaths.platformOwner);
      await _waitUntilFound(
        tester,
        find.byKey(const Key('platformOwnerShell')),
      );

      final platformToken = await _requiredLocalToken();
      await _verifyPlatformShellAndBootstrap(tester, api, platformToken);
      await _verifyAuthorizationAndDisclosure(api, platformToken);
      await _verifyDashboardAndRecovery(tester, api, platformToken, oracle);
      await _verifyInstitutionList(tester, api, platformToken, oracle);
      await _verifyInstitutionDetailSafety(tester, api, platformToken);

      final createdInstitutionId = await _createAndEditInstitution(
        tester,
        api,
        platformToken,
        oracle,
      );

      await _verifyInstitutionLifecycle(tester, api, platformToken);
      await _verifyTargetAdminList(tester, api, platformToken, oracle);
      final createdAdminId = await _createInstitutionAdmin(
        tester,
        api,
        platformToken,
        createdInstitutionId,
      );

      await _verifyCreatedAdminFirstLogin(tester);
      await _signIn(
        tester,
        loginName: 'e2e_s02_platform_owner',
        password: _stage2E2ePassword,
      );
      await _waitForRoute(tester, AppRoutePaths.platformOwner);

      final refreshedPlatformToken = await _requiredLocalToken();
      await _verifyAdminUpdateAndLifecycle(
        tester,
        api,
        refreshedPlatformToken,
        createdInstitutionId,
        createdAdminId,
      );
      await _verifySessionIsolation(tester, api, refreshedPlatformToken);

      await _signIn(
        tester,
        loginName: 'e2e_s02_platform_owner',
        password: _stage2E2ePassword,
      );
      await _waitForRoute(tester, AppRoutePaths.platformOwner);
      final finalPlatformToken = await _requiredLocalToken();
      await _leaveCreatedInstitutionInactive(
        tester,
        api,
        finalPlatformToken,
        createdInstitutionId,
      );

      await _logout(tester);
      api.close();
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );

  testWidgets(
    'Stage 2 state persists after the dedicated backend restart',
    (tester) async {
      _assertEnvironment();
      await _configureDesktopView(tester);
      final api = _RealApi();

      await _clearLocalToken();
      app.main();
      await _waitForLogin(tester);
      await _signIn(
        tester,
        loginName: 'e2e_s02_platform_owner',
        password: _stage2E2ePassword,
      );
      await _waitForRoute(tester, AppRoutePaths.platformOwner);
      final token = await _requiredLocalToken();

      final institution = await _findSingleInstitution(
        api,
        token,
        _editedInstitutionName,
      );
      expect(institution['status'], 'inactive');
      final institutionId = institution['id']! as String;

      final admin = await _findSingleAdmin(
        api,
        token,
        institutionId,
        _createdAdminLogin,
      );
      expect(admin['full_name'], _editedAdminName);
      expect(admin['email'], 'edited-admin@e2e-s02.invalid');
      expect(admin['phone'], isNull);
      expect(admin['is_active'], isTrue);
      expect(admin['must_change_password'], isFalse);

      _goTo(
        tester,
        AppRoutePaths.platformOwnerInstitutionDetailLocation(institutionId),
      );
      await _waitForDetail(tester, _editedInstitutionName);
      expect(
        _textForKey(tester, 'platformInstitutionDetailStatusChip'),
        'Inactive',
      );
      await _waitUntilFound(tester, find.text(_editedAdminName));
      expect(find.text(_editedAdminName), findsOneWidget);

      final dashboard = await _getData(api, '/platform/dashboard', token);
      _assertDashboardShape(dashboard);
      final exactInstitutions = await _getCollection(
        api,
        '/platform/institutions',
        token,
        queryParameters: {'search': _editedInstitutionName},
      );
      expect(exactInstitutions.items, hasLength(1));
      expect(exactInstitutions.pagination['total'], 1);

      await _expectLoginError(
        api,
        _createdAdminLogin,
        _stage2AdminNewPassword,
        'institution_inactive',
      );
      await _logout(tester);
      api.close();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

Future<void> _verifyPlatformShellAndBootstrap(
  WidgetTester tester,
  _RealApi api,
  String token,
) async {
  expect(find.byKey(const Key('platformOwnerNavigation')), findsOneWidget);
  expect(find.text('Dashboard'), findsWidgets);
  expect(find.text('Institutions'), findsWidgets);
  expect(find.text('Settings'), findsNothing);
  expect(find.text('Billing'), findsNothing);
  expect(find.text('Teachers'), findsNothing);
  expect(find.text('Students'), findsNothing);
  expect(find.text('Parents'), findsNothing);
  expect(
    _textForKey(tester, 'platformOwnerCurrentUser'),
    'Current user: E2E S02 Platform Owner',
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
  expect(me['role'], 'platform_owner');
  expect(me['institution_id'], isNull);
  expect(me['institution'], isNull);

  _goTo(tester, AppRoutePaths.platformOwnerInstitutions);
  await _waitForRoute(tester, AppRoutePaths.platformOwnerInstitutions);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionListSurface')),
  );
  _goTo(tester, AppRoutePaths.platformOwner);
  await _waitForRoute(tester, AppRoutePaths.platformOwner);
  await _waitUntilFound(tester, find.byKey(const Key('platformDashboardData')));
  GoRouter.of(_routerContext(tester)).refresh();
  await tester.pump();
  expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
}

Future<void> _verifyUnauthenticatedPlatformMatrix(_RealApi api) async {
  for (final request in _platformRouteMatrix()) {
    final response = await api.request(request.method, request.path);
    _expectErrorResponse(response, 401, 'authentication_required');
  }
}

Future<void> _verifyAuthorizationAndDisclosure(
  _RealApi api,
  String platformToken,
) async {
  final roleAccounts = {
    'e2e_s02_target_admin': _stage2E2ePassword,
    'e2e_s02_teacher': _stage2E2ePassword,
    'e2e_s02_student': _stage2E2ePassword,
    'e2e_s02_parent': _stage2E2ePassword,
  };

  for (final account in roleAccounts.entries) {
    final roleToken = await _loginForToken(api, account.key, account.value);
    for (final request in _platformRouteMatrix()) {
      final response = await api.request(
        request.method,
        request.path,
        token: roleToken,
      );
      _expectErrorResponse(response, 403, 'forbidden');
    }
  }

  await _expectLoginError(
    api,
    'e2e_s02_inactive_admin',
    _stage2E2ePassword,
    'user_inactive',
  );
  await _expectLoginError(
    api,
    'e2e_s02_inactive_institution_admin',
    _stage2E2ePassword,
    'institution_inactive',
  );

  final passwordGateToken = await _loginForToken(
    api,
    'e2e_s02_password_gate_admin',
    _stage2AdminInitialPassword,
  );
  _expectErrorResponse(
    await api.request('GET', '/platform/dashboard', token: passwordGateToken),
    403,
    'password_change_required',
  );

  _expectErrorResponse(
    await api.request(
      'GET',
      '/platform/institutions/$_unknownId',
      token: platformToken,
    ),
    404,
    'resource_not_found',
  );
  final inactiveInstitution = await _getData(
    api,
    '/platform/institutions/$_inactiveInstitutionId',
    platformToken,
  );
  expect(inactiveInstitution['id'], _inactiveInstitutionId);
  expect(inactiveInstitution['status'], 'inactive');
  _expectErrorResponse(
    await api.request(
      'PATCH',
      '/platform/institution-admins/$_nonAdminTargetId',
      token: platformToken,
      data: {'full_name': 'Must not change'},
    ),
    404,
    'resource_not_found',
  );

  _expectErrorResponse(
    await api.request(
      'GET',
      '/platform/dashboard',
      token: platformToken,
      queryParameters: {'include': 'users'},
    ),
    422,
    'validation_failed',
  );
  _expectErrorResponse(
    await api.request(
      'GET',
      '/platform/institutions',
      token: platformToken,
      queryParameters: {'include_learning_data': true},
    ),
    422,
    'validation_failed',
  );

  final targetBefore = await _getData(
    api,
    '/platform/institutions/$_targetInstitutionId',
    platformToken,
  );
  _expectErrorResponse(
    await api.request(
      'PATCH',
      '/platform/institutions/$_targetInstitutionId',
      token: platformToken,
      data: {'status': 'inactive'},
    ),
    422,
    'validation_failed',
  );
  _expectErrorResponse(
    await api.request(
      'POST',
      '/platform/institutions/$_targetInstitutionId/deactivate',
      token: platformToken,
      data: {'force': true},
    ),
    422,
    'validation_failed',
  );
  final targetAfter = await _getData(
    api,
    '/platform/institutions/$_targetInstitutionId',
    platformToken,
  );
  expect(targetAfter, targetBefore);

  final adminBefore = await _findSingleAdmin(
    api,
    platformToken,
    _targetInstitutionId,
    'e2e_s02_target_admin',
  );
  _expectErrorResponse(
    await api.request(
      'PATCH',
      '/platform/institution-admins/$_targetAdminId',
      token: platformToken,
      data: {'login_name': 'protected_change'},
    ),
    422,
    'validation_failed',
  );
  _expectErrorResponse(
    await api.request(
      'POST',
      '/platform/institution-admins/$_targetAdminId/deactivate',
      token: platformToken,
      data: {'reason': 'unsupported'},
    ),
    422,
    'validation_failed',
  );
  final adminAfter = await _findSingleAdmin(
    api,
    platformToken,
    _targetInstitutionId,
    'e2e_s02_target_admin',
  );
  expect(adminAfter, adminBefore);
}

Future<void> _verifyDashboardAndRecovery(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  _goTo(tester, AppRoutePaths.platformOwner);
  await _waitUntilFound(tester, find.byKey(const Key('platformDashboardData')));
  final dashboard = await _getData(api, '/platform/dashboard', token);
  _assertDashboardShape(dashboard);

  final institutions = _map(dashboard['institutions']);
  final users = _map(dashboard['users']);
  final expectedDashboard = _map(oracle['dashboard']);
  final expectedInstitutions = _map(expectedDashboard['institutions']);
  final expectedUsers = _map(expectedDashboard['users']);
  expect(institutions, expectedInstitutions);
  expect(users, expectedUsers);
  expect(
    _textForKey(tester, 'platformDashboardKpiTotal institutionsValue'),
    '${expectedInstitutions['total']}',
  );
  expect(
    _textForKey(tester, 'platformDashboardKpiActive institutionsValue'),
    '${expectedInstitutions['active']}',
  );
  expect(
    _textForKey(tester, 'platformDashboardKpiInactive institutionsValue'),
    '${expectedInstitutions['inactive']}',
  );
  expect(
    _textForKey(tester, 'platformDashboardKpiTotal usersValue'),
    '${expectedUsers['total']}',
  );
  expect(
    _textForKey(tester, 'platformDashboardKpiActive usersValue'),
    '${expectedUsers['active']}',
  );

  final recent = _list(dashboard['recent_institutions']);
  final expectedRecent = _oracleIdentities(
    expectedDashboard['recent_institutions'],
  );
  expect(
    recent.map((item) => _map(item)['id']).toList(),
    expectedRecent.map((identity) => identity.id).toList(),
  );
  expect(
    recent.map((item) => _map(item)['name']).toList(),
    expectedRecent.map((identity) => identity.name).toList(),
  );
  for (final item in recent) {
    final institution = _map(item);
    _expectExactKeys(institution, {
      'id',
      'name',
      'type',
      'status',
      'created_at',
    });
    expect(find.text(institution['name']! as String), findsOneWidget);
  }
  expect(find.textContaining('Billing'), findsNothing);
  expect(find.textContaining('Health score'), findsNothing);
  expect(find.textContaining('Learning activity'), findsNothing);

  _goTo(tester, AppRoutePaths.platformOwnerInstitutions);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionTable')),
  );
  await _setDedicatedBackendRunning(running: false);
  ProviderScope.containerOf(
    _routerContext(tester),
  ).invalidate(platformDashboardControllerProvider);
  await tester.pump();
  _goTo(tester, AppRoutePaths.platformOwner);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformDashboardError')),
    timeout: const Duration(seconds: 40),
  );
  await _setDedicatedBackendRunning(running: true);
  await _waitForDedicatedBackend();
  await _tapKey(tester, 'platformDashboardRetryButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformDashboardData')),
    timeout: const Duration(seconds: 40),
  );
  expect(
    _textForKey(tester, 'platformDashboardKpiTotal institutionsValue'),
    '${expectedInstitutions['total']}',
  );
}

Future<void> _verifyInstitutionList(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  _goTo(tester, AppRoutePaths.platformOwnerInstitutions);
  var actual = await _verifyInstitutionScenario(
    api,
    token,
    oracle,
    'default_page_1',
  );
  await _waitForInstitutionList(tester, actual);
  expect(actual.pagination['per_page'], 20);

  actual = await _searchInstitutions(
    tester,
    api,
    token,
    oracle,
    'mixed case',
    'search_mixed_case',
  );
  expect(actual.items.single['name'], 'E2E S02 MiXeD Case Lyceum');

  actual = await _searchInstitutions(
    tester,
    api,
    token,
    oracle,
    '%',
    'search_literal_percent',
  );
  expect(actual.items.single['name'], 'E2E S02 Literal % Academy');
  actual = await _searchInstitutions(
    tester,
    api,
    token,
    oracle,
    '_',
    'search_literal_underscore',
  );
  expect(actual.items.single['name'], 'E2E S02 Literal _ Academy');

  await _enterText(tester, 'platformInstitutionSearchField', '%');
  await _submitSearch(tester);
  await _enterText(tester, 'platformInstitutionSearchField', '_');
  await _submitSearch(tester);
  actual = await _verifyInstitutionScenario(
    api,
    token,
    oracle,
    'search_literal_underscore',
    queryParameters: {'search': '_'},
  );
  await _waitForInstitutionList(tester, actual);
  expect(find.text('E2E S02 Literal % Academy'), findsNothing);

  await _enterText(tester, 'platformInstitutionSearchField', 'Literal');
  await _submitSearch(tester);
  await _selectDropdown(tester, 'platformInstitutionStatusFilter', 'Inactive');
  await _selectDropdown(
    tester,
    'platformInstitutionTypeFilter',
    'Training center',
  );
  actual = await _verifyInstitutionScenario(
    api,
    token,
    oracle,
    'combined_literal_inactive_training',
    queryParameters: {
      'search': 'Literal',
      'status': 'inactive',
      'type': 'training_center',
    },
  );
  await _waitForInstitutionList(tester, actual);
  expect(actual.items.single['name'], 'E2E S02 Literal _ Academy');

  await _tapKey(tester, 'platformInstitutionResetButton');
  actual = await _verifyInstitutionScenario(
    api,
    token,
    oracle,
    'default_page_1',
  );
  await _waitForInstitutionList(tester, actual);

  await _tapTableHeader(tester, 'Institution');
  actual = await _verifyInstitutionScenario(
    api,
    token,
    oracle,
    'sort_name_desc',
    queryParameters: {'sort': 'name', 'direction': 'desc'},
  );
  await _waitForInstitutionList(tester, actual);
  expect(
    _textForKey(tester, 'platformInstitutionSortSummary'),
    'Sorted by Institution, descending',
  );

  for (final sort in const {
    'Status': ('status', 'sort_status_asc'),
    'Created': ('created_at', 'sort_created_at_asc'),
    'Updated': ('updated_at', 'sort_updated_at_asc'),
  }.entries) {
    await _tapTableHeader(tester, sort.key);
    actual = await _verifyInstitutionScenario(
      api,
      token,
      oracle,
      sort.value.$2,
      queryParameters: {'sort': sort.value.$1, 'direction': 'asc'},
    );
    await _waitForInstitutionList(tester, actual);
  }

  await _tapKey(tester, 'platformInstitutionResetButton');
  for (final pageSize in const {
    50: 'per_page_50',
    100: 'per_page_100',
    20: 'default_page_1',
  }.entries) {
    await _selectDropdown(
      tester,
      'platformInstitutionPageSize',
      pageSize.key.toString(),
    );
    actual = await _verifyInstitutionScenario(
      api,
      token,
      oracle,
      pageSize.value,
      queryParameters: {'per_page': pageSize.key},
    );
    await _waitForInstitutionList(tester, actual);
    expect(actual.pagination['per_page'], pageSize.key);
  }

  await _tapKey(tester, 'platformInstitutionNextButton');
  actual = await _verifyInstitutionScenario(
    api,
    token,
    oracle,
    'default_page_2',
    queryParameters: {'page': 2, 'per_page': 20},
  );
  await _waitForInstitutionList(tester, actual);
  expect(_textForKey(tester, 'platformInstitutionPageStatus'), 'Page 2 / 2');
  await _tapKey(tester, 'platformInstitutionPreviousButton');
  actual = await _verifyInstitutionScenario(
    api,
    token,
    oracle,
    'default_page_1',
  );
  await _waitForInstitutionList(tester, actual);
}

Future<void> _verifyInstitutionDetailSafety(
  WidgetTester tester,
  _RealApi api,
  String token,
) async {
  final target = await _getData(
    api,
    '/platform/institutions/$_targetInstitutionId',
    token,
  );
  _expectExactKeys(target, {
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
    'user_counts',
  });

  await _enterText(
    tester,
    'platformInstitutionSearchField',
    _targetInstitutionName,
  );
  await _submitSearch(tester);
  await _waitUntilFound(tester, find.text(_targetInstitutionName));
  final detailButton = find
      .byKey(const Key('platformInstitutionViewDetails0'))
      .hitTestable();
  expect(detailButton, findsOneWidget);
  await tester.tap(detailButton);
  await tester.pump();
  await _waitForRoute(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(_targetInstitutionId),
  );
  await _waitForDetail(tester, _targetInstitutionName);
  final counts = _map(target['user_counts']);
  expect(
    _textForKey(
      tester,
      'platformInstitutionDetailUsageValueTotal user accounts',
    ),
    '${counts['total']}',
  );
  expect(
    _textForKey(
      tester,
      'platformInstitutionDetailUsageValueActive user accounts',
    ),
    '${counts['active']}',
  );
  expect(find.textContaining('created_by_user_id'), findsNothing);
  expect(find.textContaining('acceptable_score_difference'), findsNothing);
  expect(find.textContaining('token'), findsNothing);

  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(_unknownId),
  );
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionDetailNotFound')),
  );

  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(_targetInstitutionId),
  );
  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(
      _unaffectedInstitutionId,
    ),
  );
  await _waitForDetail(tester, _unaffectedInstitutionName);
  expect(find.text(_targetInstitutionName), findsNothing);

  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(_targetInstitutionId),
  );
  await _waitForDetail(tester, _targetInstitutionName);
  GoRouter.of(_routerContext(tester)).refresh();
  await tester.pump();
  expect(find.text(_targetInstitutionName), findsWidgets);
}

Future<String> _createAndEditInstitution(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  final totalBefore =
      _map(_map(oracle['dashboard'])['institutions'])['total']! as int;

  _goTo(tester, AppRoutePaths.platformOwnerInstitutionCreate);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionCreateSurface')),
  );
  await _enterText(
    tester,
    'platformInstitutionCreateNameField',
    _createdInstitutionName,
  );
  await _selectDropdown(
    tester,
    'platformInstitutionCreateTypeField',
    'Private education',
  );
  await _enterText(
    tester,
    'platformInstitutionCreateEmailField',
    'created@e2e-s02.invalid',
  );
  await _enterText(
    tester,
    'platformInstitutionCreatePhoneField',
    '+998901112233',
  );
  await _enterText(
    tester,
    'platformInstitutionCreateAddressField',
    'E2E S02 created address',
  );
  await _enterText(
    tester,
    'platformInstitutionCreateDescriptionField',
    'E2E S02 created description',
  );
  await _selectDropdown(
    tester,
    'platformInstitutionCreateStatusField',
    'Active',
  );

  await tester.ensureVisible(
    find.byKey(const Key('platformInstitutionCreateSubmitButton')),
  );
  await tester.tap(
    find.byKey(const Key('platformInstitutionCreateSubmitButton')),
  );
  await tester.pump();
  expect(
    _buttonEnabled(tester, 'platformInstitutionCreateSubmitButton'),
    isFalse,
  );
  await tester.tap(
    find.byKey(const Key('platformInstitutionCreateSubmitButton')),
    warnIfMissed: false,
  );
  await _waitForRoute(tester, AppRoutePaths.platformOwnerInstitutions);

  final created = await _findSingleInstitution(
    api,
    token,
    _createdInstitutionName,
  );
  final createdId = created['id']! as String;
  _expectInstitutionSummaryShape(created);

  final dashboardAfter = await _getData(api, '/platform/dashboard', token);
  expect(_map(dashboardAfter['institutions'])['total'], totalBefore + 1);

  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(createdId),
  );
  await _waitForDetail(tester, _createdInstitutionName);
  expect(_textForKey(tester, 'platformInstitutionDetailStatusChip'), 'Active');

  await _tapKey(tester, 'platformInstitutionDetailEditButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionEditForm')),
  );
  final unchangedBefore = await _getData(
    api,
    '/platform/institutions/$createdId',
    token,
  );
  expect(_buttonEnabled(tester, 'platformInstitutionEditSubmitButton'), isTrue);
  await _tapKey(tester, 'platformInstitutionEditSubmitButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionEditNoChangesMessage')),
  );
  final unchangedAfter = await _getData(
    api,
    '/platform/institutions/$createdId',
    token,
  );
  expect(unchangedAfter, unchangedBefore);
  await _enterText(
    tester,
    'platformInstitutionEditNameField',
    _editedInstitutionName,
  );
  await _selectDropdown(
    tester,
    'platformInstitutionEditTypeField',
    'University',
  );
  await _enterText(tester, 'platformInstitutionEditEmailField', '');
  await _enterText(
    tester,
    'platformInstitutionEditPhoneField',
    '+998907778899',
  );
  await _enterText(tester, 'platformInstitutionEditAddressField', '');
  await _enterText(
    tester,
    'platformInstitutionEditDescriptionField',
    'E2E S02 edited description',
  );
  await _tapKey(tester, 'platformInstitutionEditSubmitButton');
  await _waitForDetail(tester, _editedInstitutionName);

  final edited = await _getData(
    api,
    '/platform/institutions/$createdId',
    token,
  );
  expect(edited['name'], _editedInstitutionName);
  expect(edited['type'], 'university');
  expect(edited['status'], 'active');
  expect(edited['contact_email'], isNull);
  expect(edited['contact_phone'], '+998907778899');
  expect(edited['address'], isNull);
  expect(edited['description'], 'E2E S02 edited description');

  await _tapKey(tester, 'platformInstitutionDetailEditButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionEditForm')),
  );
  await _tapKey(tester, 'platformInstitutionEditBackButton');
  await _waitForDetail(tester, _editedInstitutionName);

  return createdId;
}

Future<void> _verifyInstitutionLifecycle(
  WidgetTester tester,
  _RealApi api,
  String platformToken,
) async {
  final targetUserToken = await _loginForToken(
    api,
    'e2e_s02_target_admin',
    _stage2E2ePassword,
  );
  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(_targetInstitutionId),
  );
  await _waitForDetail(tester, _targetInstitutionName);

  await _tapKey(tester, 'platformInstitutionLifecycleDeactivateButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionLifecycleDialog')),
  );
  await _tapKey(tester, 'platformInstitutionLifecycleCancelButton');
  await _waitUntilNotFound(
    tester,
    find.byKey(const Key('platformInstitutionLifecycleDialog')),
  );
  expect(
    (await _getData(
      api,
      '/platform/institutions/$_targetInstitutionId',
      platformToken,
    ))['status'],
    'active',
  );

  await _tapKey(tester, 'platformInstitutionLifecycleDeactivateButton');
  await _tapKey(tester, 'platformInstitutionLifecycleConfirmDeactivateButton');
  await _waitForStatusChip(tester, 'Inactive');
  expect(
    (await _getData(
      api,
      '/platform/institutions/$_targetInstitutionId',
      platformToken,
    ))['status'],
    'inactive',
  );
  _expectErrorResponse(
    await api.request('GET', '/auth/me', token: targetUserToken),
    403,
    'institution_inactive',
  );
  await _expectLoginError(
    api,
    'e2e_s02_target_admin',
    _stage2E2ePassword,
    'institution_inactive',
  );
  expect(
    await _loginForToken(api, 'e2e_s02_unaffected_admin', _stage2E2ePassword),
    isNotEmpty,
  );

  await _tapKey(tester, 'platformInstitutionLifecycleActivateButton');
  await _tapKey(tester, 'platformInstitutionLifecycleConfirmActivateButton');
  await _waitForStatusChip(tester, 'Active');
  final resumed = await api.request('GET', '/auth/me', token: targetUserToken);
  expect(resumed.statusCode, 200);
  await _expectLoginError(
    api,
    'e2e_s02_inactive_admin',
    _stage2E2ePassword,
    'user_inactive',
  );
  final gatedToken = await _loginForToken(
    api,
    'e2e_s02_password_gate_admin',
    _stage2AdminInitialPassword,
  );
  _expectErrorResponse(
    await api.request('GET', '/platform/dashboard', token: gatedToken),
    403,
    'password_change_required',
  );
}

Future<void> _verifyTargetAdminList(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
) async {
  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(_targetInstitutionId),
  );
  await _waitForDetail(tester, _targetInstitutionName);
  var actual = await _verifyAdminScenario(api, token, oracle, 'default_page_1');
  await _waitForAdminList(tester, actual);
  expect(actual.pagination['total'], 24);

  await _enterText(
    tester,
    'platformInstitutionAdminSearchField',
    'Target Admin',
  );
  await _tapKey(tester, 'platformInstitutionAdminSearchCommitButton');
  actual = await _verifyAdminScenario(
    api,
    token,
    oracle,
    'search_target_admin',
    queryParameters: {'search': 'Target Admin'},
  );
  await _waitForAdminList(tester, actual);
  expect(actual.items.single['login_name'], 'e2e_s02_target_admin');

  await _selectDropdown(
    tester,
    'platformInstitutionAdminStatusFilter',
    'Inactive',
  );
  actual = await _verifyAdminScenario(
    api,
    token,
    oracle,
    'search_target_admin_inactive',
    queryParameters: {'search': 'Target Admin', 'status': 'inactive'},
  );
  await _waitForAdminList(tester, actual);
  expect(actual.items, isEmpty);

  await _tapKey(tester, 'platformInstitutionAdminResetFiltersButton');
  actual = await _verifyAdminScenario(api, token, oracle, 'default_page_1');
  await _waitForAdminList(tester, actual);

  await _enterText(tester, 'platformInstitutionAdminSearchField', '%');
  await _tapKey(tester, 'platformInstitutionAdminSearchCommitButton');
  actual = await _verifyAdminScenario(
    api,
    token,
    oracle,
    'search_literal_percent',
    queryParameters: {'search': '%'},
  );
  await _waitForAdminList(tester, actual);
  expect(actual.items.single['login_name'], 'e2e_s02_admin_percent');

  await _tapKey(tester, 'platformInstitutionAdminResetFiltersButton');

  await _selectDropdown(
    tester,
    'platformInstitutionAdminSortField',
    'Login name',
  );
  await _tapKey(tester, 'platformInstitutionAdminDirectionButton');
  actual = await _verifyAdminScenario(
    api,
    token,
    oracle,
    'sort_login_name_desc_page_1',
    queryParameters: {'sort': 'login_name', 'direction': 'desc'},
  );
  await _waitForAdminList(tester, actual);

  for (final pageSize in const {
    50: 'sort_login_name_desc_per_page_50',
    100: 'sort_login_name_desc_per_page_100',
    20: 'sort_login_name_desc_page_1',
  }.entries) {
    await _selectDropdown(
      tester,
      'platformInstitutionAdminPageSizeField',
      '${pageSize.key} per page',
    );
    actual = await _verifyAdminScenario(
      api,
      token,
      oracle,
      pageSize.value,
      queryParameters: {
        'per_page': pageSize.key,
        'sort': 'login_name',
        'direction': 'desc',
      },
    );
    await _waitForAdminList(tester, actual);
  }

  await _tapKey(tester, 'platformInstitutionAdminNextPageButton');
  actual = await _verifyAdminScenario(
    api,
    token,
    oracle,
    'sort_login_name_desc_page_2',
    queryParameters: {
      'page': 2,
      'per_page': 20,
      'sort': 'login_name',
      'direction': 'desc',
    },
  );
  await _waitForAdminList(tester, actual);
  expect(
    _textForKey(tester, 'platformInstitutionAdminPaginationSummary'),
    'Page 2 of 2 · Total 24',
  );
  await _tapKey(tester, 'platformInstitutionAdminFirstPageButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminTable')),
  );
}

Future<String> _createInstitutionAdmin(
  WidgetTester tester,
  _RealApi api,
  String token,
  String institutionId,
) async {
  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(institutionId),
  );
  await _waitForDetail(tester, _editedInstitutionName);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminCreateButton')),
  );
  await _tapKey(tester, 'platformInstitutionAdminCreateButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminCreateDialog')),
  );
  await _enterText(
    tester,
    'platformInstitutionAdminCreateFullNameField',
    _createdAdminName,
  );
  await _enterText(
    tester,
    'platformInstitutionAdminCreateLoginNameField',
    _createdAdminLogin,
  );
  await _enterText(
    tester,
    'platformInstitutionAdminCreateEmailField',
    'created-admin@e2e-s02.invalid',
  );
  await _enterText(
    tester,
    'platformInstitutionAdminCreatePhoneField',
    '+998909998877',
  );
  await _enterText(
    tester,
    'platformInstitutionAdminCreatePasswordField',
    _stage2AdminInitialPassword,
  );
  await _tapKey(tester, 'platformInstitutionAdminCreateSubmitButton');
  expect(
    _buttonEnabled(tester, 'platformInstitutionAdminCreateSubmitButton'),
    isFalse,
  );
  await tester.tap(
    find.byKey(const Key('platformInstitutionAdminCreateSubmitButton')),
    warnIfMissed: false,
  );
  await _waitUntilNotFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminCreateDialog')),
  );
  expect(
    find.byKey(const Key('platformInstitutionAdminCreatePasswordField')),
    findsNothing,
  );

  final admin = await _findSingleAdmin(
    api,
    token,
    institutionId,
    _createdAdminLogin,
  );
  _expectAdminShape(admin);
  expect(admin['full_name'], _createdAdminName);
  expect(admin['is_active'], isTrue);
  expect(admin['must_change_password'], isTrue);
  expect(admin['last_login_at'], isNull);

  return admin['id']! as String;
}

Future<void> _verifyCreatedAdminFirstLogin(WidgetTester tester) async {
  await _logout(tester);
  await _signIn(
    tester,
    loginName: _createdAdminLogin,
    password: _stage2AdminInitialPassword,
  );
  await _waitForRoute(tester, AppRoutePaths.changePassword);
  _goTo(tester, AppRoutePaths.platformOwner);
  await _waitForRoute(tester, AppRoutePaths.changePassword);

  await _submitPasswordChange(
    tester,
    currentPassword: _stage2E2ePassword,
    newPassword: _stage2AdminNewPassword,
  );
  await _waitUntilFound(tester, find.text('Current password is incorrect.'));
  await _submitPasswordChange(
    tester,
    currentPassword: _stage2AdminInitialPassword,
    newPassword: _stage2AdminNewPassword,
  );
  await _waitForRoute(tester, AppRoutePaths.institutionAdmin);

  await _logout(tester);
  await _expectUiLoginFailure(
    tester,
    loginName: _createdAdminLogin,
    password: _stage2AdminInitialPassword,
    messageFragment: 'incorrect',
  );
  await _signIn(
    tester,
    loginName: _createdAdminLogin,
    password: _stage2AdminNewPassword,
  );
  await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
  _goTo(tester, AppRoutePaths.platformOwnerInstitutions);
  await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
  expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
  expect(find.text('Platform Dashboard'), findsNothing);
  await _logout(tester);
}

Future<void> _verifyAdminUpdateAndLifecycle(
  WidgetTester tester,
  _RealApi api,
  String token,
  String institutionId,
  String adminId,
) async {
  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(institutionId),
  );
  await _waitForDetail(tester, _editedInstitutionName);
  await _enterText(
    tester,
    'platformInstitutionAdminSearchField',
    _createdAdminLogin,
  );
  await _tapKey(tester, 'platformInstitutionAdminSearchCommitButton');
  await _waitUntilFound(
    tester,
    find.byKey(Key('platformInstitutionAdminEditButton-$adminId')),
  );

  await _tapKey(tester, 'platformInstitutionAdminEditButton-$adminId');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminEditDialog')),
  );
  final unchangedAdminBefore = await _findSingleAdmin(
    api,
    token,
    institutionId,
    _createdAdminLogin,
  );
  expect(
    _buttonEnabled(tester, 'platformInstitutionAdminEditSubmitButton'),
    isTrue,
  );
  await _tapKey(tester, 'platformInstitutionAdminEditSubmitButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminEditFormError')),
  );
  expect(
    await _findSingleAdmin(api, token, institutionId, _createdAdminLogin),
    unchangedAdminBefore,
  );
  await _enterText(
    tester,
    'platformInstitutionAdminEditFullNameField',
    _editedAdminName,
  );
  await _enterText(
    tester,
    'platformInstitutionAdminEditEmailField',
    'edited-admin@e2e-s02.invalid',
  );
  await _enterText(tester, 'platformInstitutionAdminEditPhoneField', '');
  await _tapKey(tester, 'platformInstitutionAdminEditSubmitButton');
  await _waitUntilNotFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminEditDialog')),
  );
  await tester.pumpAndSettle();

  final edited = await _findSingleAdmin(
    api,
    token,
    institutionId,
    _createdAdminLogin,
  );
  expect(edited['full_name'], _editedAdminName);
  expect(edited['email'], 'edited-admin@e2e-s02.invalid');
  expect(edited['phone'], isNull);
  expect(edited['login_name'], _createdAdminLogin);
  expect(edited['must_change_password'], isFalse);

  await _tapKey(tester, 'platformInstitutionAdminDeactivateButton-$adminId');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminLifecycleDialog')),
  );
  await _tapKey(tester, 'platformInstitutionAdminLifecycleCancelButton');
  await _waitUntilNotFound(
    tester,
    find.byKey(const Key('platformInstitutionAdminLifecycleDialog')),
  );
  await tester.pumpAndSettle();
  expect(
    (await _findSingleAdmin(
      api,
      token,
      institutionId,
      _createdAdminLogin,
    ))['is_active'],
    isTrue,
  );

  await _tapKey(tester, 'platformInstitutionAdminDeactivateButton-$adminId');
  await _tapKey(
    tester,
    'platformInstitutionAdminLifecycleConfirmDeactivateButton',
  );
  await _waitUntilFound(
    tester,
    find.byKey(Key('platformInstitutionAdminActivateButton-$adminId')),
  );
  await _expectLoginError(
    api,
    _createdAdminLogin,
    _stage2AdminNewPassword,
    'user_inactive',
  );

  await _tapKey(tester, 'platformInstitutionAdminActivateButton-$adminId');
  await _tapKey(
    tester,
    'platformInstitutionAdminLifecycleConfirmActivateButton',
  );
  await _waitUntilFound(
    tester,
    find.byKey(Key('platformInstitutionAdminDeactivateButton-$adminId')),
  );
  expect(
    await _loginForToken(api, _createdAdminLogin, _stage2AdminNewPassword),
    isNotEmpty,
  );
}

Future<void> _verifySessionIsolation(
  WidgetTester tester,
  _RealApi api,
  String token,
) async {
  final admins = await _getCollection(
    api,
    '/platform/institutions/$_targetInstitutionId/admins',
    token,
  );
  final visibleAdminName = admins.items.first['full_name']! as String;
  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(_targetInstitutionId),
  );
  await _waitForDetail(tester, _targetInstitutionName);
  await _waitUntilFound(tester, find.text(visibleAdminName));
  expect(find.text(visibleAdminName), findsOneWidget);

  await _logout(tester);
  await _signIn(
    tester,
    loginName: 'e2e_s02_unaffected_admin',
    password: _stage2E2ePassword,
  );
  await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
  expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
  expect(find.text(_targetInstitutionName), findsNothing);
  expect(find.text(visibleAdminName), findsNothing);
  expect(find.text('Platform Dashboard'), findsNothing);

  _goTo(tester, AppRoutePaths.platformOwner);
  await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
  await tester.binding.handlePopRoute();
  await tester.pump();
  expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
  expect(find.text(_targetInstitutionName), findsNothing);
  await _logout(tester);
}

Future<void> _leaveCreatedInstitutionInactive(
  WidgetTester tester,
  _RealApi api,
  String token,
  String institutionId,
) async {
  _goTo(
    tester,
    AppRoutePaths.platformOwnerInstitutionDetailLocation(institutionId),
  );
  await _waitForDetail(tester, _editedInstitutionName);
  await _tapKey(tester, 'platformInstitutionLifecycleDeactivateButton');
  await _tapKey(tester, 'platformInstitutionLifecycleConfirmDeactivateButton');
  await _waitForStatusChip(tester, 'Inactive');
  await _expectLoginError(
    api,
    _createdAdminLogin,
    _stage2AdminNewPassword,
    'institution_inactive',
  );
  expect(
    await _loginForToken(api, 'e2e_s02_unaffected_admin', _stage2E2ePassword),
    isNotEmpty,
  );
  final persisted = await _getData(
    api,
    '/platform/institutions/$institutionId',
    token,
  );
  expect(persisted['status'], 'inactive');
}

Future<_CollectionResponse> _searchInstitutions(
  WidgetTester tester,
  _RealApi api,
  String token,
  JsonMap oracle,
  String search,
  String scenario,
) async {
  await _enterText(tester, 'platformInstitutionSearchField', search);
  await _submitSearch(tester);
  final actual = await _verifyInstitutionScenario(
    api,
    token,
    oracle,
    scenario,
    queryParameters: {'search': search},
  );
  await _waitForInstitutionList(tester, actual);

  return actual;
}

Future<_CollectionResponse> _verifyInstitutionScenario(
  _RealApi api,
  String token,
  JsonMap oracle,
  String scenario, {
  Map<String, Object?>? queryParameters,
}) async {
  final actual = await _getCollection(
    api,
    '/platform/institutions',
    token,
    queryParameters: queryParameters,
  );
  _expectCollectionMatchesOracle(
    actual,
    _oracleCollection(oracle, 'institutions', scenario),
  );

  return actual;
}

Future<_CollectionResponse> _verifyAdminScenario(
  _RealApi api,
  String token,
  JsonMap oracle,
  String scenario, {
  Map<String, Object?>? queryParameters,
}) async {
  final actual = await _getCollection(
    api,
    '/platform/institutions/$_targetInstitutionId/admins',
    token,
    queryParameters: queryParameters,
  );
  _expectCollectionMatchesOracle(
    actual,
    _oracleCollection(oracle, 'admins', scenario),
  );

  return actual;
}

Future<void> _waitForInstitutionList(
  WidgetTester tester,
  _CollectionResponse expected,
) async {
  await _pumpUntil(
    tester,
    () {
      final totalFinder = find.byKey(
        const Key('platformInstitutionTotalStatus'),
      );
      if (totalFinder.evaluate().isEmpty) {
        return false;
      }

      final totalText = (tester.widget<Text>(totalFinder).data ?? '').trim();
      if (totalText !=
          '${expected.pagination['total']} matching Institutions') {
        return false;
      }

      if (expected.items.isEmpty) {
        return true;
      }

      final firstNameFinder = find.byKey(const Key('platformInstitutionName0'));
      return firstNameFinder.evaluate().isNotEmpty &&
          tester.widget<Text>(firstNameFinder).data ==
              expected.items.first['name'];
    },
    reason: 'Institution list did not render the authoritative API result.',
  );

  for (var index = 0; index < expected.items.length; index++) {
    expect(
      _textForKey(tester, 'platformInstitutionName$index'),
      expected.items[index]['name'],
    );
    _expectInstitutionSummaryShape(expected.items[index]);
  }
}

Future<void> _waitForAdminList(
  WidgetTester tester,
  _CollectionResponse expected,
) async {
  await _pumpUntil(
    tester,
    () {
      final countFinder = find.byKey(
        const Key('platformInstitutionAdminCount'),
      );
      if (countFinder.evaluate().isEmpty) {
        return false;
      }

      final count = tester.widget<Text>(countFinder).data;
      if (count != '${expected.pagination['total']} matching administrators') {
        return false;
      }

      if (expected.items.isEmpty) {
        return find
            .byKey(const Key('platformInstitutionAdminFilteredEmpty'))
            .evaluate()
            .isNotEmpty;
      }

      return find
          .text(expected.items.first['full_name']! as String)
          .evaluate()
          .isNotEmpty;
    },
    reason:
        'Institution Admin list did not render the authoritative API result.',
  );

  for (final admin in expected.items) {
    _expectAdminShape(admin);
  }
}

Future<void> _waitForDetail(WidgetTester tester, String name) async {
  await _pumpUntil(tester, () {
    final finder = find.byKey(const Key('platformInstitutionDetailTitle'));
    return finder.evaluate().isNotEmpty &&
        tester.widget<Text>(finder).data == name;
  }, reason: 'Expected Institution detail for $name.');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('platformInstitutionAdministratorsSection')),
  );
}

Future<void> _waitForStatusChip(WidgetTester tester, String status) async {
  await _pumpUntil(
    tester,
    () =>
        _textForKeyOrNull(tester, 'platformInstitutionDetailStatusChip') ==
        status,
    reason: 'Expected Institution status $status.',
  );
}

Future<JsonMap> _findSingleInstitution(
  _RealApi api,
  String token,
  String name,
) async {
  final response = await _getCollection(
    api,
    '/platform/institutions',
    token,
    queryParameters: {'search': name, 'per_page': 100},
  );
  final exact = response.items.where((item) => item['name'] == name).toList();
  expect(exact, hasLength(1));

  return exact.single;
}

Future<JsonMap> _findSingleAdmin(
  _RealApi api,
  String token,
  String institutionId,
  String loginName,
) async {
  final response = await _getCollection(
    api,
    '/platform/institutions/$institutionId/admins',
    token,
    queryParameters: {'search': loginName, 'per_page': 100},
  );
  final exact = response.items
      .where((item) => item['login_name'] == loginName)
      .toList();
  expect(exact, hasLength(1));

  return exact.single;
}

Future<JsonMap> _getData(_RealApi api, String path, String token) async {
  final response = await api.request('GET', path, token: token);
  expect(
    response.statusCode,
    200,
    reason: 'Expected successful protected read.',
  );
  final envelope = _map(response.data);
  expect(envelope.keys.toSet(), {'data'});

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
    reason: 'Expected successful collection read.',
  );
  final envelope = _map(response.data);
  _expectExactKeys(envelope, {'data', 'meta'});
  final meta = _map(envelope['meta']);
  _expectExactKeys(meta, {'pagination'});
  final pagination = _map(meta['pagination']);
  _expectExactKeys(pagination, {'page', 'per_page', 'total', 'last_page'});

  return _CollectionResponse(
    items: _list(envelope['data']).map(_map).toList(),
    pagination: pagination,
  );
}

Future<String> _loginForToken(
  _RealApi api,
  String loginName,
  String password,
) async {
  final response = await api.request(
    'POST',
    '/auth/login',
    data: {'login': loginName, 'password': password},
  );
  expect(
    response.statusCode,
    200,
    reason: 'Expected fixture account login success.',
  );
  final data = _map(_map(response.data)['data']);
  final token = data['token'];
  expect(token, isA<String>());
  expect(token, isNotEmpty);

  return token! as String;
}

Future<void> _expectLoginError(
  _RealApi api,
  String loginName,
  String password,
  String expectedCode,
) async {
  final response = await api.request(
    'POST',
    '/auth/login',
    data: {'login': loginName, 'password': password},
  );
  _expectErrorResponse(response, 403, expectedCode);
}

void _expectErrorResponse(
  Response<Object?> response,
  int statusCode,
  String code,
) {
  expect(response.statusCode, statusCode);
  final error = _map(response.data);
  expect(error['code'], code);
  expect(error['message'], isA<String>());
  expect(error['errors'], isA<Map<Object?, Object?>>());
  expect(
    error.keys.toSet().difference({'message', 'code', 'errors', 'request_id'}),
    isEmpty,
  );
}

void _assertDashboardShape(JsonMap dashboard) {
  _expectExactKeys(dashboard, {'institutions', 'users', 'recent_institutions'});
  _expectExactKeys(_map(dashboard['institutions']), {
    'total',
    'active',
    'inactive',
  });
  _expectExactKeys(_map(dashboard['users']), {'total', 'active'});
}

void _expectInstitutionSummaryShape(JsonMap institution) {
  _expectExactKeys(institution, {
    'id',
    'name',
    'type',
    'status',
    'contact_email',
    'contact_phone',
    'created_at',
    'updated_at',
    'user_counts',
  });
  _expectExactKeys(_map(institution['user_counts']), {'total', 'active'});
}

void _expectAdminShape(JsonMap admin) {
  _expectExactKeys(admin, {
    'id',
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

void _expectExactKeys(JsonMap value, Set<String> expected) {
  expect(value.keys.toSet(), expected);
}

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

Future<JsonMap> _loadStage2Oracle() async {
  final oracleFile = File(_stage2OraclePath);
  if (!await oracleFile.exists()) {
    throw StateError('The Stage 2 independent oracle artifact is unavailable.');
  }

  final decoded = jsonDecode(await oracleFile.readAsString());
  final oracle = _map(decoded);
  _expectExactKeys(oracle, {'dashboard', 'institutions', 'admins'});

  return oracle;
}

_OracleCollection _oracleCollection(
  JsonMap oracle,
  String group,
  String scenario,
) {
  final scenarios = _map(oracle[group]);
  final value = _map(scenarios[scenario]);

  return _OracleCollection(
    identities: _oracleIdentities(value['identities']),
    pagination: _map(value['pagination']),
  );
}

List<_OracleIdentity> _oracleIdentities(Object? value) {
  return _list(value).map((item) {
    final identity = _map(item);
    _expectExactKeys(identity, {'id', 'name'});

    return _OracleIdentity(
      id: identity['id']! as String,
      name: identity['name']! as String,
    );
  }).toList();
}

void _expectCollectionMatchesOracle(
  _CollectionResponse actual,
  _OracleCollection expected,
) {
  expect(actual.pagination, expected.pagination);
  expect(
    actual.items.map((item) => item['id']).toList(),
    expected.identities.map((identity) => identity.id).toList(),
  );
  expect(
    actual.items.map((item) => item['name'] ?? item['full_name']).toList(),
    expected.identities.map((identity) => identity.name).toList(),
  );
}

List<_PlatformRequest> _platformRouteMatrix() {
  return const [
    _PlatformRequest('GET', '/platform/dashboard'),
    _PlatformRequest('GET', '/platform/institutions'),
    _PlatformRequest('POST', '/platform/institutions'),
    _PlatformRequest('GET', '/platform/institutions/$_targetInstitutionId'),
    _PlatformRequest('PATCH', '/platform/institutions/$_targetInstitutionId'),
    _PlatformRequest(
      'POST',
      '/platform/institutions/$_targetInstitutionId/activate',
    ),
    _PlatformRequest(
      'POST',
      '/platform/institutions/$_targetInstitutionId/deactivate',
    ),
    _PlatformRequest(
      'GET',
      '/platform/institutions/$_targetInstitutionId/admins',
    ),
    _PlatformRequest(
      'POST',
      '/platform/institutions/$_targetInstitutionId/admins',
    ),
    _PlatformRequest('PATCH', '/platform/institution-admins/$_targetAdminId'),
    _PlatformRequest(
      'POST',
      '/platform/institution-admins/$_targetAdminId/activate',
    ),
    _PlatformRequest(
      'POST',
      '/platform/institution-admins/$_targetAdminId/deactivate',
    ),
  ];
}

Future<void> _setDedicatedBackendRunning({required bool running}) async {
  final action = running ? 'start' : 'stop';
  final result = await Process.run('docker', [action, _stage2BackendContainer]);
  expect(
    result.exitCode,
    0,
    reason: 'docker $action failed for the dedicated Stage 2 backend.',
  );
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
        if (response.statusCode != null) {
          return;
        }
      } on DioException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  } finally {
    client.close(force: true);
  }

  fail('The dedicated Stage 2 backend did not become ready after restart.');
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

Future<void> _expectUiLoginFailure(
  WidgetTester tester, {
  required String loginName,
  required String password,
  required String messageFragment,
}) async {
  await _signIn(tester, loginName: loginName, password: password);
  await _waitUntilFound(
    tester,
    find.textContaining(messageFragment, findRichText: true),
  );
  expect(_currentRoute(tester), AppRoutePaths.login);
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
  expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
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
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final option = find.text(label).last;
  await tester.tap(option);
  await tester.pump();
}

Future<void> _tapTableHeader(WidgetTester tester, String label) async {
  final header = find
      .descendant(
        of: find.byKey(const Key('platformInstitutionTable')),
        matching: find.text(label),
      )
      .hitTestable();
  expect(header, findsOneWidget);
  await tester.tap(header);
  await tester.pump();
}

Future<void> _enterText(
  WidgetTester tester,
  String keyName,
  String value,
) async {
  final finder = find.byKey(Key(keyName));
  await _waitUntilFound(tester, finder);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String keyName) async {
  final finder = find.byKey(Key(keyName));
  await _waitUntilFound(tester, finder);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

bool _buttonEnabled(WidgetTester tester, String keyName) {
  final button = tester.widget<ButtonStyleButton>(find.byKey(Key(keyName)));

  return button.onPressed != null;
}

String _textForKey(WidgetTester tester, String keyName) {
  final value = _textForKeyOrNull(tester, keyName);
  expect(
    value,
    isNotNull,
    reason: 'Expected Text-bearing widget key $keyName.',
  );

  return value!;
}

String? _textForKeyOrNull(WidgetTester tester, String keyName) {
  final finder = find.byKey(Key(keyName));
  if (finder.evaluate().isEmpty) {
    return null;
  }

  final widget = tester.widget(finder);
  if (widget is Text) {
    return widget.data;
  }
  if (widget is Chip && widget.label is Text) {
    return (widget.label as Text).data;
  }

  return null;
}

Future<void> _waitForRoute(WidgetTester tester, String route) async {
  await _pumpUntil(
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

Future<void> _waitUntilNotFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) {
  return _pumpUntil(
    tester,
    () => finder.evaluate().isEmpty,
    timeout: timeout,
    reason: 'Expected a completed UI surface to close.',
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
    if (condition()) {
      return;
    }
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

  return values.take(16).join(' | ');
}

void _goTo(WidgetTester tester, String route) {
  GoRouter.of(_routerContext(tester)).go(route);
}

String _currentRoute(WidgetTester tester) {
  return GoRouter.of(
    _routerContext(tester),
  ).routeInformationProvider.value.uri.path;
}

BuildContext _routerContext(WidgetTester tester) {
  return tester.element(find.byType(Scaffold).first);
}

Future<String> _requiredLocalToken() async {
  final token = await const FlutterSecureStorage().read(key: _authTokenKey);
  expect(token, isNotNull);
  expect(token, isNotEmpty);

  return token!;
}

Future<void> _clearLocalToken() {
  return const FlutterSecureStorage().delete(key: _authTokenKey);
}

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
  if (_apiBaseUrl.isEmpty) {
    throw StateError('API_BASE_URL is required for Stage 2 E2E.');
  }
  if (_stage2E2ePassword.isEmpty) {
    throw StateError('STAGE2_E2E_PASSWORD is required for Stage 2 E2E.');
  }
  if (_stage2AdminInitialPassword.isEmpty) {
    throw StateError(
      'STAGE2_E2E_ADMIN_INITIAL_PASSWORD is required for Stage 2 E2E.',
    );
  }
  if (_stage2AdminNewPassword.isEmpty) {
    throw StateError(
      'STAGE2_E2E_ADMIN_NEW_PASSWORD is required for Stage 2 E2E.',
    );
  }
  if (_stage2AdminInitialPassword == _stage2AdminNewPassword) {
    throw StateError('Stage 2 E2E administrator passwords must differ.');
  }
  if (_stage2OraclePath.isEmpty) {
    throw StateError(
      'STAGE2_E2E_ORACLE_PATH is required for Stage 2 independent assertions.',
    );
  }
  if (_stage2BackendContainer != 'testlabuz-stage2-e2e-app') {
    throw StateError(
      'Stage 2 E2E may control only the exact dedicated backend container.',
    );
  }
  if (Platform.operatingSystem != 'windows') {
    throw StateError('Stage 2 E2E requires the Windows desktop target.');
  }
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
  }) {
    return _dio.request<Object?>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(
        method: method,
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      ),
    );
  }

  void close() {
    _dio.close(force: true);
  }
}

class _CollectionResponse {
  const _CollectionResponse({required this.items, required this.pagination});

  final List<JsonMap> items;
  final JsonMap pagination;
}

class _OracleCollection {
  const _OracleCollection({required this.identities, required this.pagination});

  final List<_OracleIdentity> identities;
  final JsonMap pagination;
}

class _OracleIdentity {
  const _OracleIdentity({required this.id, required this.name});

  final String id;
  final String name;
}

class _PlatformRequest {
  const _PlatformRequest(this.method, this.path);

  final String method;
  final String path;
}

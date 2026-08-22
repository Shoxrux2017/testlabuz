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
const _stage4Password = String.fromEnvironment('STAGE4_E2E_PASSWORD');
const _oraclePath = String.fromEnvironment('STAGE4_E2E_ORACLE_PATH');
const _backendContainer = String.fromEnvironment(
  'STAGE4_E2E_BACKEND_CONTAINER',
  defaultValue: 'testlabuz-stage4-e2e-app',
);

const _authTokenKey = 'auth_access_token';
const _targetAdminLogin = 'e2e_s04_target_admin';
const _wrongRoleLogin = 'e2e_s04_target_teacher';
const _targetTeacherName = 'E2E S04 Target Teacher';
const _targetStudentName = 'E2E S04 Flow Student';
const _targetParentName = 'E2E S04 Flow Parent';
const _targetTeacherId = '04000000-0000-4000-9000-000000000201';
const _targetStudentId = '04000000-0000-4000-9000-000000000205';
const _targetParentId = '04000000-0000-4000-9000-000000000208';
const _foreignTeacherId = '04000000-0000-4000-9000-000000000301';
const _foreignStudentId = '04000000-0000-4000-9000-000000000302';
const _foreignParentId = '04000000-0000-4000-9000-000000000303';
const _foreignGroupId = '04000000-0000-4000-a000-000000000103';
const _foreignRelationshipId = '04000000-0000-4000-c000-000000000102';
const _createdGroupName = 'E2E S04 UI Group';
const _editedGroupName = 'E2E S04 UI Group Edited';

typedef JsonMap = Map<String, Object?>;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Stage 4 groups and relationships flow uses the real Windows stack',
    (tester) async {
      _assertEnvironment();
      await _configureDesktopView(tester);
      final oracle = await _loadOracle();
      final api = _RealApi();

      await _clearLocalToken();
      app.main();
      await _waitForLogin(tester);
      await _signIn(tester, _targetAdminLogin, _stage4Password);
      await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
      await _waitUntilFound(
        tester,
        find.byKey(const Key('institutionAdminShell')),
      );
      final token = await _requiredLocalToken();

      await _verifyStage4EntryAndNesting(tester);
      final groupId = await _createAndEditGroup(tester, api, token);
      await _verifyMembershipLifecycle(
        tester,
        api,
        token,
        groupId: groupId,
        kind: 'Teacher',
        memberId: _targetTeacherId,
        memberName: _targetTeacherName,
      );
      await _verifyMembershipLifecycle(
        tester,
        api,
        token,
        groupId: groupId,
        kind: 'Student',
        memberId: _targetStudentId,
        memberName: _targetStudentName,
      );
      await _verifyParentStudentLifecycle(tester, api, token);
      await _verifySecurityMatrix(api, token, groupId, oracle);
      await _archiveCreatedGroup(tester, api, token, groupId);

      await _logout(tester);
      api.close();
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );

  testWidgets(
    'Stage 4 state persists in a fresh Windows process after backend restart',
    (tester) async {
      _assertEnvironment();
      await _configureDesktopView(tester);
      final api = _RealApi();

      await _clearLocalToken();
      app.main();
      await _waitForLogin(tester);
      await _signIn(tester, _targetAdminLogin, _stage4Password);
      await _waitForRoute(tester, AppRoutePaths.institutionAdmin);
      final token = await _requiredLocalToken();

      await _navigateTo(tester, 'Groups', AppRoutePaths.institutionAdminGroups);
      await _waitUntilFound(tester, find.text(_editedGroupName));
      await _tapText(tester, _editedGroupName);
      await _waitUntilFound(
        tester,
        find.byKey(const Key('institutionAdminGroupDetailScreen')),
      );
      await _waitUntilFound(
        tester,
        find.byKey(const Key('institutionGroupDetailName')),
      );
      expect(
        _textForKey(tester, 'institutionGroupDetailName'),
        _editedGroupName,
      );
      await _waitUntilFound(
        tester,
        find.byKey(const Key('institutionGroupArchivedReadOnly')),
      );
      await _waitUntilFound(tester, find.text(_targetTeacherName));
      await _waitUntilFound(tester, find.text(_targetStudentName));
      expect(
        find.byKey(const Key('institutionGroupAssignTeachers')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('institutionGroupAssignStudents')),
        findsNothing,
      );

      final persisted = await _getData(
        api,
        '/institution/groups/${Uri.encodeComponent(_groupIdFromRoute(tester))}',
        token,
      );
      expect(persisted['name'], _editedGroupName);
      expect(persisted['status'], 'archived');

      await _navigateTo(tester, 'Users', AppRoutePaths.institutionAdminUsers);
      await _tapKey(tester, 'institutionParentStudentConnectionsButton');
      await _waitForRoute(
        tester,
        AppRoutePaths.institutionAdminParentStudentConnections,
      );
      await _selectRelationshipAnchor(
        tester,
        purpose: 'parentAnchor',
        userId: _targetParentId,
        login: 'e2e_s04_flow_parent',
      );
      await _waitUntilFound(tester, find.text(_targetStudentName));
      await _switchRelationshipPerspective(tester, 'By Student');
      await _selectRelationshipAnchor(
        tester,
        purpose: 'studentAnchor',
        userId: _targetStudentId,
        login: 'e2e_s04_flow_student',
      );
      await _waitUntilFound(tester, find.text(_targetParentName));

      await _logout(tester);
      api.close();
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}

Future<void> _verifyStage4EntryAndNesting(WidgetTester tester) async {
  await _navigateTo(tester, 'Groups', AppRoutePaths.institutionAdminGroups);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionGroupListSurface')),
  );
  await _waitUntilFound(tester, find.text('E2E S04 Target Active Group'));
  await _waitUntilFound(tester, find.text('E2E S04 Target Archived Group'));

  await _navigateTo(tester, 'Users', AppRoutePaths.institutionAdminUsers);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionParentStudentConnectionsButton')),
  );
  await _tapKey(tester, 'institutionParentStudentConnectionsButton');
  await _waitForRoute(
    tester,
    AppRoutePaths.institutionAdminParentStudentConnections,
  );
  expect(
    _currentRoute(tester).startsWith('${AppRoutePaths.institutionAdminUsers}/'),
    isTrue,
  );
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionParentStudentConnectionsSurface')),
  );
  await _waitUntilFound(tester, find.text('By Parent'));

  await _navigateTo(tester, 'Groups', AppRoutePaths.institutionAdminGroups);
}

Future<String> _createAndEditGroup(
  WidgetTester tester,
  _RealApi api,
  String token,
) async {
  await _tapKey(tester, 'institutionGroupCreateButton');
  await _waitForRoute(tester, AppRoutePaths.institutionAdminGroupCreate);
  await _enterText(
    tester,
    'institutionGroupCreateNameField',
    _createdGroupName,
  );
  await _enterText(tester, 'institutionGroupCreateLevelField', 'Level 4');
  await _enterText(
    tester,
    'institutionGroupCreateSubjectDirectionField',
    'Mathematics Lab',
  );
  await _enterText(
    tester,
    'institutionGroupCreateDescriptionField',
    'E2E S04 created through Windows UI.',
  );
  await _tapKey(tester, 'institutionGroupCreateSubmitButton');
  await _pumpUntil(
    tester,
    () =>
        AppRoutePaths.isInstitutionAdminGroupDetailPath(_currentRoute(tester)),
    reason: 'Expected navigation to authoritative Group Detail.',
  );
  final groupId = _groupIdFromRoute(tester);
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionAdminGroupDetailScreen')),
  );
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionGroupDetailName')),
  );
  expect(_textForKey(tester, 'institutionGroupDetailName'), _createdGroupName);

  await _tapKey(tester, 'institutionGroupEditAction');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionGroupEditDialog')),
  );
  await _enterText(tester, 'institutionGroupEditName', _editedGroupName);
  await _enterText(tester, 'institutionGroupEditLevel', 'Level 4 Advanced');
  await _enterText(
    tester,
    'institutionGroupEditSubjectDirection',
    'STEM Integration',
  );
  await _enterText(
    tester,
    'institutionGroupEditDescription',
    'E2E S04 edited through Windows UI.',
  );
  await _tapKey(tester, 'institutionGroupEditSave');
  await _waitUntilGone(
    tester,
    find.byKey(const Key('institutionGroupEditDialog')),
  );
  await _waitUntilTextForKeyEquals(
    tester,
    'institutionGroupDetailName',
    _editedGroupName,
  );

  final detail = await _getData(
    api,
    '/institution/groups/${Uri.encodeComponent(groupId)}',
    token,
  );
  expect(detail['id'], groupId);
  expect(detail['name'], _editedGroupName);
  expect(detail['level'], 'Level 4 Advanced');
  expect(detail['subject_direction'], 'STEM Integration');
  expect(detail['description'], 'E2E S04 edited through Windows UI.');
  expect(detail['status'], 'active');

  await _tapKey(tester, 'institutionGroupDetailBackButton');
  await _waitForRoute(tester, AppRoutePaths.institutionAdminGroups);
  await _waitUntilFound(tester, find.text(_editedGroupName));
  await _tapText(tester, _editedGroupName);
  await _waitForRoute(
    tester,
    AppRoutePaths.institutionAdminGroupDetailLocation(groupId),
  );

  return groupId;
}

Future<void> _verifyMembershipLifecycle(
  WidgetTester tester,
  _RealApi api,
  String token, {
  required String groupId,
  required String kind,
  required String memberId,
  required String memberName,
}) async {
  final section = find.byKey(Key('institutionGroup${kind}sSection'));
  await _waitUntilFound(tester, section);
  await _assignMembership(
    tester,
    kind: kind,
    memberId: memberId,
    login: kind == 'Teacher'
        ? 'e2e_s04_target_teacher'
        : 'e2e_s04_flow_student',
  );
  await _waitUntilFound(
    tester,
    find.descendant(of: section, matching: find.text(memberName)),
  );
  await _expectCurrentMembership(api, token, groupId, kind, memberId, true);

  final remove = find.descendant(
    of: section,
    matching: find.widgetWithText(TextButton, 'Remove'),
  );
  await _waitUntilFound(tester, remove);
  await tester.ensureVisible(remove.last);
  await tester.tap(remove.last);
  await tester.pump();
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionGroupMembershipRemoveDialog')),
  );
  await _tapKey(tester, 'institutionGroupMembershipRemoveConfirm');
  await _waitUntilGone(
    tester,
    find.byKey(const Key('institutionGroupMembershipRemoveDialog')),
  );
  await _waitUntilGone(
    tester,
    find.descendant(of: section, matching: find.text(memberName)),
  );
  await _expectCurrentMembership(api, token, groupId, kind, memberId, false);

  await _assignMembership(
    tester,
    kind: kind,
    memberId: memberId,
    login: kind == 'Teacher'
        ? 'e2e_s04_target_teacher'
        : 'e2e_s04_flow_student',
  );
  await _waitUntilFound(
    tester,
    find.descendant(of: section, matching: find.text(memberName)),
  );
  await _expectCurrentMembership(api, token, groupId, kind, memberId, true);
}

Future<void> _assignMembership(
  WidgetTester tester, {
  required String kind,
  required String memberId,
  required String login,
}) async {
  await _tapKey(tester, 'institutionGroupAssign${kind}s');
  await _waitUntilFound(tester, find.byKey(Key('assign${kind}sDialog')));
  await _enterText(tester, 'assign${kind}sSearch', login);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await _waitUntilFound(
    tester,
    find.byKey(Key('candidate-${kind.toLowerCase()}-$memberId')),
  );
  await _tapKey(tester, 'candidate-${kind.toLowerCase()}-$memberId');
  await _tapKey(tester, 'assign${kind}sSubmit');
  await _waitUntilGone(tester, find.byKey(Key('assign${kind}sDialog')));
}

Future<void> _expectCurrentMembership(
  _RealApi api,
  String token,
  String groupId,
  String kind,
  String memberId,
  bool expected,
) async {
  final segment = kind == 'Teacher' ? 'teachers' : 'students';
  final response = await api.request(
    'GET',
    '/institution/groups/${Uri.encodeComponent(groupId)}/$segment',
    token: token,
  );
  expect(response.statusCode, 200, reason: '$segment postcondition failed.');
  final envelope = _map(response.data);
  _expectExactKeys(envelope, {'data', 'meta'});
  final ids = _list(envelope['data']).map((row) => _map(row)['id']).toSet();
  expect(ids.contains(memberId), expected);
}

Future<void> _verifyParentStudentLifecycle(
  WidgetTester tester,
  _RealApi api,
  String token,
) async {
  await _navigateTo(tester, 'Users', AppRoutePaths.institutionAdminUsers);
  await _tapKey(tester, 'institutionParentStudentConnectionsButton');
  await _waitForRoute(
    tester,
    AppRoutePaths.institutionAdminParentStudentConnections,
  );
  await _waitUntilFound(tester, find.text('By Parent'));
  await _selectRelationshipAnchor(
    tester,
    purpose: 'parentAnchor',
    userId: _targetParentId,
    login: 'e2e_s04_flow_parent',
  );

  await _connectFlowPair(tester);
  await _waitUntilFound(tester, find.text(_targetStudentName));
  var relationshipId = await _expectCurrentRelationship(api, token);

  await _switchRelationshipPerspective(tester, 'By Student');
  await _selectRelationshipAnchor(
    tester,
    purpose: 'studentAnchor',
    userId: _targetStudentId,
    login: 'e2e_s04_flow_student',
  );
  await _waitUntilFound(tester, find.text(_targetParentName));

  await _tapKey(tester, 'institutionParentStudentDisconnect$relationshipId');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionParentStudentDisconnectDialog')),
  );
  await _tapKey(tester, 'institutionParentStudentDisconnectConfirm');
  await _waitUntilGone(
    tester,
    find.byKey(const Key('institutionParentStudentDisconnectDialog')),
  );
  await _waitUntilGone(tester, find.text(_targetParentName));
  await _expectNoCurrentRelationship(api, token);

  await _connectFlowPair(tester);
  await _waitUntilFound(tester, find.text(_targetParentName));
  final replacementId = await _expectCurrentRelationship(api, token);
  expect(replacementId, isNot(relationshipId));
  relationshipId = replacementId;

  await _switchRelationshipPerspective(tester, 'By Parent');
  await _waitUntilFound(tester, find.text(_targetStudentName));
  expect(relationshipId, isNotEmpty);
}

Future<void> _connectFlowPair(WidgetTester tester) async {
  await _tapKey(tester, 'institutionParentStudentConnectButton');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionParentStudentConnectDialog')),
  );
  await _selectUserChoice(
    tester,
    purpose: 'activeParent',
    userId: _targetParentId,
    login: 'e2e_s04_flow_parent',
  );
  final selector = find.byKey(
    const Key('institutionParentStudentConnectSelectorMode'),
  );
  final studentChoice = find.descendant(
    of: selector,
    matching: find.text('Student'),
  );
  await _waitUntilFound(tester, studentChoice);
  await tester.tap(studentChoice.last);
  await tester.pump();
  await _selectUserChoice(
    tester,
    purpose: 'activeStudent',
    userId: _targetStudentId,
    login: 'e2e_s04_flow_student',
  );
  await _tapKey(tester, 'institutionParentStudentConnectConfirm');
  await _waitUntilGone(
    tester,
    find.byKey(const Key('institutionParentStudentConnectDialog')),
  );
}

Future<void> _selectRelationshipAnchor(
  WidgetTester tester, {
  required String purpose,
  required String userId,
  required String login,
}) async {
  await _tapKey(tester, 'institutionParentStudentSelectAnchor');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionParentStudentAnchorPicker')),
  );
  await _selectUserChoice(
    tester,
    purpose: purpose,
    userId: userId,
    login: login,
  );
  await _tapKey(tester, 'institutionParentStudentAnchorSelect');
  await _waitUntilGone(
    tester,
    find.byKey(const Key('institutionParentStudentAnchorPicker')),
  );
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionParentStudentAnchorFullName')),
  );
}

Future<void> _selectUserChoice(
  WidgetTester tester, {
  required String purpose,
  required String userId,
  required String login,
}) async {
  await _enterText(tester, 'institutionUserSelectionSearch$purpose', login);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await _waitUntilFound(
    tester,
    find.byKey(Key('institutionUserSelection$userId')),
  );
  await _tapKey(tester, 'institutionUserSelection$userId');
}

Future<void> _switchRelationshipPerspective(
  WidgetTester tester,
  String label,
) async {
  final switcher = find.byKey(
    const Key('institutionParentStudentPerspectiveSwitch'),
  );
  final option = find.descendant(of: switcher, matching: find.text(label));
  await _waitUntilFound(tester, option);
  await tester.tap(option.last);
  await tester.pump();
}

Future<String> _expectCurrentRelationship(_RealApi api, String token) async {
  final response = await api.request(
    'GET',
    '/institution/parents/$_targetParentId/students',
    token: token,
  );
  expect(response.statusCode, 200);
  final rows = _list(
    _map(response.data)['data'],
  ).map(_map).where((row) => row['student_id'] == _targetStudentId);
  expect(rows, hasLength(1));
  final relationship = rows.single;
  expect(relationship['ended_at'], isNull);
  return relationship['id']! as String;
}

Future<void> _expectNoCurrentRelationship(_RealApi api, String token) async {
  final response = await api.request(
    'GET',
    '/institution/parents/$_targetParentId/students',
    token: token,
  );
  expect(response.statusCode, 200);
  final rows = _list(
    _map(response.data)['data'],
  ).map(_map).where((row) => row['student_id'] == _targetStudentId);
  expect(rows, isEmpty);
}

Future<void> _verifySecurityMatrix(
  _RealApi api,
  String token,
  String groupId,
  JsonMap oracle,
) async {
  final foreignGroup = _map(_map(oracle['groups'])['foreign']);
  final foreignUsers = _map(oracle['users']);
  final forbiddenFragments = <String>{
    _foreignGroupId,
    foreignGroup['name']! as String,
    _foreignTeacherId,
    _foreignStudentId,
    _foreignParentId,
    _foreignRelationshipId,
    _map(foreignUsers['foreign_teacher'])['login_name']! as String,
    _map(foreignUsers['foreign_student'])['login_name']! as String,
    _map(foreignUsers['foreign_parent'])['login_name']! as String,
    'institution_id',
    'password',
    'bearer',
    'token',
    'sql',
    'stack',
    'exception',
  };
  final requests = <_SecurityRequest>[
    const _SecurityRequest('GET', '/institution/groups/$_foreignGroupId'),
    const _SecurityRequest(
      'GET',
      '/institution/groups/$_foreignGroupId/teachers',
    ),
    const _SecurityRequest(
      'GET',
      '/institution/groups/$_foreignGroupId/students',
    ),
    _SecurityRequest('POST', '/institution/groups/$groupId/teachers', {
      'teacher_ids': [_foreignTeacherId],
    }),
    _SecurityRequest('POST', '/institution/groups/$groupId/students', {
      'student_ids': [_foreignStudentId],
    }),
    const _SecurityRequest(
      'POST',
      '/institution/parent-student-relationships',
      {'parent_id': _targetParentId, 'student_id': _foreignStudentId},
    ),
    const _SecurityRequest(
      'POST',
      '/institution/parent-student-relationships',
      {'parent_id': _foreignParentId, 'student_id': _targetStudentId},
    ),
    const _SecurityRequest(
      'DELETE',
      '/institution/parent-student-relationships/$_foreignRelationshipId',
    ),
  ];
  for (final request in requests) {
    final response = await api.request(
      request.method,
      request.path,
      token: token,
      data: request.body,
    );
    _expectPrivateFailure(
      response,
      status: 404,
      code: 'resource_not_found',
      forbiddenFragments: forbiddenFragments,
    );
  }

  final wrongRoleToken = await _loginForToken(
    api,
    _wrongRoleLogin,
    _stage4Password,
  );
  final denied = await api.request(
    'GET',
    '/institution/groups',
    token: wrongRoleToken,
  );
  _expectPrivateFailure(
    denied,
    status: 403,
    code: 'forbidden',
    forbiddenFragments: forbiddenFragments,
  );
  final logout = await api.request(
    'POST',
    '/auth/logout',
    token: wrongRoleToken,
  );
  expect(logout.statusCode, 204);
}

void _expectPrivateFailure(
  Response<Object?> response, {
  required int status,
  required String code,
  required Set<String> forbiddenFragments,
}) {
  expect(response.statusCode, status, reason: response.requestOptions.path);
  final envelope = _map(response.data);
  expect(envelope['code'], code);
  expect(envelope['errors'], isA<Map<Object?, Object?>>());
  expect((envelope['errors']! as Map<Object?, Object?>), isEmpty);
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
  final serialized = jsonEncode(response.data).toLowerCase();
  for (final fragment in forbiddenFragments) {
    expect(
      serialized,
      isNot(contains(fragment.toLowerCase())),
      reason: 'Private failure leaked a forbidden fragment.',
    );
  }
}

Future<void> _archiveCreatedGroup(
  WidgetTester tester,
  _RealApi api,
  String token,
  String groupId,
) async {
  await _navigateTo(tester, 'Groups', AppRoutePaths.institutionAdminGroups);
  await _waitUntilFound(tester, find.text(_editedGroupName));
  await _tapText(tester, _editedGroupName);
  await _waitForRoute(
    tester,
    AppRoutePaths.institutionAdminGroupDetailLocation(groupId),
  );
  await _tapKey(tester, 'institutionGroupArchiveAction');
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionGroupArchiveDialog')),
  );
  await _tapKey(tester, 'institutionGroupArchiveConfirm');
  await _waitUntilGone(
    tester,
    find.byKey(const Key('institutionGroupArchiveDialog')),
  );
  await _waitUntilFound(
    tester,
    find.byKey(const Key('institutionGroupArchivedReadOnly')),
  );
  expect(find.byKey(const Key('institutionGroupEditAction')), findsNothing);
  expect(find.byKey(const Key('institutionGroupArchiveAction')), findsNothing);
  expect(find.byKey(const Key('institutionGroupAssignTeachers')), findsNothing);
  expect(find.byKey(const Key('institutionGroupAssignStudents')), findsNothing);

  final detail = await _getData(
    api,
    '/institution/groups/${Uri.encodeComponent(groupId)}',
    token,
  );
  expect(detail['status'], 'archived');
  expect(detail['archived_at'], isA<String>());
}

Future<JsonMap> _getData(_RealApi api, String path, String token) async {
  final response = await api.request('GET', path, token: token);
  expect(response.statusCode, 200, reason: 'GET $path failed.');
  final envelope = _map(response.data);
  _expectExactKeys(envelope, {'data'});
  return _map(envelope['data']);
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
  expect(response.statusCode, 200, reason: 'Security actor login failed.');
  final data = _map(_map(response.data)['data']);
  expect(data['token_type'], 'Bearer');
  return data['token']! as String;
}

Future<JsonMap> _loadOracle() async {
  final file = File(_oraclePath);
  if (!await file.exists()) {
    throw StateError('The Stage 4 independent oracle artifact is unavailable.');
  }
  final oracle = _map(jsonDecode(await file.readAsString()));
  _expectExactKeys(oracle, {
    'runtime',
    'ids',
    'users',
    'groups',
    'memberships',
    'relationships',
    'ui_expected',
    'frozen_scope',
  });
  expect(_map(oracle['runtime']), {
    'environment': 'testing',
    'database': 'testlabuz_testing',
    'driver': 'pgsql',
    'pdo_driver': 'pgsql',
  });
  expect(_map(oracle['ids']), containsPair('foreign_group', _foreignGroupId));
  expect(_map(oracle['ids']), containsPair('target_teacher', _targetTeacherId));
  expect(_map(oracle['ids']), containsPair('target_student', _targetStudentId));
  expect(_map(oracle['ids']), containsPair('target_parent', _targetParentId));
  expect(_list(_map(oracle['relationships'])['foreign']), hasLength(1));
  expect(_list(_map(oracle['memberships'])['foreign_teachers']), hasLength(1));
  expect(_list(_map(oracle['memberships'])['foreign_students']), hasLength(1));
  expect(_map(oracle['ui_expected']), {
    'created_group_name': _createdGroupName,
    'edited_group_name': _editedGroupName,
    'edited_level': 'Level 4 Advanced',
    'edited_subject_direction': 'STEM Integration',
    'edited_description': 'E2E S04 edited through Windows UI.',
  });
  return oracle;
}

Future<void> _configureDesktopView(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1800, 1000);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Future<void> _signIn(WidgetTester tester, String login, String password) async {
  await _waitForLogin(tester);
  await _enterText(tester, 'loginField', login);
  await _enterText(tester, 'passwordField', password);
  await _tapKey(tester, 'signInButton');
}

Future<void> _logout(WidgetTester tester) async {
  await _tapKey(tester, 'entryLogoutButton');
  await _waitForLogin(tester);
  await _expectNoLocalToken();
}

Future<void> _navigateTo(
  WidgetTester tester,
  String label,
  String expectedRoute,
) async {
  final navigation = find.byKey(const Key('institutionAdminNavigation'));
  final destination = find.descendant(
    of: navigation,
    matching: find.text(label),
  );
  await _waitUntilFound(tester, destination);
  await tester.tap(destination.last);
  await tester.pump();
  await _waitForRoute(tester, expectedRoute);
}

Future<void> _waitForLogin(WidgetTester tester) async {
  await _waitForRoute(tester, AppRoutePaths.login);
  await _waitUntilFound(tester, find.byKey(const Key('loginField')));
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

Future<void> _tapText(WidgetTester tester, String value) async {
  final finder = find.text(value);
  await _waitUntilFound(tester, finder);
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.pump();
}

String _textForKey(WidgetTester tester, String keyName) {
  final widget = tester.widget(find.byKey(Key(keyName)).last);
  if (widget is Text) return widget.data ?? '';
  if (widget is SelectableText) return widget.data ?? '';
  throw StateError('Expected a text-bearing widget for $keyName.');
}

Future<void> _waitForRoute(WidgetTester tester, String route) => _pumpUntil(
  tester,
  () => _currentRoute(tester) == route,
  reason: 'Expected route $route.',
);

Future<void> _waitUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) => _pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  timeout: timeout,
  reason: 'Expected a required visible widget.',
);

Future<void> _waitUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) => _pumpUntil(
  tester,
  () => finder.evaluate().isEmpty,
  timeout: timeout,
  reason: 'Expected a transient widget to disappear.',
);

Future<void> _waitUntilTextForKeyEquals(
  WidgetTester tester,
  String keyName,
  String expected,
) => _pumpUntil(tester, () {
  final finder = find.byKey(Key(keyName));
  return finder.evaluate().isNotEmpty &&
      _textForKey(tester, keyName) == expected;
}, reason: 'Expected $keyName to equal $expected.');

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
  return values.take(25).join(' | ');
}

String _currentRoute(WidgetTester tester) =>
    GoRouter.of(_routerContext(tester)).routeInformationProvider.value.uri.path;

BuildContext _routerContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

String _groupIdFromRoute(WidgetTester tester) {
  final route = _currentRoute(tester);
  const prefix = '${AppRoutePaths.institutionAdminGroups}/';
  if (!route.startsWith(prefix)) {
    throw StateError('The current route is not a Group Detail route.');
  }
  final groupId = route.substring(prefix.length);
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(groupId)) {
    throw StateError('The Group Detail route has no canonical UUID.');
  }
  return groupId;
}

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

void _expectExactKeys(JsonMap value, Set<String> expected) {
  expect(value.keys.toSet(), expected);
}

void _assertEnvironment() {
  if (!_apiBaseUrl.startsWith('http://127.0.0.1:') ||
      !_apiBaseUrl.endsWith('/api/v1')) {
    throw StateError('Stage 4 E2E requires the guarded loopback API base.');
  }
  if (_stage4Password.isEmpty || _oraclePath.isEmpty) {
    throw StateError('Stage 4 E2E transient inputs are incomplete.');
  }
  if (_backendContainer != 'testlabuz-stage4-e2e-app') {
    throw StateError('Stage 4 E2E may use only its dedicated backend.');
  }
  if (Platform.operatingSystem != 'windows') {
    throw StateError('Stage 4 E2E requires the Windows desktop target.');
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
    Object? data,
  }) => _dio.request<Object?>(
    path,
    data: data,
    options: Options(
      method: method,
      contentType: data == null ? null : Headers.jsonContentType,
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
    ),
  );

  void close() => _dio.close(force: true);
}

class _SecurityRequest {
  const _SecurityRequest(this.method, this.path, [this.body]);

  final String method;
  final String path;
  final Object? body;
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_parent_student_relationship_action_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_parent_student_relationship_action_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_parent_student_relationship_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_parent_student_relationship_list_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_selection_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_selection_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_parent_student_relationship_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_selection.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  test(
    'confirmed connect reloads By Parent and stales matching By Student',
    () async {
      final relationship = _FakeRelationshipRepository();
      final setup = _setup(relationship);
      await _selectAnchors(setup);
      await _selectConnectPair(setup);

      await setup.action.submitConnect();
      await _flush();

      expect(relationship.connectCalls, 1);
      expect(
        setup.actionState.read().feedback,
        'Parent and student connected successfully.',
      );
      expect(setup.byParent.read().anchor!.id, testParentId);
      expect(setup.byStudent.read().projectionStale, isTrue);
      expect(relationship.fetches.length, greaterThanOrEqualTo(3));
    },
  );

  test(
    'unknown connect uses exact recovery query once and never replays POST',
    () async {
      final relationship = _FakeRelationshipRepository(
        onConnect: (_) async =>
            throw const InstitutionParentStudentMutationOutcomeUnknownException(),
      );
      final setup = _setup(relationship);
      await _selectAnchors(setup);
      setup.container
          .read(
            institutionParentStudentRelationshipListControllerProvider(
              InstitutionParentStudentPerspective.byParent,
            ).notifier,
          )
          .setPerPage(50);
      await _flush();
      await _selectConnectPair(setup);

      await setup.action.submitConnect();
      await _flush();

      expect(relationship.connectCalls, 1);
      final recovery = relationship.fetches.last.query;
      expect(recovery.search, isNull);
      expect(recovery.status, isNull);
      expect(recovery.page, 1);
      expect(recovery.perPage, 50);
      expect(recovery.sort, InstitutionParentStudentRelationshipSort.startedAt);
      expect(
        recovery.direction,
        InstitutionParentStudentRelationshipSortDirection.desc,
      );
      expect(
        setup.actionState.read().feedback,
        'Connection result remains unconfirmed. Review recent current connections before connecting this pair again.',
      );
    },
  );

  test(
    'recoverable connect 422 preserves both exact selections and dialog',
    () async {
      final relationship = _FakeRelationshipRepository(
        onConnect: (_) async => throw _serverFailure(
          status: 422,
          code: ApiErrorCodes.validationFailed,
          errors: const {
            'parent_id': ['Private'],
            'student_id': ['Private'],
          },
        ),
      );
      final setup = _setup(relationship);
      await _selectAnchors(setup);
      await _selectConnectPair(setup);
      final parent = setup.parentSelection.read().selected;
      final student = setup.studentSelection.read().selected;

      await setup.action.submitConnect();
      await _flush();

      expect(relationship.connectCalls, 1);
      expect(setup.actionState.read().isConnectDialog, isTrue);
      expect(
        setup.actionState.read().status,
        InstitutionParentStudentRelationshipActionStatus
            .connectRecoverableFailure,
      );
      expect(setup.parentSelection.read().selected, same(parent));
      expect(setup.studentSelection.read().selected, same(student));
      expect(
        setup.actionState.read().parentError,
        'Review the selected Parent.',
      );
      expect(
        setup.actionState.read().studentError,
        'Review the selected Student.',
      );
    },
  );

  for (final testCase in [
    (
      status: 404,
      code: ApiErrorCodes.resourceNotFound,
      feedback:
          'One or both selected users are no longer available for this connection.',
    ),
    (
      status: 409,
      code: ApiErrorCodes.businessConflict,
      feedback:
          'The connection was not accepted because current user state changed. Review active Parents and Students before trying again.',
    ),
  ]) {
    test(
      'definite connect ${testCase.status} closes selectors without reload or replay',
      () async {
        final relationship = _FakeRelationshipRepository(
          onConnect: (_) async => throw _serverFailure(
            status: testCase.status,
            code: testCase.code,
          ),
        );
        final setup = _setup(relationship);
        await _selectAnchors(setup);
        final initialFetches = relationship.fetches.length;
        await _selectConnectPair(setup);

        await setup.action.submitConnect();
        await _flush();

        expect(relationship.connectCalls, 1);
        expect(relationship.fetches, hasLength(initialFetches));
        expect(setup.actionState.read().feedback, testCase.feedback);
        expect(setup.parentSelection.read().isOpen, isFalse);
        expect(setup.studentSelection.read().isOpen, isFalse);
      },
    );
  }

  test(
    'disconnect binds exact relationship and reloads without optimistic removal',
    () async {
      final relationship = _FakeRelationshipRepository();
      final setup = _setup(relationship);
      await _selectAnchors(setup);
      final row = setup.byParent.read().result!.relationships.single;
      expect(
        setup.action.beginDisconnect(
          perspective: InstitutionParentStudentPerspective.byParent,
          anchor: setup.byParent.read().anchor!,
          relationship: row,
        ),
        isTrue,
      );

      await setup.action.confirmDisconnect();
      await _flush();

      expect(relationship.disconnectCalls, 1);
      expect(relationship.lastDisconnectedId, testRelationshipId);
      expect(
        setup.actionState.read().feedback,
        'Parent and student disconnected.',
      );
      expect(setup.byStudent.read().projectionStale, isTrue);
      expect(setup.byParent.read().result, isNotNull);
    },
  );

  test(
    'definite disconnect failure closes dialog without staling projections',
    () async {
      final relationship = _FakeRelationshipRepository(
        onDisconnect: (_) async =>
            throw _serverFailure(status: 403, code: ApiErrorCodes.forbidden),
      );
      final setup = _setup(relationship);
      await _selectAnchors(setup);
      final initialFetches = relationship.fetches.length;
      final row = setup.byParent.read().result!.relationships.single;
      setup.action.beginDisconnect(
        perspective: InstitutionParentStudentPerspective.byParent,
        anchor: setup.byParent.read().anchor!,
        relationship: row,
      );

      await setup.action.confirmDisconnect();
      await _flush();

      expect(setup.actionState.read().hasOpenAction, isFalse);
      expect(
        setup.actionState.read().feedback,
        'You do not have permission to manage Parent–Student connections.',
      );
      expect(relationship.fetches, hasLength(initialFetches));
      expect(setup.byStudent.read().projectionStale, isFalse);
    },
  );

  for (final testCase in [
    (
      name: '404',
      failure: _serverFailure(
        status: 404,
        code: ApiErrorCodes.resourceNotFound,
      ),
      feedback: 'The selected connection is no longer available.',
    ),
    (
      name: '409',
      failure: _serverFailure(
        status: 409,
        code: ApiErrorCodes.businessConflict,
      ),
      feedback:
          'The disconnect request was not accepted because current server state changed.',
    ),
    (
      name: 'unknown',
      failure: const InstitutionParentStudentMutationOutcomeUnknownException(),
      feedback:
          'Disconnect result could not be confirmed. Review the current connections.',
    ),
  ]) {
    test(
      '${testCase.name} disconnect reloads affected state once without replay',
      () async {
        final relationship = _FakeRelationshipRepository(
          onDisconnect: (_) async => throw testCase.failure,
        );
        final setup = _setup(relationship);
        await _selectAnchors(setup);
        final initialFetches = relationship.fetches.length;
        final row = setup.byParent.read().result!.relationships.single;
        setup.action.beginDisconnect(
          perspective: InstitutionParentStudentPerspective.byParent,
          anchor: setup.byParent.read().anchor!,
          relationship: row,
        );

        await setup.action.confirmDisconnect();
        await _flush();

        expect(relationship.disconnectCalls, 1);
        expect(relationship.fetches, hasLength(initialFetches + 1));
        expect(setup.byStudent.read().projectionStale, isTrue);
        expect(setup.actionState.read().feedback, testCase.feedback);
      },
    );
  }

  test(
    'disconnect completion cannot publish to a reconnect with new identity',
    () async {
      final disconnect = Completer<void>();
      var reconnected = false;
      final relationship = _FakeRelationshipRepository(
        onFetch: (perspective, anchorId, query) async => _page(
          perspective,
          query,
          relationship: reconnected
              ? testRelationship(
                  id: testOtherRelationshipId,
                  startedAt: DateTime.utc(2026, 8, 22),
                  perspective: perspective,
                )
              : testRelationship(perspective: perspective),
        ),
        onDisconnect: (_) => disconnect.future,
      );
      final setup = _setup(relationship);
      await _selectAnchors(setup);
      final row = setup.byParent.read().result!.relationships.single;
      setup.action.beginDisconnect(
        perspective: InstitutionParentStudentPerspective.byParent,
        anchor: setup.byParent.read().anchor!,
        relationship: row,
      );
      final pending = setup.action.confirmDisconnect();
      reconnected = true;
      await setup.container
          .read(
            institutionParentStudentRelationshipListControllerProvider(
              InstitutionParentStudentPerspective.byParent,
            ).notifier,
          )
          .markCheckingAndReload();
      await _flush();
      expect(setup.actionState.read().hasOpenAction, isFalse);

      disconnect.complete();
      await pending;
      await _flush();
      expect(setup.actionState.read().feedback, isNull);
      expect(relationship.disconnectCalls, 1);
    },
  );
}

_Setup _setup(_FakeRelationshipRepository relationship) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(TestAuthSessionController.new),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionParentStudentRelationshipRepositoryProvider.overrideWithValue(
        relationship,
      ),
      institutionUserListRepositoryProvider.overrideWithValue(
        _FakeUserRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  final actionState = container.listen(
    institutionParentStudentRelationshipActionControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  final byParent = container.listen(
    institutionParentStudentRelationshipListControllerProvider(
      InstitutionParentStudentPerspective.byParent,
    ),
    (_, _) {},
    fireImmediately: true,
  );
  final byStudent = container.listen(
    institutionParentStudentRelationshipListControllerProvider(
      InstitutionParentStudentPerspective.byStudent,
    ),
    (_, _) {},
    fireImmediately: true,
  );
  final parentSelection = container.listen(
    institutionUserSelectionControllerProvider(
      InstitutionUserSelectionPurpose.activeParent,
    ),
    (_, _) {},
    fireImmediately: true,
  );
  final studentSelection = container.listen(
    institutionUserSelectionControllerProvider(
      InstitutionUserSelectionPurpose.activeStudent,
    ),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(actionState.close);
  addTearDown(byParent.close);
  addTearDown(byStudent.close);
  addTearDown(parentSelection.close);
  addTearDown(studentSelection.close);
  return _Setup(
    container: container,
    action: container.read(
      institutionParentStudentRelationshipActionControllerProvider.notifier,
    ),
    actionState: actionState,
    byParent: byParent,
    byStudent: byStudent,
    parentSelection: parentSelection,
    studentSelection: studentSelection,
  );
}

Future<void> _selectAnchors(_Setup setup) async {
  setup.container
      .read(
        institutionParentStudentRelationshipListControllerProvider(
          InstitutionParentStudentPerspective.byParent,
        ).notifier,
      )
      .selectAnchor(testInstitutionUser());
  setup.container
      .read(
        institutionParentStudentRelationshipListControllerProvider(
          InstitutionParentStudentPerspective.byStudent,
        ).notifier,
      )
      .selectAnchor(
        testInstitutionUser(
          id: testStudentId,
          role: InstitutionUserRole.student,
          fullName: 'Student One',
          loginName: 'student.one',
        ),
      );
  await _flush();
}

Future<void> _selectConnectPair(_Setup setup) async {
  expect(setup.action.beginConnect(), isTrue);
  await _flush();
  setup.container
      .read(
        institutionUserSelectionControllerProvider(
          InstitutionUserSelectionPurpose.activeParent,
        ).notifier,
      )
      .select(setup.parentSelection.read().result!.users.single);
  setup.container
      .read(
        institutionUserSelectionControllerProvider(
          InstitutionUserSelectionPurpose.activeStudent,
        ).notifier,
      )
      .select(setup.studentSelection.read().result!.users.single);
}

class _Setup {
  const _Setup({
    required this.container,
    required this.action,
    required this.actionState,
    required this.byParent,
    required this.byStudent,
    required this.parentSelection,
    required this.studentSelection,
  });

  final ProviderContainer container;
  final InstitutionParentStudentRelationshipActionController action;
  final ProviderSubscription<InstitutionParentStudentRelationshipActionState>
  actionState;
  final ProviderSubscription<InstitutionParentStudentRelationshipListState>
  byParent;
  final ProviderSubscription<InstitutionParentStudentRelationshipListState>
  byStudent;
  final ProviderSubscription<InstitutionUserSelectionState> parentSelection;
  final ProviderSubscription<InstitutionUserSelectionState> studentSelection;
}

Future<void> _flush() async {
  for (var index = 0; index < 10; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

InstitutionParentStudentRelationshipListPage _page(
  InstitutionParentStudentPerspective perspective,
  InstitutionParentStudentRelationshipQuery query, {
  InstitutionParentStudentRelationship? relationship,
}) => InstitutionParentStudentRelationshipListPage(
  relationships: [relationship ?? testRelationship(perspective: perspective)],
  pagination: InstitutionParentStudentRelationshipListPagination(
    page: query.page,
    perPage: query.perPage,
    total: 1,
    lastPage: 1,
  ),
);

ApiRequestException _serverFailure({
  required int status,
  required String code,
  Map<String, List<String>> errors = const {},
}) => ApiRequestException(
  ApiFailure.fromServerError(
    statusCode: status,
    error: ApiErrorResponse(
      message: 'Private',
      code: code,
      fieldErrors: errors,
      requestId: 'req-1',
    ),
  ),
);

class _RelationshipFetch {
  const _RelationshipFetch(this.perspective, this.anchorId, this.query);
  final InstitutionParentStudentPerspective perspective;
  final String anchorId;
  final InstitutionParentStudentRelationshipQuery query;
}

class _FakeRelationshipRepository
    implements InstitutionParentStudentRelationshipRepository {
  _FakeRelationshipRepository({
    this.onFetch,
    this.onConnect,
    this.onDisconnect,
  });

  final Future<InstitutionParentStudentRelationshipListPage> Function(
    InstitutionParentStudentPerspective perspective,
    String anchorId,
    InstitutionParentStudentRelationshipQuery query,
  )?
  onFetch;
  final Future<InstitutionParentStudentMutationResult> Function(
    InstitutionParentStudentConnectRequest request,
  )?
  onConnect;
  final Future<void> Function(String relationshipId)? onDisconnect;
  final fetches = <_RelationshipFetch>[];
  var connectCalls = 0;
  var disconnectCalls = 0;
  String? lastDisconnectedId;

  @override
  Future<InstitutionParentStudentRelationshipListPage> fetchRelationships({
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
    required InstitutionParentStudentRelationshipQuery query,
  }) {
    fetches.add(_RelationshipFetch(perspective, anchorId, query));
    return onFetch?.call(perspective, anchorId, query) ??
        Future.value(_page(perspective, query));
  }

  @override
  Future<InstitutionParentStudentMutationResult> connect(
    InstitutionParentStudentConnectRequest request,
  ) {
    connectCalls += 1;
    return onConnect?.call(request) ??
        Future.value(
          InstitutionParentStudentMutationResult(
            id: testRelationshipId,
            parentId: request.parentId,
            studentId: request.studentId,
            startedAt: DateTime.utc(2026, 8, 21, 10, 15),
            endedAt: null,
          ),
        );
  }

  @override
  Future<void> disconnect(String relationshipId) {
    disconnectCalls += 1;
    lastDisconnectedId = relationshipId;
    return onDisconnect?.call(relationshipId) ?? Future.value();
  }
}

class _FakeUserRepository implements InstitutionUserListRepository {
  @override
  Future<InstitutionUserListPage> fetchUsers(
    InstitutionUserListQuery query,
  ) async {
    final role = query.role!;
    final user = role == InstitutionUserRole.parent
        ? testInstitutionUser()
        : testInstitutionUser(
            id: testStudentId,
            role: InstitutionUserRole.student,
            fullName: 'Student One',
            loginName: 'student.one',
          );
    return InstitutionUserListPage(
      users: [user],
      pagination: InstitutionUserListPagination(
        page: query.page,
        perPage: query.perPage,
        total: 1,
        lastPage: 1,
      ),
    );
  }
}

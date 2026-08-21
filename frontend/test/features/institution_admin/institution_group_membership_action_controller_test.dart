import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_action_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_detail_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_action_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_action_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_candidate_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_list_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_membership_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'confirmed assignment settles feedback before authoritative list and Detail replacement',
    () async {
      final detail = _FakeDetailRepository(
        groups: [testGroup(), testGroup(teachersCount: 1)],
      );
      final membership = _FakeMembershipRepository();
      final setup = _setup(detail: detail, membership: membership);
      await _flush();
      await _selectTeacher(setup);

      await setup.action.submitAssignment();
      await _flush();

      expect(membership.assignCalls, 1);
      expect(membership.lastAssignmentIds, [testTeacherId]);
      expect(
        setup.actionState.read().feedback,
        'Teachers assigned to group successfully.',
      );
      expect(detail.calls, greaterThanOrEqualTo(2));
      expect(membership.fetchCalls, greaterThanOrEqualTo(2));
      expect(
        setup.container
            .read(institutionGroupDetailControllerProvider(testGroupId))
            .group!
            .teachersCount,
        1,
      );
      expect(
        setup.container
            .read(institutionGroupListRetainedQueryProvider)
            .value!
            .authoritativeRowsStale,
        isTrue,
      );
    },
  );

  test(
    'recoverable assignment 422 keeps picker query and ordered selection',
    () async {
      final membership = _FakeMembershipRepository(
        onAssign: (_, _) async => throw _serverFailure(
          status: 422,
          code: ApiErrorCodes.validationFailed,
          errors: const {
            'teacher_ids': ['private'],
          },
        ),
      );
      final setup = _setup(
        detail: _FakeDetailRepository(groups: [testGroup()]),
        membership: membership,
      );
      await _flush();
      await _selectTeacher(setup);
      final selected = setup.candidateState.read().selected.single;

      await setup.action.submitAssignment();
      await _flush();

      expect(setup.actionState.read().isAssignDialog, isTrue);
      expect(
        setup.actionState.read().status,
        InstitutionGroupMembershipActionStatus.recoverableFailure,
      );
      expect(setup.candidateState.read().selected.single, same(selected));
      expect(membership.assignCalls, 1);
    },
  );

  test(
    'unknown assignment never replays and starts independent authoritative reads',
    () async {
      final detail = _FakeDetailRepository(
        groups: [testGroup(), testGroup(teachersCount: 1)],
      );
      final membership = _FakeMembershipRepository(
        onAssign: (_, _) async =>
            throw const InstitutionGroupMembershipMutationOutcomeUnknownException(),
      );
      final setup = _setup(detail: detail, membership: membership);
      await _flush();
      await _selectTeacher(setup);

      await setup.action.submitAssignment();
      await _flush();

      expect(membership.assignCalls, 1);
      expect(
        setup.actionState.read().feedback,
        'Teacher assignment result could not be confirmed. Review the current teacher list before assigning again.',
      );
      expect(membership.fetchCalls, greaterThanOrEqualTo(2));
      expect(detail.calls, greaterThanOrEqualTo(2));
    },
  );

  test(
    'confirmed mutation feedback survives a later Detail projection failure',
    () async {
      final detail = _FakeDetailRepository(
        groups: [testGroup()],
        onFetch: (call) {
          if (call == 1) {
            return Future.value(testGroup());
          }
          throw ApiRequestException(
            ApiFailure.local(
              kind: ApiFailureKind.connection,
              message: 'private projection failure',
            ),
          );
        },
      );
      final setup = _setup(
        detail: detail,
        membership: _FakeMembershipRepository(),
      );
      await _flush();
      await _selectTeacher(setup);

      await setup.action.submitAssignment();
      await _flush();

      expect(
        setup.actionState.read().feedback,
        'Teachers assigned to group successfully.',
      );
      expect(
        setup.container
            .read(institutionGroupDetailControllerProvider(testGroupId))
            .group,
        isNull,
      );
    },
  );

  test(
    '409 reconciliation archives Group closes picker and makes membership action terminal',
    () async {
      final archived = testGroup(
        status: InstitutionGroupStatus.archived,
        archivedAt: DateTime.utc(2026, 8, 21, 12),
      );
      final membership = _FakeMembershipRepository(
        onAssign: (_, _) async => throw _serverFailure(
          status: 409,
          code: ApiErrorCodes.businessConflict,
        ),
      );
      final setup = _setup(
        detail: _FakeDetailRepository(groups: [testGroup(), archived]),
        membership: membership,
      );
      await _flush();
      await _selectTeacher(setup);

      await setup.action.submitAssignment();
      await _flush();

      expect(
        setup.actionState.read().feedback,
        'Assignment was not accepted because current server state changed. Review the group and active users before trying again.',
      );
      expect(setup.candidateState.read().isOpen, isFalse);
      expect(
        setup.container
            .read(institutionGroupDetailControllerProvider(testGroupId))
            .group!
            .status,
        InstitutionGroupStatus.archived,
      );
      expect(membership.assignCalls, 1);
    },
  );

  test(
    'remove binds exact member identity accepts 204 result and never optimistically removes',
    () async {
      final membership = _FakeMembershipRepository();
      final setup = _setup(
        detail: _FakeDetailRepository(
          groups: [testGroup(), testGroup(teachersCount: 0)],
        ),
        membership: membership,
      );
      await _flush();
      final member = setup.teacherList.read().result!.memberships.single;
      final group = setup.container
          .read(institutionGroupDetailControllerProvider(testGroupId))
          .group!;
      expect(
        setup.action.beginRemove(
          selected: group,
          kind: InstitutionGroupMemberKind.teacher,
          membership: member,
        ),
        isTrue,
      );

      await setup.action.confirmRemove();
      await _flush();

      expect(membership.removeCalls, 1);
      expect(membership.lastRemovedId, testTeacherId);
      expect(setup.actionState.read().feedback, 'Teacher removed from group.');
      expect(membership.fetchCalls, greaterThanOrEqualTo(2));
    },
  );

  test(
    'recoverable remove failure closes dialog without marking projections stale',
    () async {
      final membership = _FakeMembershipRepository(
        onRemove: (_, _) async =>
            throw _serverFailure(status: 403, code: ApiErrorCodes.forbidden),
      );
      final setup = _setup(
        detail: _FakeDetailRepository(groups: [testGroup()]),
        membership: membership,
      );
      await _flush();
      final initialFetches = membership.fetchCalls;
      final member = setup.teacherList.read().result!.memberships.single;
      final group = setup.container
          .read(institutionGroupDetailControllerProvider(testGroupId))
          .group!;
      setup.action.beginRemove(
        selected: group,
        kind: InstitutionGroupMemberKind.teacher,
        membership: member,
      );

      await setup.action.confirmRemove();
      await _flush();

      expect(setup.actionState.read().hasOpenAction, isFalse);
      expect(
        setup.actionState.read().feedback,
        'You do not have permission to change group memberships.',
      );
      expect(membership.fetchCalls, initialFetches);
      expect(
        setup.container.read(institutionGroupListRetainedQueryProvider).value,
        isNull,
      );
    },
  );

  test(
    'same UUID reassignment invalidates an in-flight Remove publication',
    () async {
      final removeResult = Completer<void>();
      var reassigned = false;
      final membership = _FakeMembershipRepository(
        onFetch: (kind, query) async => InstitutionGroupMembershipListPage(
          memberships: [
            testMembership(
              id: kind == InstitutionGroupMemberKind.teacher
                  ? testTeacherId
                  : testStudentId,
              startedAt: reassigned
                  ? DateTime.utc(2026, 8, 22)
                  : DateTime.utc(2026, 8, 21, 10, 15),
            ),
          ],
          pagination: InstitutionGroupMembershipListPagination(
            page: query.page,
            perPage: query.perPage,
            total: 1,
            lastPage: 1,
          ),
        ),
        onRemove: (_, _) => removeResult.future,
      );
      final setup = _setup(
        detail: _FakeDetailRepository(groups: [testGroup()]),
        membership: membership,
      );
      await _flush();
      final oldMembership = setup.teacherList.read().result!.memberships.single;
      final group = setup.container
          .read(institutionGroupDetailControllerProvider(testGroupId))
          .group!;
      setup.action.beginRemove(
        selected: group,
        kind: InstitutionGroupMemberKind.teacher,
        membership: oldMembership,
      );
      final removeFuture = setup.action.confirmRemove();
      reassigned = true;
      setup.container
          .read(
            institutionGroupMembershipListControllerProvider(
              InstitutionGroupMembershipListKey(
                groupId: testGroupId,
                kind: InstitutionGroupMemberKind.teacher,
              ),
            ).notifier,
          )
          .markCheckingAndReload();
      await _flush();
      expect(setup.actionState.read().hasOpenAction, isFalse);

      removeResult.complete();
      await removeFuture;
      await _flush();
      expect(setup.actionState.read().feedback, isNull);
      expect(membership.removeCalls, 1);
    },
  );

  test(
    'FE-003 open action prevents membership begin and duplicate begins are suppressed',
    () async {
      final setup = _setup(
        detail: _FakeDetailRepository(groups: [testGroup()]),
        membership: _FakeMembershipRepository(),
      );
      await _flush();
      final group = setup.container
          .read(institutionGroupDetailControllerProvider(testGroupId))
          .group!;
      final groupAction = setup.container.read(
        institutionGroupActionControllerProvider(testGroupId).notifier,
      );
      expect(groupAction.beginEdit(group), isTrue);
      expect(
        setup.action.beginAssign(group, InstitutionGroupMemberKind.teacher),
        isFalse,
      );
      groupAction.dismiss();
      await _flush();
      expect(
        setup.action.beginAssign(group, InstitutionGroupMemberKind.teacher),
        isTrue,
      );
      expect(
        setup.action.beginAssign(group, InstitutionGroupMemberKind.student),
        isFalse,
      );
    },
  );
}

Future<void> _selectTeacher(_Setup setup) async {
  final group = setup.container
      .read(institutionGroupDetailControllerProvider(testGroupId))
      .group!;
  expect(
    setup.action.beginAssign(group, InstitutionGroupMemberKind.teacher),
    isTrue,
  );
  await _flush();
  final candidate = setup.candidateState.read().result!.users.single;
  setup.candidate.toggleSelection(candidate, true);
}

_Setup _setup({
  required _FakeDetailRepository detail,
  required _FakeMembershipRepository membership,
}) {
  final user = _FakeUserRepository();
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(TestAuthSessionController.new),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionGroupDetailRepositoryProvider.overrideWithValue(detail),
      institutionGroupMembershipRepositoryProvider.overrideWithValue(
        membership,
      ),
      institutionUserListRepositoryProvider.overrideWithValue(user),
    ],
  );
  addTearDown(container.dispose);
  final teacherKey = InstitutionGroupMembershipListKey(
    groupId: testGroupId,
    kind: InstitutionGroupMemberKind.teacher,
  );
  final actionState = container.listen(
    institutionGroupMembershipActionControllerProvider(testGroupId),
    (_, _) {},
    fireImmediately: true,
  );
  final teacherList = container.listen(
    institutionGroupMembershipListControllerProvider(teacherKey),
    (_, _) {},
    fireImmediately: true,
  );
  final candidateState = container.listen(
    institutionGroupMembershipCandidateControllerProvider(teacherKey),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(actionState.close);
  addTearDown(teacherList.close);
  addTearDown(candidateState.close);
  return _Setup(
    container: container,
    action: container.read(
      institutionGroupMembershipActionControllerProvider(testGroupId).notifier,
    ),
    actionState: actionState,
    teacherList: teacherList,
    candidate: container.read(
      institutionGroupMembershipCandidateControllerProvider(
        teacherKey,
      ).notifier,
    ),
    candidateState: candidateState,
  );
}

class _Setup {
  const _Setup({
    required this.container,
    required this.action,
    required this.actionState,
    required this.teacherList,
    required this.candidate,
    required this.candidateState,
  });

  final ProviderContainer container;
  final InstitutionGroupMembershipActionController action;
  final ProviderSubscription<InstitutionGroupMembershipActionState> actionState;
  final ProviderSubscription<InstitutionGroupMembershipListState> teacherList;
  final InstitutionGroupMembershipCandidateController candidate;
  final ProviderSubscription<dynamic> candidateState;
}

Future<void> _flush() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

ApiRequestException _serverFailure({
  required int status,
  required String code,
  Map<String, List<String>> errors = const {},
}) => ApiRequestException(
  ApiFailure.fromServerError(
    statusCode: status,
    error: ApiErrorResponse(
      message: 'Private backend message.',
      code: code,
      fieldErrors: errors,
      requestId: 'req-1',
    ),
  ),
);

class _FakeDetailRepository implements InstitutionGroupDetailRepository {
  _FakeDetailRepository({required this.groups, this.onFetch});

  final List<InstitutionGroup> groups;
  final Future<InstitutionGroup> Function(int call)? onFetch;
  var calls = 0;

  @override
  Future<InstitutionGroup> fetchGroup(String groupId) {
    calls += 1;
    final custom = onFetch;
    if (custom != null) {
      return custom(calls);
    }
    final index = calls <= groups.length ? calls - 1 : groups.length - 1;
    return Future.value(groups[index]);
  }
}

class _FakeMembershipRepository
    implements InstitutionGroupMembershipRepository {
  _FakeMembershipRepository({this.onFetch, this.onAssign, this.onRemove});

  final Future<InstitutionGroupMembershipListPage> Function(
    InstitutionGroupMemberKind kind,
    InstitutionGroupMembershipQuery query,
  )?
  onFetch;
  final Future<List<InstitutionGroupMembership>> Function(
    InstitutionGroupMemberKind kind,
    InstitutionGroupMembershipAssignmentRequest request,
  )?
  onAssign;
  final Future<void> Function(InstitutionGroupMemberKind kind, String memberId)?
  onRemove;
  var fetchCalls = 0;
  var assignCalls = 0;
  var removeCalls = 0;
  List<String>? lastAssignmentIds;
  String? lastRemovedId;

  @override
  Future<InstitutionGroupMembershipListPage> fetchMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipQuery query,
  }) async {
    fetchCalls += 1;
    final custom = onFetch;
    if (custom != null) {
      return custom(kind, query);
    }
    return InstitutionGroupMembershipListPage(
      memberships: [
        testMembership(
          id: kind == InstitutionGroupMemberKind.teacher
              ? testTeacherId
              : testStudentId,
        ),
      ],
      pagination: InstitutionGroupMembershipListPagination(
        page: query.page,
        perPage: query.perPage,
        total: 1,
        lastPage: 1,
      ),
    );
  }

  @override
  Future<List<InstitutionGroupMembership>> assignMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipAssignmentRequest request,
  }) {
    assignCalls += 1;
    lastAssignmentIds = request.memberIds;
    return onAssign?.call(kind, request) ??
        Future.value([testMembership(id: request.memberIds.single)]);
  }

  @override
  Future<void> removeMembership({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required String memberId,
  }) {
    removeCalls += 1;
    lastRemovedId = memberId;
    return onRemove?.call(kind, memberId) ?? Future.value();
  }
}

class _FakeUserRepository implements InstitutionUserListRepository {
  @override
  Future<InstitutionUserListPage> fetchUsers(
    InstitutionUserListQuery query,
  ) async => InstitutionUserListPage(
    users: [testCandidate()],
    pagination: InstitutionUserListPagination(
      page: query.page,
      perPage: query.perPage,
      total: 1,
      lastPage: 1,
    ),
  );
}

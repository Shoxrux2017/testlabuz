import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_membership_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_mutation_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_mutation_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_group_detail_screen.dart';

import 'institution_group_test_support.dart';

void main() {
  testWidgets(
    'renders exact authoritative fields and active lifecycle actions',
    (tester) async {
      await _pump(tester, _FakeDetailRepository());
      await tester.pumpAndSettle();

      expect(find.text('Group Details'), findsOneWidget);
      expect(find.text('Advanced Mathematics'), findsWidgets);
      for (final label in const [
        'Name',
        'Status',
        'Level',
        'Subject direction',
        'Description',
        'Archived at',
        'Created',
        'Updated',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Teachers'), findsWidgets);
      expect(find.text('Students'), findsWidgets);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('2026-08-15 08:00 UTC'), findsOneWidget);
      expect(find.text('2026-08-15 09:30 UTC'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Archive Group'), findsOneWidget);
      expect(find.textContaining('Manage'), findsNothing);
    },
  );

  testWidgets(
    'archived Group is explicitly read-only without lifecycle actions',
    (tester) async {
      await _pump(
        tester,
        _FakeDetailRepository(
          group: testGroup(
            status: InstitutionGroupStatus.archived,
            archivedAt: DateTime.utc(2026, 8, 21, 10),
          ),
        ),
        membership: _FakeMembershipRepository(withAll: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Archived groups are read-only.'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Archive Group'), findsNothing);
      expect(find.textContaining('Reactivate'), findsNothing);
      expect(find.textContaining('Delete'), findsNothing);
      expect(
        find.text(
          'Membership changes are unavailable because this group is archived.',
        ),
        findsNWidgets(2),
      );
      expect(find.text('Assign Teachers'), findsNothing);
      expect(find.text('Assign Students'), findsNothing);
      expect(find.text('Remove'), findsNothing);
    },
  );

  testWidgets(
    'membership sections expose independent columns and assignment picker tray',
    (tester) async {
      await _pump(
        tester,
        _FakeDetailRepository(),
        membership: _FakeMembershipRepository(withAll: true),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('institutionGroupTeachersSection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('institutionGroupStudentsSection')),
        findsOneWidget,
      );
      for (final column in const [
        'Full name',
        'Login name',
        'Contact',
        'Assigned',
        'Action',
      ]) {
        expect(find.text(column), findsNWidgets(2));
      }
      expect(find.text('Status'), findsNWidgets(3));

      await tester.ensureVisible(find.text('Assign Teachers'));
      await tester.tap(find.text('Assign Teachers'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assignTeachersDialog')), findsOneWidget);
      expect(
        find.text(
          'Only active users are shown. Users already assigned to this group can be selected safely; duplicate active memberships are not created.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('candidate-teacher-$testTeacherId')),
      );
      await tester.pump();
      expect(find.text('Selected: 1 / 100'), findsOneWidget);
      expect(find.byTooltip('Remove from selection'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('institutionGroupDetailRefreshButton')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('institutionGroupEditAction')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'group membership horizontal table renders without Scrollbar assertion on Windows',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        await _pump(
          tester,
          _FakeDetailRepository(),
          membership: _FakeMembershipRepository(withTeacher: true),
        );
        await tester.pumpAndSettle();

        final teacherSection = find.byKey(
          const Key('institutionGroupTeachersSection'),
        );
        expect(
          find.descendant(of: teacherSection, matching: find.byType(Scrollbar)),
          findsWidgets,
        );
        expect(
          find.descendant(of: teacherSection, matching: find.byType(DataTable)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('remove dialog shows exact history-preserving copy', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeDetailRepository(),
      membership: _FakeMembershipRepository(withTeacher: true),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Remove').first);
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();

    expect(find.text('Remove teacher from group?'), findsOneWidget);
    expect(find.text('Teacher One'), findsWidgets);
    expect(find.text('teacher.one'), findsWidgets);
    expect(
      find.text(
        'This ends the current group membership and revokes future group-based access. Historical relationship records and existing learning history are preserved. The user account itself is not deactivated.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Edit dialog initializes fields and local no-op remains open', (
    tester,
  ) async {
    await _pump(tester, _FakeDetailRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Group'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('institutionGroupEditName')))
          .controller!
          .text,
      'Advanced Mathematics',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('institutionGroupEditDescription')),
          )
          .textInputAction,
      TextInputAction.newline,
    );

    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(find.text('No group changes to save.'), findsOneWidget);
    expect(find.text('Edit Group'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('institutionGroupEditName')),
      '10-B',
    );
    await tester.pump();
    expect(find.text('No group changes to save.'), findsNothing);
  });

  testWidgets('Archive confirmation is exact and blocks dismissal while busy', (
    tester,
  ) async {
    final archiveResult = Completer<InstitutionGroup>();
    await _pump(
      tester,
      _FakeDetailRepository(),
      mutation: _FakeMutationRepository(onArchive: () => archiveResult.future),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archive Group'));
    await tester.pumpAndSettle();
    expect(find.text('Archive group?'), findsOneWidget);
    expect(find.text('Advanced Mathematics'), findsWidgets);
    expect(
      find.text(
        'Archiving makes this group read-only for future management. Historical relationships and learning records are preserved. Groups cannot be reactivated in the current MVP.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('institutionGroupArchiveConfirm')));
    await tester.pump();
    expect(
      find.byKey(const Key('institutionGroupArchiveDialog')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('institutionGroupArchiveCancel')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('institutionGroupDetailRefreshButton')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('institutionGroupEditAction')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('institutionGroupArchiveAction')),
          )
          .onPressed,
      isNull,
    );
    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(
      find.byKey(const Key('institutionGroupArchiveDialog')),
      findsOneWidget,
    );

    archiveResult.complete(
      testGroup(
        status: InstitutionGroupStatus.archived,
        archivedAt: DateTime.utc(2026, 8, 21, 10),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('institutionGroupArchiveDialog')),
      findsNothing,
    );
    expect(find.text('Group archived successfully.'), findsOneWidget);
    expect(find.text('Archived groups are read-only.'), findsOneWidget);
  });

  testWidgets(
    'invalid local target performs zero requests and is unavailable',
    (tester) async {
      final repository = _FakeDetailRepository();
      await _pump(tester, repository, target: 'not-a-uuid');
      await tester.pumpAndSettle();
      expect(repository.targets, isEmpty);
      expect(find.text('Group not found'), findsOneWidget);
      expect(
        find.text('The requested group is not available.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('exact 404 uses privacy-safe not-found copy', (tester) async {
    final repository = _FakeDetailRepository(
      onFetch: (_) => Future.error(
        ApiRequestException(
          ApiFailure(
            kind: ApiFailureKind.server,
            statusCode: 404,
            serverCode: ApiErrorCodes.resourceNotFound,
            message: 'Private reason.',
          ),
        ),
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Group not found'), findsOneWidget);
    expect(find.textContaining('Private'), findsNothing);
  });

  testWidgets('long content text scale and narrow width do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final long = List.filled(40, 'Long group content').join(' ');
    await _pump(
      tester,
      _FakeDetailRepository(
        group: testGroup(name: long, description: long),
      ),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeDetailRepository repository, {
  String target = testGroupId,
  TextScaler textScaler = TextScaler.noScaling,
  _FakeMutationRepository? mutation,
  _FakeMembershipRepository? membership,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          TestAuthSessionController.new,
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionGroupDetailRepositoryProvider.overrideWithValue(repository),
        institutionGroupMembershipRepositoryProvider.overrideWithValue(
          membership ?? _FakeMembershipRepository(),
        ),
        institutionUserListRepositoryProvider.overrideWithValue(
          _FakeUserListRepository(),
        ),
        if (mutation != null)
          institutionGroupMutationRepositoryProvider.overrideWithValue(
            mutation,
          ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(
            body: InstitutionAdminGroupDetailScreen(groupId: target),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FakeMutationRepository implements InstitutionGroupMutationRepository {
  _FakeMutationRepository({required this.onArchive});

  final Future<InstitutionGroup> Function() onArchive;

  @override
  Future<InstitutionGroup> archiveGroup(
    String groupId,
    InstitutionGroup selected,
  ) => onArchive();

  @override
  Future<InstitutionGroup> updateGroup(
    String groupId,
    InstitutionGroup selected,
    InstitutionGroupEditRequest request,
  ) => Future.value(selected);
}

class _FakeDetailRepository implements InstitutionGroupDetailRepository {
  _FakeDetailRepository({this.onFetch, InstitutionGroup? group})
    : group = group ?? testGroup();

  final Future<InstitutionGroup> Function(String target)? onFetch;
  final InstitutionGroup group;
  final targets = <String>[];

  @override
  Future<InstitutionGroup> fetchGroup(String groupId) {
    targets.add(groupId);
    return onFetch?.call(groupId) ?? Future.value(group);
  }
}

class _FakeMembershipRepository
    implements InstitutionGroupMembershipRepository {
  _FakeMembershipRepository({this.withTeacher = false, this.withAll = false});

  final bool withTeacher;
  final bool withAll;

  @override
  Future<InstitutionGroupMembershipListPage> fetchMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipQuery query,
  }) async {
    final memberships =
        withAll || (withTeacher && kind == InstitutionGroupMemberKind.teacher)
        ? [testMembership()]
        : <InstitutionGroupMembership>[];
    return InstitutionGroupMembershipListPage(
      memberships: memberships,
      pagination: InstitutionGroupMembershipListPagination(
        page: query.page,
        perPage: query.perPage,
        total: memberships.length,
        lastPage: 1,
      ),
    );
  }

  @override
  Future<List<InstitutionGroupMembership>> assignMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipAssignmentRequest request,
  }) async => [testMembership(id: request.memberIds.single)];

  @override
  Future<void> removeMembership({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required String memberId,
  }) async {}
}

class _FakeUserListRepository implements InstitutionUserListRepository {
  @override
  Future<InstitutionUserListPage> fetchUsers(
    InstitutionUserListQuery query,
  ) async {
    final role = query.role ?? InstitutionUserRole.teacher;
    final user = testCandidate(
      id: role == InstitutionUserRole.teacher ? testTeacherId : testStudentId,
      role: role,
      fullName: role == InstitutionUserRole.teacher
          ? 'Teacher One'
          : 'Student One',
      loginName: role == InstitutionUserRole.teacher
          ? 'teacher.one'
          : 'student.one',
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

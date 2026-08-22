import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
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
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_parent_student_connections_screen.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  testWidgets('default no-anchor surface sends no relationship request', (
    tester,
  ) async {
    final relationship = _FakeRelationshipRepository();
    final users = _FakeUserRepository();
    await _pump(tester, relationship: relationship, users: users);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('institutionParentStudentConnectionsHeading')),
      findsOneWidget,
    );
    expect(find.text('Parent–Student Connections'), findsOneWidget);
    expect(find.text('By Parent'), findsOneWidget);
    expect(find.text('By Student'), findsOneWidget);
    expect(
      find.text('Select a Parent to view current Student connections.'),
      findsOneWidget,
    );
    expect(find.text('Connect Parent and Student'), findsOneWidget);
    expect(relationship.fetches, isEmpty);
    expect(users.queries, isEmpty);
  });

  testWidgets('all-status anchor loads inactive current rows and disconnects', (
    tester,
  ) async {
    final relationship = _FakeRelationshipRepository();
    final users = _FakeUserRepository();
    await _pump(tester, relationship: relationship, users: users);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('institutionParentStudentSelectAnchor')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select Parent'), findsWidgets);
    expect(users.queries.single.role, InstitutionUserRole.parent);
    expect(users.queries.single.status, isNull);
    expect(find.textContaining('Inactive'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('institutionUserSelection$testParentId')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('institutionParentStudentAnchorSelect')),
    );
    await tester.pumpAndSettle();

    expect(relationship.fetches, hasLength(1));
    expect(find.text('Student One'), findsOneWidget);
    expect(find.text('student.one'), findsOneWidget);
    expect(find.text('Not provided'), findsOneWidget);
    expect(find.text('Inactive'), findsWidgets);
    expect(find.text('2026-08-21 10:15 UTC'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Parent and Student?'), findsOneWidget);
    expect(find.textContaining('Parent: Parent One'), findsOneWidget);
    expect(find.textContaining('Student: Student One'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('institutionParentStudentDisconnectConfirm')),
    );
    await tester.pumpAndSettle();
    expect(relationship.disconnectCalls, 1);
    expect(relationship.lastDisconnectedId, testRelationshipId);
    expect(find.text('Parent and student disconnected.'), findsOneWidget);
  });

  testWidgets(
    'parent-student horizontal table renders without Scrollbar assertion on Windows',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final relationship = _FakeRelationshipRepository();
        final users = _FakeUserRepository();

        await _pump(tester, relationship: relationship, users: users);
        await tester.pumpAndSettle();
        await _selectParentAnchor(tester);

        expect(
          find.byKey(const Key('institutionParentStudentHorizontalScroll')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('institutionParentStudentRelationshipTable')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets(
    'non-dismissible parent-student feedback renders without MaterialBanner assertion',
    (tester) async {
      final relationship = _FakeRelationshipRepository(
        onFetch: (_, _, _) async => throw ApiRequestException(
          ApiFailure.fromServerError(
            statusCode: 404,
            error: ApiErrorResponse(
              message: 'Private',
              code: ApiErrorCodes.resourceNotFound,
              fieldErrors: {},
              requestId: null,
            ),
          ),
        ),
      );
      final users = _FakeUserRepository();

      await _pump(tester, relationship: relationship, users: users);
      await tester.pumpAndSettle();
      await _selectParentAnchor(tester);

      final feedback = find.byKey(
        const Key('institutionParentStudentFeedback'),
      );
      expect(feedback, findsOneWidget);
      expect(tester.widget(feedback), isA<Material>());
      expect(find.byType(MaterialBanner), findsNothing);
      expect(
        find.text(
          'The selected user is no longer available for relationship management.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('connect dialog owns independent active selectors and confirms', (
    tester,
  ) async {
    final relationship = _FakeRelationshipRepository();
    final users = _FakeUserRepository();
    await _pump(tester, relationship: relationship, users: users);
    await tester.pumpAndSettle();

    await tester.tap(find.text('By Student'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('institutionParentStudentConnectButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connect Parent and Student'), findsWidgets);
    expect(users.queries, hasLength(2));
    expect(users.queries.map((query) => query.status).toSet(), {
      InstitutionUserStatusFilter.active,
    });

    await tester.tap(
      find.byKey(const ValueKey('institutionUserSelection$testParentId')),
    );
    await tester.pump();
    await tester.tap(find.text('Student').last);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('institutionUserSelection$testStudentId')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('institutionParentStudentConnectConfirm')),
    );
    await tester.pumpAndSettle();

    expect(relationship.connectCalls, 1);
    expect(
      find.text('Parent and student connected successfully.'),
      findsOneWidget,
    );
    expect(relationship.fetches, hasLength(1));
    expect(
      relationship.fetches.single.perspective,
      InstitutionParentStudentPerspective.byParent,
    );
    expect(
      tester
          .widget<SegmentedButton<InstitutionParentStudentPerspective>>(
            find.byKey(const Key('institutionParentStudentPerspectiveSwitch')),
          )
          .selected,
      {InstitutionParentStudentPerspective.byParent},
    );
  });

  testWidgets(
    'keyboard semantics and supported desktop text scale do not overflow',
    (tester) async {
      for (final testCase in [
        (size: const Size(800, 600), scale: 1.0),
        (size: const Size(1440, 900), scale: 1.0),
        (size: const Size(800, 600), scale: 2.0),
      ]) {
        await tester.binding.setSurfaceSize(testCase.size);
        tester.platformDispatcher.textScaleFactorTestValue = testCase.scale;
        await _pump(
          tester,
          relationship: _FakeRelationshipRepository(),
          users: _FakeUserRepository(),
          setDefaultSize: false,
        );
        await tester.pumpAndSettle();
        final semantics = tester.ensureSemantics();
        expect(
          tester
              .getSemantics(
                find.byKey(
                  const Key('institutionParentStudentConnectionsHeading'),
                ),
              )
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        semantics.dispose();
        await tester.tap(
          find.byKey(const Key('institutionParentStudentConnectButton')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('institutionParentStudentConnectDialog')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const Key('institutionParentStudentConnectCancel')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeRelationshipRepository relationship,
  required _FakeUserRepository users,
  bool setDefaultSize = true,
}) async {
  if (setDefaultSize) {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          TestAuthSessionController.new,
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionParentStudentRelationshipRepositoryProvider
            .overrideWithValue(relationship),
        institutionUserListRepositoryProvider.overrideWithValue(users),
      ],
      child: const MaterialApp(
        home: Scaffold(body: InstitutionAdminParentStudentConnectionsScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _selectParentAnchor(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('institutionParentStudentSelectAnchor')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('institutionUserSelection$testParentId')),
  );
  await tester.pump();
  await tester.tap(
    find.byKey(const Key('institutionParentStudentAnchorSelect')),
  );
  await tester.pumpAndSettle();
}

class _RelationshipFetch {
  const _RelationshipFetch(this.perspective, this.anchorId, this.query);
  final InstitutionParentStudentPerspective perspective;
  final String anchorId;
  final InstitutionParentStudentRelationshipQuery query;
}

class _FakeRelationshipRepository
    implements InstitutionParentStudentRelationshipRepository {
  _FakeRelationshipRepository({this.onFetch});

  final Future<InstitutionParentStudentRelationshipListPage> Function(
    InstitutionParentStudentPerspective perspective,
    String anchorId,
    InstitutionParentStudentRelationshipQuery query,
  )?
  onFetch;
  final fetches = <_RelationshipFetch>[];
  var connectCalls = 0;
  var disconnectCalls = 0;
  String? lastDisconnectedId;

  @override
  Future<InstitutionParentStudentRelationshipListPage> fetchRelationships({
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
    required InstitutionParentStudentRelationshipQuery query,
  }) async {
    fetches.add(_RelationshipFetch(perspective, anchorId, query));
    if (onFetch != null) {
      return onFetch!(perspective, anchorId, query);
    }
    return InstitutionParentStudentRelationshipListPage(
      relationships: [
        testRelationship(perspective: perspective, relatedActive: false),
      ],
      pagination: InstitutionParentStudentRelationshipListPagination(
        page: query.page,
        perPage: query.perPage,
        total: 1,
        lastPage: 1,
      ),
    );
  }

  @override
  Future<InstitutionParentStudentMutationResult> connect(
    InstitutionParentStudentConnectRequest request,
  ) async {
    connectCalls += 1;
    return InstitutionParentStudentMutationResult(
      id: testRelationshipId,
      parentId: request.parentId,
      studentId: request.studentId,
      startedAt: DateTime.utc(2026, 8, 21, 10, 15),
      endedAt: null,
    );
  }

  @override
  Future<void> disconnect(String relationshipId) async {
    disconnectCalls += 1;
    lastDisconnectedId = relationshipId;
  }
}

class _FakeUserRepository implements InstitutionUserListRepository {
  final queries = <InstitutionUserListQuery>[];

  @override
  Future<InstitutionUserListPage> fetchUsers(
    InstitutionUserListQuery query,
  ) async {
    queries.add(query);
    final role = query.role!;
    final active = query.status == InstitutionUserStatusFilter.active;
    final user = role == InstitutionUserRole.parent
        ? testInstitutionUser(isActive: active)
        : testInstitutionUser(
            id: testStudentId,
            role: InstitutionUserRole.student,
            fullName: 'Student One',
            loginName: 'student.one',
            isActive: active,
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

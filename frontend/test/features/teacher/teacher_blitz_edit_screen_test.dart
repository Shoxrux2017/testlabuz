import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_edit_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _unresolvedStudentId = '60000000-0000-0000-0000-0000000000aa';

void main() {
  testWidgets('Edit loads current values without scheduling controls', (
    tester,
  ) async {
    await _pumpEdit(
      tester,
      blitz: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(
          id: id,
          status: TeacherBlitzStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 18, 4),
          durationSeconds: 90,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Blitz'), findsOneWidget);
    expect(find.byTooltip('Back to Blitz'), findsOneWidget);
    expect(find.text('Equation Blitz'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('Duration: 1 min 30 sec'), findsOneWidget);
    expect(find.text('Scheduled'), findsWidgets);
    expect(find.text('Normal attempts: 1'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    for (final absent in [
      'Scheduled at',
      'Schedule',
      'Timer mode',
      'Activate',
      'Close',
      'Archive',
    ]) {
      expect(find.text(absent), findsNothing, reason: absent);
    }
  });

  testWidgets('a no-op Save stays on Edit without a request', (tester) async {
    final blitz = FakeTeacherBlitzRepository();
    await _pumpEdit(tester, blitz: blitz);
    await tester.pumpAndSettle();

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text('No changes to save.'), findsOneWidget);
    expect(blitz.updateRequests, isEmpty);
    expect(find.byKey(const Key('teacherBlitzEditScreen')), findsOneWidget);
  });

  testWidgets('a confirmed Save returns to Blitz detail', (tester) async {
    final blitz = FakeTeacherBlitzRepository(
      onUpdate: (id, _) async => teacherBlitz(id: id, title: 'Renamed Blitz'),
    );
    final router = await _pumpEdit(tester, blitz: blitz);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('teacherBlitzTitleField')),
      'Renamed Blitz',
    );
    await tester.pump();

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(blitz.updateRequests.single.request.toJson(), {
      'title': 'Renamed Blitz',
    });
    expect(find.text('Blitz updated successfully.'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
    );
  });

  testWidgets('a confirmed official Blitz locks whole-group assignment', (
    tester,
  ) async {
    await _pumpEdit(
      tester,
      pairs: FakeTeacherTopicResultPairRepository(
        onFetch: (_) async => teacherResultPair(blitzAssessmentId: _blitzId),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Official Blitz uses whole-group assignment.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Selected students'));
    await tester.tap(find.text('Selected students'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherBlitzChooseStudentsButton')),
      findsNothing,
    );
    expect(find.text('Official Blitz uses whole-group assignment.'), findsOne);
  });

  testWidgets('unresolved persisted Students never show raw IDs', (
    tester,
  ) async {
    await _pumpEdit(
      tester,
      blitz: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(
          id: id,
          assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
          studentIds: const [_unresolvedStudentId],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);

    final choose = find.byKey(const Key('teacherBlitzChooseStudentsButton'));
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();

    expect(find.text('Selected student 1'), findsOneWidget);
    expect(
      find.text('Name not loaded in the current eligible roster view.'),
      findsOneWidget,
    );
    expect(find.textContaining(_unresolvedStudentId), findsNothing);
  });

  testWidgets('a server student_ids error focuses the assignment picker', (
    tester,
  ) async {
    await _pumpEdit(
      tester,
      blitz: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(
          id: id,
          assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
          studentIds: const [_unresolvedStudentId],
        ),
        onUpdate: (_, _) async => throw ApiRequestException(
          ApiFailure.fromServerError(
            statusCode: 422,
            error: ApiErrorResponse(
              message: 'Invalid.',
              code: ApiErrorCodes.validationFailed,
              fieldErrors: const {
                'student_ids': ['Not eligible.'],
              },
              requestId: 'req-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('teacherBlitzTitleField')),
      'Renamed Blitz',
    );
    await tester.pump();

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Review the selected Students. One or more selections may no longer '
        'be eligible.',
      ),
      findsOneWidget,
    );
    final choose = tester.widget<OutlinedButton>(
      find.byKey(const Key('teacherBlitzChooseStudentsButton')),
    );
    expect(choose.focusNode!.hasFocus, isTrue);
    expect(find.textContaining(_unresolvedStudentId), findsNothing);
  });

  testWidgets('an unreadable outcome blocks leaving until checked', (
    tester,
  ) async {
    var reads = 0;
    final blitz = FakeTeacherBlitzRepository(
      onFetch: (id) async {
        reads += 1;
        if (reads == 2) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherBlitz(
          id: id,
          title: reads == 1 ? 'Equation Blitz' : 'Renamed Blitz',
        );
      },
      onUpdate: (_, _) async =>
          throw const TeacherBlitzMutationOutcomeUnknownException(),
    );
    final router = await _pumpEdit(tester, blitz: blitz);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('teacherBlitzTitleField')),
      'Renamed Blitz',
    );
    await tester.pump();

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The current Blitz could not be confirmed. Check the current Blitz '
        'before taking another action.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('teacherBlitzEditBackButton')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const Key('teacherBlitzEditCheckCurrentButton')),
    );
    await tester.pumpAndSettle();

    expect(blitz.updateRequests, hasLength(1));
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
    );
  });

  testWidgets('a non-authoring Blitz shows only Back to Blitz', (tester) async {
    await _pumpEdit(
      tester,
      blitz: FakeTeacherBlitzRepository(
        onFetch: (id) async =>
            teacherBlitz(id: id, status: TeacherBlitzStatus.active),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blitz editing is no longer available.'), findsOneWidget);
    expect(
      find.byKey(const Key('teacherBlitzEditBackToBlitzButton')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a dirty form asks before returning to Blitz', (tester) async {
    await _pumpEdit(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('teacherBlitzDurationField')),
      '120',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('teacherBlitzEditBackButton')));
    await tester.pumpAndSettle();
    expect(find.text('Discard Blitz changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('teacherBlitzKeepEditingButton')));
    await tester.pumpAndSettle();
    expect(find.text('120'), findsOneWidget);
  });
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const Key('teacherBlitzEditSubmitButton'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pump();
}

Future<GoRouter> _pumpEdit(
  WidgetTester tester, {
  FakeTeacherBlitzRepository? blitz,
  FakeTeacherTopicResultPairRepository? pairs,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutePaths.teacherBlitzEditLocation(_topicId, _blitzId),
    routes: [
      GoRoute(
        path: AppRoutePaths.teacherTopicDetail,
        builder: (_, _) => const Scaffold(body: Text('Topic stub')),
        routes: [
          GoRoute(
            path:
                '${AppRoutePaths.teacherBlitzSegment}/'
                ':${AppRoutePaths.teacherBlitzIdParameter}',
            builder: (_, _) => const Scaffold(body: Text('Blitz detail stub')),
            routes: [
              GoRoute(
                path: AppRoutePaths.teacherBlitzEditSegment,
                builder: (_, state) => TeacherBlitzEditScreen(
                  topicId: state
                      .pathParameters[AppRoutePaths.teacherTopicIdParameter]!,
                  blitzId: state
                      .pathParameters[AppRoutePaths.teacherBlitzIdParameter]!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherBlitzRepositoryProvider.overrideWithValue(
          blitz ?? FakeTeacherBlitzRepository(),
        ),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          pairs ?? FakeTeacherTopicResultPairRepository(),
        ),
        teacherGroupStudentRepositoryProvider.overrideWithValue(
          FakeTeacherGroupStudentRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return router;
}

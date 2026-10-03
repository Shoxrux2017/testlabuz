import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_list_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_detail_screen.dart';

import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _otherBlitzId = '80000000-0000-0000-0000-000000000002';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _note = Key('teacherBlitzActivationOfficialNote');

const _activeHomeworkNote =
    'This is the official Blitz. Activating it closes the official Homework '
    'for the whole group. Homework Attempts still in progress are submitted '
    'with their saved work. Students without a submitted Homework Attempt '
    'cannot take this Blitz.';

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    for (final (status, note) in <(TeacherHomeworkStatus?, String)>[
      (TeacherHomeworkStatus.active, _activeHomeworkNote),
      (
        TeacherHomeworkStatus.draft,
        'The official Homework is still a draft. Activate it first; this '
            'Blitz cannot be activated before it.',
      ),
      (TeacherHomeworkStatus.closed, 'This is the official Blitz.'),
      (TeacherHomeworkStatus.archived, 'This is the official Blitz.'),
      (
        null,
        'This is the official Blitz. If the official Homework is still '
            'active, activating it closes the Homework for the whole group, '
            'submits Attempts still in progress with their saved work, and '
            'Students without a submitted Homework Attempt cannot take this '
            'Blitz.',
      ),
    ]) {
      testWidgets('${surface.name}: official activation with a '
          '${status?.value ?? 'unconfirmed'} Homework explains its effect', (
        tester,
      ) async {
        final homework = _homework(status);
        await _pump(tester, surface: surface, homework: homework);

        await _openActivation(tester);

        expect(
          find.descendant(
            of: find.byKey(const Key('teacherBlitzConfirmDialog')),
            matching: find.text(note),
          ),
          findsOneWidget,
        );
        expect(homework.fetchIds, [_homeworkId, _homeworkId]);
      });
    }
  }

  testWidgets('a missing official Homework is not confirmed', (tester) async {
    await _pump(
      tester,
      homework: FakeTeacherHomeworkRepository(
        onFetch: (_) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      ),
    );

    await _openActivation(tester);

    expect(
      find.textContaining('If the official Homework is still active'),
      findsOneWidget,
    );
  });

  testWidgets('the note follows the Homework read when the dialog opens', (
    tester,
  ) async {
    var reads = 0;
    final homework = FakeTeacherHomeworkRepository(
      onFetch: (id) async {
        reads += 1;
        return teacherHomework(
          id: id,
          status: reads == 1
              ? TeacherHomeworkStatus.draft
              : TeacherHomeworkStatus.active,
        );
      },
    );
    await _pump(tester, homework: homework);

    await _openActivation(tester);

    expect(find.text(_activeHomeworkNote), findsOneWidget);
    expect(find.textContaining('still a draft'), findsNothing);
  });

  testWidgets('desktop activation of a practice Blitz has no official note', (
    tester,
  ) async {
    final homework = _homework(TeacherHomeworkStatus.active);
    await _pump(
      tester,
      pairs: FakeTeacherTopicResultPairRepository(
        onFetch: (_) async => _pair(blitzId: _otherBlitzId),
      ),
      homework: homework,
    );

    await _openActivation(tester);

    expect(find.byKey(_note), findsNothing);
    expect(homework.fetchIds, isEmpty);
  });

  testWidgets('a draft official Homework conflict is explained and reloaded', (
    tester,
  ) async {
    final homework = _homework(TeacherHomeworkStatus.draft);
    final pairs = FakeTeacherTopicResultPairRepository(
      onFetch: (_) async => _pair(),
    );
    await _pump(
      tester,
      homework: homework,
      pairs: pairs,
      blitz: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(id: id),
        onActivate: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.officialHomeworkNotActivated,
          statusCode: 409,
        ),
      ),
    );

    await _openActivation(tester);
    final pairReads = pairs.fetchTopicIds.length;
    await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The official Homework is still a draft. Activate the official '
        'Homework before this Blitz.',
      ),
      findsOneWidget,
    );
    expect(homework.fetchIds, [_homeworkId, _homeworkId, _homeworkId]);
    expect(pairs.fetchTopicIds.length, pairReads + 1);
  });

  testWidgets('the conflict reloads the Homework list without a known pair', (
    tester,
  ) async {
    final homework = _homework(TeacherHomeworkStatus.draft);
    await _pump(
      tester,
      homework: homework,
      pairs: FakeTeacherTopicResultPairRepository(
        onFetch: (_) async => _pair(blitzId: null),
      ),
      blitz: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(id: id),
        onActivate: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.officialHomeworkNotActivated,
          statusCode: 409,
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TeacherBlitzDetailScreen)),
    );
    final listener = container.listen(
      teacherHomeworkListControllerProvider(_topicId),
      (_, _) {},
    );
    addTearDown(listener.close);
    await tester.pumpAndSettle();
    final listReads = homework.listRequests.length;

    await _openActivation(tester);
    await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
    await tester.pumpAndSettle();

    expect(homework.listRequests.length, listReads + 1);
  });

  testWidgets('a confirmed official activation reloads Homework and results', (
    tester,
  ) async {
    final homework = _homework(TeacherHomeworkStatus.active);
    final results = FakeTeacherTopicResultRepository();
    await _pump(tester, homework: homework, results: results);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TeacherBlitzDetailScreen)),
    );
    final resultsListener = container.listen(
      teacherTopicResultListControllerProvider(_topicId),
      (_, _) {},
    );
    addTearDown(resultsListener.close);
    final homeworkListListener = container.listen(
      teacherHomeworkListControllerProvider(_topicId),
      (_, _) {},
    );
    addTearDown(homeworkListListener.close);
    await tester.pumpAndSettle();
    final resultReads = results.listRequests.length;
    final homeworkListReads = homework.listRequests.length;

    await _openActivation(tester);
    await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.text('Blitz activated successfully.'), findsOneWidget);
    expect(homework.fetchIds, [_homeworkId, _homeworkId, _homeworkId]);
    expect(results.listRequests.length, resultReads + 1);
    expect(homework.listRequests.length, homeworkListReads + 1);
  });
}

FakeTeacherHomeworkRepository _homework(TeacherHomeworkStatus? status) {
  return FakeTeacherHomeworkRepository(
    onFetch: (id) async => status == null
        ? throw teacherLocalFailure(ApiFailureKind.connection)
        : teacherHomework(id: id, status: status),
  );
}

Future<void> _openActivation(WidgetTester tester) async {
  final button = find.byKey(const Key('teacherBlitzActivateButton'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

TeacherTopicResultPair _pair({String? blitzId = _blitzId}) {
  return TeacherTopicResultPair(
    id: '95000000-0000-0000-0000-000000000001',
    topicId: _topicId,
    homeworkAssessmentId: _homeworkId,
    blitzAssessmentId: blitzId,
    cohortSnapshottedAt: null,
    lockedAt: null,
    designatedAt: DateTime.utc(2026, 9, 17, 12),
    createdAt: DateTime.utc(2026, 9, 17, 12),
    updatedAt: DateTime.utc(2026, 9, 17, 12),
  );
}

class _FixedKey implements IdempotencyKeyGenerator {
  @override
  String generate() => '11111111-1111-4111-8111-111111111111';
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeTeacherHomeworkRepository homework,
  FakeTeacherBlitzRepository? blitz,
  FakeTeacherTopicResultPairRepository? pairs,
  FakeTeacherTopicResultRepository? results,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
  await tester.binding.setSurfaceSize(
    surface == AppDeviceSurface.desktop
        ? const Size(1280, 1000)
        : const Size(390, 844),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherBlitzRepositoryProvider.overrideWithValue(
          blitz ??
              FakeTeacherBlitzRepository(
                onFetch: (id) async => teacherBlitz(id: id),
              ),
        ),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          pairs ??
              FakeTeacherTopicResultPairRepository(
                onFetch: (_) async => _pair(),
              ),
        ),
        teacherHomeworkRepositoryProvider.overrideWithValue(homework),
        teacherTopicResultRepositoryProvider.overrideWithValue(
          results ?? FakeTeacherTopicResultRepository(),
        ),
        idempotencyKeyGeneratorProvider.overrideWithValue(_FixedKey()),
      ],
      child: MaterialApp(
        home: TeacherBlitzDetailScreen(
          target: TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_detail_screen.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_question_read_view.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _studentId = '60000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('loading and not-found states are safe and read-only', (
    tester,
  ) async {
    final pending = Completer<TeacherBlitz>();
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(onFetch: (_) => pending.future),
    );

    expect(find.text('Blitz Detail'), findsOneWidget);
    expect(find.byKey(const Key('teacherBlitzDetailLoading')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading Blitz detail'), findsOneWidget);
    expect(
      find.byKey(const Key('teacherBlitzDetailRefreshButton')),
      findsNothing,
    );

    pending.completeError(
      teacherServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blitz unavailable'), findsOneWidget);
    expect(
      find.text(
        'This Blitz is not available in your current Teacher workspace.',
      ),
      findsOneWidget,
    );
    expect(find.text('Back to Topic'), findsOneWidget);
    expect(find.textContaining(_blitzId), findsNothing);
  });

  testWidgets('a Blitz from another Topic is shown as unavailable', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async => teacherBlitz(
          id: blitzId,
          topicId: '10000000-0000-0000-0000-000000000002',
          title: 'Foreign Blitz',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blitz unavailable'), findsOneWidget);
    expect(find.text('Foreign Blitz'), findsNothing);
  });

  for (final (kind, message) in [
    (
      ApiFailureKind.connection,
      'Could not reach the server. Check the connection and try again.',
    ),
    (ApiFailureKind.timeout, 'The Blitz request timed out.'),
    (ApiFailureKind.invalidResponse, 'The Blitz could not be loaded.'),
  ]) {
    testWidgets('${kind.name} error maps to a safe message and retries', (
      tester,
    ) async {
      var calls = 0;
      final repository = FakeTeacherBlitzRepository(
        onFetch: (blitzId) async {
          calls += 1;
          if (calls == 1) {
            throw teacherLocalFailure(kind);
          }
          return teacherBlitz(id: blitzId);
        },
      );
      await _pumpDetail(tester, repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacherBlitzDetailError')), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('Raw local failure'), findsNothing);

      await tester.tap(find.byKey(const Key('teacherBlitzDetailRetryButton')));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Equation Blitz'), findsOneWidget);
    });
  }

  testWidgets('shows authoritative metadata, timing, policy, and history', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async => teacherBlitz(
          id: blitzId,
          status: TeacherBlitzStatus.archived,
          durationSeconds: 90,
          scheduledAt: DateTime.utc(2026, 9, 18, 4),
          totalPossiblePoints: 7.5,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Equation Blitz'), findsOneWidget);
    expect(find.text('Archived'), findsWidgets);
    expect(find.text('Whole group'), findsWidgets);
    expect(
      _row(tester, 'Blitz information', 'Description'),
      'A short timed review.',
    );
    expect(
      _row(tester, 'Blitz information', 'Student instructions'),
      'Answer quickly and carefully.',
    );
    expect(_row(tester, 'Blitz information', 'Assignment'), 'Whole group');
    expect(find.text('Selected students'), findsNothing);
    expect(_row(tester, 'Blitz information', 'Total possible points'), '7.5');
    expect(_row(tester, 'Blitz information', 'Question count'), '0');
    expect(
      _row(tester, 'Blitz information', 'Institution timezone'),
      'Asia/Tashkent',
    );

    expect(_row(tester, 'Timing', 'Duration'), '1 min 30 sec');
    expect(_row(tester, 'Timing', 'Scheduled time'), '2026-09-18 09:00');
    expect(_row(tester, 'Timing', 'Timer start mode'), 'Synchronized');
    expect(_row(tester, 'Timing', 'Activated at'), '2026-09-18 04:01 UTC');
    expect(
      _row(tester, 'Timing', 'Synchronized common end'),
      '2026-09-18 04:02 UTC',
    );
    expect(_row(tester, 'Timing', 'Closed at'), '2026-09-18 04:30 UTC');
    expect(_row(tester, 'Timing', 'Archived at'), '2026-09-18 06:00 UTC');

    expect(_row(tester, 'Attempt policy', 'Normal attempts'), '1');
    expect(
      _row(tester, 'Attempt policy', 'Maximum additional exception attempts'),
      '1',
    );

    expect(_row(tester, 'History', 'Created'), '2026-09-17 10:00 UTC');
    expect(_row(tester, 'History', 'Updated'), '2026-09-17 11:00 UTC');
    expect(_row(tester, 'History', 'Activated'), '2026-09-18 04:01 UTC');
    expect(_row(tester, 'History', 'Closed'), '2026-09-18 04:30 UTC');
    expect(_row(tester, 'History', 'Archived'), '2026-09-18 06:00 UTC');
  });

  testWidgets('pre-activation Blitz shows explicit absent timing labels', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async =>
            teacherBlitz(id: blitzId, description: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Description'), findsNothing);
    expect(_row(tester, 'Timing', 'Duration'), '10 min');
    expect(_row(tester, 'Timing', 'Scheduled time'), 'Not scheduled');
    expect(
      _row(tester, 'Timing', 'Timer start mode'),
      'Not snapshotted until activation',
    );
    for (final absent in [
      'Activated at',
      'Synchronized common end',
      'Closed at',
      'Archived at',
      'Activated',
      'Closed',
      'Archived',
    ]) {
      expect(find.text(absent), findsNothing, reason: absent);
    }
  });

  testWidgets('individual timer snapshot has no synchronized common end', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async => teacherBlitz(
          id: blitzId,
          status: TeacherBlitzStatus.active,
          timerStartMode: TeacherBlitzTimerStartMode.individual,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(_row(tester, 'Timing', 'Timer start mode'), 'Individual');
    expect(find.text('Synchronized common end'), findsNothing);
    expect(_row(tester, 'Timing', 'Activated at'), '2026-09-18 04:01 UTC');
  });

  testWidgets('selected students show only a count, never IDs or names', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async => teacherBlitz(
          id: blitzId,
          assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
          studentIds: const [
            _studentId,
            '60000000-0000-0000-0000-000000000002',
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _row(tester, 'Blitz information', 'Assignment'),
      'Selected students',
    );
    expect(_row(tester, 'Blitz information', 'Selected students'), '2');
    expect(find.textContaining(_studentId), findsNothing);
  });

  testWidgets('Questions reuse the Teacher read view for every type', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async =>
            teacherBlitz(id: blitzId, questions: teacherHomeworkQuestions()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Questions'), findsOneWidget);
    expect(find.text('No Questions have been added.'), findsNothing);
    expect(
      find.byType(TeacherQuestionReadView, skipOffstage: false),
      findsNWidgets(10),
    );
    await tester.scrollUntilVisible(
      find.text('Fill in the blank'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Short written', skipOffstage: false), findsNWidgets(2));
    for (final label in [
      'Single choice',
      'Multiple choice',
      'True/False',
      'Open written',
      'File based',
      'Matching',
      'Ordering',
      'Fill in the blank',
    ]) {
      expect(
        find.text(label, skipOffstage: false),
        findsOneWidget,
        reason: label,
      );
    }
  });

  testWidgets('empty Questions show an explicit read-only message', (
    tester,
  ) async {
    await _pumpDetail(tester, FakeTeacherBlitzRepository());
    await tester.pumpAndSettle();

    expect(find.text('No Questions have been added.'), findsOneWidget);
    expect(find.byType(TeacherQuestionReadView), findsNothing);
  });

  testWidgets('refresh keeps content visible and a failure marks it stale', (
    tester,
  ) async {
    final refresh = Completer<TeacherBlitz>();
    var calls = 0;
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) {
          calls += 1;
          return calls == 1
              ? Future.value(
                  teacherBlitz(id: blitzId, title: 'Confirmed Blitz'),
                )
              : refresh.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherBlitzDetailRefreshButton')));
    await tester.pump();

    expect(find.byKey(const Key('teacherBlitzDetailProgress')), findsOneWidget);
    expect(find.bySemanticsLabel('Refreshing Blitz detail'), findsOneWidget);
    expect(find.text('Confirmed Blitz'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('teacherBlitzDetailRefreshButton')),
          )
          .onPressed,
      isNull,
    );

    refresh.completeError(teacherLocalFailure(ApiFailureKind.connection));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherBlitzDetailStaleMessage')),
      findsOneWidget,
    );
    expect(
      find.text('The displayed Blitz may be out of date.'),
      findsOneWidget,
    );
    expect(find.text('Confirmed Blitz'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 3);
  });

  testWidgets('Official chip follows only a confirmed exact pair match', (
    tester,
  ) async {
    final cases =
        <({Future<TeacherTopicResultPair?> Function() pair, bool official})>[
          (
            pair: () async =>
                teacherResultPair(blitzAssessmentId: _blitzId.toUpperCase()),
            official: true,
          ),
          (
            pair: () async => teacherResultPair(
              blitzAssessmentId: '80000000-0000-0000-0000-000000000009',
            ),
            official: false,
          ),
          (pair: () async => null, official: false),
          (
            pair: () async => throw teacherLocalFailure(ApiFailureKind.timeout),
            official: false,
          ),
          (
            pair: () => Completer<TeacherTopicResultPair?>().future,
            official: false,
          ),
        ];
    for (final testCase in cases) {
      await _pumpDetail(
        tester,
        FakeTeacherBlitzRepository(),
        pairs: FakeTeacherTopicResultPairRepository(
          onFetch: (_) => testCase.pair(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Equation Blitz'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherBlitzDetailOfficialChip')),
        testCase.official ? findsOneWidget : findsNothing,
      );
      expect(find.text('Practice'), findsNothing);
    }
  });

  testWidgets('an Active Blitz offers only Close, no monitoring or countdown', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async => teacherBlitz(
          id: blitzId,
          status: TeacherBlitzStatus.active,
          questions: teacherHomeworkQuestions(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Close'), findsOneWidget);
    for (final label in [
      'Edit',
      'Schedule',
      'Activate',
      'Archive',
      'Monitor',
      'Monitoring',
      'Grant exception',
      'Manage Questions',
      'Delete',
      'Reorder',
      'Remaining',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('desktop Draft and Scheduled Blitz offer authoring entries', (
    tester,
  ) async {
    for (final (status, surface, visible) in [
      (TeacherBlitzStatus.draft, AppDeviceSurface.desktop, true),
      (TeacherBlitzStatus.scheduled, AppDeviceSurface.desktop, true),
      (TeacherBlitzStatus.active, AppDeviceSurface.desktop, false),
      (TeacherBlitzStatus.closed, AppDeviceSurface.desktop, false),
      (TeacherBlitzStatus.archived, AppDeviceSurface.desktop, false),
      (TeacherBlitzStatus.draft, AppDeviceSurface.mobile, false),
    ]) {
      await _pumpDetail(
        tester,
        FakeTeacherBlitzRepository(
          onFetch: (blitzId) async => teacherBlitz(
            id: blitzId,
            status: status,
            scheduledAt: status == TeacherBlitzStatus.scheduled
                ? DateTime.utc(2026, 9, 18, 4)
                : null,
          ),
        ),
        surface: surface,
      );
      await tester.pumpAndSettle();

      final matcher = visible ? findsOneWidget : findsNothing;
      final reason = '${status.value} on ${surface.name}';
      expect(
        find.byKey(const Key('teacherBlitzEditButton')),
        matcher,
        reason: reason,
      );
      expect(
        find.byKey(const Key('teacherBlitzManageQuestionsButton')),
        matcher,
        reason: reason,
      );
    }
  });

  testWidgets('a stale Blitz hides authoring entries', (tester) async {
    var reads = 0;
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async {
          reads += 1;
          if (reads > 1) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherBlitz(id: blitzId);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherBlitzEditButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherBlitzDetailRefreshButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherBlitzDetailStaleMessage')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherBlitzEditButton')), findsNothing);
    expect(
      find.byKey(const Key('teacherBlitzManageQuestionsButton')),
      findsNothing,
    );
  });

  testWidgets('a reused screen widget shows only its current target', (
    tester,
  ) async {
    const otherTopicId = '10000000-0000-0000-0000-000000000002';
    const otherBlitzId = '80000000-0000-0000-0000-000000000002';
    final targetA = Completer<TeacherBlitz>();
    final repository = FakeTeacherBlitzRepository(
      onFetch: (blitzId) => blitzId == _blitzId
          ? targetA.future
          : Future.value(
              teacherBlitz(
                id: blitzId,
                topicId: otherTopicId,
                title: 'Topic B Blitz Y',
              ),
            ),
    );
    final auth = FakeTeacherAuthSessionController.authenticated(
      teacherUser('teacher-a'),
    );
    final pairs = FakeTeacherTopicResultPairRepository();
    Widget app(TeacherBlitzRouteTarget target) => ProviderScope(
      key: const ValueKey('reusedBlitzDetailScope'),
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherBlitzRepositoryProvider.overrideWithValue(repository),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(pairs),
      ],
      child: MaterialApp(home: TeacherBlitzDetailScreen(target: target)),
    );

    await tester.pumpWidget(
      app(TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId)),
    );
    await tester.pump();
    await tester.pumpWidget(
      app(
        TeacherBlitzRouteTarget(topicId: otherTopicId, blitzId: otherBlitzId),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Topic B Blitz Y'), findsOneWidget);

    targetA.complete(teacherBlitz(title: 'Topic A Blitz X'));
    await tester.pumpAndSettle();

    expect(find.text('Topic B Blitz Y'), findsOneWidget);
    expect(find.text('Topic A Blitz X'), findsNothing);
    expect(repository.fetchIds, [_blitzId, otherBlitzId]);
  });

  testWidgets('long content fits a scaled narrow mobile surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longText = List.filled(20, 'long responsive Blitz content').join(' ');
    final questions = teacherHomeworkQuestions();
    questions[0] = TeacherQuestion(
      id: questions[0].id,
      type: questions[0].type,
      prompt: longText,
      instructions: longText,
      points: questions[0].points,
      position: questions[0].position,
      checkingMode: questions[0].checkingMode,
      configuration: questions[0].configuration,
    );
    await _pumpDetail(
      tester,
      FakeTeacherBlitzRepository(
        onFetch: (blitzId) async => teacherBlitz(
          id: blitzId,
          title: longText,
          description: longText,
          studentInstructions: longText,
          status: TeacherBlitzStatus.closed,
          questions: questions,
        ),
      ),
      pairs: FakeTeacherTopicResultPairRepository(
        onFetch: (_) async => teacherResultPair(blitzAssessmentId: _blitzId),
      ),
      surface: AppDeviceSurface.mobile,
      textScaler: const TextScaler.linear(1.5),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherBlitzDetailScroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop content stays within the constrained reading width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpDetail(tester, FakeTeacherBlitzRepository());
    await tester.pumpAndSettle();

    final header = tester.getSize(
      find.byKey(const Key('teacherBlitzDetailHeader')),
    );
    expect(header.width, lessThanOrEqualTo(900));
    expect(tester.takeException(), isNull);
  });
}

/// Returns the value rendered below [label] inside the detail [card].
String _row(WidgetTester tester, String card, String label) {
  final cardFinder = find.byKey(ValueKey('teacherBlitzDetailCard:$card'));
  final labelFinder = find.descendant(
    of: cardFinder,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == label,
    ),
    skipOffstage: false,
  );
  expect(labelFinder, findsOneWidget, reason: '$card / $label');
  final children = tester
      .widget<Column>(
        find.ancestor(of: labelFinder, matching: find.byType(Column)).first,
      )
      .children;
  final labelIndex = children.indexWhere(
    (child) => child is Text && child.data == label,
  );
  return children.skip(labelIndex + 1).whereType<SelectableText>().first.data!;
}

Future<void> _pumpDetail(
  WidgetTester tester,
  FakeTeacherBlitzRepository repository, {
  FakeTeacherTopicResultPairRepository? pairs,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
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
        teacherBlitzRepositoryProvider.overrideWithValue(repository),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          pairs ?? FakeTeacherTopicResultPairRepository(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: TeacherBlitzDetailScreen(
          target: TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

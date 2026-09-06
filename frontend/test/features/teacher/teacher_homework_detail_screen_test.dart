import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair_repository.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_detail_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _studentId = '60000000-0000-0000-0000-000000000001';
const _matchingClientKey = '80000000-0000-0000-0000-000000000001';
const _pairId = '90000000-0000-0000-0000-000000000001';
const _otherHomeworkId = '50000000-0000-0000-0000-000000000002';
const _blitzId = 'a0000000-0000-0000-0000-000000000001';
const _nextTopicId = '10000000-0000-0000-0000-000000000002';
const _nextHomeworkId = '50000000-0000-0000-0000-000000000003';

void main() {
  testWidgets('Homework detail exposes loading and unavailable states safely', (
    tester,
  ) async {
    final pending = Completer<TeacherHomework>();
    await _pumpDetail(
      tester,
      FakeTeacherHomeworkRepository(onFetch: (_) => pending.future),
    );

    expect(
      find.byKey(const Key('teacherHomeworkDetailLoading')),
      findsOneWidget,
    );
    pending.completeError(
      teacherServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
    );
    await tester.pumpAndSettle();

    expect(find.text('Homework unavailable'), findsOneWidget);
    expect(find.text('Back to Topic'), findsOneWidget);
    expect(find.textContaining(_homeworkId), findsNothing);
  });

  testWidgets('Homework detail error retries without exposing raw failure', (
    tester,
  ) async {
    var calls = 0;
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (homeworkId) async {
        calls += 1;
        if (calls == 1) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherHomework(id: homeworkId);
      },
    );

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherHomeworkDetailError')), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);

    await tester.tap(find.byKey(const Key('teacherHomeworkDetailRetryButton')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Equation practice'), findsOneWidget);
  });

  testWidgets('metadata and every typed Question configuration are read-only', (
    tester,
  ) async {
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (homeworkId) async => teacherHomework(
        id: homeworkId,
        title: 'Comprehensive equation Homework',
        status: TeacherHomeworkStatus.closed,
        questions: teacherHomeworkQuestions(),
      ),
    );

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Comprehensive equation Homework'), findsOneWidget);
    expect(find.text('Closed'), findsWidgets);
    expect(find.text('Whole group'), findsWidgets);
    expect(find.text('Question count'), findsOneWidget);
    expect(find.text('10'), findsWidgets);
    expect(find.text('Deadline'), findsOneWidget);
    expect(find.text('2026-09-10 17:00'), findsOneWidget);
    expect(find.text('Asia/Tashkent'), findsOneWidget);
    expect(find.text('Normal attempts'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Highest valid completed attempt'), findsOneWidget);
    expect(find.text('Activated'), findsOneWidget);
    expect(find.text('Closed'), findsWidgets);

    expect(find.text('Single choice'), findsOneWidget);
    expect(find.text('Multiple choice'), findsOneWidget);
    expect(find.text('True/False'), findsOneWidget);
    expect(find.text('Short written'), findsNWidgets(2));
    expect(find.text('Open written'), findsOneWidget);
    expect(find.text('File based'), findsOneWidget);
    expect(find.text('Matching'), findsOneWidget);
    expect(find.text('Ordering'), findsOneWidget);
    expect(find.text('Fill in the blank'), findsOneWidget);

    expect(find.textContaining('Correct answer: True'), findsOneWidget);
    expect(find.text('Accepted answers'), findsOneWidget);
    expect(find.text('Manual review'), findsNWidgets(3));
    expect(find.text('Allowed files: PDF, DOCX, PPT, PPTX'), findsOneWidget);
    expect(find.text('2 + 2 → 4'), findsOneWidget);
    expect(find.text('1. Simplify'), findsOneWidget);
    expect(find.text('sum: Four, 4'), findsOneWidget);
    expect(find.textContaining('Correct'), findsWidgets);

    expect(find.textContaining(_matchingClientKey), findsNothing);
    expect(find.textContaining(_studentId), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Reorder'), findsNothing);
    expect(find.text('Activate'), findsNothing);
    expect(
      find.byKey(const Key('teacherHomeworkLifecyclearchiveButton')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('desktop lifecycle actions follow confirmed Homework status', (
    tester,
  ) async {
    final cases = <(TeacherHomeworkStatus, Set<String>)>[
      (TeacherHomeworkStatus.draft, {'activate', 'archive'}),
      (TeacherHomeworkStatus.active, {'close'}),
      (TeacherHomeworkStatus.closed, {'archive'}),
      (TeacherHomeworkStatus.archived, <String>{}),
    ];

    for (final testCase in cases) {
      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(
          onFetch: (id) async => teacherHomework(id: id, status: testCase.$1),
        ),
      );
      await tester.pumpAndSettle();

      for (final action in ['activate', 'close', 'archive']) {
        expect(
          find.byKey(Key('teacherHomeworkLifecycle${action}Button')),
          testCase.$2.contains(action) ? findsOneWidget : findsNothing,
          reason: '${testCase.$1.name} / $action',
        );
      }
    }
  });

  testWidgets('every lifecycle action requires its safe confirmation', (
    tester,
  ) async {
    final cases = <(TeacherHomeworkStatus, String, String)>[
      (TeacherHomeworkStatus.draft, 'activate', 'Activate Homework?'),
      (TeacherHomeworkStatus.active, 'close', 'Close Homework?'),
      (TeacherHomeworkStatus.closed, 'archive', 'Archive Homework?'),
    ];

    for (final testCase in cases) {
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(id: id, status: testCase.$1),
      );
      await _pumpDetail(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(Key('teacherHomeworkLifecycle${testCase.$2}Button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmDialog')),
        findsOneWidget,
      );
      expect(find.text(testCase.$3), findsOneWidget);
      expect(repository.lifecycleRequests, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.lifecycleRequests, isEmpty);
    }
  });

  testWidgets(
    'mobile keeps lifecycle and official status read-only without mutations',
    (tester) async {
      final repository = FakeTeacherHomeworkRepository();
      final pairs = _FakeResultPairRepository(
        onFetch: (_) async => _resultPair(),
      );

      await _pumpDetail(
        tester,
        repository,
        pairs: pairs,
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherHomeworkLifecycleControls')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkBadge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
        findsNothing,
      );
      expect(repository.lifecycleRequests, isEmpty);
      expect(pairs.setRequests, isEmpty);
    },
  );

  testWidgets(
    'lifecycle busy disables shared actions and publishes confirmed feedback',
    (tester) async {
      final completion = Completer<TeacherHomework>();
      final repository = FakeTeacherHomeworkRepository(
        onLifecycle: (_, _) => completion.future,
      );

      await _pumpDetail(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleactivateButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmButton')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('teacherHomeworkLifecycleProgress')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('teacherHomeworkLifecyclearchiveButton')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('teacherOfficialHomeworkActionButton')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('teacherHomeworkDetailRefreshButton')),
            )
            .onPressed,
        isNull,
      );

      completion.complete(
        teacherHomework(status: TeacherHomeworkStatus.active),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Homework activated successfully.'), findsOneWidget);
      expect(repository.lifecycleRequests, hasLength(1));
      expect(
        find.byKey(const Key('teacherHomeworkLifecyclecloseButton')),
        findsOneWidget,
      );
    },
  );

  testWidgets('activation conflicts expose the relevant recovery action', (
    tester,
  ) async {
    final cases = <(String, String)>[
      (ApiErrorCodes.assessmentHasNoScoreablePoints, 'Manage Questions'),
      (ApiErrorCodes.assessmentNotAssigned, 'Edit Homework'),
      (ApiErrorCodes.deadlinePassed, 'Edit Homework'),
      (ApiErrorCodes.topicNotEditable, 'Back to Topic'),
    ];

    for (final testCase in cases) {
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(id: id),
        onLifecycle: (_, _) async =>
            throw teacherServerFailure(testCase.$1, statusCode: 409),
      );
      await _pumpDetail(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleactivateButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmButton')),
      );
      await tester.pumpAndSettle();

      final conflictAction = find.byKey(
        const Key('teacherHomeworkLifecycleConflictAction'),
      );
      expect(
        find.byKey(const Key('teacherHomeworkLifecycleNotice')),
        findsOneWidget,
      );
      expect(conflictAction, findsOneWidget, reason: testCase.$1);
      expect(
        find.descendant(of: conflictAction, matching: find.text(testCase.$2)),
        findsOneWidget,
      );
      expect(find.textContaining('Raw server failure'), findsNothing);
      expect(repository.lifecycleRequests, hasLength(1));
    }
  });

  testWidgets('pair loading does not hide detail or lifecycle controls', (
    tester,
  ) async {
    final pending = Completer<TeacherTopicResultPair?>();

    await _pumpDetail(
      tester,
      FakeTeacherHomeworkRepository(),
      pairs: _FakeResultPairRepository(onFetch: (_) => pending.future),
    );

    expect(find.text('Equation practice'), findsOneWidget);
    expect(
      find.byKey(const Key('teacherOfficialHomeworkLoading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('teacherHomeworkLifecycleactivateButton')),
      findsOneWidget,
    );

    pending.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('pair error and Retry stay independent from loaded detail', (
    tester,
  ) async {
    var fetches = 0;
    final pairs = _FakeResultPairRepository(
      onFetch: (_) async {
        fetches += 1;
        if (fetches == 1) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return _resultPair();
      },
    );

    await _pumpDetail(tester, FakeTeacherHomeworkRepository(), pairs: pairs);
    await tester.pumpAndSettle();

    expect(find.text('Equation practice'), findsOneWidget);
    expect(
      find.byKey(const Key('teacherOfficialHomeworkReadError')),
      findsOneWidget,
    );
    expect(find.textContaining('Raw local failure'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('teacherOfficialHomeworkRetryButton')),
    );
    await tester.tap(
      find.byKey(const Key('teacherOfficialHomeworkRetryButton')),
    );
    await tester.pumpAndSettle();

    expect(fetches, 2);
    expect(
      find.byKey(const Key('teacherOfficialHomeworkBadge')),
      findsOneWidget,
    );
    expect(find.text('Equation practice'), findsOneWidget);
  });

  testWidgets(
    'official states show cohort, lock, practice, and archive variants',
    (tester) async {
      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(),
        pairs: _FakeResultPairRepository(onFetch: (_) async => _resultPair()),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherOfficialHomeworkBadge')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Official cohort will be fixed when this Homework is activated.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherHomeworkLifecyclearchiveButton')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('teacherHomeworkOfficialDraftArchiveMessage')),
        findsOneWidget,
      );

      final snapshottedAt = DateTime.utc(2026, 9, 4, 10);
      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(
          onFetch: (id) async =>
              teacherHomework(id: id, status: TeacherHomeworkStatus.closed),
        ),
        pairs: _FakeResultPairRepository(
          onFetch: (_) async => _resultPair(
            cohortSnapshottedAt: snapshottedAt,
            lockedAt: snapshottedAt.add(const Duration(minutes: 5)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Official cohort prepared.'), findsOneWidget);
      expect(find.text('Official selection locked.'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherHomeworkLifecyclearchiveButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
        findsNothing,
      );

      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(
          onFetch: (id) async => teacherHomework(
            id: id,
            assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
            studentIds: const [_studentId],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Practice Homework'), findsOneWidget);
      expect(
        find.text(
          'Selected-student Homework is practice-only and cannot be the official Homework.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
        findsNothing,
      );
      expect(find.textContaining(_studentId), findsNothing);

      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(
          onFetch: (id) async => teacherHomework(
            id: id,
            assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
            studentIds: const [_studentId],
          ),
        ),
        pairs: _FakeResultPairRepository(onFetch: (_) async => _resultPair()),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherOfficialHomeworkBadge')),
        findsOneWidget,
      );
      expect(find.text('Practice Homework'), findsNothing);
      expect(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'another official is replaceable only while unlocked and without Blitz',
    (tester) async {
      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(),
        pairs: _FakeResultPairRepository(
          onFetch: (_) async => _resultPair(homeworkId: _otherHomeworkId),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Another Homework is currently official for this Topic.'),
        findsOneWidget,
      );
      expect(find.text('Replace official Homework'), findsOneWidget);

      final snapshottedAt = DateTime.utc(2026, 9, 4, 10);
      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(),
        pairs: _FakeResultPairRepository(
          onFetch: (_) async => _resultPair(
            homeworkId: _otherHomeworkId,
            cohortSnapshottedAt: snapshottedAt,
            lockedAt: snapshottedAt,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Official Homework selection is locked.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
        findsNothing,
      );

      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(),
        pairs: _FakeResultPairRepository(
          onFetch: (_) async =>
              _resultPair(homeworkId: _otherHomeworkId, blitzId: _blitzId),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Official Homework selection is locked.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
        findsNothing,
      );
      expect(find.textContaining('Blitz'), findsNothing);
      expect(find.textContaining(_pairId), findsNothing);
      expect(find.textContaining(_otherHomeworkId), findsNothing);
      expect(find.textContaining(_blitzId), findsNothing);
    },
  );

  testWidgets('Set and Replace confirmations include the active cohort note', (
    tester,
  ) async {
    final cases = <(TeacherTopicResultPair?, String, String)>[
      (null, 'Set as official Homework?', 'Set official'),
      (
        _resultPair(homeworkId: _otherHomeworkId),
        'Replace official Homework?',
        'Replace',
      ),
    ];

    for (final testCase in cases) {
      final pairs = _FakeResultPairRepository(
        onFetch: (_) async => testCase.$1,
      );
      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(
          onFetch: (id) async =>
              teacherHomework(id: id, status: TeacherHomeworkStatus.active),
        ),
        pairs: pairs,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherOfficialHomeworkConfirmDialog')),
        findsOneWidget,
      );
      expect(find.text(testCase.$2), findsOneWidget);
      expect(
        find.textContaining(
          'Its existing assigned-group snapshot will become the official Topic cohort.',
        ),
        findsOneWidget,
      );
      expect(find.text(testCase.$3), findsOneWidget);
      expect(find.textContaining(_otherHomeworkId), findsNothing);
      expect(pairs.setRequests, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(pairs.setRequests, isEmpty);
    }
  });

  testWidgets(
    'official busy disables lifecycle and refresh then publishes the pair',
    (tester) async {
      final completion = Completer<TeacherTopicResultPair>();
      final pairs = _FakeResultPairRepository(
        onSet: (_, _) => completion.future,
      );
      await _pumpDetail(tester, FakeTeacherHomeworkRepository(), pairs: pairs);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkConfirmButton')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('teacherOfficialHomeworkProgress')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('teacherHomeworkLifecycleactivateButton')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('teacherHomeworkDetailRefreshButton')),
            )
            .onPressed,
        isNull,
      );
      expect(pairs.setRequests, [(_topicId, _homeworkId)]);

      completion.complete(_resultPair());
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Official Homework updated successfully.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkBadge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'server lock suppresses designation even when refreshed pair stays null',
    (tester) async {
      final pairs = _FakeResultPairRepository(
        onSet: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.resultPairLocked,
          statusCode: 409,
        ),
      );
      await _pumpDetail(tester, FakeTeacherHomeworkRepository(), pairs: pairs);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Official Homework selection is locked.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Official Homework selection is locked by the current server state.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
        findsNothing,
      );
      expect(pairs.setRequests, [(_topicId, _homeworkId)]);
      expect(pairs.fetchRequests, [_topicId, _topicId]);
      expect(find.textContaining('Student Attempt'), findsNothing);
    },
  );

  testWidgets(
    'same detail widget target update cannot dispatch against the old target',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final oldCompletion = Completer<TeacherHomework>();
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async => teacherHomework(
          id: homeworkId,
          topicId: homeworkId == _nextHomeworkId ? _nextTopicId : _topicId,
          title: homeworkId == _nextHomeworkId
              ? 'Next target Homework'
              : 'Original target Homework',
        ),
        onLifecycle: (homeworkId, _) {
          if (homeworkId == _homeworkId) {
            return oldCompletion.future;
          }
          return Future.value(
            teacherHomework(
              id: homeworkId,
              topicId: _nextTopicId,
              status: TeacherHomeworkStatus.active,
            ),
          );
        },
      );
      final pairs = _FakeResultPairRepository();

      await tester.pumpWidget(
        _targetUpdatingDetailHarness(
          topicId: _topicId,
          homeworkId: _homeworkId,
          auth: auth,
          repository: repository,
          pairs: pairs,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Original target Homework'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleactivateButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmDialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmButton')),
      );
      await tester.pump();
      expect(repository.lifecycleRequests.single.homeworkId, _homeworkId);

      await tester.pumpWidget(
        _targetUpdatingDetailHarness(
          topicId: _nextTopicId,
          homeworkId: _nextHomeworkId,
          auth: auth,
          repository: repository,
          pairs: pairs,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next target Homework'), findsOneWidget);
      oldCompletion.complete(
        teacherHomework(
          id: _homeworkId,
          topicId: _topicId,
          title: 'Stale completed Homework',
          status: TeacherHomeworkStatus.active,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next target Homework'), findsOneWidget);
      expect(find.text('Stale completed Homework'), findsNothing);
      expect(find.text('Homework activated successfully.'), findsNothing);
      expect(repository.lifecycleRequests, hasLength(1));

      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleactivateButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(repository.lifecycleRequests, hasLength(2));
      expect(repository.lifecycleRequests.last.homeworkId, _nextHomeworkId);
    },
  );

  testWidgets(
    'target replacement during lifecycle confirmation sends no obsolete POST',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async => teacherHomework(
          id: homeworkId,
          topicId: homeworkId == _nextHomeworkId ? _nextTopicId : _topicId,
          title: homeworkId == _nextHomeworkId
              ? 'Next target Homework'
              : 'Original target Homework',
        ),
      );
      final pairs = _FakeResultPairRepository();

      await tester.pumpWidget(
        _targetUpdatingDetailHarness(
          topicId: _topicId,
          homeworkId: _homeworkId,
          auth: auth,
          repository: repository,
          pairs: pairs,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleactivateButton')),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _targetUpdatingDetailHarness(
          topicId: _nextTopicId,
          homeworkId: _nextHomeworkId,
          auth: auth,
          repository: repository,
          pairs: pairs,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next target Homework'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmDialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(repository.lifecycleRequests, isEmpty);
    },
  );

  testWidgets(
    'target replacement during Official confirmation sends no obsolete PUT',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async => teacherHomework(
          id: homeworkId,
          topicId: homeworkId == _nextHomeworkId ? _nextTopicId : _topicId,
          title: homeworkId == _nextHomeworkId
              ? 'Next target Homework'
              : 'Original target Homework',
        ),
      );
      final pairs = _FakeResultPairRepository();

      await tester.pumpWidget(
        _targetUpdatingDetailHarness(
          topicId: _topicId,
          homeworkId: _homeworkId,
          auth: auth,
          repository: repository,
          pairs: pairs,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _targetUpdatingDetailHarness(
          topicId: _nextTopicId,
          homeworkId: _nextHomeworkId,
          auth: auth,
          repository: repository,
          pairs: pairs,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next target Homework'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherOfficialHomeworkConfirmDialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(pairs.setRequests, isEmpty);
    },
  );

  testWidgets(
    'Teacher session replacement during lifecycle confirmation sends nothing',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final repository = FakeTeacherHomeworkRepository();
      await _pumpDetail(tester, repository, auth: auth);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleactivateButton')),
      );
      await tester.pumpAndSettle();

      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('teacherHomeworkLifecycleConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(repository.lifecycleRequests, isEmpty);
    },
  );

  testWidgets(
    'Teacher session replacement during Official confirmation sends nothing',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final pairs = _FakeResultPairRepository();
      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(),
        auth: auth,
        pairs: pairs,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkActionButton')),
      );
      await tester.pumpAndSettle();

      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('teacherOfficialHomeworkConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(pairs.setRequests, isEmpty);
    },
  );

  testWidgets(
    'selected recipients show only count and null deadline is clear',
    (tester) async {
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async => teacherHomework(
          id: homeworkId,
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          studentIds: const [
            _studentId,
            '60000000-0000-0000-0000-000000000002',
          ],
          hasDeadline: false,
        ),
      );

      await _pumpDetail(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('Selected students: 2'), findsOneWidget);
      expect(find.text('No deadline'), findsOneWidget);
      expect(find.textContaining(_studentId), findsNothing);
      expect(
        find.byKey(const Key('teacherHomeworkEditButton')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'authoring actions require current draft or active desktop detail',
    (tester) async {
      for (final status in [
        TeacherHomeworkStatus.draft,
        TeacherHomeworkStatus.active,
      ]) {
        await _pumpDetail(
          tester,
          FakeTeacherHomeworkRepository(
            onFetch: (id) async => teacherHomework(id: id, status: status),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('teacherHomeworkEditButton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('teacherHomeworkManageQuestionsButton')),
          findsOneWidget,
        );
      }

      for (final status in [
        TeacherHomeworkStatus.closed,
        TeacherHomeworkStatus.archived,
      ]) {
        await _pumpDetail(
          tester,
          FakeTeacherHomeworkRepository(
            onFetch: (id) async => teacherHomework(id: id, status: status),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('teacherHomeworkEditButton')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('teacherHomeworkManageQuestionsButton')),
          findsNothing,
        );
      }

      await _pumpDetail(
        tester,
        FakeTeacherHomeworkRepository(),
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacherHomeworkEditButton')), findsNothing);
      expect(
        find.byKey(const Key('teacherHomeworkManageQuestionsButton')),
        findsNothing,
      );
    },
  );

  testWidgets('refresh retains confirmed detail and marks a failure stale', (
    tester,
  ) async {
    final refresh = Completer<TeacherHomework>();
    var calls = 0;
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (homeworkId) {
        calls += 1;
        if (calls == 1) {
          return Future.value(
            teacherHomework(id: homeworkId, title: 'Confirmed Homework'),
          );
        }
        return refresh.future;
      },
    );

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherHomeworkEditButton')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('teacherHomeworkDetailRefreshButton')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('teacherHomeworkDetailProgress')),
      findsOneWidget,
    );
    expect(find.text('Confirmed Homework'), findsOneWidget);
    expect(find.byKey(const Key('teacherHomeworkEditButton')), findsNothing);
    expect(
      find.byKey(const Key('teacherHomeworkManageQuestionsButton')),
      findsNothing,
    );

    refresh.completeError(teacherLocalFailure(ApiFailureKind.connection));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailStaleMessage')),
      findsOneWidget,
    );
    expect(find.text('Confirmed Homework'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);
    expect(find.byKey(const Key('teacherHomeworkEditButton')), findsNothing);
    expect(
      find.byKey(const Key('teacherHomeworkManageQuestionsButton')),
      findsNothing,
    );
  });

  testWidgets('long typed detail content fits a scaled mobile surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longText = List.filled(
      20,
      'long responsive Homework content',
    ).join(' ');
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
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (homeworkId) async => teacherHomework(
        id: homeworkId,
        title: longText,
        description: longText,
        studentInstructions: longText,
        questions: questions,
      ),
    );

    await _pumpDetail(
      tester,
      repository,
      surface: AppDeviceSurface.mobile,
      textScaler: const TextScaler.linear(1.5),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailScroll')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherHomeworkEditButton')), findsNothing);
    expect(
      find.byKey(const Key('teacherHomeworkManageQuestionsButton')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _targetUpdatingDetailHarness({
  required String topicId,
  required String homeworkId,
  required FakeTeacherAuthSessionController auth,
  required FakeTeacherHomeworkRepository repository,
  required _FakeResultPairRepository pairs,
}) {
  return ProviderScope(
    key: const ValueKey('reusedHomeworkDetailScope'),
    overrides: [
      authSessionControllerProvider.overrideWith(() => auth),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      teacherHomeworkRepositoryProvider.overrideWithValue(repository),
      teacherTopicResultPairRepositoryProvider.overrideWithValue(pairs),
    ],
    child: MaterialApp(
      home: TeacherHomeworkDetailScreen(
        key: const ValueKey('reusedHomeworkDetailScreen'),
        topicId: topicId,
        homeworkId: homeworkId,
      ),
    ),
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  FakeTeacherHomeworkRepository repository, {
  FakeTeacherAuthSessionController? auth,
  _FakeResultPairRepository? pairs,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeTeacherAuthSessionController.authenticated(
                teacherUser('teacher-a'),
              ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          pairs ?? _FakeResultPairRepository(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const TeacherHomeworkDetailScreen(
          topicId: _topicId,
          homeworkId: _homeworkId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

TeacherTopicResultPair _resultPair({
  String homeworkId = _homeworkId,
  String? blitzId,
  DateTime? cohortSnapshottedAt,
  DateTime? lockedAt,
}) {
  return TeacherTopicResultPair(
    id: _pairId,
    topicId: _topicId,
    homeworkAssessmentId: homeworkId,
    blitzAssessmentId: blitzId,
    cohortSnapshottedAt: cohortSnapshottedAt,
    lockedAt: lockedAt,
    designatedAt: DateTime.utc(2026, 9, 3, 10),
    createdAt: DateTime.utc(2026, 9, 3, 10),
    updatedAt: lockedAt ?? cohortSnapshottedAt ?? DateTime.utc(2026, 9, 3, 10),
  );
}

class _FakeResultPairRepository implements TeacherTopicResultPairRepository {
  _FakeResultPairRepository({this.onFetch, this.onSet});

  final Future<TeacherTopicResultPair?> Function(String topicId)? onFetch;
  final Future<TeacherTopicResultPair> Function(
    String topicId,
    String homeworkId,
  )?
  onSet;

  final fetchRequests = <String>[];
  final setRequests = <(String, String)>[];

  @override
  Future<TeacherTopicResultPair?> fetchResultPair(String topicId) {
    fetchRequests.add(topicId);
    return onFetch?.call(topicId) ?? Future.value(null);
  }

  @override
  Future<TeacherTopicResultPair> setOfficialHomework(
    String topicId,
    String homeworkId,
  ) {
    setRequests.add((topicId, homeworkId));
    return onSet?.call(topicId, homeworkId) ??
        Future.value(_resultPair(homeworkId: homeworkId));
  }
}

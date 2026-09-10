import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_start_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_start_state.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_detail_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_section.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_read_view.dart';
import 'package:testlabuz_client/features/student/presentation/student_topic_detail_screen.dart';

import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _questionPrefix = '50000000-0000-0000-0000-';

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} confirmed current Attempt resumes by exact route with no POST',
      (tester) async {
        final repository = _StartRepository();
        final (router, _) = await _pumpStartDetail(
          tester,
          surface: surface,
          starts: repository,
        );
        final semantics = tester.ensureSemantics();
        try {
          await tester.pump();
          expect(find.text('Resume Attempt 1'), findsOneWidget);
          expect(
            find.byKey(const Key('studentHomeworkStartAttemptButton')),
            findsNothing,
          );
          expect(find.bySemanticsLabel('Resume Attempt 1'), findsOneWidget);
          await tester.tap(
            find.byKey(const Key('studentHomeworkResumeAttemptButton')),
          );
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            AppRoutePaths.studentHomeworkAttemptLocation(
              studentTopicId,
              _homeworkId,
              _startedAttemptId,
            ),
          );
          expect(repository.keys, isEmpty);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      '${surface.name} Start is busy, uncertain Retry is keyboard accessible and keeps counts',
      (tester) async {
        final first = Completer<StudentHomeworkAttemptStartResult>();
        final second = Completer<StudentHomeworkAttemptStartResult>();
        var calls = 0;
        final repository = _StartRepository(
          onStart: (_, _) => ++calls == 1 ? first.future : second.future,
        );
        final (router, _) = await _pumpStartDetail(
          tester,
          surface: surface,
          starts: repository,
          homework: _HomeworkRepository(
            onDetail: (_) async => _detail(inProgress: false),
          ),
        );
        final semantics = tester.ensureSemantics();
        try {
          await tester.pump();
          expect(find.bySemanticsLabel('Start Attempt'), findsOneWidget);
          await tester.tap(
            find.byKey(const Key('studentHomeworkStartAttemptButton')),
          );
          await tester.pump();
          expect(
            _button(tester, 'studentHomeworkStartAttemptButton').onPressed,
            isNull,
          );
          expect(
            tester
                .getSemantics(
                  find.byKey(const Key('studentHomeworkStartAttemptButton')),
                )
                .label,
            contains('Starting Attempt, please wait'),
          );
          first.completeError(studentLocalFailure(ApiFailureKind.timeout));
          await tester.pumpAndSettle();
          expect(find.text('Retry Start'), findsOneWidget);
          expect(
            find.byKey(const Key('studentHomeworkStartAttemptButton')),
            findsNothing,
          );
          expect(
            find.textContaining(
              'We could not confirm whether the attempt started.',
            ),
            findsOneWidget,
          );
          expect(find.text('Remaining'), findsOneWidget);
          expect(find.text('1'), findsNWidgets(2));
          final retry = find.byKey(
            const Key('studentHomeworkRetryStartButton'),
          );
          Focus.of(
            tester.element(
              find.descendant(of: retry, matching: find.text('Retry Start')),
            ),
          ).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(repository.keys, hasLength(2));
          expect(repository.keys[1], repository.keys[0]);
          second.complete(_startResult());
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            AppRoutePaths.studentHomeworkAttemptLocation(
              studentTopicId,
              _homeworkId,
              _startedAttemptId,
            ),
          );
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      '${surface.name} deterministic rejection shows safe feedback and no optimistic counts',
      (tester) async {
        final repository = _StartRepository(
          onStart: (_, _) async => throw studentServerFailure(
            ApiErrorCodes.attemptsExhausted,
            statusCode: 409,
          ),
        );
        await _pumpStartDetail(
          tester,
          surface: surface,
          starts: repository,
          homework: _HomeworkRepository(
            onDetail: (_) async => _detail(inProgress: false),
          ),
        );
        await tester.tap(
          find.byKey(const Key('studentHomeworkStartAttemptButton')),
        );
        await tester.pumpAndSettle();
        expect(find.text('No Homework attempts remain.'), findsOneWidget);
        expect(find.textContaining('Raw server failure'), findsNothing);
        expect(find.text('1'), findsNWidgets(2));
        expect(find.text('Remaining'), findsOneWidget);
        expect(repository.keys, hasLength(1));
      },
    );
  }

  for (final status in StudentHomeworkDetailStatus.values.where(
    (status) => status != StudentHomeworkDetailStatus.data,
  )) {
    testWidgets(
      '${status.name} detail cannot offer new Start even with retained eligibility',
      (tester) async {
        await _pumpStartDetail(
          tester,
          parentState: StudentHomeworkDetailState(
            status: status,
            homework: _detail(inProgress: false),
            failure: status == StudentHomeworkDetailStatus.error
                ? studentLocalFailure(ApiFailureKind.connection).failure
                : null,
          ),
          settle: false,
        );
        expect(
          find.byKey(const Key('studentHomeworkStartAttemptButton')),
          findsNothing,
        );
      },
    );
  }
  testWidgets('null confirmed Homework cannot authorize Start', (tester) async {
    await _pumpStartDetail(
      tester,
      parentState: const StudentHomeworkDetailState(
        status: StudentHomeworkDetailStatus.data,
      ),
      settle: false,
    );
    expect(
      find.byKey(const Key('studentHomeworkStartAttemptButton')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  for (final status in [
    StudentHomeworkStatus.closed,
    StudentHomeworkStatus.archived,
  ]) {
    testWidgets('${status.name} Homework has no new Start action', (
      tester,
    ) async {
      await _pumpStartDetail(
        tester,
        homework: _HomeworkRepository(
          onDetail: (_) async => _detail(inProgress: false, status: status),
        ),
      );
      expect(
        find.byKey(const Key('studentHomeworkStartAttemptButton')),
        findsNothing,
      );
    });
  }
  testWidgets('zero remaining Attempts has no new Start action', (
    tester,
  ) async {
    await _pumpStartDetail(
      tester,
      homework: _HomeworkRepository(
        onDetail: (_) async => _detail(inProgress: false, remaining: 0),
      ),
    );
    expect(
      find.byKey(const Key('studentHomeworkStartAttemptButton')),
      findsNothing,
    );
  });

  testWidgets(
    'confirmed 200 race Resume navigates once and consumes completion',
    (tester) async {
      final (router, container) = await _pumpStartDetail(
        tester,
        starts: _StartRepository(
          onStart: (_, _) async =>
              _startResult(kind: StudentHomeworkAttemptStartResultKind.resumed),
        ),
        homework: _HomeworkRepository(
          onDetail: (_) async => _detail(inProgress: false),
        ),
      );
      await tester.tap(
        find.byKey(const Key('studentHomeworkStartAttemptButton')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attempt destination'), findsOneWidget);
      router.go(
        AppRoutePaths.studentHomeworkDetailLocation(
          studentTopicId,
          _homeworkId,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('studentHomeworkDetailScreen')),
        findsOneWidget,
      );
      expect(
        container
            .read(studentHomeworkAttemptStartControllerProvider(_startTarget))
            .status,
        StudentHomeworkAttemptStartStatus.idle,
      );
    },
  );

  testWidgets(
    'pending Start completion on an offstage detail cannot navigate or remain completed',
    (tester) async {
      final pending = Completer<StudentHomeworkAttemptStartResult>();
      final (router, container) = await _pumpStartDetail(
        tester,
        starts: _StartRepository(onStart: (_, _) => pending.future),
        homework: _HomeworkRepository(
          onDetail: (_) async => _detail(inProgress: false),
        ),
      );
      await tester.tap(
        find.byKey(const Key('studentHomeworkStartAttemptButton')),
      );
      await tester.pump();
      unawaited(router.push<void>('/other'));
      await tester.pumpAndSettle();
      pending.complete(_startResult());
      await tester.pumpAndSettle();
      expect(find.text('Other destination'), findsOneWidget);
      expect(find.text('Attempt destination'), findsNothing);
      expect(
        ModalRoute.of(
          tester.element(find.text('Other destination')),
        )!.isCurrent,
        isTrue,
      );
      expect(
        container
            .read(studentHomeworkAttemptStartControllerProvider(_startTarget))
            .status,
        StudentHomeworkAttemptStartStatus.idle,
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('studentHomeworkStartAttemptButton')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Start from uppercase canonical Homework path navigates to returned Attempt',
    (tester) async {
      final target = StudentHomeworkRouteTarget(
        topicId: 'a0000000-0000-0000-0000-000000000001',
        homeworkId: 'b0000000-0000-0000-0000-000000000001',
      );
      final location = AppRoutePaths.studentHomeworkDetailLocation(
        target.topicId.toUpperCase(),
        target.homeworkId.toUpperCase(),
      );
      final (router, _) = await _pumpStartDetail(
        tester,
        routeTarget: target,
        initialLocation: location,
        homework: _HomeworkRepository(
          onDetail: (_) async => _detail(
            id: target.homeworkId.toUpperCase(),
            topicId: target.topicId.toUpperCase(),
            inProgress: false,
          ),
        ),
        starts: _StartRepository(
          onStart: (_, _) async =>
              _startResult(assessmentId: target.homeworkId.toUpperCase()),
        ),
      );
      await tester.tap(
        find.byKey(const Key('studentHomeworkStartAttemptButton')),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.studentHomeworkAttemptLocation(
          target.topicId,
          target.homeworkId,
          _startedAttemptId,
        ),
      );
    },
  );

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    final label = surface.name;

    testWidgets('$label Homework section announces loading then empty', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final pending = Completer<StudentHomeworkList>();
        await _pumpSection(
          tester,
          surface: surface,
          repository: _HomeworkRepository(onList: (_) => pending.future),
        );
        expect(find.text('Loading Homework'), findsOneWidget);
        expect(find.byKey(const Key('studentHomeworkLoading')), findsOneWidget);
        pending.complete(_page(items: const []));
        await tester.pumpAndSettle();

        expect(find.text('Homework'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Homework')),
          matchesSemantics(
            isHeader: true,
            label: 'Homework',
            textDirection: TextDirection.ltr,
          ),
        );
        expect(
          find.text('No Homework is assigned for this Topic.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('studentHomeworkLoading')), findsNothing);
        _expectReadOnly(tester);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
      '$label summary shows server counts and lifecycle without actions',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _pumpSection(
            tester,
            surface: surface,
            repository: _HomeworkRepository(
              onList: (_) async => _page(
                items: [
                  _summary(),
                  _summary(
                    id: '40000000-0000-0000-0000-000000000002',
                    title: 'Closed Homework',
                    status: StudentHomeworkStatus.closed,
                    myStatus: StudentHomeworkMyStatus.submitted,
                  ),
                  _summary(
                    id: '40000000-0000-0000-0000-000000000003',
                    title: 'Archived Homework',
                    status: StudentHomeworkStatus.archived,
                    myStatus: StudentHomeworkMyStatus.waitingForReview,
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Homework: Active'), findsOneWidget);
          expect(find.text('Homework: Closed'), findsOneWidget);
          expect(find.text('Homework: Archived'), findsOneWidget);
          expect(find.text('Status: In progress'), findsOneWidget);
          expect(find.text('Status: Submitted'), findsOneWidget);
          expect(find.text('Status: Waiting for review'), findsOneWidget);
          expect(find.text('Attempts: 1 of 3 used'), findsNWidgets(3));
          // Remaining is deliberately less than allowed - used: backend owns it.
          expect(find.text('Remaining: 1'), findsNWidgets(3));
          expect(find.text('Deadline: 2020-09-10 18:00'), findsNWidgets(3));
          expect(find.text('Open Homework'), findsNWidgets(3));
          expect(
            find.bySemanticsLabel(RegExp('Open Homework Homework 1')),
            findsOneWidget,
          );
          expect(find.text('Score'), findsNothing);
          _expectReadOnly(tester);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      '$label filter, pagination and refresh use current backend page',
      (tester) async {
        final repository = _HomeworkRepository(
          onList: (query) async => _page(
            page: query.page,
            total: query.status == null ? 41 : 0,
            lastPage: query.status == null ? 3 : 1,
            items: query.status == null
                ? [_summary(title: 'Homework page ${query.page}')]
                : const [],
          ),
        );
        await _pumpSection(tester, surface: surface, repository: repository);
        await tester.pumpAndSettle();
        expect(find.text('Page 1 of 3'), findsOneWidget);
        expect(
          _button(tester, 'studentHomeworkPreviousButton').onPressed,
          isNull,
        );

        await _tap(tester, 'studentHomeworkNextButton');
        expect(find.text('Page 2 of 3'), findsOneWidget);
        expect(find.text('Homework page 2'), findsOneWidget);
        await _tap(tester, 'studentHomeworkPreviousButton');
        expect(find.text('Page 1 of 3'), findsOneWidget);
        await _tap(tester, 'studentHomeworkNextButton');

        await tester.ensureVisible(
          find.byKey(const Key('studentHomeworkStatusFilter')),
        );
        await tester.tap(find.byKey(const Key('studentHomeworkStatusFilter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archived').last);
        await tester.pumpAndSettle();

        expect(repository.queries.last.status, StudentHomeworkStatus.archived);
        expect(repository.queries.last.page, 1);
        expect(find.text('No Homework matches this status.'), findsOneWidget);
        expect(
          find.text('No Homework is assigned for this Topic.'),
          findsNothing,
        );
        await _tap(tester, 'studentHomeworkRefreshButton');
        expect(repository.queries.last.status, StudentHomeworkStatus.archived);
        expect(repository.queries.last.page, 1);
        expect(
          repository.queries.every((query) => query.topicId == studentTopicId),
          isTrue,
        );
        expect(
          repository.queries.every((query) => query.perPage == 20),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$label refresh retains rows, shows stale failure, and retries',
      (tester) async {
        final refresh = Completer<StudentHomeworkList>();
        var calls = 0;
        final repository = _HomeworkRepository(
          onList: (_) {
            calls++;
            return calls == 2
                ? refresh.future
                : Future.value(_page(items: [_summary()]));
          },
        );
        await _pumpSection(tester, surface: surface, repository: repository);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('studentHomeworkRefreshButton')));
        await tester.pump();
        expect(
          find.byKey(const Key('studentHomeworkRefreshing')),
          findsOneWidget,
        );
        expect(find.text('Homework 1'), findsOneWidget);
        expect(
          _button(tester, 'studentHomeworkOpen$_homeworkId').onPressed,
          isNull,
        );
        refresh.completeError(studentLocalFailure(ApiFailureKind.connection));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('studentHomeworkStale')), findsOneWidget);
        expect(find.text('Homework 1'), findsOneWidget);
        expect(find.text('Unable to load Homework'), findsOneWidget);
        expect(find.textContaining('Raw local failure'), findsNothing);
        expect(
          _button(tester, 'studentHomeworkOpen$_homeworkId').onPressed,
          isNull,
        );
        await _tap(tester, 'studentHomeworkRetryButton');
        expect(find.byKey(const Key('studentHomeworkStale')), findsNothing);
        expect(
          _button(tester, 'studentHomeworkOpen$_homeworkId').onPressed,
          isNotNull,
        );
        expect(calls, 3);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$label initial list failure has safe retry', (tester) async {
      var calls = 0;
      await _pumpSection(
        tester,
        surface: surface,
        repository: _HomeworkRepository(
          onList: (_) async {
            if (++calls == 1) {
              throw studentLocalFailure(ApiFailureKind.invalidResponse);
            }
            return _page(items: [_summary()]);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load Homework'), findsOneWidget);
      expect(find.textContaining('Raw local failure'), findsNothing);
      expect(find.text('Homework 1'), findsNothing);
      await _tap(tester, 'studentHomeworkRetryButton');
      expect(find.text('Homework 1'), findsOneWidget);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$label Homework detail loading, metadata and nine safe projections',
      (tester) async {
        final pending = Completer<StudentHomeworkDetail>();
        await _pumpDetail(
          tester,
          surface: surface,
          repository: _HomeworkRepository(onDetail: (_) => pending.future),
        );
        expect(
          find.byKey(const Key('studentHomeworkDetailLoading')),
          findsOneWidget,
        );
        pending.complete(_detail(questions: _allQuestions()));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('studentHomeworkDetailScreen')),
          findsOneWidget,
        );
        expect(find.text('Homework 1'), findsOneWidget);
        expect(find.text('Internet Basics'), findsOneWidget);
        expect(find.text('Homework description'), findsOneWidget);
        expect(find.text('Read every prompt carefully.'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('In progress'), findsOneWidget);
        expect(find.text('2020-09-10 18:00'), findsOneWidget);
        expect(find.text('Total possible points'), findsOneWidget);
        expect(find.text('13.5'), findsOneWidget);
        expect(find.text('Allowed attempts'), findsOneWidget);
        expect(find.text('Used'), findsOneWidget);
        expect(find.text('Remaining'), findsOneWidget);
        expect(find.text('Highest valid completed attempt'), findsOneWidget);
        expect(find.text('Attempt 1 in progress'), findsOneWidget);
        expect(find.text('Started: 2026-09-08 17:00'), findsOneWidget);
        expect(find.byType(StudentQuestionReadView), findsNWidgets(9));
        for (var position = 1; position <= 9; position++) {
          expect(find.text('Prompt $position'), findsOneWidget);
        }
        expect(find.text('Question instructions'), findsOneWidget);
        expect(find.text('• Single option A'), findsOneWidget);
        expect(find.text('• Multiple option A'), findsOneWidget);
        expect(find.text('Select up to 2 when answering.'), findsOneWidget);
        expect(find.text('True / False answer'), findsOneWidget);
        expect(find.text('Short written answer'), findsOneWidget);
        expect(find.text('Written answer'), findsOneWidget);
        expect(find.text('Allowed: PDF, DOCX, PPT, PPTX'), findsOneWidget);
        expect(find.text('Maximum file size: 15 MiB'), findsOneWidget);
        expect(find.text('Left items'), findsOneWidget);
        expect(find.text('Right items'), findsOneWidget);
        expect(find.text('• Display item B'), findsOneWidget);
        expect(find.text('• Display item A'), findsOneWidget);
        expect(find.text('Blank 1: first_blank'), findsOneWidget);
        expect(find.text('Points: 1.5'), findsNWidgets(9));
        _expectReadOnly(tester);
        expect(
          find.byType(DropdownButton<StudentHomeworkStatus?>),
          findsNothing,
        );
        expect(find.text('Correct answer'), findsNothing);
        expect(find.textContaining('accepted_answers'), findsNothing);
        expect(find.textContaining('checking_mode'), findsNothing);
        expect(find.textContaining('configuration'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$label Homework detail refresh retains confirmed content', (
      tester,
    ) async {
      final refresh = Completer<StudentHomeworkDetail>();
      var calls = 0;
      await _pumpDetail(
        tester,
        surface: surface,
        repository: _HomeworkRepository(
          onDetail: (_) =>
              ++calls == 1 ? Future.value(_detail()) : refresh.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('studentHomeworkDetailRefreshButton')),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('studentHomeworkDetailRefreshing')),
        findsOneWidget,
      );
      expect(find.text('Homework 1'), findsOneWidget);
      expect(
        _button(tester, 'studentHomeworkDetailRefreshButton').onPressed,
        isNull,
      );
      refresh.complete(_detail(title: 'Refreshed Homework'));
      await tester.pumpAndSettle();
      expect(find.text('Refreshed Homework'), findsOneWidget);
      expect(
        find.byKey(const Key('studentHomeworkDetailRefreshing')),
        findsNothing,
      );
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label detail notFound and failure are private with retry', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        surface: surface,
        repository: _HomeworkRepository(
          onDetail: (_) async => throw studentServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Homework unavailable'), findsOneWidget);
      expect(
        find.text('This Homework is no longer available.'),
        findsOneWidget,
      );
      expect(find.text('Back to Topic'), findsOneWidget);
      expect(find.textContaining('Raw server failure'), findsNothing);

      var calls = 0;
      await _pumpDetail(
        tester,
        surface: surface,
        repository: _HomeworkRepository(
          onDetail: (_) async {
            if (++calls == 1) {
              throw studentLocalFailure(ApiFailureKind.timeout);
            }
            return _detail(inProgress: false);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load Homework'), findsOneWidget);
      expect(find.textContaining('Raw local failure'), findsNothing);
      await _tap(tester, 'studentHomeworkDetailRetryButton');
      expect(find.text('Homework 1'), findsOneWidget);
      expect(find.text('No Questions are available.'), findsOneWidget);
      expect(find.textContaining('Attempt 1 in progress'), findsNothing);
      expect(find.textContaining('Started:'), findsNothing);
      expect(calls, 2);
      _expectReadOnly(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$label independent Homework failure preserves Topic materials',
      (tester) async {
        final repository = _HomeworkRepository(
          onList: (_) async =>
              throw studentLocalFailure(ApiFailureKind.connection),
        );
        await _pumpHome(
          tester,
          surface: surface,
          repository: repository,
          home: const StudentTopicDetailScreen(topicId: studentTopicId),
        );
        await tester.pumpAndSettle();
        expect(find.text('Internet Basics'), findsOneWidget);
        expect(find.text('Learning Materials'), findsOneWidget);
        expect(find.text('Lesson slides'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Save as…'), findsOneWidget);
        expect(find.text('Homework'), findsOneWidget);
        expect(find.text('Unable to load Homework'), findsOneWidget);
        expect(repository.queries.single.topicId, studentTopicId);
        expect(
          tester.getTopLeft(find.byKey(const Key('studentHomeworkSection'))).dy,
          greaterThan(
            tester
                .getBottomLeft(
                  find.byKey(const Key('studentLearningMaterialsSection')),
                )
                .dy,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'exhausted page correction has page-empty text, not assignment empty',
    (tester) async {
      var calls = 0;
      final repository = _HomeworkRepository(
        onList: (query) async {
          calls++;
          return calls == 1
              ? _page(items: [_summary()], total: 21, lastPage: 2)
              : _page(items: const [], page: query.page, total: 1, lastPage: 1);
        },
      );
      await _pumpSection(tester, repository: repository);
      await tester.pumpAndSettle();
      await _tap(tester, 'studentHomeworkNextButton');
      expect(calls, 3);
      expect(
        find.text('No Homework is available on this page.'),
        findsOneWidget,
      );
      expect(
        find.text('No Homework is assigned for this Topic.'),
        findsNothing,
      );
      expect(find.text('Page 1 of 1'), findsOneWidget);
    },
  );

  testWidgets('mobile Homework section remains scrollable with enlarged text', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      surface: AppDeviceSurface.mobile,
      textScale: 2,
      repository: _HomeworkRepository(
        onList: (_) async => _page(
          items: [
            _summary(
              title:
                  'A long Homework title remains readable with enlarged text',
              myStatus: StudentHomeworkMyStatus.waitingForReview,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('studentHomeworkPagination')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Status: Waiting for review'), findsOneWidget);
    expect(find.text('Remaining: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'matching groups stack on mobile and retain semantic reading order',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final surface in [
          AppDeviceSurface.desktop,
          AppDeviceSurface.mobile,
        ]) {
          await _pumpDetail(
            tester,
            surface: surface,
            textScale: 2,
            timezone: 'Unknown/Timezone',
            repository: _HomeworkRepository(
              onDetail: (_) async => _detail(questions: _allQuestions()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Institution timezone unavailable'), findsOneWidget);
          expect(
            find.text('Started: Institution timezone unavailable'),
            findsOneWidget,
          );
          final matchingId = '$_questionPrefix${7.toString().padLeft(12, '0')}';
          final left = find.byKey(ValueKey('studentMatchingLeft$matchingId'));
          final right = find.byKey(ValueKey('studentMatchingRight$matchingId'));
          await tester.ensureVisible(left);
          await tester.pumpAndSettle();
          final leftOrigin = tester.getTopLeft(left);
          final rightOrigin = tester.getTopLeft(right);
          if (surface == AppDeviceSurface.mobile) {
            expect(rightOrigin.dy, greaterThan(tester.getBottomLeft(left).dy));
            expect(rightOrigin.dx, leftOrigin.dx);
          } else {
            expect(rightOrigin.dy, leftOrigin.dy);
            expect(rightOrigin.dx, greaterThan(leftOrigin.dx));
          }
          expect(
            tester.getSemantics(find.text('Left items')),
            matchesSemantics(
              isHeader: true,
              label: 'Left items',
              textDirection: TextDirection.ltr,
            ),
          );
          await tester.ensureVisible(right);
          await tester.pumpAndSettle();
          expect(
            tester.getSemantics(find.text('Right items')),
            matchesSemantics(
              isHeader: true,
              label: 'Right items',
              textDirection: TextDirection.ltr,
            ),
          );
          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required _HomeworkRepository repository,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  double textScale = 1,
}) => _pumpHome(
  tester,
  surface: surface,
  repository: repository,
  textScale: textScale,
  home: const Scaffold(
    body: SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: StudentHomeworkSection(topicId: studentTopicId),
    ),
  ),
);

Future<void> _pumpDetail(
  WidgetTester tester, {
  required _HomeworkRepository repository,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  double textScale = 1,
  String timezone = 'Asia/Tashkent',
}) => _pumpHome(
  tester,
  surface: surface,
  repository: repository,
  textScale: textScale,
  timezone: timezone,
  home: StudentHomeworkDetailScreen(
    target: StudentHomeworkRouteTarget(
      topicId: studentTopicId,
      homeworkId: _homeworkId,
    ),
  ),
);

Future<void> _pumpHome(
  WidgetTester tester, {
  required _HomeworkRepository repository,
  required Widget home,
  required AppDeviceSurface surface,
  double textScale = 1,
  String timezone = 'Asia/Tashkent',
}) async {
  await tester.binding.setSurfaceSize(
    surface == AppDeviceSurface.mobile
        ? const Size(360, 760)
        : const Size(1100, 900),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeStudentAuthSessionController.authenticated(
            studentUser('student-a', institutionTimezone: timezone),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentHomeworkRepositoryProvider.overrideWithValue(repository),
        studentTopicRepositoryProvider.overrideWithValue(
          FakeStudentTopicRepository(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final control = find.byKey(Key(key));
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

ButtonStyleButton _button(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(Key(key)));

void _expectReadOnly(WidgetTester tester) {
  for (final label in [
    'Start',
    'Resume',
    'Submit',
    'Save answer',
    'Upload file',
  ]) {
    expect(find.text(label), findsNothing);
  }
  expect(find.byType(TextField), findsNothing);
  expect(find.byType(TextFormField), findsNothing);
  expect(find.byType(Checkbox), findsNothing);
  expect(find.byType(Radio<bool>), findsNothing);
  expect(
    tester
        .widgetList<EditableText>(find.byType(EditableText))
        .every((widget) => widget.readOnly),
    isTrue,
  );
}

StudentHomeworkAttemptSummary _attempts({
  bool detail = false,
  bool inProgress = true,
  int remaining = 1,
}) => StudentHomeworkAttemptSummary(
  allowed: 3,
  used: 1,
  remaining: remaining,
  officialScorePolicy: 'highest_valid_completed',
  inProgressAttempt: detail && inProgress
      ? StudentInProgressHomeworkAttempt(
          id: '60000000-0000-0000-0000-000000000001',
          attemptNumber: 1,
          startedAt: DateTime.utc(2026, 9, 8, 12),
        )
      : null,
);

StudentHomeworkSummary _summary({
  String id = _homeworkId,
  String title = 'Homework 1',
  StudentHomeworkStatus status = StudentHomeworkStatus.active,
  StudentHomeworkMyStatus myStatus = StudentHomeworkMyStatus.inProgress,
}) => StudentHomeworkSummary(
  id: id,
  topic: const StudentHomeworkTopicSummary(
    id: studentTopicId,
    title: 'Internet Basics',
  ),
  title: title,
  status: status,
  deadlineAt: DateTime.utc(2020, 9, 10, 13),
  attempts: _attempts(),
  myStatus: myStatus,
  scoreVisible: false,
);

StudentHomeworkList _page({
  required List<StudentHomeworkSummary> items,
  int page = 1,
  int? total,
  int lastPage = 1,
}) => StudentHomeworkList(
  items: items,
  page: page,
  perPage: 20,
  total: total ?? items.length,
  lastPage: lastPage,
);

StudentHomeworkDetail _detail({
  String id = _homeworkId,
  String topicId = studentTopicId,
  String title = 'Homework 1',
  List<StudentQuestion> questions = const [],
  bool inProgress = true,
  StudentHomeworkStatus status = StudentHomeworkStatus.active,
  int remaining = 1,
}) => StudentHomeworkDetail(
  id: id,
  topic: StudentHomeworkTopicSummary(id: topicId, title: 'Internet Basics'),
  title: title,
  description: 'Homework description',
  studentInstructions: 'Read every prompt carefully.',
  status: status,
  deadlineAt: DateTime.utc(2020, 9, 10, 13),
  totalPossiblePoints: 13.5,
  attempts: _attempts(
    detail: true,
    inProgress: inProgress,
    remaining: remaining,
  ),
  myStatus: inProgress
      ? StudentHomeworkMyStatus.inProgress
      : StudentHomeworkMyStatus.submitted,
  scoreVisible: false,
  questions: questions,
);

List<StudentQuestion> _allQuestions() {
  final answerStructures = <StudentAnswerUi>[
    StudentChoiceAnswerUi(
      options: const [
        StudentChoiceOption(
          id: '70000000-0000-0000-0000-000000000001',
          text: 'Single option A',
        ),
        StudentChoiceOption(
          id: '70000000-0000-0000-0000-000000000002',
          text: 'Single option B',
        ),
      ],
    ),
    StudentChoiceAnswerUi(
      options: const [
        StudentChoiceOption(
          id: '70000000-0000-0000-0000-000000000003',
          text: 'Multiple option A',
        ),
        StudentChoiceOption(
          id: '70000000-0000-0000-0000-000000000004',
          text: 'Multiple option B',
        ),
      ],
      maxSelections: 2,
    ),
    const StudentEmptyAnswerUi(),
    const StudentEmptyAnswerUi(),
    const StudentEmptyAnswerUi(),
    StudentFileAnswerUi(
      allowedExtensions: const ['pdf', 'docx', 'ppt', 'pptx'],
      maxSizeBytes: 15728640,
    ),
    StudentMatchingAnswerUi(
      leftItems: const [
        StudentMatchingItem(
          id: '70000000-0000-0000-0000-000000000005',
          text: 'A long left item that wraps clearly on mobile',
        ),
        StudentMatchingItem(
          id: '70000000-0000-0000-0000-000000000006',
          text: 'Another independent left item',
        ),
      ],
      rightItems: const [
        StudentMatchingItem(
          id: '70000000-0000-0000-0000-000000000007',
          text: 'A separate right item without pairing lines',
        ),
      ],
    ),
    StudentOrderingAnswerUi(
      items: const [
        StudentOrderingItem(
          id: '70000000-0000-0000-0000-000000000008',
          text: 'Display item B',
        ),
        StudentOrderingItem(
          id: '70000000-0000-0000-0000-000000000009',
          text: 'Display item A',
        ),
      ],
    ),
    StudentFillBlankAnswerUi(
      blanks: const [
        StudentFillBlank(
          id: '70000000-0000-0000-0000-000000000010',
          key: 'first_blank',
          position: 1,
        ),
      ],
    ),
  ];
  return [
    for (var index = 0; index < StudentQuestionType.values.length; index++)
      StudentQuestion(
        id: '$_questionPrefix${(index + 1).toString().padLeft(12, '0')}',
        type: StudentQuestionType.values[index],
        prompt: 'Prompt ${index + 1}',
        instructions: index == 0 ? 'Question instructions' : null,
        points: 1.5,
        position: index + 1,
        answerUi: answerStructures[index],
      ),
  ];
}

class _HomeworkRepository implements StudentHomeworkRepository {
  _HomeworkRepository({this.onList, this.onDetail});

  final Future<StudentHomeworkList> Function(StudentHomeworkListQuery)? onList;
  final Future<StudentHomeworkDetail> Function(String)? onDetail;
  final queries = <StudentHomeworkListQuery>[];

  @override
  Future<StudentHomeworkList> fetchHomework(StudentHomeworkListQuery query) {
    queries.add(query);
    return onList?.call(query) ??
        Future.value(_page(items: [_summary()], page: query.page));
  }

  @override
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) =>
      onDetail?.call(homeworkId) ?? Future.value(_detail());
}

const _startedAttemptId = '60000000-0000-0000-0000-000000000001';
final _startTarget = StudentHomeworkRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
);

Future<(GoRouter, ProviderContainer)> _pumpStartDetail(
  WidgetTester tester, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  _StartRepository? starts,
  _HomeworkRepository? homework,
  StudentHomeworkDetailState? parentState,
  bool settle = true,
  StudentHomeworkRouteTarget? routeTarget,
  String? initialLocation,
}) async {
  final target = routeTarget ?? _startTarget;
  final router = GoRouter(
    initialLocation:
        initialLocation ??
        AppRoutePaths.studentHomeworkDetailLocation(
          target.topicId,
          target.homeworkId,
        ),
    routes: [
      GoRoute(
        path: AppRoutePaths.studentHomeworkDetail,
        builder: (_, _) => StudentHomeworkDetailScreen(target: target),
      ),
      GoRoute(
        path: AppRoutePaths.studentHomeworkAttempt,
        builder: (_, _) => const Scaffold(body: Text('Attempt destination')),
      ),
      GoRoute(
        path: '/other',
        builder: (_, _) => const Scaffold(body: Text('Other destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(
    surface == AppDeviceSurface.mobile
        ? const Size(390, 900)
        : const Size(1100, 900),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appDeviceSurfaceProvider.overrideWithValue(surface),
        authSessionControllerProvider.overrideWith(
          () => FakeStudentAuthSessionController.authenticated(
            studentUser('student-a'),
          ),
        ),
        studentHomeworkRepositoryProvider.overrideWithValue(
          homework ?? _HomeworkRepository(),
        ),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(
          starts ?? _StartRepository(),
        ),
        if (parentState != null)
          studentHomeworkDetailControllerProvider(
            _startTarget,
          ).overrideWith(() => _FixedHomeworkController(parentState)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
  return (
    router,
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp))),
  );
}

class _FixedHomeworkController extends StudentHomeworkDetailController {
  _FixedHomeworkController(this.initial) : super(_startTarget);
  final StudentHomeworkDetailState initial;
  @override
  StudentHomeworkDetailState build() => initial;
}

class _StartRepository implements StudentHomeworkAttemptRepository {
  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) => throw StateError('This regression must not save answers.');

  _StartRepository({this.onStart});
  final Future<StudentHomeworkAttemptStartResult> Function(String, String)?
  onStart;
  final keys = <String>[];
  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) {
    keys.add(idempotencyKey);
    return onStart?.call(homeworkId, idempotencyKey) ??
        Future.value(_startResult());
  }

  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) =>
      throw StateError('Homework detail does not load the Attempt.');
}

StudentHomeworkAttemptStartResult _startResult({
  String assessmentId = _homeworkId,
  StudentHomeworkAttemptStartResultKind kind =
      StudentHomeworkAttemptStartResultKind.created,
}) => StudentHomeworkAttemptStartResult(
  resultKind: kind,
  attempt: StudentHomeworkAttempt(
    id: _startedAttemptId,
    assessmentId: assessmentId,
    attemptNumber: 2,
    status: StudentHomeworkAttemptStatus.inProgress,
    startedAt: DateTime.utc(2026, 9, 8, 12),
    deadlineAt: null,
    submittedAt: null,
    finalizedAt: null,
    finalizationReason: null,
    questions: const [],
    answers: const [],
  ),
);

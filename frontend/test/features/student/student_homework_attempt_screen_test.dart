import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';
import 'package:testlabuz_client/features/student/presentation/student_attempt_answer_read_view.dart';
import 'package:testlabuz_client/features/student/presentation/student_file_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_attempt_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_read_view.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_answer_editor.dart';

import 'student_test_support.dart';

const _homeworkId = '4abcdef0-0000-0000-0000-000000000001';
const _attemptId = '6abcdef0-0000-0000-0000-000000000001';
final _target = StudentHomeworkAttemptRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
  attemptId: _attemptId,
);
final _parentTarget = StudentHomeworkRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
);

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} waits for both hierarchy reads then shows shell',
      (tester) async {
        final parent = Completer<StudentHomeworkDetail>();
        final attempt = Completer<StudentHomeworkAttempt>();
        await _pump(
          tester,
          surface: surface,
          homeworkRepository: _HomeworkRepository(
            onDetail: (_) => parent.future,
          ),
          attemptRepository: _AttemptRepository(onFetch: (_) => attempt.future),
        );
        expect(
          find.byKey(const Key('studentHomeworkAttemptLoading')),
          findsOneWidget,
        );
        attempt.complete(_attempt());
        await tester.pump();
        expect(find.text('Attempt 2'), findsNothing);
        parent.complete(_homework());
        await tester.pumpAndSettle();
        expect(find.text('Homework shell'), findsOneWidget);
        expect(find.text('Attempt 2'), findsOneWidget);
        expect(find.text('In progress'), findsOneWidget);
        expect(find.text('Started'), findsOneWidget);
        expect(find.text('2026-09-08 17:00'), findsOneWidget);
        expect(find.text('Deadline'), findsOneWidget);
        expect(find.text('2026-09-10 18:00'), findsOneWidget);
        expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(9));
        expect(find.byType(StudentQuestionAnswerCard), findsNWidgets(10));
        expect(find.byType(StudentQuestionReadView), findsNothing);
        expect(find.byType(StudentFileAnswerEditor), findsOneWidget);
        expect(find.text('Current file:'), findsOneWidget);
        expect(find.text('Choose replacement'), findsOneWidget);
        _expectSavedFileActions(tester);
        expect(find.text('Save answer'), findsNWidgets(9));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${surface.name} renders every own saved answer with mixed-case UUIDs without editing',
      (tester) async {
        await _pump(
          tester,
          surface: surface,
          attemptRepository: _AttemptRepository(
            onFetch: (_) async =>
                _attempt(status: StudentHomeworkAttemptStatus.submitted),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Single selected option'), findsOneWidget);
        expect(find.text('Multiple selected A'), findsOneWidget);
        expect(find.text('Multiple selected B'), findsOneWidget);
        expect(find.text('False'), findsOneWidget);
        expect(find.text('  Exact short answer  '), findsOneWidget);
        expect(find.text(_longAnswer), findsOneWidget);
        expect(
          find.text('Left selected text → Right selected text'),
          findsOneWidget,
        );
        expect(find.text('1. Ordered first'), findsOneWidget);
        expect(find.text('2. Ordered second'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('1. Ordered first')).dy,
          lessThan(tester.getTopLeft(find.text('2. Ordered second')).dy),
        );
        expect(find.text('first_blank →   Exact blank text  '), findsOneWidget);
        expect(
          find.text('my-own-long-homework-submission.pdf'),
          findsOneWidget,
        );
        expect(find.text('Current file:'), findsOneWidget);
        expect(find.text('PDF · 1.0 KB'), findsOneWidget);
        expect(find.byType(StudentFileAnswerEditor), findsOneWidget);
        expect(find.byType(StudentAttemptAnswerReadView), findsNWidgets(9));
        expect(find.byType(StudentQuestionReadView), findsNWidgets(9));
        _expectReadOnly(tester);
        await tester.ensureVisible(find.text('Not answered'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    for (final status in [
      StudentHomeworkAttemptStatus.submitted,
      StudentHomeworkAttemptStatus.waitingForReview,
      StudentHomeworkAttemptStatus.checked,
    ]) {
      testWidgets(
        '${surface.name} ${status.name} remains readable with terminal timing',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await _pump(
              tester,
              surface: surface,
              attemptRepository: _AttemptRepository(
                onFetch: (_) async => _attempt(status: status),
              ),
            );
            await tester.pumpAndSettle();
            final label = switch (status) {
              StudentHomeworkAttemptStatus.submitted => 'Submitted',
              StudentHomeworkAttemptStatus.waitingForReview =>
                'Waiting for review',
              _ => 'Checked',
            };
            expect(
              tester
                  .widget<Text>(
                    find.byKey(const Key('studentHomeworkAttemptStatus')),
                  )
                  .data,
              label,
            );
            expect(find.text('Finalized at'), findsOneWidget);
            expect(find.text('Finalization reason'), findsOneWidget);
            expect(find.text('Submitted by you'), findsOneWidget);
            expect(
              tester
                  .getSemantics(
                    find.byKey(const Key('studentHomeworkAttemptStatus')),
                  )
                  .label,
              label,
            );
            _expectReadOnly(tester);
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets(
      '${surface.name} distinguishes parent and Attempt unavailable',
      (tester) async {
        await _pump(
          tester,
          surface: surface,
          homeworkRepository: _HomeworkRepository(
            onDetail: (_) async => throw studentServerFailure(
              ApiErrorCodes.resourceNotFound,
              statusCode: 404,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Homework unavailable'), findsOneWidget);
        expect(find.text('Back to Topic'), findsOneWidget);
        expect(find.text('Attempt 2'), findsNothing);
        await _pump(
          tester,
          surface: surface,
          attemptRepository: _AttemptRepository(
            onFetch: (_) async => throw studentServerFailure(
              ApiErrorCodes.resourceNotFound,
              statusCode: 404,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Attempt unavailable'), findsOneWidget);
        expect(find.text('Back to Homework'), findsOneWidget);
        expect(find.text('Attempt 2'), findsNothing);
        expect(find.textContaining('Raw server failure'), findsNothing);
      },
    );

    testWidgets(
      '${surface.name} Attempt failure is private and retry reloads',
      (tester) async {
        var fetches = 0;
        await _pump(
          tester,
          surface: surface,
          attemptRepository: _AttemptRepository(
            onFetch: (_) async {
              if (++fetches == 1) {
                throw studentLocalFailure(ApiFailureKind.timeout);
              }
              return _attempt();
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Unable to load Attempt'), findsOneWidget);
        expect(find.text('The Attempt request timed out.'), findsOneWidget);
        expect(find.textContaining('Raw local failure'), findsNothing);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(fetches, 2);
        expect(find.text('Attempt 2'), findsOneWidget);
      },
    );

    testWidgets(
      '${surface.name} refresh hides shell until both reads are current',
      (tester) async {
        final parentRefresh = Completer<StudentHomeworkDetail>();
        final attemptRefresh = Completer<StudentHomeworkAttempt>();
        var parents = 0;
        var attempts = 0;
        await _pump(
          tester,
          surface: surface,
          homeworkRepository: _HomeworkRepository(
            onDetail: (_) => ++parents == 1
                ? Future.value(_homework())
                : parentRefresh.future,
          ),
          attemptRepository: _AttemptRepository(
            onFetch: (_) => ++attempts == 1
                ? Future.value(_attempt())
                : attemptRefresh.future,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Refresh Attempt'));
        await tester.pump();
        expect(
          find.byKey(const Key('studentHomeworkAttemptRefreshing')),
          findsOneWidget,
        );
        expect(find.text('Attempt 2'), findsNothing);
        attemptRefresh.complete(_attempt());
        await tester.pump();
        expect(find.text('Attempt 2'), findsNothing);
        parentRefresh.complete(_homework());
        await tester.pumpAndSettle();
        expect(find.text('Attempt 2'), findsOneWidget);
      },
    );
  }

  for (final status in StudentHomeworkDetailStatus.values.where(
    (status) => status != StudentHomeworkDetailStatus.data,
  )) {
    testWidgets(
      'retained ${status.name} parent never establishes execution hierarchy',
      (tester) async {
        await _pump(
          tester,
          parentState: StudentHomeworkDetailState(
            status: status,
            homework: _homework(),
            failure: status == StudentHomeworkDetailStatus.error
                ? studentLocalFailure(ApiFailureKind.connection).failure
                : null,
          ),
        );
        await tester.pump();
        expect(find.text('Attempt 2'), findsNothing);
        expect(find.byType(StudentQuestionReadView), findsNothing);
      },
    );
  }

  testWidgets(
    'narrow shell with enlarged text wraps long answers and metadata',
    (tester) async {
      await _pump(
        tester,
        surface: AppDeviceSurface.mobile,
        textScale: 2,
        width: 320,
        attemptRepository: _AttemptRepository(
          onFetch: (_) async =>
              _attempt(status: StudentHomeworkAttemptStatus.submitted),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.byKey(const Key('studentHomeworkAttemptScroll'));
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.vertical,
      );
      await tester.ensureVisible(find.text('Not answered'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final view in tester.elementList(
        find.byType(StudentAttemptAnswerReadView),
      )) {
        final box = view.renderObject! as RenderBox;
        expect(box.size.width, lessThanOrEqualTo(320));
      }
    },
  );

  testWidgets('back action returns to exact parent Homework', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutePaths.studentHomeworkAttemptLocation(
        studentTopicId,
        _homeworkId,
        _attemptId,
      ),
      routes: [
        GoRoute(
          path: AppRoutePaths.studentHomeworkAttempt,
          builder: (_, _) => StudentHomeworkAttemptScreen(target: _target),
        ),
        GoRoute(
          path: AppRoutePaths.studentHomeworkDetail,
          builder: (_, _) =>
              const Scaffold(body: Text('Parent Homework destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pump(tester, router: router);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to Homework'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutePaths.studentHomeworkDetailLocation(studentTopicId, _homeworkId),
    );
    expect(find.text('Parent Homework destination'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  _HomeworkRepository? homeworkRepository,
  _AttemptRepository? attemptRepository,
  StudentHomeworkDetailState? parentState,
  double textScale = 1,
  double? width,
  GoRouter? router,
}) async {
  await tester.binding.setSurfaceSize(
    Size(width ?? (surface == AppDeviceSurface.mobile ? 390 : 1100), 900),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Widget scale(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeStudentAuthSessionController.authenticated(
            studentUser('student-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentHomeworkRepositoryProvider.overrideWithValue(
          homeworkRepository ?? _HomeworkRepository(),
        ),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(
          attemptRepository ?? _AttemptRepository(),
        ),
        if (parentState != null)
          studentHomeworkDetailControllerProvider(
            _parentTarget,
          ).overrideWith(() => _ParentStateController(parentState)),
      ],
      child: router == null
          ? MaterialApp(
              builder: scale,
              home: StudentHomeworkAttemptScreen(target: _target),
            )
          : MaterialApp.router(builder: scale, routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void _expectReadOnly(WidgetTester tester) {
  for (final label in [
    'Save',
    'Save answer',
    'Submit',
    'Score',
    'Correct answer',
    'Download',
    'Upload file',
    'Choose file',
    'Choose replacement',
    'Upload answer',
    'Upload replacement',
    'Retry upload',
    'Discard selected file',
    'Delete answer',
  ]) {
    expect(find.text(label), findsNothing);
  }
  expect(find.byType(TextField), findsNothing);
  expect(find.byType(TextFormField), findsNothing);
  expect(find.byType(Checkbox), findsNothing);
  expect(
    tester
        .widgetList<EditableText>(find.byType(EditableText))
        .every((widget) => widget.readOnly),
    isTrue,
  );
  _expectSavedFileActions(tester);
}

void _expectSavedFileActions(WidgetTester tester) {
  for (final label in ['Open', 'Save As…']) {
    final button = find.widgetWithText(OutlinedButton, label);
    expect(button, findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
  }
}

const _longAnswer =
    '  My exact written answer\ncontinues on a new line with enough words to wrap clearly on a narrow mobile screen.  ';
String _id(int suffix) =>
    '7abcdef0-0000-0000-0000-${suffix.toString().padLeft(12, '0')}';

List<StudentQuestion> _questions() {
  final structures = <StudentAnswerUi>[
    StudentChoiceAnswerUi(
      options: [
        StudentChoiceOption(id: _id(1), text: 'Single selected option'),
      ],
    ),
    StudentChoiceAnswerUi(
      options: [
        StudentChoiceOption(id: _id(2), text: 'Multiple selected A'),
        StudentChoiceOption(id: _id(3), text: 'Multiple selected B'),
      ],
      maxSelections: 2,
    ),
    const StudentEmptyAnswerUi(),
    const StudentEmptyAnswerUi(),
    const StudentEmptyAnswerUi(),
    StudentFileAnswerUi(allowedExtensions: const ['pdf'], maxSizeBytes: 2048),
    StudentMatchingAnswerUi(
      leftItems: [StudentMatchingItem(id: _id(4), text: 'Left selected text')],
      rightItems: [
        StudentMatchingItem(id: _id(5), text: 'Right selected text'),
      ],
    ),
    StudentOrderingAnswerUi(
      items: [
        StudentOrderingItem(id: _id(6), text: 'Ordered second'),
        StudentOrderingItem(id: _id(7), text: 'Ordered first'),
      ],
    ),
    StudentFillBlankAnswerUi(
      blanks: [StudentFillBlank(id: _id(8), key: 'first_blank', position: 1)],
    ),
    const StudentEmptyAnswerUi(),
  ];
  return [
    for (var index = 0; index < structures.length; index++)
      StudentQuestion(
        id: _id(100 + index).toUpperCase(),
        type: index < 9
            ? StudentQuestionType.values[index]
            : StudentQuestionType.shortWritten,
        prompt: 'Question prompt ${index + 1}',
        instructions: null,
        points: 1,
        position: index + 1,
        answerUi: structures[index],
      ),
  ];
}

StudentHomeworkAttempt _attempt({
  StudentHomeworkAttemptStatus status = StudentHomeworkAttemptStatus.inProgress,
}) {
  final questions = _questions();
  final values = <StudentAttemptAnswerValue>[
    StudentChoiceAnswerValue(selectedOptionIds: [_id(1).toUpperCase()]),
    StudentChoiceAnswerValue(
      selectedOptionIds: [_id(2).toUpperCase(), _id(3).toUpperCase()],
    ),
    const StudentBooleanAnswerValue(value: false),
    const StudentTextAnswerValue(text: '  Exact short answer  '),
    const StudentTextAnswerValue(text: _longAnswer),
    StudentFileAnswerValue(
      file: StudentSubmissionFile(
        id: _id(9),
        originalName: 'my-own-long-homework-submission.pdf',
        extension: 'pdf',
        sizeBytes: 1024,
      ),
    ),
    StudentMatchingAnswerValue(
      pairs: [
        StudentMatchingAnswerPair(
          leftItemId: _id(4).toUpperCase(),
          rightItemId: _id(5).toUpperCase(),
        ),
      ],
    ),
    StudentOrderingAnswerValue(
      items: [
        StudentOrderingAnswerItem(itemId: _id(6).toUpperCase(), position: 2),
        StudentOrderingAnswerItem(itemId: _id(7).toUpperCase(), position: 1),
      ],
    ),
    StudentFillBlankAnswerValue(
      values: [
        StudentFillBlankAnswerEntry(
          blankId: _id(8).toUpperCase(),
          text: '  Exact blank text  ',
        ),
      ],
    ),
  ];
  final terminal = status != StudentHomeworkAttemptStatus.inProgress;
  return StudentHomeworkAttempt(
    id: _attemptId.toUpperCase(),
    assessmentId: _homeworkId.toUpperCase(),
    attemptNumber: 2,
    status: status,
    startedAt: DateTime.utc(2026, 9, 8, 12),
    deadlineAt: DateTime.utc(2026, 9, 10, 13),
    submittedAt: terminal ? DateTime.utc(2026, 9, 8, 13) : null,
    finalizedAt: terminal ? DateTime.utc(2026, 9, 8, 13) : null,
    finalizationReason: terminal
        ? StudentHomeworkAttemptFinalizationReason.studentSubmit
        : null,
    questions: questions,
    answers: [
      for (var index = 0; index < values.length; index++)
        StudentAttemptAnswerState(
          questionId: questions[index].id.toLowerCase(),
          type: questions[index].type,
          value: values[index],
          updatedAt: DateTime.utc(2026, 9, 8, 12, 30),
        ),
    ],
  );
}

StudentHomeworkDetail _homework() => StudentHomeworkDetail(
  id: _homeworkId.toUpperCase(),
  topic: const StudentHomeworkTopicSummary(id: studentTopicId, title: 'Topic'),
  title: 'Homework shell',
  description: null,
  studentInstructions: 'Read',
  status: StudentHomeworkStatus.active,
  deadlineAt: DateTime.utc(2026, 9, 10, 13),
  totalPossiblePoints: 10,
  attempts: const StudentHomeworkAttemptSummary(
    allowed: 3,
    used: 2,
    remaining: 1,
    officialScorePolicy: 'highest_valid_completed',
  ),
  myStatus: StudentHomeworkMyStatus.inProgress,
  scoreVisible: false,
  questions: _questions(),
);

class _HomeworkRepository implements StudentHomeworkRepository {
  _HomeworkRepository({this.onDetail});
  final Future<StudentHomeworkDetail> Function(String)? onDetail;
  @override
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) =>
      onDetail?.call(homeworkId) ?? Future.value(_homework());
  @override
  Future<StudentHomeworkList> fetchHomework(StudentHomeworkListQuery query) =>
      throw UnimplementedError();
}

class _AttemptRepository implements StudentHomeworkAttemptRepository {
  @override
  Future<StudentHomeworkSubmitResult> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  ) async {
    throw StateError(
      'This regression must not submit a Student Homework Attempt.',
    );
  }

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) =>
      throw StateError('This regression must not upload Student file answers.');

  _AttemptRepository({this.onFetch});
  final Future<StudentHomeworkAttempt> Function(String)? onFetch;
  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) =>
      onFetch?.call(attemptId) ?? Future.value(_attempt());
  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) => throw StateError('Shell regression must never save an answer.');
  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) => throw StateError('Read shell must never start an Attempt.');
}

class _ParentStateController extends StudentHomeworkDetailController {
  _ParentStateController(this.initial) : super(_parentTarget);
  final StudentHomeworkDetailState initial;
  @override
  StudentHomeworkDetailState build() => initial;
}

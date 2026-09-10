import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';
import 'package:testlabuz_client/features/student/presentation/student_file_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_attempt_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_answer_editor.dart';

import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _attemptId = '60000000-0000-0000-0000-000000000001';
const _questionId = '70000000-0000-0000-0000-000000000001';
final _target = StudentHomeworkAttemptRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
  attemptId: _attemptId,
);
final _homeworkTarget = StudentHomeworkRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
);
const _saved = StudentSubmissionFile(
  id: studentFileId,
  originalName: 'saved.pdf',
  extension: 'pdf',
  sizeBytes: 10,
);
final _fileQuestion = StudentQuestion(
  id: _questionId,
  type: StudentQuestionType.fileBased,
  prompt: 'Attach your completed work.',
  instructions: 'Choose one answer file.',
  points: 4,
  position: 1,
  answerUi: StudentFileAnswerUi(
    allowedExtensions: ['pdf', 'docx', 'ppt', 'pptx'],
    maxSizeBytes: 2048,
  ),
);

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} chooses explicitly, uploads progress, then shows confirmed file',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final harness = await _pump(tester, surface: surface);
          expect(find.text('No file uploaded.'), findsOneWidget);
          expect(find.byType(StudentQuestionAnswerCard), findsNWidgets(2));
          expect(find.byType(StudentFileAnswerEditor), findsOneWidget);
          expect(find.text('Maximum upload size: 2.0 KB'), findsOneWidget);
          expect(
            find.bySemanticsLabel(RegExp('Question 1: Choose file')),
            findsWidgets,
          );
          await _tap(tester, 'Choose file');
          expect(find.text('Selected:'), findsOneWidget);
          expect(find.text('answer.pdf'), findsOneWidget);
          expect(find.text('Discard selected file'), findsOneWidget);
          expect(harness.repository.uploads, isEmpty);
          await _tap(tester, 'Upload answer', settle: false);
          final upload = harness.repository.uploads.single;
          upload.onProgress!(5, 10);
          await tester.pump();
          expect(find.text('Uploading file…'), findsOneWidget);
          expect(find.text('50%'), findsOneWidget);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Choose file'),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Upload answer'),
                )
                .onPressed,
            isNull,
          );
          expect(
            find.bySemanticsLabel(RegExp('Question 1: Uploading file')),
            findsWidgets,
          );
          final saved = upload.savedFile;
          harness.repository.current = _attempt(file: saved);
          upload.succeed();
          await tester.pumpAndSettle();
          expect(find.text('Current file:'), findsOneWidget);
          expect(find.text('answer.pdf'), findsOneWidget);
          expect(find.text('Selected:'), findsNothing);
          expect(find.text('File answer uploaded.'), findsOneWidget);
          expect(harness.files.hasPendingSelection, isFalse);
          expect(harness.repository.fetches, 2);
          expect(find.text('Score'), findsNothing);
          expect(find.text('Submit'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'saved file remains separate from replacement and has Open Save As without clear',
    (tester) async {
      final harness = await _pump(tester, file: _saved);
      expect(find.text('Current file:'), findsOneWidget);
      expect(find.text('saved.pdf'), findsOneWidget);
      _expectTransfer(tester, enabled: true);
      await _tap(tester, 'Choose replacement');
      expect(find.text('Selected replacement:'), findsOneWidget);
      expect(find.text('saved.pdf'), findsOneWidget);
      expect(find.text('answer.pdf'), findsOneWidget);
      _expectTransfer(tester, enabled: true);
      await _tap(tester, 'Upload replacement', settle: false);
      _expectTransfer(tester, enabled: false);
      final upload = harness.repository.uploads.single;
      harness.repository.current = _attempt(file: upload.savedFile);
      upload.succeed();
      await tester.pumpAndSettle();
      expect(
        harness.files.questions[_questionId]!.serverFile!.id,
        studentFileId,
      );
      expect(find.text('answer.pdf'), findsOneWidget);
      expect(find.text('Selected replacement:'), findsNothing);
      for (final wording in [
        'Delete answer',
        'Clear file answer',
        'Delete file answer',
        'Remove file',
      ]) {
        expect(find.text(wording), findsNothing);
      }
    },
  );

  testWidgets(
    'picker cancellation restores selection and choose focus, picker failure is safe',
    (tester) async {
      final harness = await _pump(tester);
      await _tap(tester, 'Choose file');
      final selected = harness.files.questions[_questionId]!.selectedFile;
      harness.picker.result = null;
      await _tap(tester, 'Choose file');
      expect(
        harness.files.questions[_questionId]!.selectedFile,
        same(selected),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Choose file'),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      harness.picker.error = StateError('private source path');
      await _tap(tester, 'Choose file');
      expect(find.text('The file picker could not be opened.'), findsOneWidget);
      expect(find.textContaining('private source path'), findsNothing);
      expect(harness.repository.uploads, isEmpty);
    },
  );

  testWidgets(
    'uncertain recovery is GET only and omitted parent question retains recovery UI',
    (tester) async {
      final harness = await _pump(tester, file: _saved);
      await _uncertain(tester, harness);
      final pending = harness.files.questions[_questionId]!.selectedFile;
      const message = 'We could not confirm whether this file was uploaded.';
      expect(find.text(message), findsOneWidget);
      expect(find.text('Retry upload'), findsNothing);
      expect(find.text('Choose replacement'), findsNothing);
      expect(find.text('Discard selected file'), findsNothing);
      harness.parent.publish(
        StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.data,
          attempt: _attempt(omitFile: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.text('Reload attempt'), findsOneWidget);
      final reconciliation = Completer<StudentHomeworkAttempt>();
      harness.repository.nextFetches.add(reconciliation.future);
      await _tap(tester, 'Reload attempt', settle: false);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Reload attempt'),
            )
            .onPressed,
        isNull,
      );
      expect(harness.repository.uploads, hasLength(1));
      reconciliation.complete(
        _attempt(file: harness.repository.uploads.single.savedFile),
      );
      await tester.pumpAndSettle();
      expect(harness.files.hasUncertainUpload, isFalse);
      expect(harness.files.questions[_questionId]!.selectedFile, same(pending));
      expect(find.text('File answer uploaded.'), findsNothing);
      expect(harness.repository.uploads, hasLength(1));
    },
  );

  for (final failure in [
    (
      code: ApiErrorCodes.unsupportedFileType,
      status: 422,
      message:
          'The selected file content is not a supported PDF, DOCX, PPT, or PPTX file.',
    ),
    (
      code: ApiErrorCodes.fileTooLarge,
      status: 422,
      message: 'The selected file exceeds the current upload limit.',
    ),
    (
      code: ApiErrorCodes.fileUploadFailed,
      status: 500,
      message: 'The file could not be stored. Try again.',
    ),
  ]) {
    testWidgets(
      '${failure.code} safe feedback and only storage failure offers explicit retry',
      (tester) async {
        final harness = await _pump(tester, file: _saved);
        await _tap(tester, 'Choose replacement');
        await _tap(tester, 'Upload replacement', settle: false);
        harness.repository.uploads.single.completer.completeError(
          studentServerFailure(failure.code, statusCode: failure.status),
        );
        await tester.pumpAndSettle();
        expect(find.text(failure.message), findsOneWidget);
        expect(find.text('saved.pdf'), findsOneWidget);
        expect(find.text('Reload attempt'), findsNothing);
        if (failure.code == ApiErrorCodes.fileUploadFailed) {
          expect(find.text('Retry upload'), findsOneWidget);
          await tester.ensureVisible(find.text('Retry upload'));
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          expect(FocusManager.instance.primaryFocus, isNotNull);
          await _tap(tester, 'Retry upload', settle: false);
          expect(harness.repository.uploads, hasLength(2));
          harness.repository.uploads.last.completer.completeError(
            studentServerFailure(failure.code, statusCode: failure.status),
          );
          await tester.pumpAndSettle();
        } else {
          expect(find.text('Retry upload'), findsNothing);
          expect(harness.files.hasPendingSelection, isFalse);
        }
      },
    );
  }

  testWidgets(
    'local source failure clears selected file and retains current file with choose again message',
    (tester) async {
      final harness = await _pump(tester, file: _saved);
      await _tap(tester, 'Choose replacement');
      await _tap(tester, 'Upload replacement', settle: false);
      harness.repository.uploads.single.completer.completeError(
        const StudentSubmissionSourceUnavailable(),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The selected file is no longer available. Choose the file again.',
        ),
        findsOneWidget,
      );
      expect(find.text('saved.pdf'), findsOneWidget);
      expect(find.text('Selected replacement:'), findsNothing);
      expect(find.text('Choose replacement'), findsOneWidget);
      expect(find.text('Reload attempt'), findsNothing);
      expect(harness.repository.fetches, 2);
    },
  );

  testWidgets(
    'file-owned terminal reconciliation wins over older GET and retained in-progress failures',
    (tester) async {
      final harness = await _pump(tester, file: _saved);
      await _uncertain(tester, harness);
      final owned = Completer<StudentHomeworkAttempt>();
      harness.repository.nextFetches.add(owned.future);
      await _tap(tester, 'Reload attempt', settle: false);
      final olderParent = Completer<StudentHomeworkAttempt>();
      harness.repository.nextFetches.add(olderParent.future);
      harness.parent.refresh();
      await tester.pump();
      final terminal = _attempt(file: _saved, terminal: true);
      owned.complete(terminal);
      await tester.pumpAndSettle();
      expect(find.text('Submitted'), findsWidgets);
      expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
      expect(find.text('saved.pdf'), findsOneWidget);
      expect(harness.files.hasPendingSelection, isFalse);
      _expectTransfer(tester, enabled: true);
      olderParent.complete(_attempt());
      await tester.pumpAndSettle();
      expect(
        harness.container
            .read(studentHomeworkAttemptControllerProvider(_target))
            .attempt,
        same(terminal),
      );
      expect(
        harness.container
            .read(studentAttemptAnswerEditorControllerProvider(_target))
            .terminalAttempt,
        same(terminal),
      );
      for (final status in [
        StudentHomeworkAttemptLoadStatus.refreshing,
        StudentHomeworkAttemptLoadStatus.error,
      ]) {
        harness.parent.publish(
          StudentHomeworkAttemptState(
            status: status,
            attempt: _attempt(),
            failure: status == StudentHomeworkAttemptLoadStatus.error
                ? studentLocalFailure(ApiFailureKind.connection).failure
                : null,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('saved.pdf'), findsOneWidget);
        _expectTransfer(tester, enabled: true);
        expect(find.text('Choose replacement'), findsNothing);
        expect(find.text('Reload attempt'), findsNothing);
        expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
      }
      harness.parent.publish(
        const StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.notFound,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attempt unavailable'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
    },
  );

  testWidgets(
    'ordinary retained in-progress error grants no saved-file actions',
    (tester) async {
      final harness = await _pump(tester, file: _saved);
      harness.parent.publish(
        StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.error,
          attempt: _attempt(file: _saved),
          failure: studentLocalFailure(ApiFailureKind.connection).failure,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load Attempt'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
      expect(find.text('Save As…'), findsNothing);
    },
  );

  testWidgets(
    'terminal unanswered file is read-only and late upload cannot restore controls',
    (tester) async {
      final harness = await _pump(tester);
      await _tap(tester, 'Choose file');
      await _tap(tester, 'Upload answer', settle: false);
      harness.parent.publish(
        StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.data,
          attempt: _attempt(terminal: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No file was submitted.'), findsOneWidget);
      expect(find.text('Choose file'), findsNothing);
      expect(find.text('Upload answer'), findsNothing);
      harness.repository.uploads.single.succeed();
      await tester.pumpAndSettle();
      expect(find.text('No file was submitted.'), findsOneWidget);
      expect(find.text('File answer uploaded.'), findsNothing);
    },
  );

  testWidgets(
    'mobile enlarged text wraps long Unicode filenames and actions without overflow',
    (tester) async {
      final harness = await _pump(
        tester,
        surface: AppDeviceSurface.mobile,
        width: 320,
        textScale: 2,
        file: _saved,
      );
      harness.picker.result = _selection(
        '${List.filled(150, '😀').join()}.pdf',
      );
      await _tap(tester, 'Choose replacement');
      for (final text in [
        'Current file:',
        'Selected replacement:',
        'Upload replacement',
        'Discard selected file',
      ]) {
        await tester.ensureVisible(find.text(text));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(
        tester.getSize(find.byType(StudentFileAnswerEditor)).width,
        lessThanOrEqualTo(320),
      );
      expect(
        find.descendant(
          of: find.byType(StudentFileAnswerEditor),
          matching: find.byType(Wrap),
        ),
        findsNWidgets(2),
      );
    },
  );
}

Future<void> _tap(
  WidgetTester tester,
  String text, {
  bool settle = true,
}) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

void _expectTransfer(WidgetTester tester, {required bool enabled}) {
  for (final label in ['Open', 'Save As…']) {
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, label),
    );
    expect(button.onPressed, enabled ? isNotNull : isNull);
  }
}

Future<void> _uncertain(WidgetTester tester, _Harness harness) async {
  await _tap(tester, 'Choose replacement');
  await _tap(tester, 'Upload replacement', settle: false);
  harness.repository.uploads.single.completer.completeError(
    studentLocalFailure(ApiFailureKind.timeout),
  );
  await tester.pumpAndSettle();
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  double? width,
  double textScale = 1,
  StudentSubmissionFile? file,
}) async {
  await tester.binding.setSurfaceSize(
    Size(width ?? (surface == AppDeviceSurface.mobile ? 390 : 1100), 900),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final harness = _Harness(file);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(() => harness.auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(
          harness.repository,
        ),
        studentSubmissionFilePickerProvider.overrideWithValue(harness.picker),
        studentHomeworkAttemptControllerProvider(
          _target,
        ).overrideWith(() => harness.parent),
        studentHomeworkDetailControllerProvider(
          _homeworkTarget,
        ).overrideWith(_HomeworkController.new),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: StudentHomeworkAttemptScreen(target: _target),
      ),
    ),
  );
  await tester.pumpAndSettle();
  harness.container = ProviderScope.containerOf(
    tester.element(find.byType(StudentHomeworkAttemptScreen)),
  );
  return harness;
}

class _Harness {
  _Harness(StudentSubmissionFile? file)
    : repository = _Repository(_attempt(file: file));
  final _Repository repository;
  final picker = _Picker();
  final parent = _AttemptController();
  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  late ProviderContainer container;
  StudentFileAnswerState get files =>
      container.read(studentFileAnswerControllerProvider(_target));
}

class _AttemptController extends StudentHomeworkAttemptController {
  _AttemptController() : super(_target);
  void publish(StudentHomeworkAttemptState value) {
    state = value;
  }
}

class _Picker implements StudentSubmissionFilePicker {
  StudentSubmissionUploadFile? result = _selection('answer.pdf');
  Object? error;
  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) async {
    expect(allowedExtensions, ['pdf', 'docx', 'ppt', 'pptx']);
    if (error != null) throw error!;
    return result;
  }
}

StudentSubmissionUploadFile _selection(String name) =>
    StudentSubmissionUploadFile(
      name: name,
      length: 10,
      openRead: () => Stream.value(List.filled(10, 1)),
    );

class _Repository implements StudentHomeworkAttemptRepository {
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

  _Repository(this.current);
  StudentHomeworkAttempt current;
  final nextFetches = Queue<Future<StudentHomeworkAttempt>>();
  final uploads = <_Upload>[];
  var fetches = 0;
  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) {
    expect(attemptId, _attemptId);
    fetches++;
    return nextFetches.isEmpty
        ? Future.value(current)
        : nextFetches.removeFirst();
  }

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) {
    expect(attemptId, _attemptId);
    expect(question.id, _questionId);
    final upload = _Upload(file, onProgress);
    uploads.add(upload);
    return upload.completer.future;
  }

  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) => throw StateError(
    'These file screen tests must not save non-file answers.',
  );
  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) => throw StateError('These file screen tests must not start Attempts.');
}

class _Upload {
  _Upload(this.file, this.onProgress);
  final StudentSubmissionUploadFile file;
  final StudentSubmissionUploadProgress? onProgress;
  final completer = Completer<StudentAttemptAnswerMutationResult>();
  StudentSubmissionFile get savedFile => StudentSubmissionFile(
    id: studentFileId,
    originalName: file.name,
    extension: file.extension!,
    sizeBytes: file.length,
  );
  void succeed() => completer.complete(
    StudentAttemptAnswerMutationResult(
      questionId: _questionId,
      type: StudentQuestionType.fileBased,
      answer: StudentFileAnswerValue(file: savedFile),
      updatedAt: DateTime.utc(2026, 9, 10, 9),
    ),
  );
}

class _HomeworkController extends StudentHomeworkDetailController {
  _HomeworkController() : super(_homeworkTarget);
  @override
  StudentHomeworkDetailState build() => StudentHomeworkDetailState(
    status: StudentHomeworkDetailStatus.data,
    homework: StudentHomeworkDetail(
      id: _homeworkId,
      topic: const StudentHomeworkTopicSummary(
        id: studentTopicId,
        title: 'Topic',
      ),
      title: 'File homework',
      description: null,
      studentInstructions: 'Read each question before choosing your file.',
      status: StudentHomeworkStatus.active,
      deadlineAt: null,
      totalPossiblePoints: 5,
      attempts: const StudentHomeworkAttemptSummary(
        allowed: 3,
        used: 1,
        remaining: 2,
        officialScorePolicy: 'highest_valid_completed',
      ),
      myStatus: StudentHomeworkMyStatus.inProgress,
      scoreVisible: false,
      questions: _attempt().questions,
    ),
  );
}

StudentHomeworkAttempt _attempt({
  StudentSubmissionFile? file,
  bool terminal = false,
  bool omitFile = false,
}) => StudentHomeworkAttempt(
  id: _attemptId,
  assessmentId: _homeworkId,
  attemptNumber: 1,
  status: terminal
      ? StudentHomeworkAttemptStatus.submitted
      : StudentHomeworkAttemptStatus.inProgress,
  startedAt: DateTime.utc(2026, 9, 10, 8),
  submittedAt: terminal ? DateTime.utc(2026, 9, 10, 9) : null,
  finalizedAt: terminal ? DateTime.utc(2026, 9, 10, 9) : null,
  finalizationReason: terminal
      ? StudentHomeworkAttemptFinalizationReason.studentSubmit
      : null,
  deadlineAt: null,
  questions: [
    if (!omitFile) _fileQuestion,
    const StudentQuestion(
      id: '70000000-0000-0000-0000-000000000002',
      type: StudentQuestionType.shortWritten,
      prompt: 'Explain your answer.',
      instructions: null,
      points: 1,
      position: 2,
      answerUi: StudentEmptyAnswerUi(),
    ),
  ],
  answers: [
    if (file != null)
      StudentAttemptAnswerState(
        questionId: _questionId,
        type: StudentQuestionType.fileBased,
        value: StudentFileAnswerValue(file: file),
        updatedAt: DateTime.utc(2026, 9, 10, 8),
      ),
  ],
);

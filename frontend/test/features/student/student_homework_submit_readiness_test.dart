import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_route_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_submit_readiness.dart';
import 'package:testlabuz_client/features/student/application/student_session_key.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

void main() {
  test('synchronous non-file claim blocks before its entry status changes', () {
    final fixture = _Fixture();
    fixture.answers = StudentAttemptAnswerEditorState(
      isEligible: true,
      isAuthoritative: true,
      sourceAttemptPublication: fixture.publication,
      activeQuestionId: _textId,
      questions: {_textId: _answer()},
    );
    _expectBlocked(
      fixture.evaluate(),
      StudentHomeworkSubmitBlocker.nonFileSaveInProgress,
    );
  });

  test('claimed mutation snapshot blocks before its entry status changes', () {
    final fixture = _Fixture();
    fixture.answers = StudentAttemptAnswerEditorState(
      isEligible: true,
      isAuthoritative: true,
      sourceAttemptPublication: fixture.publication,
      pendingMutationSnapshot: const StudentShortWrittenMutation(
        text: 'Pending',
      ),
      questions: {_textId: _answer()},
    );
    _expectBlocked(
      fixture.evaluate(),
      StudentHomeworkSubmitBlocker.nonFileSaveInProgress,
    );
  });

  test('synchronous file claim blocks before its entry status changes', () {
    final fixture = _Fixture();
    fixture.files = StudentFileAnswerState(
      isAuthoritative: true,
      sourceAttemptPublication: fixture.publication,
      activeQuestionId: _fileId,
      questions: {_fileId: _file()},
    );
    _expectBlocked(
      fixture.evaluate(),
      StudentHomeworkSubmitBlocker.fileUploadInProgress,
    );
  });

  test(
    'clean aligned data is ready with zero answers and no deadline inference',
    () {
      final fixture = _Fixture();
      final readiness = fixture.evaluate();
      expect(readiness.isReady, isTrue);
      expect(readiness.blockers, isEmpty);
      _expectCounts(readiness, questions: 2, answered: 0);
      expect(readiness.readyToken!.sessionKey, fixture.sessionKey);
      expect(readiness.readyToken!.target, fixture.target);
      expect(readiness.readyToken!.publicationToken, same(fixture.publication));
    },
  );

  for (final status in StudentHomeworkAttemptLoadStatus.values) {
    if (status == StudentHomeworkAttemptLoadStatus.data) continue;
    test(
      '$status never grants Submit authority even with retained aligned data',
      () {
        final fixture = _Fixture();
        fixture.parent = _parent(
          fixture.attempt,
          fixture.publication,
          status: status,
        );
        _expectBlocked(
          fixture.evaluate(),
          StudentHomeworkSubmitBlocker.attemptNotEditable,
        );
        if (status == StudentHomeworkAttemptLoadStatus.initial ||
            status == StudentHomeworkAttemptLoadStatus.loading ||
            status == StudentHomeworkAttemptLoadStatus.refreshing) {
          _expectBlocked(
            fixture.evaluate(),
            StudentHomeworkSubmitBlocker.attemptStateLoading,
          );
        }
      },
    );
  }

  for (final status in [
    StudentHomeworkAttemptStatus.submitted,
    StudentHomeworkAttemptStatus.waitingForReview,
    StudentHomeworkAttemptStatus.checked,
  ]) {
    test('${status.apiValue} terminal Attempt cannot submit', () {
      final fixture = _Fixture();
      fixture.parent = _parent(_attempt(status: status), fixture.publication);
      _expectBlocked(
        fixture.evaluate(),
        StudentHomeworkSubmitBlocker.attemptNotEditable,
      );
    });
  }

  final parentFailures = <String, void Function(_Fixture)>{
    'missing Attempt': (fixture) =>
        fixture.parent = StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.data,
          publicationToken: fixture.publication,
        ),
    'wrong Attempt ID': (fixture) =>
        fixture.parent = _parent(_attempt(id: _otherId), fixture.publication),
    'wrong Homework ID': (fixture) => fixture.parent = _parent(
      _attempt(homeworkId: _otherId),
      fixture.publication,
    ),
    'invalid Attempt UUID': (fixture) => fixture.parent = _parent(
      _attempt(id: '../attempts'),
      fixture.publication,
    ),
    'ineligible session': (fixture) => fixture.sessionKey = null,
  };
  for (final failure in parentFailures.entries) {
    test('${failure.key} blocks readiness', () {
      final fixture = _Fixture();
      failure.value(fixture);
      _expectBlocked(
        fixture.evaluate(),
        StudentHomeworkSubmitBlocker.attemptNotEditable,
      );
    });
  }

  final localFailures = <String, void Function(_Fixture)>{
    'null parent publication': (fixture) =>
        fixture.parent = _parent(fixture.attempt, null),
    'FE-003 uninitialized': (fixture) =>
        fixture.answers = StudentAttemptAnswerEditorState(),
    'FE-004 uninitialized': (fixture) =>
        fixture.files = StudentFileAnswerState(),
    'FE-003 null source': (fixture) => fixture.answers = _answers(null),
    'FE-004 null source': (fixture) => fixture.files = _files(null),
    'FE-003 older publication': (fixture) =>
        fixture.answers = _answers(StudentHomeworkAttemptPublicationToken()),
    'FE-004 older publication': (fixture) =>
        fixture.files = _files(StudentHomeworkAttemptPublicationToken()),
    'both local states older than parent': (fixture) => fixture.parent =
        _parent(fixture.attempt, StudentHomeworkAttemptPublicationToken()),
    'FE-003 ineligible': (fixture) =>
        fixture.answers = _answers(fixture.publication, eligible: false),
    'FE-003 non-authoritative': (fixture) =>
        fixture.answers = _answers(fixture.publication, authoritative: false),
    'FE-003 terminal': (fixture) => fixture.answers = _answers(
      fixture.publication,
      terminal: _attempt(status: StudentHomeworkAttemptStatus.submitted),
    ),
    'FE-004 non-authoritative': (fixture) =>
        fixture.files = _files(fixture.publication, authoritative: false),
    'FE-004 terminal': (fixture) =>
        fixture.files = _files(fixture.publication, terminal: true),
    'missing non-file Question': (fixture) =>
        fixture.answers = _answers(fixture.publication, questions: {}),
    'missing file Question': (fixture) =>
        fixture.files = _files(fixture.publication, questions: {}),
    'extra non-file Question': (fixture) => fixture.answers = _answers(
      fixture.publication,
      questions: {
        _textId: _answer(),
        _otherId: _answer(question: _textQuestion(id: _otherId)),
      },
    ),
    'extra file Question': (fixture) => fixture.files = _files(
      fixture.publication,
      questions: {
        _fileId: _file(),
        _otherId: _file(question: _fileQuestion(id: _otherId)),
      },
    ),
    'wrong non-file map key': (fixture) => fixture.answers = _answers(
      fixture.publication,
      questions: {_otherId: _answer()},
    ),
    'wrong file map key': (fixture) => fixture.files = _files(
      fixture.publication,
      questions: {_otherId: _file()},
    ),
    'wrong non-file entry identity': (fixture) => fixture.answers = _answers(
      fixture.publication,
      questions: {_textId: _answer(question: _textQuestion(id: _otherId))},
    ),
    'wrong file entry identity': (fixture) => fixture.files = _files(
      fixture.publication,
      questions: {_fileId: _file(question: _fileQuestion(id: _otherId))},
    ),
    'wrong non-file Question family': (fixture) => fixture.answers = _answers(
      fixture.publication,
      questions: {_textId: _answer(question: _fileQuestion(id: _textId))},
    ),
    'wrong file Question family': (fixture) => fixture.files = _files(
      fixture.publication,
      questions: {_fileId: _file(question: _textQuestion(id: _fileId))},
    ),
    'duplicate non-file local identity under different keys': (fixture) =>
        fixture.answers = _answers(
          fixture.publication,
          questions: {_textId: _answer(), _textId.toUpperCase(): _answer()},
        ),
    'duplicate file local identity under different keys': (fixture) =>
        fixture.files = _files(
          fixture.publication,
          questions: {_fileId: _file(), _fileId.toUpperCase(): _file()},
        ),
    'duplicate parent Question IDs': (fixture) => fixture.parent = _parent(
      _attempt(
        questions: [
          _textQuestion(),
          _textQuestion(id: _textId.toUpperCase()),
          _fileQuestion(),
        ],
      ),
      fixture.publication,
    ),
    'Question moves from non-file to file family': (fixture) =>
        fixture.parent = _parent(
          _attempt(
            questions: [
              _fileQuestion(id: _textId),
              _fileQuestion(),
            ],
          ),
          fixture.publication,
        ),
  };
  for (final failure in localFailures.entries) {
    test('${failure.key} is localStateUnavailable without invented counts', () {
      final fixture = _Fixture();
      failure.value(fixture);
      _expectBlocked(
        fixture.evaluate(),
        StudentHomeworkSubmitBlocker.localStateUnavailable,
      );
    });
  }

  for (final operation in [
    StudentAttemptRouteOperation.submitting,
    StudentAttemptRouteOperation.submitUncertain,
  ]) {
    test('$operation gate blocks otherwise clean ready state', () {
      final fixture = _Fixture()..operation = operation;
      _expectBlocked(
        fixture.evaluate(),
        StudentHomeworkSubmitBlocker.attemptStateLoading,
      );
    });
  }

  final answerBlockers =
      <
        String,
        (StudentQuestionAnswerEditorState, StudentHomeworkSubmitBlocker)
      >{
        'dirty draft': (
          _answer(draft: 'Unsaved text'),
          StudentHomeworkSubmitBlocker.nonFileUnsavedChanges,
        ),
        'dirty deterministic failure': (
          _answer(
            draft: 'Unsaved text',
            status: StudentAnswerSaveStatus.failure,
          ),
          StudentHomeworkSubmitBlocker.nonFileUnsavedChanges,
        ),
        'saving': (
          _answer(status: StudentAnswerSaveStatus.saving),
          StudentHomeworkSubmitBlocker.nonFileSaveInProgress,
        ),
        'uncertain': (
          _answer(status: StudentAnswerSaveStatus.uncertain),
          StudentHomeworkSubmitBlocker.nonFileSaveUncertain,
        ),
      };
  for (final entry in answerBlockers.entries) {
    test('non-file ${entry.key} blocks without counting pending work', () {
      final fixture = _Fixture();
      fixture.answers = _answers(
        fixture.publication,
        questions: {_textId: entry.value.$1},
      );
      _expectBlocked(fixture.evaluate(), entry.value.$2);
    });
  }

  test('non-file owned reconciliation blocks even without dirty draft', () {
    final fixture = _Fixture();
    fixture.answers = _answers(fixture.publication, reconciling: true);
    _expectBlocked(
      fixture.evaluate(),
      StudentHomeworkSubmitBlocker.nonFileSaveInProgress,
    );
  });

  for (final status in [
    StudentFileAnswerStatus.ready,
    StudentFileAnswerStatus.failure,
  ]) {
    test(
      'selected local file in $status blocks and does not count as saved',
      () {
        final fixture = _Fixture();
        fixture.files = _files(
          fixture.publication,
          questions: {_fileId: _file(selected: _selection(), status: status)},
        );
        _expectBlocked(
          fixture.evaluate(),
          StudentHomeworkSubmitBlocker.fileSelectionPending,
        );
      },
    );
  }
  for (final status in [
    StudentFileAnswerStatus.selecting,
    StudentFileAnswerStatus.uploading,
  ]) {
    test('$status file operation blocks before any upload is confirmed', () {
      final fixture = _Fixture();
      fixture.files = _files(
        fixture.publication,
        questions: {_fileId: _file(status: status)},
      );
      _expectBlocked(
        fixture.evaluate(),
        StudentHomeworkSubmitBlocker.fileUploadInProgress,
      );
    });
  }
  test('uncertain file and its owned reconciliation remain blockers', () {
    final fixture = _Fixture();
    fixture.files = _files(
      fixture.publication,
      reconciling: true,
      questions: {_fileId: _file(status: StudentFileAnswerStatus.uncertain)},
    );
    final readiness = fixture.evaluate();
    _expectBlocked(readiness, StudentHomeworkSubmitBlocker.fileUploadUncertain);
    _expectBlocked(
      readiness,
      StudentHomeworkSubmitBlocker.fileUploadInProgress,
    );
  });
  test('uncertain file alone blocks with typed uncertainty', () {
    final fixture = _Fixture();
    fixture.files = _files(
      fixture.publication,
      questions: {_fileId: _file(status: StudentFileAnswerStatus.uncertain)},
    );
    _expectBlocked(
      fixture.evaluate(),
      StudentHomeworkSubmitBlocker.fileUploadUncertain,
    );
  });
  test('file reconciliation alone blocks with typed progress', () {
    final fixture = _Fixture();
    fixture.files = _files(fixture.publication, reconciling: true);
    _expectBlocked(
      fixture.evaluate(),
      StudentHomeworkSubmitBlocker.fileUploadInProgress,
    );
  });

  test(
    'confirmed bases count every saved answer and preserve count bounds',
    () {
      final fixture = _Fixture();
      fixture.attempt = _attempt(
        answers: [
          StudentAttemptAnswerState(
            questionId: _textId,
            type: StudentQuestionType.shortWritten,
            value: const StudentTextAnswerValue(text: 'Saved'),
            updatedAt: _timestamp,
          ),
          StudentAttemptAnswerState(
            questionId: _fileId,
            type: StudentQuestionType.fileBased,
            value: const StudentFileAnswerValue(file: _savedFile),
            updatedAt: _timestamp,
          ),
        ],
      );
      fixture.parent = _parent(fixture.attempt, fixture.publication);
      fixture.answers = _answers(
        fixture.publication,
        questions: {_textId: _answer(saved: 'Saved')},
      );
      fixture.files = _files(
        fixture.publication,
        questions: {_fileId: _file(saved: _savedFile)},
      );
      _expectCounts(fixture.evaluate(), questions: 2, answered: 2);
    },
  );

  test(
    'new confirmed non-file and file overlays count before a parent GET',
    () {
      final fixture = _Fixture();
      expect(fixture.attempt.answers, isEmpty);
      fixture.answers = _answers(
        fixture.publication,
        questions: {
          _textId: _answer(
            saved: 'New saved answer',
            status: StudentAnswerSaveStatus.saved,
          ),
        },
      );
      _expectCounts(fixture.evaluate(), questions: 2, answered: 1);
      fixture.files = _files(
        fixture.publication,
        questions: {
          _fileId: _file(
            saved: _savedFile,
            status: StudentFileAnswerStatus.uploaded,
          ),
        },
      );
      _expectCounts(fixture.evaluate(), questions: 2, answered: 2);
    },
  );

  test(
    'confirmed clear overrides an older parent answer without another cache',
    () {
      final fixture = _Fixture();
      fixture.attempt = _attempt(
        answers: [
          StudentAttemptAnswerState(
            questionId: _textId,
            type: StudentQuestionType.shortWritten,
            value: const StudentTextAnswerValue(text: 'Old saved answer'),
            updatedAt: _timestamp,
          ),
        ],
      );
      fixture.parent = _parent(fixture.attempt, fixture.publication);
      fixture.answers = _answers(
        fixture.publication,
        questions: {_textId: _answer(status: StudentAnswerSaveStatus.saved)},
      );
      _expectCounts(fixture.evaluate(), questions: 2, answered: 0);
    },
  );

  test(
    'newer complete GET publication supersedes overlays and stale bases block',
    () {
      final fixture = _Fixture();
      fixture.answers = _answers(
        fixture.publication,
        questions: {_textId: _answer(saved: 'Overlay')},
      );
      fixture.files = _files(
        fixture.publication,
        questions: {_fileId: _file(saved: _savedFile)},
      );
      _expectCounts(fixture.evaluate(), questions: 2, answered: 2);
      final newerPublication = StudentHomeworkAttemptPublicationToken();
      fixture.parent = _parent(_attempt(), newerPublication);
      _expectBlocked(
        fixture.evaluate(),
        StudentHomeworkSubmitBlocker.localStateUnavailable,
      );
      fixture.answers = _answers(newerPublication);
      _expectBlocked(
        fixture.evaluate(),
        StudentHomeworkSubmitBlocker.localStateUnavailable,
      );
      fixture.files = _files(newerPublication);
      _expectCounts(fixture.evaluate(), questions: 2, answered: 0);
    },
  );

  test('uncertain mutation snapshot is never a confirmed answer', () {
    final fixture = _Fixture();
    fixture.answers = StudentAttemptAnswerEditorState(
      isEligible: true,
      isAuthoritative: true,
      sourceAttemptPublication: fixture.publication,
      pendingMutationSnapshot: const StudentShortWrittenMutation(
        text: 'Unconfirmed',
      ),
      questions: {_textId: _answer(status: StudentAnswerSaveStatus.uncertain)},
    );
    _expectBlocked(
      fixture.evaluate(),
      StudentHomeworkSubmitBlocker.nonFileSaveUncertain,
    );
    fixture.answers = _answers(fixture.publication);
    _expectCounts(fixture.evaluate(), questions: 2, answered: 0);
  });

  test(
    'zero Questions remains ready only with both aligned empty local families',
    () {
      final fixture = _Fixture();
      fixture.parent = _parent(_attempt(questions: []), fixture.publication);
      fixture.answers = _answers(fixture.publication, questions: {});
      fixture.files = _files(fixture.publication, questions: {});
      _expectCounts(fixture.evaluate(), questions: 0, answered: 0);
    },
  );

  test('ready token retains exact identities across equivalent evaluation', () {
    final fixture = _Fixture();
    final token = fixture.evaluate().readyToken!;
    expect(token.matches(fixture.evaluate().readyToken!), isTrue);
    fixture.parent = _parent(fixture.attempt, fixture.publication);
    expect(token.matches(fixture.evaluate().readyToken!), isTrue);
  });

  final tokenChanges = <String, void Function(_Fixture)>{
    'eligible session identity': (fixture) =>
        fixture.sessionKey = _session(Object()),
    'route Topic': (fixture) =>
        fixture.target = StudentHomeworkAttemptRouteTarget(
          topicId: _otherId,
          homeworkId: _homeworkId,
          attemptId: _attemptId,
        ),
    'parent Attempt object': (fixture) =>
        fixture.parent = _parent(_attempt(), fixture.publication),
    'FE-003 state identity': (fixture) =>
        fixture.answers = _answers(fixture.publication),
    'FE-004 state identity': (fixture) =>
        fixture.files = _files(fixture.publication),
    'confirmed count overlay': (fixture) => fixture.answers = _answers(
      fixture.publication,
      questions: {_textId: _answer(saved: 'Newly saved')},
    ),
    'complete new publication': (fixture) {
      final publication = StudentHomeworkAttemptPublicationToken();
      fixture.parent = _parent(fixture.attempt, publication);
      fixture.answers = _answers(publication);
      fixture.files = _files(publication);
    },
  };
  for (final change in tokenChanges.entries) {
    test('${change.key} invalidates the captured confirmation token', () {
      final fixture = _Fixture();
      final token = fixture.evaluate().readyToken!;
      change.value(fixture);
      final current = fixture.evaluate();
      expect(current.isReady, isTrue);
      expect(token.matches(current.readyToken!), isFalse);
    });
  }
}

void _expectBlocked(
  StudentHomeworkSubmitReadiness readiness,
  StudentHomeworkSubmitBlocker blocker,
) {
  expect(readiness.isReady, isFalse);
  expect(readiness.readyToken, isNull);
  expect(readiness.blockers, contains(blocker));
}

void _expectCounts(
  StudentHomeworkSubmitReadiness readiness, {
  required int questions,
  required int answered,
}) {
  expect(readiness.isReady, isTrue);
  final snapshot = readiness.readyToken!.snapshot;
  expect(snapshot.questionCount, questions);
  expect(snapshot.confirmedAnsweredCount, answered);
  expect(
    snapshot.confirmedAnsweredCount,
    inInclusiveRange(0, snapshot.questionCount),
  );
  expect(snapshot.unansweredCount, questions - answered);
}

class _Fixture {
  _Fixture() {
    parent = _parent(attempt, publication);
    answers = _answers(publication);
    files = _files(publication);
  }
  final publication = StudentHomeworkAttemptPublicationToken();
  StudentSessionKey? sessionKey = _session(Object());
  StudentHomeworkAttemptRouteTarget target = StudentHomeworkAttemptRouteTarget(
    topicId: _topicId,
    homeworkId: _homeworkId,
    attemptId: _attemptId,
  );
  StudentHomeworkAttempt attempt = _attempt();
  late StudentHomeworkAttemptState parent;
  late StudentAttemptAnswerEditorState answers;
  late StudentFileAnswerState files;
  StudentAttemptRouteOperation operation = StudentAttemptRouteOperation.idle;

  StudentHomeworkSubmitReadiness evaluate() =>
      StudentHomeworkSubmitReadiness.evaluate(
        sessionKey: sessionKey,
        target: target,
        attemptState: parent,
        answerState: answers,
        fileState: files,
        operation: operation,
      );
}

StudentSessionKey _session(Object user) => StudentSessionKey(
  userId: 'student-1',
  userInstance: user,
  institutionId: 'institution-1',
  institutionTimezone: 'Asia/Tashkent',
  surface: AppDeviceSurface.desktop,
);

StudentHomeworkAttemptState _parent(
  StudentHomeworkAttempt attempt,
  StudentHomeworkAttemptPublicationToken? publication, {
  StudentHomeworkAttemptLoadStatus status =
      StudentHomeworkAttemptLoadStatus.data,
}) => StudentHomeworkAttemptState(
  status: status,
  attempt: attempt,
  publicationToken: publication,
);

StudentAttemptAnswerEditorState _answers(
  StudentHomeworkAttemptPublicationToken? publication, {
  bool eligible = true,
  bool authoritative = true,
  bool reconciling = false,
  StudentHomeworkAttempt? terminal,
  Map<String, StudentQuestionAnswerEditorState>? questions,
}) => StudentAttemptAnswerEditorState(
  isEligible: eligible,
  isAuthoritative: authoritative,
  isReconciling: reconciling,
  terminalAttempt: terminal,
  sourceAttemptPublication: publication,
  questions: questions ?? {_textId: _answer()},
);

StudentFileAnswerState _files(
  StudentHomeworkAttemptPublicationToken? publication, {
  bool authoritative = true,
  bool terminal = false,
  bool reconciling = false,
  Map<String, StudentFileQuestionAnswerState>? questions,
}) => StudentFileAnswerState(
  isAuthoritative: authoritative,
  isTerminal: terminal,
  isReconciling: reconciling,
  sourceAttemptPublication: publication,
  questions: questions ?? {_fileId: _file()},
);

StudentQuestionAnswerEditorState _answer({
  StudentQuestion? question,
  String? saved,
  String? draft,
  StudentAnswerSaveStatus status = StudentAnswerSaveStatus.idle,
}) => StudentQuestionAnswerEditorState(
  question: question ?? _textQuestion(),
  serverAnswer: saved == null ? null : StudentTextAnswerValue(text: saved),
  updatedAt: saved == null ? null : _timestamp,
  draft: StudentShortWrittenDraft(text: draft ?? saved ?? ''),
  saveStatus: status,
);

StudentFileQuestionAnswerState _file({
  StudentQuestion? question,
  StudentSubmissionFile? saved,
  StudentSubmissionUploadFile? selected,
  StudentFileAnswerStatus status = StudentFileAnswerStatus.idle,
}) => StudentFileQuestionAnswerState(
  question: question ?? _fileQuestion(),
  serverFile: saved,
  selectedFile: selected,
  status: status,
);

StudentQuestion _textQuestion({String id = _textId}) => StudentQuestion(
  id: id,
  type: StudentQuestionType.shortWritten,
  prompt: 'Write an answer.',
  instructions: null,
  points: 1,
  position: 1,
  answerUi: const StudentEmptyAnswerUi(),
);

StudentQuestion _fileQuestion({String id = _fileId}) => StudentQuestion(
  id: id,
  type: StudentQuestionType.fileBased,
  prompt: 'Upload a file.',
  instructions: null,
  points: 1,
  position: 2,
  answerUi: StudentFileAnswerUi(
    allowedExtensions: ['pdf'],
    maxSizeBytes: 15728640,
  ),
);

StudentHomeworkAttempt _attempt({
  String id = _attemptId,
  String homeworkId = _homeworkId,
  StudentHomeworkAttemptStatus status = StudentHomeworkAttemptStatus.inProgress,
  List<StudentQuestion>? questions,
  List<StudentAttemptAnswerState> answers = const [],
}) => StudentHomeworkAttempt(
  id: id,
  assessmentId: homeworkId,
  attemptNumber: 1,
  status: status,
  startedAt: DateTime.utc(2026, 9, 8, 12),
  submittedAt: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : _timestamp,
  finalizedAt: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : _timestamp,
  finalizationReason: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : StudentHomeworkAttemptFinalizationReason.studentSubmit,
  deadlineAt: DateTime.utc(2026, 9, 9),
  questions: questions ?? [_textQuestion(), _fileQuestion()],
  answers: answers,
);

StudentSubmissionUploadFile _selection() => StudentSubmissionUploadFile(
  name: 'unsaved.pdf',
  length: 3,
  openRead: () => Stream.value([1, 2, 3]),
);

final _timestamp = DateTime.utc(2026, 9, 8, 12, 10);
const _savedFile = StudentSubmissionFile(
  id: 'a6000000-0000-0000-0000-000000000001',
  originalName: 'saved.pdf',
  extension: 'pdf',
  sizeBytes: 3,
);
const _topicId = 'a0000000-0000-0000-0000-000000000001';
const _homeworkId = 'a1000000-0000-0000-0000-000000000001';
const _attemptId = 'a2000000-0000-0000-0000-000000000001';
const _textId = 'a3000000-0000-0000-0000-000000000001';
const _fileId = 'a4000000-0000-0000-0000-000000000001';
const _otherId = 'a5000000-0000-0000-0000-000000000001';

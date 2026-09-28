import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/student/application/student_answer_autosave.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_route_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'student_autosave_test_support.dart';
import 'student_test_support.dart';

const _homeworkId = '4abcdef0-0000-0000-0000-000000000001';
const _attemptId = '6abcdef0-0000-0000-0000-000000000001';
const _otherAttemptId = '6abcdef0-0000-0000-0000-000000000002';
final _updatedAt = DateTime.utc(2026, 9, 1, 1);

void main() {
  test(
    'route gate permits only owned Submit transitions and releases on session loss',
    () async {
      final h = _Harness();
      await h.flush();
      final view = h.container.listen(
        studentAttemptRouteOperationGateProvider(h.target),
        (_, _) {},
      );
      final gate = h.container.read(
        studentAttemptRouteOperationGateProvider(h.target).notifier,
      );
      expect(view.read(), StudentAttemptRouteOperation.idle);
      expect(gate.claimRetry(), isFalse);
      expect(gate.markSubmitUncertain(), isFalse);
      expect(gate.claimSubmit(), isTrue);
      expect(gate.claimSubmit(), isFalse);
      expect(gate.claimRetry(), isFalse);
      expect(gate.markSubmitUncertain(), isTrue);
      expect(gate.markSubmitUncertain(), isFalse);
      expect(gate.claimSubmit(), isFalse);
      expect(gate.claimRetry(), isTrue);
      expect(view.read(), StudentAttemptRouteOperation.submitting);
      gate.release();
      expect(view.read(), StudentAttemptRouteOperation.idle);
      expect(gate.claimSubmit(), isTrue);
      h.auth.logOut();
      await h.flush();
      expect(view.read(), StudentAttemptRouteOperation.idle);
      expect(gate.claimSubmit(), isFalse);
      expect(gate.claimRetry(), isFalse);
    },
  );

  test(
    'parent publication survives draft overlays and follows a confirmed patch',
    () async {
      final h = _Harness();
      await h.flush();
      final publication = h.container
          .read(studentHomeworkAttemptControllerProvider(h.target))
          .publicationToken;
      expect(publication, isNotNull);
      expect(h.state.sourceAttemptPublication, same(publication));
      h.editText('Confirmed answer');
      expect(h.state.sourceAttemptPublication, same(publication));
      final save = h.controller.saveAnswer(_id(4));
      expect(h.state.activeQuestionId, _id(4));
      expect(
        h.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.saving,
      );
      h.repository.saves.single.complete(
        _result(answer: const StudentTextAnswerValue(text: 'Confirmed answer')),
      );
      await save;
      await h.flush();
      final patched = h.container
          .read(studentHomeworkAttemptControllerProvider(h.target))
          .publicationToken;
      expect(patched, isNot(same(publication)));
      expect(h.state.sourceAttemptPublication, same(patched));
      final newer = _parentState(_attempt(shortText: 'Newer server answer'));
      h.parent.publish(newer);
      await h.flush();
      expect(h.state.sourceAttemptPublication, same(newer.publicationToken));
      expect(
        (h.entry(StudentQuestionType.shortWritten).serverAnswer!
                as StudentTextAnswerValue)
            .text,
        'Newer server answer',
      );
    },
  );

  test('older save overlay cannot claim a newer parent publication', () async {
    final h = _Harness();
    await h.flush();
    h.editText('Saved intent');
    final save = h.controller.saveAnswer(_id(4));
    h.parent.publish(_parentState(_attempt(shortText: 'Newer GET')));
    await h.flush();
    h.repository.saves.single.complete(
      _result(answer: const StudentTextAnswerValue(text: 'Saved intent')),
    );
    await save;
    expect(h.state.sourceAttemptPublication, isNull);
  });

  test(
    'mixed uncertain and owned GET state awaits a complete parent rebase',
    () async {
      final h = _Harness();
      await h.makeUncertain(text: 'Pending intent');
      expect(h.state.sourceAttemptPublication, isNotNull);
      final newer = _parentState(_attempt(shortText: 'Pending intent'));
      h.parent.publish(newer);
      await h.flush();
      expect(h.state.hasUncertainMutation, isTrue);
      expect(h.state.sourceAttemptPublication, isNull);
      final reload = h.controller.reloadAttempt();
      h.repository.reads.single.complete(_attempt(shortText: 'Pending intent'));
      await reload;
      expect(h.state.hasUncertainMutation, isFalse);
      expect(h.state.sourceAttemptPublication, isNull);
      final complete = _parentState(_attempt(shortText: 'Pending intent'));
      h.parent.publish(complete);
      await h.flush();
      expect(h.state.sourceAttemptPublication, same(complete.publicationToken));
    },
  );

  for (final uncertainGate in [false, true]) {
    test(
      'Submit gate uncertain=$uncertainGate refuses every answer entry',
      () async {
        final h = _Harness(attempt: _attempt(saved: true));
        await h.flush();
        h.editText('Preserved draft');
        h.container.listen(
          studentAttemptRouteOperationGateProvider(h.target),
          (_, _) {},
        );
        final gate = h.container.read(
          studentAttemptRouteOperationGateProvider(h.target).notifier,
        );
        expect(gate.claimSubmit(), isTrue);
        if (uncertainGate) expect(gate.markSubmitUncertain(), isTrue);
        final before = h.state;
        h.editText('Blocked draft');
        h.controller.clearAnswer(_id(4));
        await h.controller.saveAnswer(_id(4));
        await h.controller.reloadAttempt();
        expect(h.state, same(before));
        expect(h.repository.saves, isEmpty);
        expect(h.repository.reads, isEmpty);
        h.controller.clearLocalState();
        expect(h.state.questions, isEmpty);
        expect(h.state.sourceAttemptPublication, isNull);
      },
    );

    test(
      'Submit gate uncertain=$uncertainGate freezes uncertain answer GET',
      () async {
        final h = _Harness();
        await h.makeUncertain();
        h.container.listen(
          studentAttemptRouteOperationGateProvider(h.target),
          (_, _) {},
        );
        final gate = h.container.read(
          studentAttemptRouteOperationGateProvider(h.target).notifier,
        );
        expect(gate.claimSubmit(), isTrue);
        if (uncertainGate) expect(gate.markSubmitUncertain(), isTrue);
        final before = h.state;
        await h.controller.reloadAttempt();
        expect(h.state, same(before));
        expect(h.repository.reads, isEmpty);
      },
    );
  }

  for (final saved in [false, true]) {
    test('initializes exactly eight typed drafts with saved=$saved', () async {
      final harness = _Harness(attempt: _attempt(saved: saved));
      await harness.flush();
      expect(harness.state.questions, hasLength(8));
      expect(harness.state.questions.containsKey(_id(6)), isFalse);
      for (final question in _questions().where(
        (question) => question.type != StudentQuestionType.fileBased,
      )) {
        final editor = harness.state.questions[question.id]!;
        expect(editor.question.type, question.type);
        expect(editor.isDirty, isFalse);
        expect(editor.saveStatus, StudentAnswerSaveStatus.idle);
        expect(editor.serverAnswer == null, !saved);
        expect(editor.updatedAt, saved ? _updatedAt : null);
        expect(harness.state.canSave(question.id), isFalse);
        if (saved) {
          expect(editor.validation, isNull);
          expect(
            editor.draft.toMutation(question).toJson(),
            StudentAnswerDraft.fromAnswer(
              question,
              _savedValue(question.type),
            ).toMutation(question).toJson(),
          );
        }
      }
      expect(harness.repository.saves, isEmpty);
    });
  }

  test('semantic ordering changes remain clean and send nothing', () async {
    final harness = _Harness(attempt: _attempt(saved: true));
    await harness.flush();
    final replacements = <StudentQuestionType, StudentAttemptAnswerValue>{
      StudentQuestionType.multipleChoice: StudentChoiceAnswerValue(
        selectedOptionIds: [_id(22), _id(21)],
      ),
      StudentQuestionType.matching: StudentMatchingAnswerValue(
        pairs: [
          StudentMatchingAnswerPair(leftItemId: _id(72), rightItemId: _id(82)),
          StudentMatchingAnswerPair(leftItemId: _id(71), rightItemId: _id(81)),
        ],
      ),
      StudentQuestionType.ordering: StudentOrderingAnswerValue(
        items: [
          StudentOrderingAnswerItem(itemId: _id(92), position: 1),
          StudentOrderingAnswerItem(itemId: _id(91), position: 2),
        ],
      ),
      StudentQuestionType.fillInBlank: StudentFillBlankAnswerValue(
        values: [
          StudentFillBlankAnswerEntry(blankId: _id(102), text: 'Two'),
          StudentFillBlankAnswerEntry(blankId: _id(101), text: ' One '),
        ],
      ),
    };
    for (final replacement in replacements.entries) {
      harness.edit(replacement.key, replacement.value);
      expect(harness.entry(replacement.key).isDirty, isFalse);
      await harness.controller.saveAnswer(harness.question(replacement.key).id);
    }
    expect(harness.repository.saves, isEmpty);
  });

  test(
    'clear marks a change, absent clear is clean, editing back restores base',
    () async {
      final harness = _Harness(attempt: _attempt(saved: true));
      await harness.flush();
      for (final type in _clearableTypes) {
        final question = harness.question(type);
        harness.controller.clearAnswer(question.id);
        expect(harness.entry(type).isDirty, isTrue);
        expect(harness.entry(type).validation, isNull);
        harness.edit(type, _savedValue(type));
        expect(harness.entry(type).isDirty, isFalse);
        expect(harness.entry(type).validation, isNull);
        expect(harness.entry(type).saveStatus, StudentAnswerSaveStatus.idle);
      }
      harness.parent.publish(_parentState(_attempt()));
      await harness.flush();
      for (final type in _clearableTypes) {
        final question = harness.question(type);
        harness.controller.clearAnswer(question.id);
        expect(harness.entry(type).isDirty, isFalse);
        await harness.controller.saveAnswer(question.id);
      }
      expect(harness.repository.saves, isEmpty);
    },
  );

  for (final type in [
    StudentQuestionType.singleChoice,
    StudentQuestionType.trueFalse,
  ]) {
    test('$type needs a selection and cannot clear a saved answer', () async {
      final harness = _Harness();
      await harness.flush();
      expect(harness.entry(type).validation, isNotNull);
      await harness.controller.saveAnswer(harness.question(type).id);
      expect(harness.repository.saves, isEmpty);
      harness.parent.publish(_parentState(_attempt(saved: true)));
      await harness.flush();
      final before = harness
          .entry(type)
          .draft
          .toMutation(harness.question(type))
          .toJson();
      harness.controller.clearAnswer(harness.question(type).id);
      expect(
        harness.entry(type).draft.toMutation(harness.question(type)).toJson(),
        before,
      );
      expect(harness.entry(type).isDirty, isFalse);
    });
  }

  final invalidAnswers =
      <(String, StudentQuestionType, StudentAttemptAnswerValue)>[
        (
          'multiple cap',
          StudentQuestionType.multipleChoice,
          StudentChoiceAnswerValue(
            selectedOptionIds: [_id(21), _id(22), _id(23)],
          ),
        ),
        (
          'short scalar limit',
          StudentQuestionType.shortWritten,
          StudentTextAnswerValue(text: '😀' * 1001),
        ),
        (
          'open scalar limit',
          StudentQuestionType.openWritten,
          StudentTextAnswerValue(text: '😀' * 20001),
        ),
        (
          'duplicate matching right',
          StudentQuestionType.matching,
          StudentMatchingAnswerValue(
            pairs: [
              StudentMatchingAnswerPair(
                leftItemId: _id(71),
                rightItemId: _id(81),
              ),
              StudentMatchingAnswerPair(
                leftItemId: _id(72),
                rightItemId: _id(81),
              ),
            ],
          ),
        ),
        (
          'duplicate ordering position',
          StudentQuestionType.ordering,
          StudentOrderingAnswerValue(
            items: [
              StudentOrderingAnswerItem(itemId: _id(91), position: 1),
              StudentOrderingAnswerItem(itemId: _id(92), position: 1),
            ],
          ),
        ),
        (
          'ordering position zero',
          StudentQuestionType.ordering,
          StudentOrderingAnswerValue(
            items: [StudentOrderingAnswerItem(itemId: _id(91), position: 0)],
          ),
        ),
        (
          'ordering position above N',
          StudentQuestionType.ordering,
          StudentOrderingAnswerValue(
            items: [StudentOrderingAnswerItem(itemId: _id(91), position: 3)],
          ),
        ),
        (
          'fill scalar limit',
          StudentQuestionType.fillInBlank,
          StudentFillBlankAnswerValue(
            values: [
              StudentFillBlankAnswerEntry(blankId: _id(101), text: '😀' * 1001),
            ],
          ),
        ),
      ];
  for (final (name, type, value) in invalidAnswers) {
    test('$name remains visible but cannot dispatch', () async {
      final harness = _Harness();
      await harness.flush();
      harness.edit(type, value);
      expect(harness.entry(type).validation, isNotNull);
      expect(harness.state.canSave(harness.question(type).id), isFalse);
      await harness.controller.saveAnswer(harness.question(type).id);
      expect(harness.repository.saves, isEmpty);
    });
  }

  for (final (type, count) in [
    (StudentQuestionType.shortWritten, 1000),
    (StudentQuestionType.openWritten, 20000),
  ]) {
    test('$type counts Unicode scalars instead of UTF-16 units', () async {
      final harness = _Harness();
      await harness.flush();
      harness.edit(type, StudentTextAnswerValue(text: '😀' * count));
      expect(harness.entry(type).validation, isNull);
      expect(harness.state.canSave(harness.question(type).id), isTrue);
    });
  }

  for (final status in StudentHomeworkAttemptLoadStatus.values.where(
    (status) => status != StudentHomeworkAttemptLoadStatus.data,
  )) {
    test(
      '$status parent never authorizes PUT even with retained data',
      () async {
        final harness = _Harness();
        await harness.flush();
        harness.editText('Unsent intent');
        harness.parent.publish(
          StudentHomeworkAttemptState(status: status, attempt: _attempt()),
        );
        await harness.flush();
        expect(harness.state.canSave(_id(4)), isFalse);
        await harness.controller.saveAnswer(_id(4));
        expect(harness.repository.saves, isEmpty);
        if (status == StudentHomeworkAttemptLoadStatus.refreshing ||
            status == StudentHomeworkAttemptLoadStatus.error) {
          expect(
            harness.entry(StudentQuestionType.shortWritten).isDirty,
            isTrue,
          );
          harness.parent.publish(_parentState(_attempt()));
          await harness.flush();
          expect(harness.state.canSave(_id(4)), isTrue);
        }
      },
    );
  }

  for (final (name, attempt) in <(String, StudentHomeworkAttempt?)>[
    ('null', null),
    ('wrong Attempt', _attempt(id: _otherAttemptId)),
    ('wrong Homework', _attempt(homeworkId: _id(400))),
    ('malformed Attempt UUID', _attempt(id: 'not-an-attempt')),
    ('malformed Homework UUID', _attempt(homeworkId: 'not-a-homework')),
    ('submitted', _attempt(status: StudentHomeworkAttemptStatus.submitted)),
  ]) {
    test('$name data does not authorize an answer mutation', () async {
      final harness = _Harness();
      await harness.flush();
      harness.editText('Unsaved');
      harness.parent.publish(_parentState(attempt));
      await harness.flush();
      expect(harness.state.canSave(_id(4)), isFalse);
      await harness.controller.saveAnswer(_id(4));
      expect(harness.repository.saves, isEmpty);
    });
  }

  for (final user in [
    studentUser('teacher', role: UserRole.teacher),
    studentUser('inactive', isActive: false),
    studentUser('password', mustChangePassword: true),
    studentUser('institution', institutionStatus: 'inactive'),
    studentUser('hierarchy', nestedInstitutionId: 'other-institution'),
  ]) {
    test(
      'ineligible ${user.loginName} cannot use retained parent data',
      () async {
        final harness = _Harness(
          auth: FakeStudentAuthSessionController.authenticated(user),
        );
        await harness.flush();
        await harness.controller.saveAnswer(_id(4));
        expect(harness.state.questions, isEmpty);
        expect(harness.repository.saves, isEmpty);
      },
    );
  }

  test(
    'valid dirty save sends one exact typed mutation and keeps typing',
    () async {
      final harness = _Harness();
      await harness.flush();
      harness.editText('  Exact\nStudent input  ');
      final save = harness.controller.saveAnswer(_id(4));
      expect(harness.repository.saves, hasLength(1));
      final request = harness.repository.saves.single;
      expect(request.attemptId, _attemptId);
      expect(request.question.id, _id(4));
      expect(request.mutation.toJson(), {
        'type': 'short_written',
        'text': '  Exact\nStudent input  ',
      });
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.saving,
      );
      expect(harness.state.canEdit(_id(4)), isTrue);
      harness.editText('Typing continues');
      harness.edit(
        StudentQuestionType.openWritten,
        const StudentTextAnswerValue(text: 'Other local draft'),
      );
      await harness.controller.saveAnswer(_id(4));
      await harness.controller.saveAnswer(_id(5));
      expect(harness.repository.saves, hasLength(1));
      expect(harness.state.canEdit(_id(5)), isTrue);
      expect(harness.entry(StudentQuestionType.openWritten).isDirty, isTrue);
      request.complete(
        _result(
          answer: const StudentTextAnswerValue(text: 'Authoritative response'),
        ),
      );
      await save;
      await harness.flush();
      final editor = harness.entry(StudentQuestionType.shortWritten);
      expect(
        (editor.serverAnswer! as StudentTextAnswerValue).text,
        'Authoritative response',
      );
      expect(editor.draft.toMutation(editor.question).toJson(), {
        'type': 'short_written',
        'text': 'Typing continues',
      });
      expect(editor.isDirty, isTrue);
      expect(editor.updatedAt, _updatedAt);
      expect(editor.saveStatus, StudentAnswerSaveStatus.idle);
      expect(harness.state.pendingMutationSnapshot, isNull);
      expect(harness.parent.refreshCalls, 0);
      expect(harness.parent.accepted, hasLength(1));
      harness.editText('Next answer');
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.idle,
      );
      expect(harness.entry(StudentQuestionType.shortWritten).isDirty, isTrue);
    },
  );

  test(
    'confirmed clear resets to empty and failed parent refresh does not roll back',
    () async {
      final harness = _Harness(attempt: _attempt(saved: true));
      await harness.flush();
      harness.controller.clearAnswer(_id(4));
      final save = harness.controller.saveAnswer(_id(4));
      harness.repository.saves.single.complete(_result(answer: null));
      await save;
      harness.parent.publish(
        StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.error,
          attempt: _attempt(saved: true),
          failure: ApiFailure.local(
            kind: ApiFailureKind.connection,
            message: 'Unavailable',
          ),
        ),
      );
      await harness.flush();
      final editor = harness.entry(StudentQuestionType.shortWritten);
      expect(editor.serverAnswer, isNull);
      expect(editor.isDirty, isFalse);
      expect(editor.saveStatus, StudentAnswerSaveStatus.saved);
      harness.editText('Next');
      expect(harness.state.canSave(_id(4)), isFalse);
    },
  );

  test(
    'normal confirmed refresh preserves dirty intent and updates clean bases',
    () async {
      final harness = _Harness();
      await harness.flush();
      harness.editText('Local intent');
      harness.parent.publish(_parentState(_attempt(saved: true)));
      await harness.flush();
      final editor = harness.entry(StudentQuestionType.shortWritten);
      expect(
        (editor.serverAnswer! as StudentTextAnswerValue).text,
        ' Saved short ',
      );
      expect(editor.draft.toMutation(editor.question).toJson(), {
        'type': 'short_written',
        'text': 'Local intent',
      });
      expect(editor.isDirty, isTrue);
      expect(harness.entry(StudentQuestionType.openWritten).isDirty, isFalse);
      harness.editText(' Saved short ');
      expect(harness.entry(StudentQuestionType.shortWritten).isDirty, isFalse);
      expect(harness.repository.saves, isEmpty);
    },
  );

  for (final kind in [
    ApiFailureKind.connection,
    ApiFailureKind.timeout,
    ApiFailureKind.cancelled,
    ApiFailureKind.invalidResponse,
    ApiFailureKind.unknown,
  ]) {
    test(
      '$kind PUT keeps exact intent and only permits owned GET recovery',
      () async {
        final harness = _Harness();
        await harness.makeUncertain(kind: kind);
        final snapshot = harness.state.pendingMutationSnapshot;
        expect(snapshot, same(harness.repository.saves.single.mutation));
        expect(
          harness.entry(StudentQuestionType.shortWritten).saveStatus,
          StudentAnswerSaveStatus.uncertain,
        );
        expect(harness.state.hasUncertainMutation, isTrue);
        expect(harness.state.canEdit(_id(4)), isTrue);
        harness.editText('Typing continues');
        harness.controller.clearAnswer(_id(4));
        await harness.controller.saveAnswer(_id(4));
        harness.edit(
          StudentQuestionType.openWritten,
          const StudentTextAnswerValue(text: 'Other intent'),
        );
        await harness.controller.saveAnswer(_id(5));
        expect(harness.repository.saves, hasLength(1));
        expect(harness.repository.reads, isEmpty);
        expect(harness.state.pendingMutationSnapshot, same(snapshot));
        expect(harness.entry(StudentQuestionType.openWritten).isDirty, isTrue);
      },
    );
  }

  for (final status in <int?>[null, 500, 503]) {
    test(
      'server status $status cannot prove deterministic PUT failure',
      () async {
        final harness = _Harness();
        await harness.flush();
        harness.editText('Pending');
        final save = harness.controller.saveAnswer(_id(4));
        harness.repository.saves.single.fail(
          ApiRequestException(
            ApiFailure(
              kind: ApiFailureKind.server,
              message: 'Safe failure',
              statusCode: status,
              serverCode: ApiErrorCodes.serverError,
            ),
          ),
        );
        await save;
        expect(harness.state.hasUncertainMutation, isTrue);
        expect(
          harness.state.pendingMutationSnapshot,
          same(harness.repository.saves.single.mutation),
        );
      },
    );
  }

  for (final result in [
    _result(
      questionId: _id(5),
      answer: const StudentTextAnswerValue(text: 'Wrong target'),
    ),
    _result(
      type: StudentQuestionType.openWritten,
      answer: const StudentTextAnswerValue(text: 'Wrong type'),
    ),
    _result(answer: StudentChoiceAnswerValue(selectedOptionIds: [_id(11)])),
    _result(answer: StudentTextAnswerValue(text: 'x' * 1001)),
  ]) {
    test('invalid typed success remains uncertain without rebasing', () async {
      final harness = _Harness();
      await harness.flush();
      harness.editText('Original intent');
      final save = harness.controller.saveAnswer(_id(4));
      harness.repository.saves.single.complete(result);
      await save;
      expect(harness.state.hasUncertainMutation, isTrue);
      expect(
        harness.entry(StudentQuestionType.shortWritten).serverAnswer,
        isNull,
      );
      expect(
        harness.state.pendingMutationSnapshot,
        same(harness.repository.saves.single.mutation),
      );
      expect(harness.parent.refreshCalls, 0);
    });
  }

  test(
    'removed current-safe choice option invalidates an in-flight success',
    () async {
      final harness = _Harness();
      await harness.flush();
      harness.edit(
        StudentQuestionType.singleChoice,
        StudentChoiceAnswerValue(selectedOptionIds: [_id(11)]),
      );
      final save = harness.controller.saveAnswer(_id(1));
      final changedQuestions = _questions();
      final previous = changedQuestions.first;
      changedQuestions[0] = StudentQuestion(
        id: previous.id,
        type: previous.type,
        prompt: previous.prompt,
        instructions: previous.instructions,
        points: previous.points,
        position: previous.position,
        answerUi: StudentChoiceAnswerUi(
          options: [StudentChoiceOption(id: _id(12), text: 'Remaining B')],
        ),
      );
      harness.parent.publish(
        _parentState(_attempt(questions: changedQuestions)),
      );
      await harness.flush();
      harness.repository.saves.single.complete(
        _result(
          questionId: _id(1),
          type: StudentQuestionType.singleChoice,
          answer: StudentChoiceAnswerValue(selectedOptionIds: [_id(11)]),
        ),
      );
      await save;
      final editor = harness.entry(StudentQuestionType.singleChoice);
      expect(editor.saveStatus, StudentAnswerSaveStatus.uncertain);
      expect(editor.failure!.kind, ApiFailureKind.invalidResponse);
      expect(editor.serverAnswer, isNull);
      expect(
        harness.state.pendingMutationSnapshot,
        same(harness.repository.saves.single.mutation),
      );
      expect(harness.parent.refreshCalls, 0);
    },
  );

  test(
    'ordinary matching parent refresh never proves an uncertain PUT result',
    () async {
      final harness = _Harness();
      await harness.makeUncertain();
      final snapshot = harness.state.pendingMutationSnapshot;
      harness.parent.publish(
        _parentState(_attempt(shortText: 'Pending intent', saved: true)),
      );
      await harness.flush();
      expect(harness.state.hasUncertainMutation, isTrue);
      expect(harness.state.pendingMutationSnapshot, same(snapshot));
      expect(
        harness.entry(StudentQuestionType.shortWritten).serverAnswer,
        isNull,
      );
      expect(
        harness.entry(StudentQuestionType.openWritten).serverAnswer,
        isNotNull,
      );
      expect(harness.repository.reads, isEmpty);
      expect(harness.repository.saves, hasLength(1));
    },
  );

  test(
    'ordinary parent omission retains uncertainty and owned recovery',
    () async {
      final harness = _Harness();
      await harness.makeUncertain();
      final snapshot = harness.state.pendingMutationSnapshot;
      harness.parent.publish(
        _parentState(
          _attempt(
            questions: _questions()
                .where((question) => question.id != _id(4))
                .toList(),
          ),
        ),
      );
      await harness.flush();
      expect(harness.state.hasUncertainMutation, isTrue);
      expect(harness.state.pendingMutationSnapshot, same(snapshot));
      expect(harness.state.questions.containsKey(_id(4)), isTrue);
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.uncertain,
      );
      expect(harness.state.canSave(_id(5)), isFalse);
      final reload = harness.controller.reloadAttempt();
      expect(harness.repository.reads.single.attemptId, _attemptId);
      harness.repository.reads.single.complete(
        _attempt(shortText: 'Pending intent'),
      );
      await reload;
      expect(harness.state.hasUncertainMutation, isFalse);
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.saved,
      );
      expect(harness.repository.saves, hasLength(1));
    },
  );

  test(
    'Question omitted during saving makes a subsequent 200 unconfirmed',
    () async {
      final harness = _Harness();
      await harness.flush();
      harness.editText('Pending intent');
      final save = harness.controller.saveAnswer(_id(4));
      final snapshot = harness.state.pendingMutationSnapshot;
      harness.parent.publish(
        _parentState(
          _attempt(
            questions: _questions()
                .where((question) => question.id != _id(4))
                .toList(),
          ),
        ),
      );
      await harness.flush();
      harness.repository.saves.single.complete(
        _result(answer: const StudentTextAnswerValue(text: 'Pending intent')),
      );
      await save;
      expect(harness.state.hasUncertainMutation, isTrue);
      expect(harness.state.pendingMutationSnapshot, same(snapshot));
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.uncertain,
      );
      expect(
        harness.entry(StudentQuestionType.shortWritten).failure!.kind,
        ApiFailureKind.invalidResponse,
      );
      expect(harness.parent.refreshCalls, 0);
      expect(harness.repository.saves, hasLength(1));
    },
  );

  for (final type in [
    StudentQuestionType.shortWritten,
    StudentQuestionType.openWritten,
  ]) {
    test(
      '$type whitespace clear is proven saved by owned GET with absent answer',
      () async {
        final harness = _Harness(attempt: _attempt(saved: true));
        await harness.flush();
        final question = harness.question(type);
        harness.edit(type, const StudentTextAnswerValue(text: ' \n\t '));
        final save = harness.controller.saveAnswer(question.id);
        final request = harness.repository.saves.single;
        expect(request.mutation.toJson(), {
          'type': type.apiValue,
          'text': ' \n\t ',
        });
        request.fail(studentLocalFailure(ApiFailureKind.timeout));
        await save;
        expect(harness.state.pendingMutationSnapshot, same(request.mutation));
        final reload = harness.controller.reloadAttempt();
        harness.repository.reads.single.complete(_attempt());
        await reload;
        final editor = harness.entry(type);
        expect(editor.serverAnswer, isNull);
        expect(editor.updatedAt, isNull);
        expect(editor.isDirty, isFalse);
        expect(editor.saveStatus, StudentAnswerSaveStatus.saved);
        expect(editor.draft.toMutation(question).toJson(), {
          'type': type.apiValue,
          'text': ' \n\t ',
        });
        expect(harness.state.pendingMutationSnapshot, isNull);
        expect(harness.state.hasUncertainMutation, isFalse);
        expect(harness.repository.saves, hasLength(1));
      },
    );
  }

  test(
    'owned matching reconciliation proves saved and suppresses duplicate reload',
    () async {
      final harness = _Harness();
      await harness.makeUncertain();
      final reload = harness.controller.reloadAttempt();
      expect(harness.repository.reads.single.attemptId, _attemptId);
      expect(harness.state.isReconciling, isTrue);
      expect(harness.state.canSave(_id(4)), isFalse);
      await harness.controller.reloadAttempt();
      await harness.controller.saveAnswer(_id(4));
      expect(harness.repository.reads, hasLength(1));
      harness.repository.reads.single.complete(
        _attempt(shortText: 'Pending intent'),
      );
      await reload;
      await harness.flush();
      expect(harness.state.hasUncertainMutation, isFalse);
      expect(harness.state.isReconciling, isFalse);
      expect(harness.state.pendingMutationSnapshot, isNull);
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.saved,
      );
      expect(harness.entry(StudentQuestionType.shortWritten).isDirty, isFalse);
      expect(harness.repository.saves, hasLength(1));
    },
  );

  test(
    'different owned server answer restores exact dirty intent without resend',
    () async {
      final harness = _Harness();
      await harness.makeUncertain(text: '  Pending\nintent  ');
      final snapshotJson = harness.state.pendingMutationSnapshot!.toJson();
      final reload = harness.controller.reloadAttempt();
      harness.parent.publish(
        StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.refreshing,
          attempt: _attempt(),
        ),
      );
      await harness.flush();
      harness.repository.reads.single.complete(
        _attempt(shortText: 'Newer other-device answer'),
      );
      await reload;
      await harness.flush();
      final editor = harness.entry(StudentQuestionType.shortWritten);
      expect(
        (editor.serverAnswer! as StudentTextAnswerValue).text,
        'Newer other-device answer',
      );
      expect(editor.draft.toMutation(editor.question).toJson(), snapshotJson);
      expect(editor.isDirty, isTrue);
      expect(harness.state.hasUncertainMutation, isFalse);
      expect(harness.state.canSave(_id(4)), isFalse);
      expect(harness.repository.saves, hasLength(1));
      harness.parent.publish(
        _parentState(_attempt(shortText: 'Newer other-device answer')),
      );
      await harness.flush();
      expect(harness.state.canSave(_id(4)), isTrue);
      final explicitSave = harness.controller.saveAnswer(_id(4));
      expect(harness.repository.saves, hasLength(2));
      harness.repository.saves.last.complete(
        _result(
          answer: const StudentTextAnswerValue(text: '  Pending\nintent  '),
        ),
      );
      await explicitSave;
    },
  );

  test(
    'refreshed tighter choice cap retains pending intent with validation',
    () async {
      final harness = _Harness();
      await harness.flush();
      harness.edit(
        StudentQuestionType.multipleChoice,
        StudentChoiceAnswerValue(selectedOptionIds: [_id(21), _id(22)]),
      );
      final save = harness.controller.saveAnswer(_id(2));
      harness.repository.saves.single.fail(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await save;
      final reload = harness.controller.reloadAttempt();
      harness.repository.reads.single.complete(_attempt(maxSelections: 1));
      await reload;
      final editor = harness.entry(StudentQuestionType.multipleChoice);
      expect(editor.validation, isNotNull);
      expect(editor.isDirty, isTrue);
      expect(harness.state.canSave(_id(2)), isFalse);
      expect(harness.state.pendingMutationSnapshot, isNull);
      expect(harness.repository.saves, hasLength(1));
    },
  );

  for (final (name, returned) in [
    (
      'wrong Attempt',
      _attempt(id: _otherAttemptId, shortText: 'Pending intent'),
    ),
    (
      'wrong Homework',
      _attempt(homeworkId: _id(400), shortText: 'Pending intent'),
    ),
    (
      'malformed Attempt UUID',
      _attempt(id: 'not-a-uuid', shortText: 'Pending intent'),
    ),
    (
      'malformed Homework UUID',
      _attempt(homeworkId: 'not-a-uuid', shortText: 'Pending intent'),
    ),
  ]) {
    test('$name reconciliation cannot prove success', () async {
      final harness = _Harness();
      await harness.makeUncertain();
      final snapshot = harness.state.pendingMutationSnapshot;
      final reload = harness.controller.reloadAttempt();
      harness.repository.reads.single.complete(returned);
      await reload;
      expect(harness.state.hasUncertainMutation, isTrue);
      expect(harness.state.pendingMutationSnapshot, same(snapshot));
      expect(harness.state.isReconciling, isFalse);
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.uncertain,
      );
      expect(
        harness.entry(StudentQuestionType.shortWritten).failure!.kind,
        ApiFailureKind.invalidResponse,
      );
      expect(harness.repository.saves, hasLength(1));
    });
  }

  test(
    'canonical upper-case returned identities match route during reconciliation',
    () async {
      final harness = _Harness();
      await harness.makeUncertain();
      final reload = harness.controller.reloadAttempt();
      harness.repository.reads.single.complete(
        _attempt(
          id: _attemptId.toUpperCase(),
          homeworkId: _homeworkId.toUpperCase(),
          shortText: 'Pending intent',
        ),
      );
      await reload;
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.saved,
      );
      expect(harness.state.hasUncertainMutation, isFalse);
    },
  );

  test(
    'failed owned GET retains snapshot and permits another GET only',
    () async {
      final harness = _Harness();
      await harness.makeUncertain();
      final snapshot = harness.state.pendingMutationSnapshot;
      final first = harness.controller.reloadAttempt();
      harness.repository.reads.single.fail(
        studentLocalFailure(ApiFailureKind.connection),
      );
      await first;
      expect(harness.state.hasUncertainMutation, isTrue);
      expect(harness.state.isReconciling, isFalse);
      expect(harness.state.pendingMutationSnapshot, same(snapshot));
      final second = harness.controller.reloadAttempt();
      expect(harness.repository.reads, hasLength(2));
      harness.repository.reads.last.complete(
        _attempt(shortText: 'Pending intent'),
      );
      await second;
      expect(harness.state.hasUncertainMutation, isFalse);
      expect(harness.repository.saves, hasLength(1));
    },
  );

  for (final (code, attemptRefresh, homeworkRefresh) in [
    ('selection_limit_exceeded', true, false),
    (ApiErrorCodes.validationFailed, false, false),
    (ApiErrorCodes.deadlinePassed, true, true),
    ('attempt_not_editable', true, false),
    (ApiErrorCodes.taskClosed, true, true),
    (ApiErrorCodes.taskArchived, true, true),
    (ApiErrorCodes.taskNotActive, true, true),
    (ApiErrorCodes.resourceNotFound, true, false),
    (ApiErrorCodes.businessConflict, true, false),
  ]) {
    test(
      '$code clears mutation ownership and requests required reconciliation',
      () async {
        final harness = _Harness();
        await harness.flush();
        final initialDetailBuilds = harness.detailBuilds;
        harness.editText('Retained draft');
        final save = harness.controller.saveAnswer(_id(4));
        harness.repository.saves.single.fail(
          studentServerFailure(
            code,
            statusCode: code == ApiErrorCodes.resourceNotFound ? 404 : 422,
          ),
        );
        await save;
        await harness.flush();
        expect(harness.state.pendingMutationSnapshot, isNull);
        expect(harness.state.hasUncertainMutation, isFalse);
        expect(
          harness.entry(StudentQuestionType.shortWritten).saveStatus,
          StudentAnswerSaveStatus.failure,
        );
        expect(harness.entry(StudentQuestionType.shortWritten).isDirty, isTrue);
        expect(harness.parent.refreshCalls > 0, attemptRefresh);
        expect(
          harness.detailBuilds > initialDetailBuilds ||
              harness.detail.refreshCalls > 0,
          homeworkRefresh,
        );
        expect(harness.repository.saves, hasLength(1));
      },
    );
  }

  for (final operation in ['dirty', 'saving', 'uncertain', 'reconciling']) {
    test(
      'terminal parent wins over $operation and ignores late completion',
      () async {
        final harness = _Harness();
        await harness.flush();
        harness.editText('Discarded local draft');
        Future<void>? pending;
        if (operation != 'dirty') {
          pending = harness.controller.saveAnswer(_id(4));
          if (operation == 'uncertain' || operation == 'reconciling') {
            harness.repository.saves.single.fail(
              studentLocalFailure(ApiFailureKind.timeout),
            );
            await pending;
            pending = null;
          }
          if (operation == 'reconciling') {
            pending = harness.controller.reloadAttempt();
          }
        }
        final terminal = _attempt(
          status: StudentHomeworkAttemptStatus.submitted,
          shortText: 'Final server answer',
        );
        harness.parent.publish(_parentState(terminal));
        await harness.flush();
        _expectTerminal(harness, 'Final server answer');
        final refreshCount = harness.parent.refreshCalls;
        if (operation == 'saving') {
          harness.repository.saves.single.complete(
            _result(
              answer: const StudentTextAnswerValue(text: 'Obsolete success'),
            ),
          );
        } else if (operation == 'reconciling') {
          harness.repository.reads.single.complete(
            _attempt(shortText: 'Discarded local draft'),
          );
        }
        if (pending != null) await pending;
        await harness.flush();
        _expectTerminal(harness, 'Final server answer');
        expect(harness.parent.refreshCalls, refreshCount);
        expect(
          harness.repository.saves,
          hasLength(operation == 'dirty' ? 0 : 1),
        );
      },
    );
  }

  test(
    'terminal owned reconciliation discards pending intent and shows server answers',
    () async {
      final harness = _Harness();
      await harness.makeUncertain();
      final reload = harness.controller.reloadAttempt();
      harness.repository.reads.single.complete(
        _attempt(
          status: StudentHomeworkAttemptStatus.submitted,
          shortText: 'Terminal server answer',
        ),
      );
      await reload;
      _expectTerminal(harness, 'Terminal server answer');
      expect(harness.repository.saves, hasLength(1));
    },
  );

  for (final code in [
    ApiErrorCodes.authenticationRequired,
    ApiErrorCodes.passwordChangeRequired,
    ApiErrorCodes.userInactive,
    ApiErrorCodes.institutionInactive,
  ]) {
    for (final reconciling in [false, true]) {
      test(
        '$code during ${reconciling ? 'GET' : 'PUT'} clears all local state',
        () async {
          final harness = _Harness();
          await harness.flush();
          Future<void> operation;
          if (reconciling) {
            await harness.makeUncertain();
            operation = harness.controller.reloadAttempt();
            harness.repository.reads.single.fail(studentServerFailure(code));
          } else {
            harness.editText('Private draft');
            operation = harness.controller.saveAnswer(_id(4));
            harness.repository.saves.single.fail(studentServerFailure(code));
          }
          await operation;
          await harness.flush();
          expect(harness.state.questions, isEmpty);
          expect(harness.state.pendingMutationSnapshot, isNull);
          expect(harness.state.hasDirtyDrafts, isFalse);
          expect(harness.state.hasUncertainMutation, isFalse);
          harness.parent.publish(_parentState(_attempt(saved: true)));
          await harness.flush();
          expect(harness.state.questions, isEmpty);
          expect(
            harness.auth.bootstrapCalls,
            code == ApiErrorCodes.authenticationRequired ? 0 : 1,
          );
        },
      );
    }
  }

  for (final reconciling in [false, true]) {
    for (final boundary in [
      'logout',
      'Student switch',
      'surface change',
      'local Leave',
      'disposal',
    ]) {
      test(
        '$boundary rejects obsolete ${reconciling ? 'GET' : 'PUT'} completion',
        () async {
          final harness = _Harness();
          await harness.flush();
          Future<void> operation;
          if (reconciling) {
            await harness.makeUncertain();
            operation = harness.controller.reloadAttempt();
          } else {
            harness.editText('Private local intent');
            operation = harness.controller.saveAnswer(_id(4));
          }
          switch (boundary) {
            case 'logout':
              harness.auth.logOut();
            case 'Student switch':
              harness.auth.replaceUser(studentUser('student-b'));
            case 'surface change':
              harness.container
                  .read(_surfaceProvider.notifier)
                  .change(AppDeviceSurface.mobile);
            case 'local Leave':
              harness.controller.clearLocalState();
            case 'disposal':
              harness.close();
          }
          if (boundary != 'disposal') await harness.flush();
          if (reconciling) {
            harness.repository.reads.single.complete(
              _attempt(shortText: 'Private local intent'),
            );
          } else {
            harness.repository.saves.single.fail(
              studentServerFailure(ApiErrorCodes.userInactive),
            );
          }
          await operation;
          if (boundary != 'disposal') {
            await harness.flush();
            expect(harness.state.hasDirtyDrafts, isFalse);
            expect(harness.state.hasUncertainMutation, isFalse);
            expect(harness.state.pendingMutationSnapshot, isNull);
            expect(
              harness.state.questions.values.any(
                (entry) => entry.saveStatus == StudentAnswerSaveStatus.saved,
              ),
              isFalse,
            );
          }
          expect(harness.auth.bootstrapCalls, 0);
          expect(harness.parent.refreshCalls, 0);
          expect(harness.repository.saves, hasLength(1));
        },
      );
    }
  }

  for (final reconciling in [false, true]) {
    test(
      'route target disposal rejects obsolete ${reconciling ? 'GET' : 'PUT'}',
      () async {
        final harness = _Harness();
        await harness.flush();
        Future<void> oldOperation;
        if (reconciling) {
          await harness.makeUncertain();
          oldOperation = harness.controller.reloadAttempt();
        } else {
          harness.editText('Old route intent');
          oldOperation = harness.controller.saveAnswer(_id(4));
        }
        harness.subscription.close();
        await harness.flush();
        final current = harness.container.listen(
          studentAttemptAnswerEditorControllerProvider(_otherTarget),
          (_, _) {},
        );
        await harness.flush();
        if (reconciling) {
          harness.repository.reads.single.complete(
            _attempt(shortText: 'Pending intent'),
          );
        } else {
          harness.repository.saves.single.complete(
            _result(
              answer: const StudentTextAnswerValue(text: 'Old route intent'),
            ),
          );
        }
        await oldOperation;
        await harness.flush();
        expect(current.read().hasDirtyDrafts, isFalse);
        expect(current.read().hasUncertainMutation, isFalse);
        expect(current.read().questions[_id(4)]!.serverAnswer, isNull);
        expect(
          current.read().questions[_id(4)]!.saveStatus,
          StudentAnswerSaveStatus.idle,
        );
        expect(harness.parent.refreshCalls, 0);
        expect(harness.repository.saves, hasLength(1));
        current.close();
      },
    );
  }

  test(
    'a newer session save cannot be completed by an old pending snapshot',
    () async {
      final harness = _Harness();
      await harness.makeUncertain();
      final oldReload = harness.controller.reloadAttempt();
      harness.auth.replaceUser(studentUser('student-b'));
      await harness.flush();
      harness.editText('New session intent');
      final newSave = harness.controller.saveAnswer(_id(4));
      final newSnapshot = harness.state.pendingMutationSnapshot;
      harness.repository.reads.single.complete(
        _attempt(shortText: 'Pending intent'),
      );
      await oldReload;
      expect(harness.state.pendingMutationSnapshot, same(newSnapshot));
      expect(
        harness.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.saving,
      );
      harness.repository.saves.last.complete(
        _result(
          answer: const StudentTextAnswerValue(text: 'New session intent'),
        ),
      );
      await newSave;
      expect(
        (harness.entry(StudentQuestionType.shortWritten).serverAnswer!
                as StudentTextAnswerValue)
            .text,
        'New session intent',
      );
      expect(harness.repository.saves, hasLength(2));
    },
  );

  test('equivalent session rebuild preserves an owned save', () async {
    final user = studentUser('student-a');
    final harness = _Harness(
      auth: FakeStudentAuthSessionController.authenticated(user),
    );
    await harness.flush();
    harness.editText('Same session');
    final save = harness.controller.saveAnswer(_id(4));
    harness.auth.replaceUser(user);
    await harness.flush();
    harness.repository.saves.single.complete(
      _result(answer: const StudentTextAnswerValue(text: 'Same session')),
    );
    await save;
    expect(
      harness.entry(StudentQuestionType.shortWritten).saveStatus,
      StudentAnswerSaveStatus.saved,
    );
  });

  test(
    'same-session invalidation lets a retained cleared editor synchronize again',
    () async {
      final h = _Harness(attempt: _attempt(shortText: 'Persisted answer'));
      await h.makeUncertain(text: 'Abandoned draft');
      final retained = h.controller;
      retained.clearLocalState();
      expect(h.state.questions, isEmpty);
      h.parent.publish(
        const StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.loading,
        ),
      );
      await h.flush();
      h.container.invalidate(
        studentAttemptAnswerEditorControllerProvider(h.target),
      );
      await h.flush();
      expect(h.controller, same(retained));
      expect(h.state.questions, isEmpty);
      expect(h.state.sourceAttemptPublication, isNull);
      final authoritative = _parentState(
        _attempt(shortText: 'Fresh persisted answer'),
      );
      h.parent.publish(authoritative);
      await h.flush();
      final restored = h.entry(StudentQuestionType.shortWritten);
      expect(
        (restored.serverAnswer! as StudentTextAnswerValue).text,
        'Fresh persisted answer',
      );
      expect(restored.isDirty, isFalse);
      expect(h.state.hasDirtyDrafts, isFalse);
      expect(h.state.hasUncertainMutation, isFalse);
      expect(h.state.activeQuestionId, isNull);
      expect(h.state.pendingMutationSnapshot, isNull);
      expect(h.state.canEdit(_id(4)), isTrue);
      expect(
        h.state.sourceAttemptPublication,
        same(authoritative.publicationToken),
      );
      expect(h.repository.saves, hasLength(1));
      expect(h.repository.reads, isEmpty);
    },
  );

  for (final reconciling in [false, true]) {
    test(
      'same-session invalidation drops editor state and rejects old ${reconciling ? 'GET' : 'PUT'}',
      () async {
        final h = _Harness(attempt: _attempt(shortText: 'Persisted answer'));
        await h.flush();
        final retained = h.controller;
        final Future<void> obsolete;
        if (reconciling) {
          await h.makeUncertain();
          obsolete = retained.reloadAttempt();
        } else {
          h.editText('Abandoned draft');
          obsolete = retained.saveAnswer(_id(4));
        }
        expect(h.state.pendingMutationSnapshot, isNotNull);
        h.container.invalidate(
          studentAttemptAnswerEditorControllerProvider(h.target),
        );
        await h.flush();
        expect(h.controller, same(retained));
        final reset = h.state;
        final restored = h.entry(StudentQuestionType.shortWritten);
        expect(
          (restored.serverAnswer! as StudentTextAnswerValue).text,
          'Persisted answer',
        );
        expect(restored.saveStatus, StudentAnswerSaveStatus.idle);
        expect(restored.isDirty, isFalse);
        expect(reset.hasUncertainMutation, isFalse);
        expect(reset.isReconciling, isFalse);
        expect(reset.activeQuestionId, isNull);
        expect(reset.pendingMutationSnapshot, isNull);
        if (reconciling) {
          h.repository.reads.single.complete(
            _attempt(shortText: 'Obsolete recovery answer'),
          );
        } else {
          h.repository.saves.single.complete(
            _result(
              answer: const StudentTextAnswerValue(text: 'Abandoned draft'),
            ),
          );
        }
        await obsolete;
        await h.flush();
        expect(h.state, same(reset));
        expect(h.parent.refreshCalls, 0);
        expect(h.repository.saves, hasLength(1));
        expect(h.repository.reads, hasLength(reconciling ? 1 : 0));
      },
    );
  }

  test(
    'Leaving uncertainty clears local state and re-entry never resends old PUT',
    () async {
      final harness = _Harness();
      await harness.makeUncertain();
      harness.controller.clearLocalState();
      expect(harness.state.hasDirtyDrafts, isFalse);
      expect(harness.state.hasUncertainMutation, isFalse);
      expect(harness.state.pendingMutationSnapshot, isNull);
      harness.subscription.close();
      await harness.flush();
      final reentry = harness.container.listen(
        studentAttemptAnswerEditorControllerProvider(harness.target),
        (_, _) {},
      );
      await harness.flush();
      expect(reentry.read().hasUncertainMutation, isFalse);
      expect(harness.repository.saves, hasLength(1));
      reentry.close();
    },
  );

  group('autosave', () {
    const second = Duration(seconds: 1);

    Future<_Harness> ready() async {
      final h = _Harness();
      await h.flush();
      return h;
    }

    test('a typed change is saved one second after the last change', () async {
      final h = await ready();
      h.editText('First');
      h.timers.elapse(const Duration(milliseconds: 600));
      h.editText('First words');
      h.timers.elapse(const Duration(milliseconds: 999));
      expect(h.repository.saves, isEmpty);
      h.timers.elapse(const Duration(milliseconds: 1));
      expect(h.repository.saves, hasLength(1));
      expect(_sentText(h.repository.saves.single), 'First words');
    });

    test('typing continues during the save and is saved afterwards', () async {
      final h = await ready();
      h.editText('Draft');
      h.timers.elapse(second);
      expect(h.state.canEdit(_id(4)), isTrue);
      h.editText('Draft plus');
      h.repository.saves.single.complete(
        _result(answer: const StudentTextAnswerValue(text: 'Draft')),
      );
      await h.flush();
      final entry = h.entry(StudentQuestionType.shortWritten);
      expect((entry.draft as StudentShortWrittenDraft).text, 'Draft plus');
      expect(entry.isDirty, isTrue);
      expect(h.repository.saves, hasLength(1));
      h.timers.elapse(second);
      await h.flush();
      expect(h.repository.saves, hasLength(2));
      expect(_sentText(h.repository.saves.last), 'Draft plus');
    });

    test('a successful save patches the Attempt instead of re-reading it', () async {
      final h = await ready();
      h.editText(' Kept spacing ');
      final draft = h.entry(StudentQuestionType.shortWritten).draft;
      h.timers.elapse(second);
      h.repository.saves.single.complete(
        _result(answer: const StudentTextAnswerValue(text: ' Kept spacing ')),
      );
      await h.flush();
      expect(h.parent.refreshCalls, 0);
      expect(h.parent.accepted, hasLength(1));
      final entry = h.entry(StudentQuestionType.shortWritten);
      expect(entry.saveStatus, StudentAnswerSaveStatus.saved);
      expect(entry.isDirty, isFalse);
      expect(entry.draft, same(draft));
      expect(
        h.state.sourceAttemptPublication,
        same(h.container
            .read(studentHomeworkAttemptControllerProvider(h.target))
            .publicationToken),
      );
    });

    test('a rejected patch falls back to one Attempt refresh', () async {
      final h = await ready();
      h.parent.acceptsMutations = false;
      h.editText('Answer');
      h.timers.elapse(second);
      h.repository.saves.single.complete(
        _result(answer: const StudentTextAnswerValue(text: 'Answer')),
      );
      await h.flush();
      expect(h.parent.refreshCalls, 1);
    });

    test('one save at a time, in the order Questions first changed', () async {
      final h = await ready();
      h.edit(
        StudentQuestionType.openWritten,
        const StudentTextAnswerValue(text: 'Open first'),
      );
      h.editText('Short second');
      h.timers.elapse(second);
      expect(h.repository.saves, hasLength(1));
      expect(h.repository.saves.single.question.id, _id(5));
      h.repository.saves.single.complete(
        _result(
          questionId: _id(5),
          type: StudentQuestionType.openWritten,
          answer: const StudentTextAnswerValue(text: 'Open first'),
        ),
      );
      await h.flush();
      expect(h.repository.saves, hasLength(2));
      expect(h.repository.saves.last.question.id, _id(4));
    });

    test('leaving a text field saves it at once', () async {
      final h = await ready();
      h.editText('Focus left');
      h.controller.saveNow(_id(4));
      expect(h.repository.saves, hasLength(1));
      expect(h.timers.pendingCount, 0);
    });

    test('saveAllNow sends every dirty valid Question without waiting', () async {
      final h = await ready();
      h.editText('Short');
      h.edit(
        StudentQuestionType.openWritten,
        const StudentTextAnswerValue(text: 'Open'),
      );
      h.controller.saveAllNow();
      expect(h.repository.saves, hasLength(1));
      h.repository.saves.single.complete(
        _result(answer: const StudentTextAnswerValue(text: 'Short')),
      );
      await h.flush();
      expect(h.repository.saves, hasLength(2));
    });

    test('an invalid draft is not sent until it becomes valid', () async {
      final h = await ready();
      h.edit(
        StudentQuestionType.shortWritten,
        StudentTextAnswerValue(text: 'x' * 1001),
      );
      h.timers.elapse(second);
      h.controller.saveAllNow();
      expect(h.repository.saves, isEmpty);
      h.editText('Valid');
      h.timers.elapse(second);
      expect(h.repository.saves, hasLength(1));
    });

    test('an uncertain save recovers automatically and keeps new typing', () async {
      final h = await ready();
      h.editText('Sent');
      h.timers.elapse(second);
      h.repository.saves.single.fail(studentLocalFailure(ApiFailureKind.timeout));
      await h.flush();
      expect(h.state.hasUncertainMutation, isTrue);
      expect(h.state.canEdit(_id(4)), isTrue);
      h.editText('Sent and more');
      h.timers.elapse(const Duration(milliseconds: 1999));
      expect(h.repository.reads, isEmpty);
      h.timers.elapse(const Duration(milliseconds: 1));
      expect(h.repository.reads, hasLength(1));
      h.repository.reads.single.complete(_attempt(shortText: 'Sent'));
      await h.flush();
      expect(h.state.hasUncertainMutation, isFalse);
      expect(h.parent.refreshCalls, 1);
      h.parent.publish(_parentState(_attempt(shortText: 'Sent')));
      await h.flush();
      final entry = h.entry(StudentQuestionType.shortWritten);
      expect((entry.draft as StudentShortWrittenDraft).text, 'Sent and more');
      expect(
        (entry.serverAnswer! as StudentTextAnswerValue).text,
        'Sent',
      );
      expect(h.repository.saves, hasLength(2));
      expect(_sentText(h.repository.saves.last), 'Sent and more');
    });

    test('recovery backs off while it stays uncertain', () async {
      final h = await ready();
      h.editText('Sent');
      h.timers.elapse(second);
      h.repository.saves.single.fail(studentLocalFailure(ApiFailureKind.timeout));
      await h.flush();
      h.timers.elapse(const Duration(seconds: 2));
      h.repository.reads.single.fail(
        studentLocalFailure(ApiFailureKind.connection),
      );
      await h.flush();
      expect(h.timers.pendingDelays, [const Duration(seconds: 4)]);
    });

    test('a validation rejection is not resent until the draft changes', () async {
      final h = await ready();
      h.editText('Rejected');
      h.timers.elapse(second);
      h.repository.saves.single.fail(
        studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
      );
      await h.flush();
      expect(
        h.entry(StudentQuestionType.shortWritten).saveStatus,
        StudentAnswerSaveStatus.failure,
      );
      h.controller.saveAllNow();
      h.timers.elapse(const Duration(minutes: 1));
      expect(h.repository.saves, hasLength(1));
      h.editText('Changed');
      h.timers.elapse(second);
      expect(h.repository.saves, hasLength(2));
    });

    test('flushAll saves pending changes, locks editing and succeeds', () async {
      final h = await ready();
      h.editText('Before Submit');
      final flush = h.controller.flushAll();
      expect(h.state.isFlushing, isTrue);
      expect(h.state.canEdit(_id(4)), isFalse);
      expect(h.repository.saves, hasLength(1));
      h.repository.saves.single.complete(
        _result(answer: const StudentTextAnswerValue(text: 'Before Submit')),
      );
      expect(await flush, isTrue);
      expect(h.state.isFlushing, isFalse);
      expect(h.state.hasDirtyDrafts, isFalse);
    });

    test('flushAll stops on an uncertain save and on cancel', () async {
      final h = await ready();
      h.editText('Before Submit');
      final uncertain = h.controller.flushAll();
      h.repository.saves.single.fail(studentLocalFailure(ApiFailureKind.timeout));
      expect(await uncertain, isFalse);
      expect(h.state.isFlushing, isFalse);

      final other = await ready();
      other.editText('Cancelled');
      final cancelled = other.controller.flushAll();
      other.controller.cancelFlush();
      expect(await cancelled, isFalse);
      expect(other.state.canEdit(_id(4)), isTrue);
    });

    test('flushAll stops on an invalid draft', () async {
      final h = await ready();
      h.edit(
        StudentQuestionType.shortWritten,
        StudentTextAnswerValue(text: 'x' * 1001),
      );
      expect(await h.controller.flushAll(), isFalse);
      expect(h.repository.saves, isEmpty);
    });

    test('pending timers stop when the editor is disposed', () async {
      final h = await ready();
      h.editText('Unsent');
      expect(h.timers.pendingCount, 1);
      h.close();
      expect(h.timers.pendingCount, 0);
    });

    test('a terminal Attempt drops pending autosave', () async {
      final h = await ready();
      h.editText('Too late');
      h.parent.publish(
        _parentState(
          _attempt(status: StudentHomeworkAttemptStatus.submitted),
        ),
      );
      await h.flush();
      expect(h.timers.pendingCount, 0);
      h.timers.elapse(const Duration(minutes: 1));
      expect(h.repository.saves, isEmpty);
    });

    test('a clean Question shows a value saved elsewhere', () async {
      final h = await ready();
      h.parent.publish(_parentState(_attempt(shortText: 'From other device')));
      await h.flush();
      final entry = h.entry(StudentQuestionType.shortWritten);
      expect(
        (entry.draft as StudentShortWrittenDraft).text,
        'From other device',
      );
      expect(entry.isDirty, isFalse);
      h.timers.elapse(const Duration(minutes: 1));
      expect(h.repository.saves, isEmpty);
    });
  });
}

void _expectTerminal(_Harness harness, String text) {
  expect(harness.state.hasDirtyDrafts, isFalse);
  expect(harness.state.hasUncertainMutation, isFalse);
  expect(harness.state.isReconciling, isFalse);
  expect(harness.state.pendingMutationSnapshot, isNull);
  expect(harness.state.canSave(_id(4)), isFalse);
  expect(harness.state.canEdit(_id(4)), isFalse);
  final terminal = harness.state.terminalAttempt;
  expect(terminal, isNotNull);
  expect(terminal!.status, StudentHomeworkAttemptStatus.submitted);
  expect(
    (terminal.answers.singleWhere((answer) => answer.questionId == _id(4)).value
            as StudentTextAnswerValue)
        .text,
    text,
  );
}

class _Harness {
  _Harness({
    StudentHomeworkAttempt? attempt,
    FakeStudentAuthSessionController? auth,
  }) : auth =
           auth ??
           FakeStudentAuthSessionController.authenticated(
             studentUser('student-a'),
           ) {
    final initialParentState = _parentState(attempt ?? _attempt());
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWith(
          (ref) => ref.watch(_surfaceProvider),
        ),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(repository),
        studentAutosaveTimerFactoryProvider.overrideWithValue(timers.factory),
        studentHomeworkAttemptControllerProvider(target).overrideWith(() {
          parent = _Parent(target, initialParentState);
          return parent;
        }),
        studentHomeworkAttemptControllerProvider(_otherTarget).overrideWith(
          () => _Parent(
            _otherTarget,
            _parentState(_attempt(id: _otherAttemptId)),
          ),
        ),
        studentHomeworkDetailControllerProvider(_homeworkTarget).overrideWith(
          () {
            detail = _Detail(_homeworkTarget, () => detailBuilds += 1);
            return detail;
          },
        ),
      ],
    );
    container.listen(
      studentHomeworkDetailControllerProvider(_homeworkTarget),
      (_, _) {},
    );
    subscription = container.listen(
      studentAttemptAnswerEditorControllerProvider(target),
      (_, _) {},
    );
    addTearDown(close);
  }

  final target = StudentHomeworkAttemptRouteTarget(
    topicId: studentTopicId,
    homeworkId: _homeworkId,
    attemptId: _attemptId,
  );
  final FakeStudentAuthSessionController auth;
  final repository = _Repository();
  final timers = FakeAutosaveTimers();
  late final ProviderContainer container;
  late _Parent parent;
  late _Detail detail;
  var detailBuilds = 0;
  late final ProviderSubscription<StudentAttemptAnswerEditorState> subscription;
  var closed = false;

  StudentAttemptAnswerEditorState get state => subscription.read();
  StudentAttemptAnswerEditorController get controller => container.read(
    studentAttemptAnswerEditorControllerProvider(target).notifier,
  );
  StudentQuestion question(StudentQuestionType type) => state.questions.values
      .singleWhere((entry) => entry.question.type == type)
      .question;
  StudentQuestionAnswerEditorState entry(StudentQuestionType type) =>
      state.questions[question(type).id]!;
  void edit(StudentQuestionType type, StudentAttemptAnswerValue value) {
    final currentQuestion = question(type);
    controller.updateDraft(
      currentQuestion.id,
      StudentAnswerDraft.fromAnswer(currentQuestion, value),
    );
  }

  void editText(String text) => edit(
    StudentQuestionType.shortWritten,
    StudentTextAnswerValue(text: text),
  );
  Future<void> makeUncertain({
    String text = 'Pending intent',
    ApiFailureKind kind = ApiFailureKind.timeout,
  }) async {
    await flush();
    editText(text);
    final save = controller.saveAnswer(_id(4));
    repository.saves.last.fail(studentLocalFailure(kind));
    await save;
    await flush();
  }

  Future<void> flush() async {
    await Future<void>.value();
    await container.pump();
    await Future<void>.value();
    await container.pump();
  }

  void close() {
    if (!closed) {
      closed = true;
      container.dispose();
    }
  }
}

class _Parent extends StudentHomeworkAttemptController {
  _Parent(super.target, this.initial);
  final StudentHomeworkAttemptState initial;
  var refreshCalls = 0;
  @override
  StudentHomeworkAttemptState build() => initial;
  @override
  void refresh() => refreshCalls += 1;
  void publish(StudentHomeworkAttemptState next) => state = next;

  final accepted = <StudentAttemptAnswerMutationResult>[];
  var acceptsMutations = true;
  @override
  bool acceptAnswerMutation({
    required String questionId,
    required StudentAttemptAnswerMutationResult result,
    required StudentHomeworkAttemptPublicationToken? expectedReadToken,
  }) {
    final attempt = state.attempt;
    if (!acceptsMutations ||
        attempt == null ||
        !identical(expectedReadToken, state.readToken)) {
      return false;
    }
    accepted.add(result);
    state = StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.data,
      attempt: _withAnswer(attempt, result),
      publicationToken: StudentHomeworkAttemptPublicationToken(),
      readToken: state.readToken,
    );
    return true;
  }
}

String _sentText(_SaveRequest request) =>
    (request.mutation as StudentShortWrittenMutation).text;

StudentHomeworkAttempt _withAnswer(
  StudentHomeworkAttempt attempt,
  StudentAttemptAnswerMutationResult result,
) => StudentHomeworkAttempt(
  id: attempt.id,
  assessmentId: attempt.assessmentId,
  attemptNumber: attempt.attemptNumber,
  status: attempt.status,
  startedAt: attempt.startedAt,
  submittedAt: attempt.submittedAt,
  finalizedAt: attempt.finalizedAt,
  finalizationReason: attempt.finalizationReason,
  deadlineAt: attempt.deadlineAt,
  questions: attempt.questions,
  answers: [
    for (final answer in attempt.answers)
      if (answer.questionId.toLowerCase() != result.questionId.toLowerCase())
        answer,
    if (result.answer case final value?)
      StudentAttemptAnswerState(
        questionId: result.questionId,
        type: result.type,
        value: value,
        updatedAt: result.updatedAt!,
      ),
  ],
);

class _Detail extends StudentHomeworkDetailController {
  _Detail(super.target, this.onBuild);
  final void Function() onBuild;
  var refreshCalls = 0;
  @override
  StudentHomeworkDetailState build() {
    onBuild();
    return const StudentHomeworkDetailState();
  }

  @override
  void refresh() => refreshCalls += 1;
}

final _surfaceProvider = NotifierProvider<_Surface, AppDeviceSurface>(
  _Surface.new,
);

class _Surface extends Notifier<AppDeviceSurface> {
  @override
  AppDeviceSurface build() => AppDeviceSurface.desktop;
  void change(AppDeviceSurface value) => state = value;
}

class _Repository implements StudentHomeworkAttemptRepository {
  @override
  Future<StudentHomeworkSubmitResult> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  ) => throw StateError(
    'This regression must not submit a Student Homework Attempt.',
  );

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) =>
      throw StateError('This regression must not upload Student file answers.');

  final saves = <_SaveRequest>[];
  final reads = <_ReadRequest>[];
  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) {
    final request = _SaveRequest(attemptId, question, mutation);
    saves.add(request);
    return request.completer.future;
  }

  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) {
    final request = _ReadRequest(attemptId);
    reads.add(request);
    return request.completer.future;
  }

  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) => throw StateError('Answer editing must not Start an Attempt.');
}

class _SaveRequest {
  _SaveRequest(this.attemptId, this.question, this.mutation);
  final String attemptId;
  final StudentQuestion question;
  final StudentAnswerMutation mutation;
  final completer = Completer<StudentAttemptAnswerMutationResult>();
  void complete(StudentAttemptAnswerMutationResult result) =>
      completer.complete(result);
  void fail(Object failure) => completer.completeError(failure);
}

class _ReadRequest {
  _ReadRequest(this.attemptId);
  final String attemptId;
  final completer = Completer<StudentHomeworkAttempt>();
  void complete(StudentHomeworkAttempt attempt) => completer.complete(attempt);
  void fail(Object failure) => completer.completeError(failure);
}

final _homeworkTarget = StudentHomeworkRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
);
final _otherTarget = StudentHomeworkAttemptRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
  attemptId: _otherAttemptId,
);
StudentHomeworkAttemptState _parentState(StudentHomeworkAttempt? attempt) =>
    StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.data,
      attempt: attempt,
      publicationToken: StudentHomeworkAttemptPublicationToken(),
      readToken: StudentHomeworkAttemptPublicationToken(),
    );
StudentAttemptAnswerMutationResult _result({
  String? questionId,
  StudentQuestionType type = StudentQuestionType.shortWritten,
  required StudentAttemptAnswerValue? answer,
}) => StudentAttemptAnswerMutationResult(
  questionId: questionId ?? _id(4),
  type: type,
  answer: answer,
  updatedAt: answer == null ? null : _updatedAt,
);
String _id(int suffix) =>
    '7abcdef0-0000-0000-0000-${suffix.toString().padLeft(12, '0')}';

const _clearableTypes = [
  StudentQuestionType.multipleChoice,
  StudentQuestionType.shortWritten,
  StudentQuestionType.openWritten,
  StudentQuestionType.matching,
  StudentQuestionType.ordering,
  StudentQuestionType.fillInBlank,
];

List<StudentQuestion> _questions({int maxSelections = 2}) {
  final structures = <StudentAnswerUi>[
    StudentChoiceAnswerUi(
      options: [
        StudentChoiceOption(id: _id(11), text: 'A'),
        StudentChoiceOption(id: _id(12), text: 'B'),
      ],
    ),
    StudentChoiceAnswerUi(
      options: [
        StudentChoiceOption(id: _id(21), text: 'A'),
        StudentChoiceOption(id: _id(22), text: 'B'),
        StudentChoiceOption(id: _id(23), text: 'C'),
      ],
      maxSelections: maxSelections,
    ),
    const StudentEmptyAnswerUi(),
    const StudentEmptyAnswerUi(),
    const StudentEmptyAnswerUi(),
    StudentFileAnswerUi(allowedExtensions: ['pdf'], maxSizeBytes: 1024),
    StudentMatchingAnswerUi(
      leftItems: [
        StudentMatchingItem(id: _id(71), text: 'Left A'),
        StudentMatchingItem(id: _id(72), text: 'Left B'),
      ],
      rightItems: [
        StudentMatchingItem(id: _id(81), text: 'Right A'),
        StudentMatchingItem(id: _id(82), text: 'Right B'),
      ],
    ),
    StudentOrderingAnswerUi(
      items: [
        StudentOrderingItem(id: _id(91), text: 'A'),
        StudentOrderingItem(id: _id(92), text: 'B'),
      ],
    ),
    StudentFillBlankAnswerUi(
      blanks: [
        StudentFillBlank(id: _id(101), key: 'first', position: 1),
        StudentFillBlank(id: _id(102), key: 'second', position: 2),
      ],
    ),
  ];
  return [
    for (var index = 0; index < StudentQuestionType.values.length; index++)
      StudentQuestion(
        id: _id(index + 1),
        type: StudentQuestionType.values[index],
        prompt: 'Question ${index + 1}',
        instructions: null,
        points: 1,
        position: index + 1,
        answerUi: structures[index],
      ),
  ];
}

StudentAttemptAnswerValue _savedValue(StudentQuestionType type) =>
    switch (type) {
      StudentQuestionType.singleChoice => StudentChoiceAnswerValue(
        selectedOptionIds: [_id(11)],
      ),
      StudentQuestionType.multipleChoice => StudentChoiceAnswerValue(
        selectedOptionIds: [_id(21), _id(22)],
      ),
      StudentQuestionType.trueFalse => const StudentBooleanAnswerValue(
        value: false,
      ),
      StudentQuestionType.shortWritten => const StudentTextAnswerValue(
        text: ' Saved short ',
      ),
      StudentQuestionType.openWritten => const StudentTextAnswerValue(
        text: ' Saved open\nanswer ',
      ),
      StudentQuestionType.fileBased => StudentFileAnswerValue(
        file: StudentSubmissionFile(
          id: _id(61),
          originalName: 'saved.pdf',
          extension: 'pdf',
          sizeBytes: 128,
        ),
      ),
      StudentQuestionType.matching => StudentMatchingAnswerValue(
        pairs: [
          StudentMatchingAnswerPair(leftItemId: _id(71), rightItemId: _id(81)),
          StudentMatchingAnswerPair(leftItemId: _id(72), rightItemId: _id(82)),
        ],
      ),
      StudentQuestionType.ordering => StudentOrderingAnswerValue(
        items: [
          StudentOrderingAnswerItem(itemId: _id(91), position: 2),
          StudentOrderingAnswerItem(itemId: _id(92), position: 1),
        ],
      ),
      StudentQuestionType.fillInBlank => StudentFillBlankAnswerValue(
        values: [
          StudentFillBlankAnswerEntry(blankId: _id(101), text: ' One '),
          StudentFillBlankAnswerEntry(blankId: _id(102), text: 'Two'),
        ],
      ),
    };

StudentHomeworkAttempt _attempt({
  String id = _attemptId,
  String homeworkId = _homeworkId,
  bool saved = false,
  String? shortText,
  int maxSelections = 2,
  List<StudentQuestion>? questions,
  StudentHomeworkAttemptStatus status = StudentHomeworkAttemptStatus.inProgress,
}) {
  final currentQuestions =
      questions ?? _questions(maxSelections: maxSelections);
  return StudentHomeworkAttempt(
    id: id,
    assessmentId: homeworkId,
    attemptNumber: 1,
    status: status,
    startedAt: DateTime.utc(2026, 9, 1),
    submittedAt: status == StudentHomeworkAttemptStatus.inProgress
        ? null
        : _updatedAt,
    finalizedAt: status == StudentHomeworkAttemptStatus.inProgress
        ? null
        : _updatedAt,
    finalizationReason: status == StudentHomeworkAttemptStatus.inProgress
        ? null
        : StudentHomeworkAttemptFinalizationReason.studentSubmit,
    deadlineAt: null,
    questions: currentQuestions,
    answers: [
      for (final question in currentQuestions)
        if (saved ||
            question.type == StudentQuestionType.shortWritten &&
                shortText != null)
          StudentAttemptAnswerState(
            questionId: question.id,
            type: question.type,
            value:
                question.type == StudentQuestionType.shortWritten &&
                    shortText != null
                ? StudentTextAnswerValue(text: shortText)
                : _savedValue(question.type),
            updatedAt: _updatedAt,
          ),
    ],
  );
}

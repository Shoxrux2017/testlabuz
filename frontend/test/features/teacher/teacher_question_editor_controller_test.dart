import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_builder_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_builder_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_editor_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_editor_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_authoring.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherQuestionEditorController initialization', () {
    test('initializes the documented Add Question draft', () async {
      final harness = _EditorHarness(
        initialHomework: teacherHomework(questions: const []),
      );
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.add,
      );
      await flushTeacherControllers();

      final state = subscription.read();
      final draft = state.draft!;
      final configuration =
          draft.configurationDraft as TeacherChoiceConfigurationDraft;
      expect(state.status, TeacherQuestionEditorStatus.editing);
      expect(state.initialDraft, same(draft));
      expect(draft.type, TeacherQuestionType.singleChoice);
      expect(draft.prompt, isEmpty);
      expect(draft.instructions, isEmpty);
      expect(draft.pointsText, '1');
      expect(draft.checkingMode, TeacherQuestionCheckingMode.automatic);
      expect(configuration.options, hasLength(2));
      expect(configuration.options.map((option) => option.text), ['', '']);
      expect(configuration.options.map((option) => option.isCorrect), [
        true,
        false,
      ]);
      expect(state.isDirty, isFalse);
      expect(state.canSubmit, isTrue);
    });

    test('converts authoritative readback for all nine types', () async {
      final questions = teacherHomeworkQuestions();
      final cases =
          <
            ({
              TeacherQuestion question,
              Type draftType,
              void Function(TeacherQuestionDraft draft) verify,
            })
          >[
            (
              question: questions[0],
              draftType: TeacherChoiceConfigurationDraft,
              verify: (draft) {
                final value =
                    draft.configurationDraft as TeacherChoiceConfigurationDraft;
                expect(value.options.map((option) => option.text), [
                  'Four',
                  'Five',
                ]);
                expect(value.options.map((option) => option.isCorrect), [
                  true,
                  false,
                ]);
              },
            ),
            (
              question: questions[1],
              draftType: TeacherChoiceConfigurationDraft,
              verify: (draft) {
                final value =
                    draft.configurationDraft as TeacherChoiceConfigurationDraft;
                expect(value.options.map((option) => option.text), [
                  'Two',
                  'Three',
                  'Four',
                ]);
              },
            ),
            (
              question: questions[2],
              draftType: TeacherTrueFalseConfigurationDraft,
              verify: (draft) => expect(
                (draft.configurationDraft as TeacherTrueFalseConfigurationDraft)
                    .correctValue,
                isTrue,
              ),
            ),
            (
              question: questions[3],
              draftType: TeacherShortWrittenConfigurationDraft,
              verify: (draft) => expect(
                (draft.configurationDraft
                        as TeacherShortWrittenConfigurationDraft)
                    .acceptedAnswers
                    .map((answer) => answer.text),
                ['Addition', 'Add'],
              ),
            ),
            (
              question: questions[5],
              draftType: TeacherEmptyConfigurationDraft,
              verify: (draft) => expect(
                draft.checkingMode,
                TeacherQuestionCheckingMode.manual,
              ),
            ),
            (
              question: questions[6],
              draftType: TeacherFileBasedConfigurationDraft,
              verify: (draft) => expect(
                TeacherFileBasedConfigurationDraft.allowedExtensions,
                ['pdf', 'docx', 'ppt', 'pptx'],
              ),
            ),
            (
              question: questions[7],
              draftType: TeacherMatchingConfigurationDraft,
              verify: (draft) {
                final pair =
                    (draft.configurationDraft
                            as TeacherMatchingConfigurationDraft)
                        .pairs
                        .single;
                expect((pair.left, pair.right), ('2 + 2', '4'));
                expect(pair.localId, startsWith('question_row_'));
              },
            ),
            (
              question: questions[8],
              draftType: TeacherOrderingConfigurationDraft,
              verify: (draft) => expect(
                (draft.configurationDraft as TeacherOrderingConfigurationDraft)
                    .items
                    .map((item) => item.text),
                ['Simplify', 'Solve'],
              ),
            ),
            (
              question: questions[9],
              draftType: TeacherFillInBlankConfigurationDraft,
              verify: (draft) {
                final blank =
                    (draft.configurationDraft
                            as TeacherFillInBlankConfigurationDraft)
                        .blanks
                        .single;
                expect(blank.key, 'sum');
                expect(blank.acceptedAnswers.map((answer) => answer.text), [
                  'Four',
                  '4',
                ]);
              },
            ),
          ];
      final harness = _EditorHarness(
        initialHomework: teacherHomework(questions: questions),
      );
      await harness.prepareRoute();

      for (var index = 0; index < cases.length; index += 1) {
        final testCase = cases[index];
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: testCase.question.id,
          editorGeneration: index + 1,
        );
        await flushTeacherControllers();

        final state = subscription.read();
        expect(
          state.status,
          TeacherQuestionEditorStatus.editing,
          reason: testCase.question.type.value,
        );
        expect(state.draft!.type, testCase.question.type);
        expect(state.draft!.prompt, testCase.question.prompt);
        expect(state.draft!.instructions, testCase.question.instructions ?? '');
        expect(
          state.draft!.pointsText,
          formatTeacherQuestionPoints(testCase.question.points),
        );
        expect(state.draft!.configurationDraft.runtimeType, testCase.draftType);
        testCase.verify(state.draft!);
        subscription.close();
      }
    });

    test('requires confirmation and resets only type configuration', () async {
      final harness = _EditorHarness(
        initialHomework: teacherHomework(questions: const []),
      );
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.add,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.add,
      );
      controller
        ..updatePrompt('Kept prompt')
        ..updateInstructions('Kept instructions')
        ..updatePoints('2.5')
        ..updateChoiceText(0, 'Meaningful answer');

      expect(
        controller.requestTypeChange(TeacherQuestionType.openWritten),
        isTrue,
      );
      expect(subscription.read().pendingType, TeacherQuestionType.openWritten);
      expect(subscription.read().draft!.type, TeacherQuestionType.singleChoice);

      controller.cancelTypeChange();
      expect(subscription.read().pendingType, isNull);
      expect(
        controller.requestTypeChange(TeacherQuestionType.openWritten),
        isTrue,
      );
      controller.confirmTypeChange();

      final draft = subscription.read().draft!;
      expect(draft.type, TeacherQuestionType.openWritten);
      expect(draft.checkingMode, TeacherQuestionCheckingMode.manual);
      expect(draft.configurationDraft, isA<TeacherEmptyConfigurationDraft>());
      expect(draft.prompt, 'Kept prompt');
      expect(draft.instructions, 'Kept instructions');
      expect(draft.pointsText, '2.5');
      expect(subscription.read().pendingType, isNull);
    });

    test('confirms destructive Short Written mode reset', () async {
      final question = teacherHomeworkQuestions()[3];
      final harness = _EditorHarness(
        initialHomework: teacherHomework(questions: [question]),
      );
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );

      expect(
        controller.requestCheckingModeChange(
          TeacherQuestionCheckingMode.manual,
        ),
        isTrue,
      );
      expect(
        subscription.read().draft!.checkingMode,
        TeacherQuestionCheckingMode.automatic,
      );
      controller.confirmCheckingModeChange();
      expect(
        subscription.read().draft!.configurationDraft,
        isA<TeacherEmptyConfigurationDraft>(),
      );

      expect(
        controller.requestCheckingModeChange(
          TeacherQuestionCheckingMode.automatic,
        ),
        isFalse,
      );
      final configuration =
          subscription.read().draft!.configurationDraft
              as TeacherShortWrittenConfigurationDraft;
      expect(configuration.acceptedAnswers, hasLength(1));
      expect(configuration.acceptedAnswers.single.text, isEmpty);
    });
  });

  group('TeacherQuestionEditorController submit', () {
    test('keeps local validation failures in the editor', () async {
      final harness = _EditorHarness(
        initialHomework: teacherHomework(questions: const []),
      );
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.add,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.add,
      );

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherQuestionEditorStatus.localValidationFailure,
      );
      expect(
        subscription.read().fieldErrors.keys,
        containsAll([
          TeacherQuestionDraftField.prompt,
          TeacherQuestionDraftField.configuration,
        ]),
      );
      expect(harness.repository.addQuestionRequests, isEmpty);
    });

    test('blocks add at the latest authoritative 100 Question limit', () async {
      final questions = _oneHundredQuestions();
      final harness = _EditorHarness(
        initialHomework: teacherHomework(questions: questions),
      );
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.add,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.add,
      );
      _completeChoiceDraft(controller);

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherQuestionEditorStatus.definiteFailure,
      );
      expect(subscription.read().formError, 'Maximum 100 Questions.');
      expect(harness.repository.addQuestionRequests, isEmpty);
    });

    test(
      'add uses latest authoritative count plus one and accepts response',
      () async {
        final initialQuestions = [teacherHomeworkQuestions()[0]];
        late TeacherHomework returned;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(questions: initialQuestions),
          onAddQuestion: (_, _) async => returned,
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.add,
        );
        await flushTeacherControllers();
        final latestQuestions = teacherHomeworkQuestions().take(2).toList();
        harness.acceptAuthoritative(
          teacherHomework(questions: latestQuestions, totalPossiblePoints: 3),
        );
        await flushTeacherControllers();
        final controller = harness.editorController(
          mode: TeacherQuestionEditorMode.add,
        );
        _completeChoiceDraft(controller);
        returned = teacherHomework(
          questions: [...latestQuestions, teacherHomeworkQuestions()[2]],
          totalPossiblePoints: 4,
        );

        await controller.submit();
        await flushTeacherControllers();

        expect(repository.addQuestionRequests, hasLength(1));
        expect(repository.addQuestionRequests.single.request.position, 3);
        expect(
          repository.addQuestionRequests.single.request.prompt,
          'New prompt',
        );
        expect(
          subscription.read().status,
          TeacherQuestionEditorStatus.confirmedSuccess,
        );
        expect(harness.currentDetail, same(returned));
        expect(harness.builderState.notice, 'Question created successfully.');
      },
    );

    test('edit target vanished from latest Homework sends no PATCH', () async {
      final question = teacherHomeworkQuestions().first;
      final harness = _EditorHarness(
        initialHomework: teacherHomework(questions: [question]),
      );
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      controller.updatePrompt('Unsaved prompt');
      harness.acceptAuthoritative(teacherHomework(questions: const []));
      await flushTeacherControllers();

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherQuestionEditorStatus.unavailable,
      );
      expect(
        subscription.read().formError,
        'This Question is no longer available.',
      );
      expect(harness.repository.updateQuestionRequests, isEmpty);
    });

    test('semantic no-op edit sends no PATCH', () async {
      final question = teacherHomeworkQuestions().first;
      final harness = _EditorHarness(
        initialHomework: teacherHomework(questions: [question]),
      );
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      await flushTeacherControllers();

      await harness
          .editorController(
            mode: TeacherQuestionEditorMode.edit,
            questionId: question.id,
          )
          .submit();

      expect(harness.repository.updateQuestionRequests, isEmpty);
      expect(subscription.read().formError, 'No changes to save.');
      expect(subscription.read().status, TeacherQuestionEditorStatus.editing);
    });

    test(
      'confirmed edit publishes the complete authoritative Homework',
      () async {
        final question = teacherHomeworkQuestions().first;
        final updatedQuestion = _copyQuestion(
          question,
          prompt: 'Updated prompt',
        );
        final returned = teacherHomework(
          questions: [updatedQuestion],
          totalPossiblePoints: 77,
        );
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(questions: [question]),
          onUpdateQuestion: (_, _) async => returned,
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        await flushTeacherControllers();
        final controller = harness.editorController(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        controller.updatePrompt('Updated prompt');

        await controller.submit();
        await flushTeacherControllers();

        expect(repository.updateQuestionRequests, hasLength(1));
        expect(repository.updateQuestionRequests.single.request.toJson(), {
          'prompt': 'Updated prompt',
        });
        expect(
          subscription.read().status,
          TeacherQuestionEditorStatus.confirmedSuccess,
        );
        expect(harness.currentDetail, same(returned));
        expect(harness.currentDetail!.totalPossiblePoints, 77);
      },
    );

    test(
      'newer detail state forces confirmed update through reconciliation GET',
      () async {
        final question = teacherHomeworkQuestions().first;
        final initial = teacherHomework(
          questions: [question],
          totalPossiblePoints: 1,
        );
        final newerDetail = teacherHomework(
          title: 'Newer detail authority',
          questions: [_copyQuestion(question, prompt: 'Newer detail prompt')],
          totalPossiblePoints: 30,
        );
        final olderMutationResponse = teacherHomework(
          title: 'Older mutation response',
          questions: [_copyQuestion(question, prompt: 'Submitted prompt')],
          totalPossiblePoints: 2,
        );
        final reconciled = teacherHomework(
          title: 'Post-response GET authority',
          questions: [_copyQuestion(question, prompt: 'Server final prompt')],
          totalPossiblePoints: 44,
        );
        final pending = Completer<TeacherHomework>();
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return fetchCount == 1 ? initial : reconciled;
          },
          onUpdateQuestion: (_, _) => pending.future,
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        await flushTeacherControllers();
        final controller = harness.editorController(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        controller.updatePrompt('Submitted prompt');

        final submission = controller.submit();
        harness.acceptAuthoritative(newerDetail);
        await flushTeacherControllers();
        expect(harness.currentDetail, same(newerDetail));

        pending.complete(olderMutationResponse);
        await submission;
        await flushTeacherControllers();

        expect(fetchCount, 2);
        expect(repository.updateQuestionRequests, hasLength(1));
        expect(
          subscription.read().status,
          TeacherQuestionEditorStatus.confirmedSuccess,
        );
        expect(harness.currentDetail, same(reconciled));
        expect(harness.currentDetail, isNot(same(olderMutationResponse)));
        expect(harness.currentDetail!.totalPossiblePoints, 44);
        expect(harness.builderState.notice, 'Question updated successfully.');
      },
    );

    test('422 maps common and nested configuration fields safely', () async {
      final question = teacherHomeworkQuestions().first;
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => teacherHomework(questions: [question]),
        onUpdateQuestion: (_, _) async => throw ApiRequestException(
          ApiFailure(
            kind: ApiFailureKind.validation,
            statusCode: 422,
            serverCode: ApiErrorCodes.validationFailed,
            message: 'Raw validation response.',
            fieldErrors: const {
              'prompt': ['Raw prompt detail.'],
              'configuration.options.0.text': ['Raw option detail.'],
            },
          ),
        ),
      );
      final harness = _EditorHarness(repository: repository);
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      controller.updatePrompt('Updated prompt');

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherQuestionEditorStatus.serverValidationFailure,
      );
      expect(subscription.read().fieldErrors, {
        TeacherQuestionDraftField.prompt: 'Review the Question prompt.',
        TeacherQuestionDraftField.configuration:
            'Review the Question configuration.',
      });
      expect(subscription.read().draft!.prompt, 'Updated prompt');
      expect(subscription.read().formError, isNull);
    });
  });

  group('TeacherQuestionEditorController conflict reconciliation', () {
    test(
      'business and result-pair conflicts lock this Builder instance',
      () async {
        for (final code in [
          ApiErrorCodes.businessConflict,
          ApiErrorCodes.resultPairLocked,
        ]) {
          final question = teacherHomeworkQuestions().first;
          var fetchCount = 0;
          final current = teacherHomework(questions: [question]);
          final repository = FakeTeacherHomeworkRepository(
            onFetch: (_) async {
              fetchCount += 1;
              return current;
            },
            onUpdateQuestion: (_, _) async =>
                throw teacherServerFailure(code, statusCode: 409),
          );
          final harness = _EditorHarness(repository: repository);
          await harness.prepareRoute();
          final subscription = harness.listenEditor(
            mode: TeacherQuestionEditorMode.edit,
            questionId: question.id,
          );
          await flushTeacherControllers();
          final controller = harness.editorController(
            mode: TeacherQuestionEditorMode.edit,
            questionId: question.id,
          );
          controller.updatePrompt('Attempted prompt');

          await controller.submit();
          await flushTeacherControllers();

          expect(fetchCount, 2, reason: code);
          expect(
            subscription.read().status,
            TeacherQuestionEditorStatus.lockedReview,
            reason: code,
          );
          expect(harness.builderState.serverLocked, isTrue, reason: code);
          expect(
            subscription.read().formError,
            contains('locked by the current server state'),
            reason: code,
          );
        }
      },
    );

    test('scoreable-points conflict preserves draft without locking', () async {
      final question = teacherHomeworkQuestions().first;
      final current = teacherHomework(
        status: TeacherHomeworkStatus.active,
        questions: [question],
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => current,
        onUpdateQuestion: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.assessmentHasNoScoreablePoints,
          statusCode: 409,
        ),
      );
      final harness = _EditorHarness(repository: repository);
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      controller.updatePoints('0');

      await controller.submit();
      await flushTeacherControllers();

      expect(
        subscription.read().status,
        TeacherQuestionEditorStatus.definiteFailure,
      );
      expect(
        subscription.read().formError,
        'An active Homework must keep at least one scoreable Question.',
      );
      expect(subscription.read().draft!.pointsText, '0');
      expect(harness.builderState.serverLocked, isFalse);
      expect(harness.currentDetail, same(current));
    });

    test(
      'lifecycle and Topic conflicts reconcile with exact safe messages',
      () async {
        final cases = <(String, TeacherHomeworkStatus, String)>[
          (
            ApiErrorCodes.taskClosed,
            TeacherHomeworkStatus.closed,
            'This Homework is closed.',
          ),
          (
            ApiErrorCodes.taskArchived,
            TeacherHomeworkStatus.archived,
            'This Homework is archived.',
          ),
          (
            ApiErrorCodes.topicNotEditable,
            TeacherHomeworkStatus.draft,
            'The Topic is no longer editable.',
          ),
        ];
        for (final testCase in cases) {
          final question = teacherHomeworkQuestions().first;
          var fetchCount = 0;
          final initial = teacherHomework(questions: [question]);
          final current = teacherHomework(
            status: testCase.$2,
            questions: [question],
          );
          final repository = FakeTeacherHomeworkRepository(
            onFetch: (_) async {
              fetchCount += 1;
              return fetchCount == 1 ? initial : current;
            },
            onUpdateQuestion: (_, _) async =>
                throw teacherServerFailure(testCase.$1, statusCode: 409),
          );
          final harness = _EditorHarness(repository: repository);
          await harness.prepareRoute();
          final subscription = harness.listenEditor(
            mode: TeacherQuestionEditorMode.edit,
            questionId: question.id,
          );
          await flushTeacherControllers();
          final controller = harness.editorController(
            mode: TeacherQuestionEditorMode.edit,
            questionId: question.id,
          );
          controller.updatePrompt('Attempted prompt');

          await controller.submit();
          await flushTeacherControllers();

          expect(fetchCount, 2, reason: testCase.$1);
          expect(
            subscription.read().status,
            TeacherQuestionEditorStatus.lockedReview,
            reason: testCase.$1,
          );
          expect(subscription.read().formError, testCase.$3);
          expect(harness.builderState.serverLocked, isFalse);
          expect(harness.currentDetail, same(current));
        }
      },
    );
  });

  group('TeacherQuestionEditorController unknown outcomes', () {
    test('unknown add always closes for authoritative review', () async {
      var fetchCount = 0;
      final duplicate = teacherHomeworkQuestions().first;
      final initial = teacherHomework(questions: const []);
      final current = teacherHomework(questions: [duplicate]);
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return fetchCount == 1 ? initial : current;
        },
        onAddQuestion: (_, _) async =>
            throw const TeacherQuestionMutationOutcomeUnknownException(
              TeacherQuestionMutationOperation.add,
            ),
      );
      final harness = _EditorHarness(repository: repository);
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.add,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.add,
      );
      _completeChoiceDraft(controller, prompt: duplicate.prompt);

      await controller.submit();
      await flushTeacherControllers();

      expect(repository.addQuestionRequests, hasLength(1));
      expect(fetchCount, 2);
      expect(
        subscription.read().status,
        TeacherQuestionEditorStatus.closeForReview,
      );
      expect(subscription.read().formError, contains('could not be confirmed'));
      expect(harness.currentDetail, same(current));
    });

    test(
      'unknown update is confirmed only when pending PATCH matches GET',
      () async {
        final initialQuestion = teacherHomeworkQuestions().first;
        final currentQuestion = _copyQuestion(
          initialQuestion,
          prompt: 'Updated prompt',
        );
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return teacherHomework(
              questions: [fetchCount == 1 ? initialQuestion : currentQuestion],
            );
          },
          onUpdateQuestion: (_, _) async =>
              throw const TeacherQuestionMutationOutcomeUnknownException(
                TeacherQuestionMutationOperation.update,
              ),
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: initialQuestion.id,
        );
        await flushTeacherControllers();
        final controller = harness.editorController(
          mode: TeacherQuestionEditorMode.edit,
          questionId: initialQuestion.id,
        );
        controller.updatePrompt('Updated prompt');

        await controller.submit();
        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherQuestionEditorStatus.confirmedSuccess,
        );
        expect(repository.updateQuestionRequests, hasLength(1));
        expect(fetchCount, 2);
        expect(
          harness.currentDetail!.questions.single.prompt,
          'Updated prompt',
        );
      },
    );

    test(
      'unknown update mismatch publishes current Homework for review',
      () async {
        final initialQuestion = teacherHomeworkQuestions().first;
        final currentQuestion = _copyQuestion(
          initialQuestion,
          prompt: 'Different server prompt',
        );
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return teacherHomework(
              questions: [fetchCount == 1 ? initialQuestion : currentQuestion],
            );
          },
          onUpdateQuestion: (_, _) async =>
              throw const TeacherQuestionMutationOutcomeUnknownException(
                TeacherQuestionMutationOperation.update,
              ),
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: initialQuestion.id,
        );
        await flushTeacherControllers();
        final controller = harness.editorController(
          mode: TeacherQuestionEditorMode.edit,
          questionId: initialQuestion.id,
        );
        controller.updatePrompt('Attempted prompt');

        await controller.submit();
        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherQuestionEditorStatus.closeForReview,
        );
        expect(
          subscription.read().formError,
          contains('could not be confirmed'),
        );
        expect(
          harness.currentDetail!.questions.single.prompt,
          'Different server prompt',
        );
        expect(repository.updateQuestionRequests, hasLength(1));
      },
    );

    test('failed GET blocks mutations until Check current succeeds', () async {
      final initialQuestion = teacherHomeworkQuestions().first;
      final updatedQuestion = _copyQuestion(
        initialQuestion,
        prompt: 'Updated prompt',
      );
      var fetchCount = 0;
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          if (fetchCount == 1) {
            return teacherHomework(questions: [initialQuestion]);
          }
          if (fetchCount == 2) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return teacherHomework(questions: [updatedQuestion]);
        },
        onUpdateQuestion: (_, _) async =>
            throw const TeacherQuestionMutationOutcomeUnknownException(
              TeacherQuestionMutationOperation.update,
            ),
      );
      final harness = _EditorHarness(repository: repository);
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.edit,
        questionId: initialQuestion.id,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.edit,
        questionId: initialQuestion.id,
      );
      controller.updatePrompt('Updated prompt');

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherQuestionEditorStatus.outcomeReview,
      );
      expect(
        subscription.read().formError,
        contains('Check the current Homework'),
      );
      expect(subscription.read().blocksNavigation, isTrue);
      await controller.submit();
      expect(repository.updateQuestionRequests, hasLength(1));

      await controller.checkCurrentHomework();
      await flushTeacherControllers();

      expect(fetchCount, 3);
      expect(repository.updateQuestionRequests, hasLength(1));
      expect(
        subscription.read().status,
        TeacherQuestionEditorStatus.confirmedSuccess,
      );
    });
  });

  group('TeacherQuestionEditorController async ownership', () {
    test(
      'takeover releases Editor outcome review and reloads authority',
      () async {
        final question = teacherHomeworkQuestions().first;
        final initial = teacherHomework(questions: [question]);
        final refreshed = teacherHomework(
          title: 'Editor takeover GET authority',
          questions: [question],
          totalPossiblePoints: 32,
        );
        final reloadPending = Completer<TeacherHomework>();
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) {
            fetchCount += 1;
            if (fetchCount == 1) return Future.value(initial);
            if (fetchCount == 2) {
              return Future.error(teacherLocalFailure(ApiFailureKind.timeout));
            }
            return reloadPending.future;
          },
          onUpdateQuestion: (_, _) async =>
              throw const TeacherQuestionMutationOutcomeUnknownException(
                TeacherQuestionMutationOperation.update,
              ),
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        await flushTeacherControllers();
        final controller = harness.editorController(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        controller.updatePrompt('Attempted prompt');
        await controller.submit();
        expect(
          subscription.read().status,
          TeacherQuestionEditorStatus.outcomeReview,
        );
        expect(harness.mutationActivity.outcomeReviewBlocking, isTrue);
        final oldOwnerGeneration = harness.routeOwnerGeneration;

        final newOwnerGeneration = harness.builderController.enterRoute();

        expect(harness.mutationActivity.isActive, isFalse);
        expect(harness.builderState.authoritativeReloadPending, isTrue);
        harness.builderController.leaveRoute(oldOwnerGeneration);
        await flushTeacherControllers();
        expect(fetchCount, 3);
        expect(
          harness.builderController.isCurrentRouteOwner(
            harness.sessionKey,
            ownerGeneration: newOwnerGeneration,
          ),
          isTrue,
        );
        expect(
          subscription.read().status,
          TeacherQuestionEditorStatus.closeForReview,
        );
        await controller.checkCurrentHomework();
        expect(fetchCount, 3);

        reloadPending.complete(refreshed);
        await flushTeacherControllers();

        expect(harness.currentDetail, same(refreshed));
        expect(harness.builderState.authoritativeReloadPending, isFalse);
      },
    );

    test(
      'route leave retains pending update transport until stale completion',
      () async {
        final question = teacherHomeworkQuestions().first;
        final pending = Completer<TeacherHomework>();
        final initial = teacherHomework(questions: [question]);
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => initial,
          onUpdateQuestion: (_, _) => pending.future,
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        await flushTeacherControllers();
        final controller = harness.editorController(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        controller.updatePrompt('Updated prompt');

        final submission = controller.submit();
        expect(harness.mutationActivity.isActive, isTrue);
        harness.builderController.leaveRoute(harness.routeOwnerGeneration);
        expect(harness.mutationActivity.isActive, isTrue);
        final stale = teacherHomework(
          questions: [_copyQuestion(question, prompt: 'Updated prompt')],
          totalPossiblePoints: 88,
        );
        pending.complete(stale);
        await submission;
        await flushTeacherControllers();

        expect(repository.updateQuestionRequests, hasLength(1));
        expect(harness.mutationActivity.isActive, isFalse);
        expect(
          subscription.read().status,
          isNot(TeacherQuestionEditorStatus.confirmedSuccess),
        );
        expect(harness.currentDetail, same(initial));
      },
    );

    test(
      'pending editor transport survives listener disposal and requires a fresh GET',
      () async {
        final question = teacherHomeworkQuestions().first;
        final initial = teacherHomework(questions: [question]);
        final staleMutationResponse = teacherHomework(
          title: 'Stale editor response',
          questions: [_copyQuestion(question, prompt: 'First edit')],
          totalPossiblePoints: 84,
        );
        final naturalReentryResult = teacherHomework(
          title: 'Natural editor re-entry result',
          questions: [question],
          totalPossiblePoints: 85,
        );
        final requiredReloadResult = teacherHomework(
          title: 'Required editor authority',
          questions: [question],
          totalPossiblePoints: 86,
        );
        final confirmed = teacherHomework(
          questions: [_copyQuestion(question, prompt: 'Second edit')],
        );
        final oldPending = Completer<TeacherHomework>();
        final naturalReentry = Completer<TeacherHomework>();
        final requiredReload = Completer<TeacherHomework>();
        var fetchCount = 0;
        var updateCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) {
            fetchCount += 1;
            return switch (fetchCount) {
              1 => Future.value(initial),
              2 => naturalReentry.future,
              _ => requiredReload.future,
            };
          },
          onUpdateQuestion: (_, _) {
            updateCount += 1;
            return updateCount == 1
                ? oldPending.future
                : Future.value(confirmed);
          },
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final oldOwnerGeneration = harness.routeOwnerGeneration;
        final oldTarget = harness._editorTarget(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
          editorGeneration: 1,
        );
        final oldSubscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        await flushTeacherControllers();
        final oldController = harness.editorController(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
        );
        oldController.updatePrompt('First edit');

        final submission = oldController.submit();
        harness.builderController.leaveRoute(oldOwnerGeneration);
        oldSubscription.close();
        harness.closeBuilderSubscription();
        await flushTeacherControllers();

        expect(
          harness.container.exists(
            teacherQuestionEditorControllerProvider(oldTarget),
          ),
          isFalse,
        );
        expect(
          harness.container.exists(
            teacherQuestionBuilderControllerProvider(harness.routeTarget),
          ),
          isFalse,
        );
        expect(harness.mutationActivity.isActive, isTrue);
        expect(harness.mutationActivity.authoritativeReloadRequired, isTrue);

        oldPending.complete(staleMutationResponse);
        await submission;
        await flushTeacherControllers();

        expect(harness.mutationActivity.isActive, isFalse);
        expect(harness.mutationActivity.authoritativeReloadRequired, isTrue);

        await harness.prepareRoute();
        expect(fetchCount, 2);
        final newSubscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
          editorGeneration: 2,
        );
        await flushTeacherControllers();

        naturalReentry.complete(naturalReentryResult);
        await flushTeacherControllers();

        expect(fetchCount, 3);
        expect(harness.builderState.authoritativeReloadPending, isTrue);
        final newController = harness.editorController(
          mode: TeacherQuestionEditorMode.edit,
          questionId: question.id,
          editorGeneration: 2,
        );
        newController.updatePrompt('Second edit');
        await newController.submit();
        expect(repository.updateQuestionRequests, hasLength(1));

        requiredReload.complete(requiredReloadResult);
        await flushTeacherControllers();

        expect(harness.currentDetail, same(requiredReloadResult));
        expect(harness.currentDetail, isNot(same(staleMutationResponse)));
        expect(harness.builderState.authoritativeReloadPending, isFalse);
        expect(harness.mutationActivity.authoritativeReloadRequired, isFalse);
        expect(newSubscription.read().draft?.prompt, 'Second edit');

        await newController.submit();
        await flushTeacherControllers();

        expect(repository.updateQuestionRequests, hasLength(2));
        expect(harness.currentDetail, same(confirmed));
        expect(
          newSubscription.read().status,
          TeacherQuestionEditorStatus.confirmedSuccess,
        );
      },
    );

    test(
      'route leave retains pending add transport until stale completion',
      () async {
        final pending = Completer<TeacherHomework>();
        final initial = teacherHomework(questions: const []);
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => initial,
          onAddQuestion: (_, _) => pending.future,
        );
        final harness = _EditorHarness(repository: repository);
        await harness.prepareRoute();
        final subscription = harness.listenEditor(
          mode: TeacherQuestionEditorMode.add,
        );
        await flushTeacherControllers();
        final controller = harness.editorController(
          mode: TeacherQuestionEditorMode.add,
        );
        _completeChoiceDraft(controller);

        final submission = controller.submit();
        expect(harness.mutationActivity.isActive, isTrue);
        harness.builderController.leaveRoute(harness.routeOwnerGeneration);
        expect(harness.mutationActivity.isActive, isTrue);
        final stale = teacherHomework(
          questions: [teacherHomeworkQuestions().first],
          totalPossiblePoints: 89,
        );
        pending.complete(stale);
        await submission;
        await flushTeacherControllers();

        expect(repository.addQuestionRequests, hasLength(1));
        expect(harness.mutationActivity.isActive, isFalse);
        expect(
          subscription.read().status,
          isNot(TeacherQuestionEditorStatus.confirmedSuccess),
        );
        expect(harness.currentDetail, same(initial));
      },
    );

    test('completion from a replaced session is ignored', () async {
      final question = teacherHomeworkQuestions().first;
      final pending = Completer<TeacherHomework>();
      final initial = teacherHomework(questions: [question]);
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => initial,
        onUpdateQuestion: (_, _) => pending.future,
      );
      final harness = _EditorHarness(repository: repository, auth: auth);
      await harness.prepareRoute();
      final subscription = harness.listenEditor(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      await flushTeacherControllers();
      final controller = harness.editorController(
        mode: TeacherQuestionEditorMode.edit,
        questionId: question.id,
      );
      controller.updatePrompt('Updated prompt');

      final submission = controller.submit();
      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      final stale = teacherHomework(
        questions: [_copyQuestion(question, prompt: 'Updated prompt')],
        totalPossiblePoints: 99,
      );
      pending.complete(stale);
      await submission;
      await flushTeacherControllers();

      expect(repository.updateQuestionRequests, hasLength(1));
      expect(
        subscription.read().status,
        isNot(TeacherQuestionEditorStatus.confirmedSuccess),
      );
      expect(harness.currentDetail, isNot(same(stale)));
      expect(harness.currentDetail?.totalPossiblePoints, isNot(99));
    });
  });
}

class _EditorHarness {
  _EditorHarness({
    TeacherHomework? initialHomework,
    FakeTeacherHomeworkRepository? repository,
    FakeTeacherAuthSessionController? auth,
  }) : auth =
           auth ??
           FakeTeacherAuthSessionController.authenticated(
             teacherUser('teacher-a'),
           ),
       repository =
           repository ??
           FakeTeacherHomeworkRepository(
             onFetch: (_) async => initialHomework ?? teacherHomework(),
           ) {
    routeTarget = TeacherHomeworkRouteTarget(
      topicId: _topicId,
      homeworkId: _homeworkId,
    );
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherHomeworkRepositoryProvider.overrideWithValue(this.repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherHomeworkRepository repository;
  late final TeacherHomeworkRouteTarget routeTarget;
  late final ProviderContainer container;
  late int routeOwnerGeneration;
  ProviderSubscription<TeacherQuestionBuilderState>? _builderSubscription;

  Future<void> prepareRoute() async {
    _builderSubscription ??= container.listen(
      teacherQuestionBuilderControllerProvider(routeTarget),
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
    routeOwnerGeneration = builderController.enterRoute();
    await flushTeacherControllers();
  }

  void closeBuilderSubscription() {
    _builderSubscription?.close();
    _builderSubscription = null;
  }

  ProviderSubscription<TeacherQuestionEditorState> listenEditor({
    required TeacherQuestionEditorMode mode,
    String? questionId,
    int editorGeneration = 1,
  }) {
    return container.listen(
      teacherQuestionEditorControllerProvider(
        _editorTarget(
          mode: mode,
          questionId: questionId,
          editorGeneration: editorGeneration,
        ),
      ),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherQuestionEditorController editorController({
    required TeacherQuestionEditorMode mode,
    String? questionId,
    int editorGeneration = 1,
  }) {
    return container.read(
      teacherQuestionEditorControllerProvider(
        _editorTarget(
          mode: mode,
          questionId: questionId,
          editorGeneration: editorGeneration,
        ),
      ).notifier,
    );
  }

  TeacherQuestionEditorTarget _editorTarget({
    required TeacherQuestionEditorMode mode,
    required String? questionId,
    required int editorGeneration,
  }) {
    return TeacherQuestionEditorTarget(
      routeTarget: routeTarget,
      routeOwnerGeneration: routeOwnerGeneration,
      mode: mode,
      questionId: questionId,
      editorGeneration: editorGeneration,
    );
  }

  TeacherQuestionBuilderController get builderController => container.read(
    teacherQuestionBuilderControllerProvider(routeTarget).notifier,
  );

  TeacherQuestionBuilderState get builderState =>
      container.read(teacherQuestionBuilderControllerProvider(routeTarget));

  TeacherQuestionMutationActivityState get mutationActivity =>
      container.read(teacherQuestionMutationActivityProvider(routeTarget));

  TeacherHomework? get currentDetail => container
      .read(teacherHomeworkDetailControllerProvider(routeTarget))
      .homework;

  void acceptAuthoritative(TeacherHomework homework) {
    container
        .read(teacherHomeworkDetailControllerProvider(routeTarget).notifier)
        .acceptAuthoritativeHomework(homework, sessionKey);
  }

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    AppDeviceSurface.desktop,
  ).eligibleKey!;
}

void _completeChoiceDraft(
  TeacherQuestionEditorController controller, {
  String prompt = 'New prompt',
}) {
  controller
    ..updatePrompt(prompt)
    ..updateChoiceText(0, 'First option')
    ..updateChoiceText(1, 'Second option');
}

List<TeacherQuestion> _oneHundredQuestions() {
  final template = teacherHomeworkQuestions().first;
  return List.generate(
    TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment,
    (index) => _copyQuestion(
      template,
      id: '70000000-0000-0000-0000-${(index + 1).toString().padLeft(12, '0')}',
      position: index + 1,
    ),
  );
}

TeacherQuestion _copyQuestion(
  TeacherQuestion question, {
  String? id,
  String? prompt,
  int? position,
}) {
  return TeacherQuestion(
    id: id ?? question.id,
    type: question.type,
    prompt: prompt ?? question.prompt,
    instructions: question.instructions,
    points: question.points,
    position: position ?? question.position,
    checkingMode: question.checkingMode,
    configuration: question.configuration,
  );
}

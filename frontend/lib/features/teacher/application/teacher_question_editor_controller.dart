import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_homework_repository_impl.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_question.dart';
import '../domain/teacher_question_authoring.dart';
import '../domain/teacher_question_mutation.dart';
import 'teacher_homework_detail_controller.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_question_builder_controller.dart';
import 'teacher_question_editor_state.dart';
import 'teacher_question_mutation_activity.dart';
import 'teacher_session_key.dart';

final teacherQuestionEditorControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherQuestionEditorController,
      TeacherQuestionEditorState,
      TeacherQuestionEditorTarget
    >(TeacherQuestionEditorController.new);

class TeacherQuestionEditorController
    extends Notifier<TeacherQuestionEditorState> {
  TeacherQuestionEditorController(this.target);

  final TeacherQuestionEditorTarget target;
  final TeacherQuestionLocalIdSequence _localIds =
      TeacherQuestionLocalIdSequence();
  TeacherSessionKey? _activeSessionKey;
  var _operationGeneration = 0;
  var _initialized = false;

  @override
  TeacherQuestionEditorState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(
      teacherHomeworkDetailControllerProvider(target.routeTarget),
    );
    final builder = ref.watch(
      teacherQuestionBuilderControllerProvider(target.routeTarget),
    );
    ref.watch(teacherQuestionMutationActivityProvider(target.routeTarget));

    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      final shouldClose = _initialized;
      _clearSession();
      return TeacherQuestionEditorState(
        status: shouldClose
            ? TeacherQuestionEditorStatus.closeForReview
            : TeacherQuestionEditorStatus.unavailable,
        formError: 'Question editing is unavailable.',
      );
    }
    if (_activeSessionKey != sessionKey) {
      _clearSession();
      _activeSessionKey = sessionKey;
    }
    if (_initialized &&
        !_builder.isCurrentRouteOwner(
          sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        )) {
      _operationGeneration += 1;
      return state.copyWith(
        status: TeacherQuestionEditorStatus.closeForReview,
        pendingOperation: null,
      );
    }

    if (_initialized &&
        (state.isBusy ||
            state.status == TeacherQuestionEditorStatus.outcomeReview ||
            state.shouldClose)) {
      return state;
    }
    if (detail.status == TeacherHomeworkDetailStatus.notFound) {
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.unavailable,
        formError: 'This Homework is no longer available.',
      );
    }
    final homework =
        detail.status == TeacherHomeworkDetailStatus.data && !detail.isStale
        ? detail.homework
        : null;
    if (homework == null || !_matchesTarget(homework)) {
      return _initialized ? state : TeacherQuestionEditorState();
    }
    if (homework.status == TeacherHomeworkStatus.closed ||
        homework.status == TeacherHomeworkStatus.archived) {
      final retainedDraft = _initialized ? state.draft : null;
      final retainedInitialDraft = _initialized ? state.initialDraft : null;
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.lockedReview,
        draft: retainedDraft,
        initialDraft: retainedInitialDraft,
        formError: homework.status == TeacherHomeworkStatus.closed
            ? 'This Homework is closed.'
            : 'This Homework is archived.',
      );
    }
    if (builder.serverLocked) {
      final retainedDraft = _initialized ? state.draft : null;
      final retainedInitialDraft = _initialized ? state.initialDraft : null;
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.lockedReview,
        draft: retainedDraft,
        initialDraft: retainedInitialDraft,
        formError: 'Question editing is locked by the current server state.',
      );
    }

    final question = target.mode == TeacherQuestionEditorMode.edit
        ? _findQuestion(homework, target.questionId!)
        : null;
    if (target.mode == TeacherQuestionEditorMode.edit && question == null) {
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.unavailable,
        formError: 'This Question is no longer available.',
      );
    }

    if (!_initialized || state.draft == null || state.initialDraft == null) {
      final draft = target.mode == TeacherQuestionEditorMode.add
          ? TeacherQuestionDraft.forAdd(nextLocalId: _localIds.next)
          : TeacherQuestionDraft.fromQuestion(
              question!,
              nextLocalId: _localIds.next,
            );
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.editing,
        draft: draft,
        initialDraft: draft,
        formError:
            target.mode == TeacherQuestionEditorMode.add &&
                homework.questions.length >=
                    TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment
            ? 'Maximum 100 Questions.'
            : null,
      );
    }

    if (state.status == TeacherQuestionEditorStatus.lockedReview) {
      return state;
    }
    if (state.isDirty) {
      return state;
    }
    final refreshedDraft = target.mode == TeacherQuestionEditorMode.add
        ? state.draft!
        : TeacherQuestionDraft.fromQuestion(
            question!,
            nextLocalId: _localIds.next,
          );
    if (refreshedDraft.semanticallyEqualsDraft(state.draft!)) {
      return state;
    }
    return TeacherQuestionEditorState(
      status: TeacherQuestionEditorStatus.editing,
      draft: refreshedDraft,
      initialDraft: refreshedDraft,
    );
  }

  void updatePrompt(String value) {
    _updateDraft(
      (draft) => draft.copyWith(prompt: value),
      TeacherQuestionDraftField.prompt,
    );
  }

  void updateInstructions(String value) {
    _updateDraft(
      (draft) => draft.copyWith(instructions: value),
      TeacherQuestionDraftField.instructions,
    );
  }

  void updatePoints(String value) {
    _updateDraft(
      (draft) => draft.copyWith(pointsText: value),
      TeacherQuestionDraftField.points,
    );
  }

  bool requestTypeChange(TeacherQuestionType type) {
    final draft = state.draft;
    if (!state.canSubmit || draft == null || draft.type == type) {
      return false;
    }
    if (draft.requiresTypeChangeConfirmation(type)) {
      state = state.copyWith(pendingType: type);
      return true;
    }
    _applyTypeChange(type);
    return false;
  }

  void confirmTypeChange() {
    final type = state.pendingType;
    if (type != null) {
      _applyTypeChange(type);
    }
  }

  void cancelTypeChange() {
    if (state.pendingType != null) {
      state = state.copyWith(pendingType: null);
    }
  }

  void _applyTypeChange(TeacherQuestionType type) {
    _updateDraft(
      (draft) => draft.changeType(type, nextLocalId: _localIds.next),
      TeacherQuestionDraftField.type,
      additionalFields: const {
        TeacherQuestionDraftField.checkingMode,
        TeacherQuestionDraftField.configuration,
      },
    );
    state = state.copyWith(pendingType: null);
  }

  bool requestCheckingModeChange(TeacherQuestionCheckingMode mode) {
    final draft = state.draft;
    if (!state.canSubmit || draft == null || draft.checkingMode == mode) {
      return false;
    }
    if (draft.requiresCheckingModeChangeConfirmation(mode)) {
      state = state.copyWith(pendingCheckingMode: mode);
      return true;
    }
    _applyCheckingModeChange(mode);
    return false;
  }

  void confirmCheckingModeChange() {
    final mode = state.pendingCheckingMode;
    if (mode != null) {
      _applyCheckingModeChange(mode);
    }
  }

  void cancelCheckingModeChange() {
    if (state.pendingCheckingMode != null) {
      state = state.copyWith(pendingCheckingMode: null);
    }
  }

  void _applyCheckingModeChange(TeacherQuestionCheckingMode mode) {
    _updateDraft(
      (draft) => draft.changeCheckingMode(mode, nextLocalId: _localIds.next),
      TeacherQuestionDraftField.checkingMode,
      additionalFields: const {TeacherQuestionDraftField.configuration},
    );
    state = state.copyWith(pendingCheckingMode: null);
  }

  void updateChoiceText(int index, String value) {
    _updateConfiguration<TeacherChoiceConfigurationDraft>((configuration) {
      final options = configuration.options.toList();
      if (!_validIndex(options, index)) return configuration;
      options[index] = options[index].copyWith(text: value);
      return configuration.copyWith(options: options);
    });
  }

  void setChoiceCorrect(int index, bool selected) {
    _updateConfiguration<TeacherChoiceConfigurationDraft>((configuration) {
      if (!_validIndex(configuration.options, index)) return configuration;
      final singleChoice =
          state.draft!.type == TeacherQuestionType.singleChoice;
      final options = <TeacherChoiceOptionDraft>[
        for (
          var itemIndex = 0;
          itemIndex < configuration.options.length;
          itemIndex += 1
        )
          configuration.options[itemIndex].copyWith(
            isCorrect: singleChoice
                ? itemIndex == index
                : itemIndex == index
                ? selected
                : configuration.options[itemIndex].isCorrect,
          ),
      ];
      return configuration.copyWith(options: options);
    });
  }

  void addChoiceOption() {
    _updateConfiguration<TeacherChoiceConfigurationDraft>((configuration) {
      if (configuration.options.length >=
          TeacherQuestionAuthoringLimits.maxChoiceOptions) {
        return configuration;
      }
      return configuration.copyWith(
        options: [
          ...configuration.options,
          TeacherChoiceOptionDraft(
            localId: _localIds.next(),
            text: '',
            isCorrect: false,
          ),
        ],
      );
    });
  }

  void removeChoiceOption(int index) {
    _updateConfiguration<TeacherChoiceConfigurationDraft>((configuration) {
      if (configuration.options.length <= 2 ||
          !_validIndex(configuration.options, index)) {
        return configuration;
      }
      final options = configuration.options.toList()..removeAt(index);
      return configuration.copyWith(options: options);
    });
  }

  void moveChoiceOption(int index, int delta) {
    _updateConfiguration<TeacherChoiceConfigurationDraft>((configuration) {
      return configuration.copyWith(
        options: _move(configuration.options, index, delta),
      );
    });
  }

  void setTrueFalseValue(bool value) {
    _updateConfiguration<TeacherTrueFalseConfigurationDraft>(
      (configuration) => configuration.copyWith(correctValue: value),
    );
  }

  void updateShortAnswer(int index, String value) {
    _updateConfiguration<TeacherShortWrittenConfigurationDraft>((
      configuration,
    ) {
      final answers = configuration.acceptedAnswers.toList();
      if (!_validIndex(answers, index)) return configuration;
      answers[index] = answers[index].copyWith(text: value);
      return configuration.copyWith(acceptedAnswers: answers);
    });
  }

  void addShortAnswer() {
    _updateConfiguration<TeacherShortWrittenConfigurationDraft>((
      configuration,
    ) {
      if (configuration.acceptedAnswers.length >=
          TeacherQuestionAuthoringLimits.maxShortAcceptedAnswers) {
        return configuration;
      }
      return configuration.copyWith(
        acceptedAnswers: [
          ...configuration.acceptedAnswers,
          TeacherAcceptedAnswerDraft(localId: _localIds.next(), text: ''),
        ],
      );
    });
  }

  void removeShortAnswer(int index) {
    _updateConfiguration<TeacherShortWrittenConfigurationDraft>((
      configuration,
    ) {
      if (configuration.acceptedAnswers.length <= 1 ||
          !_validIndex(configuration.acceptedAnswers, index)) {
        return configuration;
      }
      final answers = configuration.acceptedAnswers.toList()..removeAt(index);
      return configuration.copyWith(acceptedAnswers: answers);
    });
  }

  void moveShortAnswer(int index, int delta) {
    _updateConfiguration<TeacherShortWrittenConfigurationDraft>((
      configuration,
    ) {
      return configuration.copyWith(
        acceptedAnswers: _move(configuration.acceptedAnswers, index, delta),
      );
    });
  }

  void updateMatchingLeft(int index, String value) {
    _updateMatching(index, (pair) => pair.copyWith(left: value));
  }

  void updateMatchingRight(int index, String value) {
    _updateMatching(index, (pair) => pair.copyWith(right: value));
  }

  void _updateMatching(
    int index,
    TeacherMatchingPairDraft Function(TeacherMatchingPairDraft) update,
  ) {
    _updateConfiguration<TeacherMatchingConfigurationDraft>((configuration) {
      final pairs = configuration.pairs.toList();
      if (!_validIndex(pairs, index)) return configuration;
      pairs[index] = update(pairs[index]);
      return configuration.copyWith(pairs: pairs);
    });
  }

  void addMatchingPair() {
    _updateConfiguration<TeacherMatchingConfigurationDraft>((configuration) {
      if (configuration.pairs.length >=
          TeacherQuestionAuthoringLimits.maxMatchingPairs) {
        return configuration;
      }
      return configuration.copyWith(
        pairs: [
          ...configuration.pairs,
          TeacherMatchingPairDraft(
            localId: _localIds.next(),
            left: '',
            right: '',
          ),
        ],
      );
    });
  }

  void removeMatchingPair(int index) {
    _updateConfiguration<TeacherMatchingConfigurationDraft>((configuration) {
      if (configuration.pairs.length <= 1 ||
          !_validIndex(configuration.pairs, index)) {
        return configuration;
      }
      final pairs = configuration.pairs.toList()..removeAt(index);
      return configuration.copyWith(pairs: pairs);
    });
  }

  void moveMatchingPair(int index, int delta) {
    _updateConfiguration<TeacherMatchingConfigurationDraft>((configuration) {
      return configuration.copyWith(
        pairs: _move(configuration.pairs, index, delta),
      );
    });
  }

  void updateOrderingText(int index, String value) {
    _updateConfiguration<TeacherOrderingConfigurationDraft>((configuration) {
      final items = configuration.items.toList();
      if (!_validIndex(items, index)) return configuration;
      items[index] = items[index].copyWith(text: value);
      return configuration.copyWith(items: items);
    });
  }

  void addOrderingItem() {
    _updateConfiguration<TeacherOrderingConfigurationDraft>((configuration) {
      if (configuration.items.length >=
          TeacherQuestionAuthoringLimits.maxOrderingItems) {
        return configuration;
      }
      return configuration.copyWith(
        items: [
          ...configuration.items,
          TeacherOrderingItemDraft(localId: _localIds.next(), text: ''),
        ],
      );
    });
  }

  void removeOrderingItem(int index) {
    _updateConfiguration<TeacherOrderingConfigurationDraft>((configuration) {
      if (configuration.items.length <= 2 ||
          !_validIndex(configuration.items, index)) {
        return configuration;
      }
      final items = configuration.items.toList()..removeAt(index);
      return configuration.copyWith(items: items);
    });
  }

  void moveOrderingItem(int index, int delta) {
    _updateConfiguration<TeacherOrderingConfigurationDraft>((configuration) {
      return configuration.copyWith(
        items: _move(configuration.items, index, delta),
      );
    });
  }

  void updateBlankKey(int blankIndex, String value) {
    _updateBlank(blankIndex, (blank) => blank.copyWith(key: value));
  }

  void addBlank() {
    _updateConfiguration<TeacherFillInBlankConfigurationDraft>((configuration) {
      if (configuration.blanks.length >=
          TeacherQuestionAuthoringLimits.maxFillBlanks) {
        return configuration;
      }
      return configuration.copyWith(
        blanks: [
          ...configuration.blanks,
          TeacherFillBlankDraft(
            localId: _localIds.next(),
            key: '',
            acceptedAnswers: [
              TeacherAcceptedAnswerDraft(localId: _localIds.next(), text: ''),
            ],
          ),
        ],
      );
    });
  }

  void removeBlank(int blankIndex) {
    _updateConfiguration<TeacherFillInBlankConfigurationDraft>((configuration) {
      if (configuration.blanks.length <= 1 ||
          !_validIndex(configuration.blanks, blankIndex)) {
        return configuration;
      }
      final blanks = configuration.blanks.toList()..removeAt(blankIndex);
      return configuration.copyWith(blanks: blanks);
    });
  }

  void moveBlank(int blankIndex, int delta) {
    _updateConfiguration<TeacherFillInBlankConfigurationDraft>((configuration) {
      return configuration.copyWith(
        blanks: _move(configuration.blanks, blankIndex, delta),
      );
    });
  }

  void updateBlankAnswer(int blankIndex, int answerIndex, String value) {
    _updateBlank(blankIndex, (blank) {
      final answers = blank.acceptedAnswers.toList();
      if (!_validIndex(answers, answerIndex)) return blank;
      answers[answerIndex] = answers[answerIndex].copyWith(text: value);
      return blank.copyWith(acceptedAnswers: answers);
    });
  }

  void addBlankAnswer(int blankIndex) {
    _updateBlank(blankIndex, (blank) {
      if (blank.acceptedAnswers.length >=
          TeacherQuestionAuthoringLimits.maxAcceptedAnswersPerBlank) {
        return blank;
      }
      return blank.copyWith(
        acceptedAnswers: [
          ...blank.acceptedAnswers,
          TeacherAcceptedAnswerDraft(localId: _localIds.next(), text: ''),
        ],
      );
    });
  }

  void removeBlankAnswer(int blankIndex, int answerIndex) {
    _updateBlank(blankIndex, (blank) {
      if (blank.acceptedAnswers.length <= 1 ||
          !_validIndex(blank.acceptedAnswers, answerIndex)) {
        return blank;
      }
      final answers = blank.acceptedAnswers.toList()..removeAt(answerIndex);
      return blank.copyWith(acceptedAnswers: answers);
    });
  }

  void moveBlankAnswer(int blankIndex, int answerIndex, int delta) {
    _updateBlank(blankIndex, (blank) {
      return blank.copyWith(
        acceptedAnswers: _move(blank.acceptedAnswers, answerIndex, delta),
      );
    });
  }

  void _updateBlank(
    int blankIndex,
    TeacherFillBlankDraft Function(TeacherFillBlankDraft) update,
  ) {
    _updateConfiguration<TeacherFillInBlankConfigurationDraft>((configuration) {
      final blanks = configuration.blanks.toList();
      if (!_validIndex(blanks, blankIndex)) return configuration;
      blanks[blankIndex] = update(blanks[blankIndex]);
      return configuration.copyWith(blanks: blanks);
    });
  }

  Future<void> submit() async {
    final draft = state.draft;
    final sessionKey = _activeSessionKey;
    final detail = ref.read(
      teacherHomeworkDetailControllerProvider(target.routeTarget),
    );
    final homework =
        detail.status == TeacherHomeworkDetailStatus.data && !detail.isStale
        ? detail.homework
        : null;
    if (!state.canSubmit ||
        state.pendingOperation != null ||
        draft == null ||
        sessionKey == null ||
        homework == null ||
        !_canMutate(homework, sessionKey)) {
      return;
    }

    final validation = draft.validate();
    final validated = validation.validatedDraft;
    if (validated == null) {
      state = state.copyWith(
        status: TeacherQuestionEditorStatus.localValidationFailure,
        fieldErrors: validation.errors,
        formError: null,
      );
      return;
    }

    final operation = target.mode == TeacherQuestionEditorMode.add
        ? TeacherQuestionMutationOperation.add
        : TeacherQuestionMutationOperation.update;
    TeacherQuestionCreateRequest? createRequest;
    TeacherQuestionEditRequest? editRequest;
    String? questionId;
    if (operation == TeacherQuestionMutationOperation.add) {
      if (homework.questions.length >=
          TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment) {
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.definiteFailure,
          formError: 'Maximum 100 Questions.',
        );
        return;
      }
      createRequest = TeacherQuestionCreateRequest.fromValidated(
        validatedDraft: validated,
        position: homework.questions.length + 1,
      );
    } else {
      questionId = target.questionId!;
      final currentQuestion = _findQuestion(homework, questionId);
      if (currentQuestion == null) {
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.unavailable,
          formError: 'This Question is no longer available.',
        );
        return;
      }
      editRequest = TeacherQuestionEditRequest.fromValidated(
        validatedDraft: validated,
        initial: TeacherQuestionEditSnapshot.fromQuestion(currentQuestion),
      );
      if (editRequest.isEmpty) {
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.editing,
          formError: 'No changes to save.',
          fieldErrors: const {},
        );
        return;
      }
    }

    final activity = ref.read(
      teacherQuestionMutationActivityProvider(target.routeTarget).notifier,
    );
    final lease = activity.begin(operation);
    if (lease == null) {
      return;
    }
    final pending = TeacherQuestionEditorPendingOperation(
      lease: lease,
      authorityStateAtStart: detail,
      createRequest: createRequest,
      editRequest: editRequest,
      questionId: questionId,
    );
    final generation = ++_operationGeneration;
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.submitting,
      fieldErrors: const {},
      formError: null,
      pendingOperation: pending,
    );
    try {
      final returned = operation == TeacherQuestionMutationOperation.add
          ? await ref
                .read(teacherHomeworkRepositoryProvider)
                .addQuestion(target.routeTarget.homeworkId, createRequest!)
          : await ref
                .read(teacherHomeworkRepositoryProvider)
                .updateQuestion(questionId!, editRequest!);
      if (!_canPublish(pending, generation)) {
        return;
      }
      if (!_matchesTarget(returned)) {
        await _reconcile(pending, generation);
        return;
      }
      if (!_detailAuthorityUnchanged(pending)) {
        await _reconcile(pending.withConfirmedTransport(), generation);
        return;
      }
      _publishConfirmed(returned, pending);
    } on TeacherQuestionMutationOutcomeUnknownException {
      await _reconcile(pending, generation);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(pending, generation)) {
        return;
      }
      await _handleDefiniteFailure(exception.failure, pending, generation);
    } catch (_) {
      await _reconcile(pending, generation);
    } finally {
      _releaseIfAbandoned(pending, generation, activity);
    }
  }

  Future<void> checkCurrentHomework() async {
    final pending = state.pendingOperation;
    if (state.status != TeacherQuestionEditorStatus.outcomeReview ||
        pending == null) {
      return;
    }
    await _reconcile(pending, _operationGeneration);
  }

  Future<void> _handleDefiniteFailure(
    ApiFailure failure,
    TeacherQuestionEditorPendingOperation pending,
    int generation,
  ) async {
    if (_isSessionFailure(failure)) {
      _release(pending);
      _clearForSessionFailure(failure);
      return;
    }
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      await _reconcile(
        pending.withConflictCode(ApiErrorCodes.resourceNotFound),
        generation,
      );
      return;
    }
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      _release(pending);
      _publishServerValidation(failure);
      return;
    }
    if (failure.statusCode == 409 && _isQuestionConflict(failure.serverCode)) {
      await _reconcile(
        pending.withConflictCode(failure.serverCode!),
        generation,
      );
      return;
    }

    _release(pending);
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.definiteFailure,
      formError: switch (failure.serverCode) {
        ApiErrorCodes.rateLimited =>
          'Too many requests. Wait before trying again.',
        ApiErrorCodes.forbidden =>
          'You do not have permission to change this Question.',
        _ => 'The Question could not be saved.',
      },
      pendingOperation: null,
    );
  }

  Future<void> _reconcile(
    TeacherQuestionEditorPendingOperation pending,
    int generation,
  ) async {
    if (!_canPublish(pending, generation)) {
      return;
    }
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.reconciling,
      pendingOperation: pending,
    );
    try {
      final current = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.routeTarget.homeworkId);
      if (!_canPublish(pending, generation)) {
        return;
      }
      if (!_matchesTarget(current)) {
        _release(pending);
        _builder.markEditorTargetUnavailable(
          pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        );
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.closeForReview,
          formError: 'This Homework is no longer available.',
          pendingOperation: null,
        );
        return;
      }

      final conflictCode = pending.conflictCode;
      if (conflictCode != null) {
        if (conflictCode == ApiErrorCodes.resourceNotFound) {
          final message =
              pending.operation == TeacherQuestionMutationOperation.add
              ? 'The Question could not be created because the target is no longer available. Review the current Homework.'
              : 'This Question is no longer available. Review the current Homework.';
          _builder.acceptEditorAuthoritativeHomework(
            homework: current,
            sessionKey: pending.lease.sessionKey,
            ownerGeneration: target.routeOwnerGeneration,
            notice: message,
          );
          _release(pending);
          state = state.copyWith(
            status: TeacherQuestionEditorStatus.closeForReview,
            formError: message,
            pendingOperation: null,
          );
          return;
        }
        final locked =
            conflictCode == ApiErrorCodes.businessConflict ||
            conflictCode == ApiErrorCodes.resultPairLocked;
        final topicNotEditable = conflictCode == ApiErrorCodes.topicNotEditable;
        final message = _editorConflictMessage(conflictCode);
        _builder.acceptEditorAuthoritativeHomework(
          homework: current,
          sessionKey: pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
          notice: message,
          serverLocked: locked,
          topicNotEditable: topicNotEditable,
        );
        _release(pending);
        state = state.copyWith(
          status: conflictCode == ApiErrorCodes.assessmentHasNoScoreablePoints
              ? TeacherQuestionEditorStatus.definiteFailure
              : TeacherQuestionEditorStatus.lockedReview,
          formError: message,
          pendingOperation: null,
        );
        return;
      }

      if (pending.transportConfirmed) {
        _publishConfirmed(current, pending);
        return;
      }

      if (pending.operation == TeacherQuestionMutationOperation.add) {
        const message =
            'The Question creation result could not be confirmed. Review the current Question list before adding another Question.';
        _builder.acceptEditorAuthoritativeHomework(
          homework: current,
          sessionKey: pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
          notice: message,
        );
        _release(pending);
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.closeForReview,
          formError: message,
          pendingOperation: null,
        );
        return;
      }

      final currentQuestion = _findQuestion(current, pending.questionId!);
      if (currentQuestion != null &&
          pending.editRequest!.matches(currentQuestion)) {
        _publishConfirmed(current, pending);
        return;
      }
      final message = currentQuestion == null
          ? 'This Question is no longer available. Review the current Homework.'
          : 'The Question update result could not be confirmed. Review the current Question before editing again.';
      _builder.acceptEditorAuthoritativeHomework(
        homework: current,
        sessionKey: pending.lease.sessionKey,
        ownerGeneration: target.routeOwnerGeneration,
        notice: message,
      );
      _release(pending);
      state = state.copyWith(
        status: TeacherQuestionEditorStatus.closeForReview,
        formError: message,
        pendingOperation: null,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(pending, generation)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _release(pending);
        _clearForSessionFailure(exception.failure);
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _release(pending);
        _builder.markEditorTargetUnavailable(
          pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        );
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.closeForReview,
          formError: 'This Homework is no longer available.',
          pendingOperation: null,
        );
        return;
      }
      _publishBlockingReview(pending);
    } catch (_) {
      if (_canPublish(pending, generation)) {
        _publishBlockingReview(pending);
      }
    }
  }

  void _publishConfirmed(
    TeacherHomework homework,
    TeacherQuestionEditorPendingOperation pending,
  ) {
    final message = pending.operation == TeacherQuestionMutationOperation.add
        ? 'Question created successfully.'
        : 'Question updated successfully.';
    _builder.acceptEditorAuthoritativeHomework(
      homework: homework,
      sessionKey: pending.lease.sessionKey,
      ownerGeneration: target.routeOwnerGeneration,
      notice: message,
    );
    _release(pending);
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.confirmedSuccess,
      formError: null,
      pendingOperation: null,
    );
  }

  void _publishBlockingReview(TeacherQuestionEditorPendingOperation pending) {
    ref
        .read(
          teacherQuestionMutationActivityProvider(target.routeTarget).notifier,
        )
        .markOutcomeReviewBlocking(pending.lease);
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.outcomeReview,
      formError:
          'The current Homework could not be confirmed. Check the current Homework before taking another action.',
      pendingOperation: pending,
    );
  }

  void _publishServerValidation(ApiFailure failure) {
    final errors = <TeacherQuestionDraftField, String>{};
    var hasUnknown = failure.fieldErrors.isEmpty;
    for (final key in failure.fieldErrors.keys) {
      final field = _draftFieldForServerKey(key);
      if (field == null) {
        hasUnknown = true;
      } else {
        errors[field] = _serverValidationMessage(field);
      }
    }
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.serverValidationFailure,
      fieldErrors: errors,
      formError: hasUnknown ? 'The Question could not be saved.' : null,
      pendingOperation: null,
    );
  }

  void _updateDraft(
    TeacherQuestionDraft Function(TeacherQuestionDraft) update,
    TeacherQuestionDraftField clearField, {
    Set<TeacherQuestionDraftField> additionalFields = const {},
  }) {
    final draft = state.draft;
    if (!state.canSubmit || draft == null) {
      return;
    }
    final updated = update(draft);
    final errors = Map<TeacherQuestionDraftField, String>.of(state.fieldErrors)
      ..remove(clearField);
    for (final field in additionalFields) {
      errors.remove(field);
    }
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.editing,
      draft: updated,
      fieldErrors: errors,
      formError: null,
    );
  }

  void _updateConfiguration<T extends TeacherQuestionConfigurationDraft>(
    T Function(T configuration) update,
  ) {
    final draft = state.draft;
    if (!state.canSubmit || draft == null || draft.configurationDraft is! T) {
      return;
    }
    _updateDraft(
      (current) => current.copyWith(
        configurationDraft: update(current.configurationDraft as T),
      ),
      TeacherQuestionDraftField.configuration,
    );
  }

  bool _canMutate(TeacherHomework homework, TeacherSessionKey sessionKey) {
    final builderState = ref.read(
      teacherQuestionBuilderControllerProvider(target.routeTarget),
    );
    return _builder.isCurrentRouteOwner(
          sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        ) &&
        _matchesTarget(homework) &&
        (homework.status == TeacherHomeworkStatus.draft ||
            homework.status == TeacherHomeworkStatus.active) &&
        !builderState.serverLocked &&
        !builderState.topicNotEditable &&
        !builderState.authoritativeReloadPending &&
        !builderState.orderDirty &&
        !builderState.isBusy &&
        !builderState.hasBlockingOutcome &&
        !ref
            .read(teacherQuestionMutationActivityProvider(target.routeTarget))
            .isActive;
  }

  bool _canPublish(
    TeacherQuestionEditorPendingOperation pending,
    int generation,
  ) {
    return ref.mounted &&
        generation == _operationGeneration &&
        identical(state.pendingOperation?.lease, pending.lease) &&
        ref
            .read(
              teacherQuestionMutationActivityProvider(
                target.routeTarget,
              ).notifier,
            )
            .owns(pending.lease) &&
        _activeSessionKey == pending.lease.sessionKey &&
        _builder.isCurrentRouteOwner(
          pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        );
  }

  void _release(TeacherQuestionEditorPendingOperation pending) {
    ref
        .read(
          teacherQuestionMutationActivityProvider(target.routeTarget).notifier,
        )
        .release(pending.lease);
  }

  void _releaseIfAbandoned(
    TeacherQuestionEditorPendingOperation pending,
    int generation,
    TeacherQuestionMutationActivityController activity,
  ) {
    final remainsBlocking =
        ref.mounted &&
        _canPublish(pending, generation) &&
        state.status == TeacherQuestionEditorStatus.outcomeReview;
    if (!remainsBlocking) {
      activity.release(pending.lease);
    }
  }

  TeacherQuestionBuilderController get _builder => ref.read(
    teacherQuestionBuilderControllerProvider(target.routeTarget).notifier,
  );

  bool _matchesTarget(TeacherHomework homework) {
    return homework.id.toLowerCase() ==
            target.routeTarget.homeworkId.toLowerCase() &&
        homework.topicId.toLowerCase() ==
            target.routeTarget.topicId.toLowerCase();
  }

  bool _detailAuthorityUnchanged(
    TeacherQuestionEditorPendingOperation pending,
  ) {
    return identical(
      ref.read(teacherHomeworkDetailControllerProvider(target.routeTarget)),
      pending.authorityStateAtStart,
    );
  }

  void _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    _clearSession();
    state = TeacherQuestionEditorState(
      status: TeacherQuestionEditorStatus.unavailable,
    );
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  bool _isSessionFailure(ApiFailure failure) {
    return failure.serverCode == ApiErrorCodes.authenticationRequired ||
        failure.serverCode == ApiErrorCodes.passwordChangeRequired ||
        failure.serverCode == ApiErrorCodes.userInactive ||
        failure.serverCode == ApiErrorCodes.institutionInactive;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _operationGeneration += 1;
    _initialized = false;
  }
}

TeacherQuestion? _findQuestion(TeacherHomework homework, String questionId) {
  for (final question in homework.questions) {
    if (question.id.toLowerCase() == questionId.toLowerCase()) {
      return question;
    }
  }
  return null;
}

bool _validIndex(List<Object?> values, int index) {
  return index >= 0 && index < values.length;
}

List<T> _move<T>(List<T> values, int index, int delta) {
  final moved = values.toList();
  final next = index + delta;
  if (index < 0 || index >= moved.length || next < 0 || next >= moved.length) {
    return moved;
  }
  final item = moved.removeAt(index);
  moved.insert(next, item);
  return moved;
}

bool _isQuestionConflict(String? code) {
  return code == ApiErrorCodes.topicNotEditable ||
      code == ApiErrorCodes.taskClosed ||
      code == ApiErrorCodes.taskArchived ||
      code == ApiErrorCodes.businessConflict ||
      code == ApiErrorCodes.resultPairLocked ||
      code == ApiErrorCodes.assessmentHasNoScoreablePoints;
}

String _editorConflictMessage(String code) {
  return switch (code) {
    ApiErrorCodes.businessConflict || ApiErrorCodes.resultPairLocked =>
      'Question editing is locked by the current server state. Review the current Homework before continuing.',
    ApiErrorCodes.taskClosed => 'This Homework is closed.',
    ApiErrorCodes.taskArchived => 'This Homework is archived.',
    ApiErrorCodes.topicNotEditable => 'The Topic is no longer editable.',
    ApiErrorCodes.assessmentHasNoScoreablePoints =>
      'An active Homework must keep at least one scoreable Question.',
    _ => 'The Question could not be saved.',
  };
}

TeacherQuestionDraftField? _draftFieldForServerKey(String key) {
  final root = key.split('.').first;
  return switch (TeacherQuestionMutationField.fromRequestKey(root)) {
    TeacherQuestionMutationField.type => TeacherQuestionDraftField.type,
    TeacherQuestionMutationField.prompt => TeacherQuestionDraftField.prompt,
    TeacherQuestionMutationField.instructions =>
      TeacherQuestionDraftField.instructions,
    TeacherQuestionMutationField.points => TeacherQuestionDraftField.points,
    TeacherQuestionMutationField.checkingMode =>
      TeacherQuestionDraftField.checkingMode,
    TeacherQuestionMutationField.configuration =>
      TeacherQuestionDraftField.configuration,
    null => null,
  };
}

String _serverValidationMessage(TeacherQuestionDraftField field) {
  return switch (field) {
    TeacherQuestionDraftField.type => 'Review the Question type.',
    TeacherQuestionDraftField.prompt => 'Review the Question prompt.',
    TeacherQuestionDraftField.instructions =>
      'Review the Question instructions.',
    TeacherQuestionDraftField.points => 'Review the Question points.',
    TeacherQuestionDraftField.checkingMode => 'Review the checking behavior.',
    TeacherQuestionDraftField.configuration =>
      'Review the Question configuration.',
  };
}

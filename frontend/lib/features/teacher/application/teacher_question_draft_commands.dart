import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/teacher_question.dart';
import '../domain/teacher_question_authoring.dart';
import 'teacher_question_editor_state.dart';

/// Local draft edits shared by every Question editor controller.
///
/// Subtype controllers own loading, submission and reconciliation; this mixin
/// is the single implementation of the nine-type draft transformations.
mixin TeacherQuestionDraftCommands on Notifier<TeacherQuestionEditorState> {
  TeacherQuestionLocalIdSequence get draftLocalIds;

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
      (draft) => draft.changeType(type, nextLocalId: draftLocalIds.next),
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
      (draft) =>
          draft.changeCheckingMode(mode, nextLocalId: draftLocalIds.next),
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
            localId: draftLocalIds.next(),
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
          TeacherAcceptedAnswerDraft(localId: draftLocalIds.next(), text: ''),
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
            localId: draftLocalIds.next(),
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
          TeacherOrderingItemDraft(localId: draftLocalIds.next(), text: ''),
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
            localId: draftLocalIds.next(),
            key: '',
            acceptedAnswers: [
              TeacherAcceptedAnswerDraft(
                localId: draftLocalIds.next(),
                text: '',
              ),
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
          TeacherAcceptedAnswerDraft(localId: draftLocalIds.next(), text: ''),
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

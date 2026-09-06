import 'teacher_question.dart';

abstract final class TeacherQuestionAuthoringLimits {
  static const maxQuestionsPerAssessment = 100;
  static const maxPromptLength = 10000;
  static const maxInstructionsLength = 5000;
  static const maxChoiceOptions = 20;
  static const maxOptionTextLength = 2000;
  static const maxShortAcceptedAnswers = 20;
  static const maxAcceptedAnswerLength = 1000;
  static const maxMatchingPairs = 50;
  static const maxMatchingItemTextLength = 2000;
  static const maxClientKeyLength = 80;
  static const maxOrderingItems = 50;
  static const maxOrderingItemTextLength = 2000;
  static const maxFillBlanks = 50;
  static const maxAcceptedAnswersPerBlank = 20;
  static const maxPoints = 999999.999999;
  static const maxPointsFractionDigits = 6;
}

typedef TeacherQuestionLocalIdGenerator = String Function();

class TeacherQuestionLocalIdSequence {
  TeacherQuestionLocalIdSequence({int initialValue = 0})
    : _nextValue = initialValue;

  int _nextValue;

  String next() {
    _nextValue += 1;
    return 'question_row_$_nextValue';
  }
}

enum TeacherQuestionDraftField {
  type,
  prompt,
  instructions,
  points,
  checkingMode,
  configuration,
}

class TeacherQuestionPoints {
  const TeacherQuestionPoints._(this.value, this.canonicalText);

  static TeacherQuestionPoints? tryParse(String text) {
    if (!_pointsPattern.hasMatch(text)) {
      return null;
    }
    final value = double.tryParse(text);
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        value > TeacherQuestionAuthoringLimits.maxPoints) {
      return null;
    }
    return TeacherQuestionPoints._(value, formatTeacherQuestionPoints(value));
  }

  final double value;
  final String canonicalText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherQuestionPoints && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

String formatTeacherQuestionPoints(double value) {
  if (!value.isFinite ||
      value < 0 ||
      value > TeacherQuestionAuthoringLimits.maxPoints) {
    throw ArgumentError.value(value, 'value', 'Points are outside the range.');
  }
  final fixed = value.toStringAsFixed(
    TeacherQuestionAuthoringLimits.maxPointsFractionDigits,
  );
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

TeacherQuestionCheckingMode teacherQuestionDefaultCheckingMode(
  TeacherQuestionType type,
) {
  return switch (type) {
    TeacherQuestionType.openWritten ||
    TeacherQuestionType.fileBased => TeacherQuestionCheckingMode.manual,
    _ => TeacherQuestionCheckingMode.automatic,
  };
}

bool isTeacherQuestionCheckingModeAllowed(
  TeacherQuestionType type,
  TeacherQuestionCheckingMode checkingMode,
) {
  return switch (type) {
    TeacherQuestionType.shortWritten => true,
    TeacherQuestionType.openWritten || TeacherQuestionType.fileBased =>
      checkingMode == TeacherQuestionCheckingMode.manual,
    _ => checkingMode == TeacherQuestionCheckingMode.automatic,
  };
}

class TeacherQuestionDraft {
  const TeacherQuestionDraft({
    required this.type,
    required this.prompt,
    required this.instructions,
    required this.pointsText,
    required this.checkingMode,
    required this.configurationDraft,
  });

  factory TeacherQuestionDraft.forAdd({
    TeacherQuestionLocalIdGenerator? nextLocalId,
  }) {
    final ids = _localIds(nextLocalId);
    return TeacherQuestionDraft(
      type: TeacherQuestionType.singleChoice,
      prompt: '',
      instructions: '',
      pointsText: '1',
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configurationDraft: TeacherQuestionConfigurationDraft.skeleton(
        TeacherQuestionType.singleChoice,
        TeacherQuestionCheckingMode.automatic,
        nextLocalId: ids,
      ),
    );
  }

  factory TeacherQuestionDraft.fromQuestion(
    TeacherQuestion question, {
    TeacherQuestionLocalIdGenerator? nextLocalId,
  }) {
    return TeacherQuestionDraft(
      type: question.type,
      prompt: question.prompt,
      instructions: question.instructions ?? '',
      pointsText: formatTeacherQuestionPoints(question.points),
      checkingMode: question.checkingMode,
      configurationDraft: TeacherQuestionConfigurationDraft.fromQuestion(
        question,
        nextLocalId: _localIds(nextLocalId),
      ),
    );
  }

  final TeacherQuestionType type;
  final String prompt;
  final String instructions;
  final String pointsText;
  final TeacherQuestionCheckingMode checkingMode;
  final TeacherQuestionConfigurationDraft configurationDraft;

  TeacherQuestionDraft copyWith({
    TeacherQuestionType? type,
    String? prompt,
    String? instructions,
    String? pointsText,
    TeacherQuestionCheckingMode? checkingMode,
    TeacherQuestionConfigurationDraft? configurationDraft,
  }) {
    return TeacherQuestionDraft(
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      instructions: instructions ?? this.instructions,
      pointsText: pointsText ?? this.pointsText,
      checkingMode: checkingMode ?? this.checkingMode,
      configurationDraft: configurationDraft ?? this.configurationDraft,
    );
  }

  bool requiresTypeChangeConfirmation(TeacherQuestionType nextType) {
    return nextType != type && configurationDraft.hasMeaningfulContent;
  }

  TeacherQuestionDraft changeType(
    TeacherQuestionType nextType, {
    TeacherQuestionLocalIdGenerator? nextLocalId,
  }) {
    if (nextType == type) {
      return this;
    }
    final nextMode = teacherQuestionDefaultCheckingMode(nextType);
    return TeacherQuestionDraft(
      type: nextType,
      prompt: prompt,
      instructions: instructions,
      pointsText: pointsText,
      checkingMode: nextMode,
      configurationDraft: TeacherQuestionConfigurationDraft.skeleton(
        nextType,
        nextMode,
        nextLocalId: _localIds(nextLocalId),
      ),
    );
  }

  bool requiresCheckingModeChangeConfirmation(
    TeacherQuestionCheckingMode nextMode,
  ) {
    return type == TeacherQuestionType.shortWritten &&
        checkingMode == TeacherQuestionCheckingMode.automatic &&
        nextMode == TeacherQuestionCheckingMode.manual &&
        configurationDraft.hasMeaningfulContent;
  }

  TeacherQuestionDraft changeCheckingMode(
    TeacherQuestionCheckingMode nextMode, {
    TeacherQuestionLocalIdGenerator? nextLocalId,
  }) {
    if (!isTeacherQuestionCheckingModeAllowed(type, nextMode)) {
      throw ArgumentError.value(
        nextMode,
        'nextMode',
        'Checking mode is incompatible with the Question type.',
      );
    }
    if (nextMode == checkingMode) {
      return this;
    }
    return copyWith(
      checkingMode: nextMode,
      configurationDraft: TeacherQuestionConfigurationDraft.skeleton(
        type,
        nextMode,
        nextLocalId: _localIds(nextLocalId),
      ),
    );
  }

  TeacherQuestionDraftValidationResult validate() {
    final errors = <TeacherQuestionDraftField, String>{};
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty ||
        normalizedPrompt.runes.length >
            TeacherQuestionAuthoringLimits.maxPromptLength) {
      errors[TeacherQuestionDraftField.prompt] =
          'Enter a Question prompt of ${TeacherQuestionAuthoringLimits.maxPromptLength} characters or fewer.';
    }

    String? normalizedInstructions;
    if (instructions.isEmpty) {
      normalizedInstructions = null;
    } else if (instructions.trim().isEmpty ||
        instructions.runes.length >
            TeacherQuestionAuthoringLimits.maxInstructionsLength) {
      errors[TeacherQuestionDraftField.instructions] =
          'Enter non-blank instructions of ${TeacherQuestionAuthoringLimits.maxInstructionsLength} characters or fewer.';
    } else {
      normalizedInstructions = instructions;
    }

    final points = TeacherQuestionPoints.tryParse(pointsText);
    if (points == null) {
      errors[TeacherQuestionDraftField.points] =
          'Enter points from 0 to ${TeacherQuestionAuthoringLimits.maxPoints} with up to ${TeacherQuestionAuthoringLimits.maxPointsFractionDigits} decimal places.';
    }

    if (!isTeacherQuestionCheckingModeAllowed(type, checkingMode)) {
      errors[TeacherQuestionDraftField.checkingMode] =
          'Select a checking mode supported by this Question type.';
    }

    final configurationResult = _validateConfiguration(this, normalizedPrompt);
    if (configurationResult.error case final error?) {
      errors[TeacherQuestionDraftField.configuration] = error;
    }

    if (errors.isNotEmpty ||
        points == null ||
        configurationResult.value == null) {
      return TeacherQuestionDraftValidationResult.invalid(errors);
    }
    return TeacherQuestionDraftValidationResult.valid(
      TeacherValidatedQuestionDraft(
        type: type,
        prompt: normalizedPrompt,
        instructions: normalizedInstructions,
        points: points,
        checkingMode: checkingMode,
        configuration: configurationResult.value!,
      ),
    );
  }

  bool semanticallyEqualsDraft(TeacherQuestionDraft other) {
    return type == other.type &&
        prompt == other.prompt &&
        instructions == other.instructions &&
        pointsText == other.pointsText &&
        checkingMode == other.checkingMode &&
        configurationDraft.semanticallyEqualsDraft(other.configurationDraft);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherQuestionDraft && semanticallyEqualsDraft(other);

  @override
  int get hashCode => Object.hash(
    type,
    prompt,
    instructions,
    pointsText,
    checkingMode,
    configurationDraft.semanticHashCode,
  );
}

class TeacherQuestionDraftValidationResult {
  TeacherQuestionDraftValidationResult._({
    required Map<TeacherQuestionDraftField, String> errors,
    required this.validatedDraft,
  }) : errors = Map<TeacherQuestionDraftField, String>.unmodifiable(errors);

  factory TeacherQuestionDraftValidationResult.valid(
    TeacherValidatedQuestionDraft draft,
  ) {
    return TeacherQuestionDraftValidationResult._(
      errors: const {},
      validatedDraft: draft,
    );
  }

  factory TeacherQuestionDraftValidationResult.invalid(
    Map<TeacherQuestionDraftField, String> errors,
  ) {
    if (errors.isEmpty) {
      throw ArgumentError.value(errors, 'errors', 'Errors cannot be empty.');
    }
    return TeacherQuestionDraftValidationResult._(
      errors: errors,
      validatedDraft: null,
    );
  }

  final Map<TeacherQuestionDraftField, String> errors;
  final TeacherValidatedQuestionDraft? validatedDraft;

  bool get isValid => validatedDraft != null;
  String? errorFor(TeacherQuestionDraftField field) => errors[field];

  TeacherValidatedQuestionDraft requireValidated() {
    final value = validatedDraft;
    if (value == null) {
      throw TeacherQuestionDraftValidationException(this);
    }
    return value;
  }
}

class TeacherQuestionDraftValidationException implements Exception {
  const TeacherQuestionDraftValidationException(this.result);

  final TeacherQuestionDraftValidationResult result;
}

class TeacherValidatedQuestionDraft {
  const TeacherValidatedQuestionDraft({
    required this.type,
    required this.prompt,
    required this.instructions,
    required this.points,
    required this.checkingMode,
    required this.configuration,
  });

  final TeacherQuestionType type;
  final String prompt;
  final String? instructions;
  final TeacherQuestionPoints points;
  final TeacherQuestionCheckingMode checkingMode;
  final TeacherCanonicalQuestionConfiguration configuration;
}

sealed class TeacherQuestionConfigurationDraft {
  const TeacherQuestionConfigurationDraft();

  factory TeacherQuestionConfigurationDraft.skeleton(
    TeacherQuestionType type,
    TeacherQuestionCheckingMode checkingMode, {
    TeacherQuestionLocalIdGenerator? nextLocalId,
  }) {
    final ids = _localIds(nextLocalId);
    return switch ((type, checkingMode)) {
      (
        TeacherQuestionType.singleChoice || TeacherQuestionType.multipleChoice,
        TeacherQuestionCheckingMode.automatic,
      ) =>
        TeacherChoiceConfigurationDraft(
          options: [
            TeacherChoiceOptionDraft(localId: ids(), text: '', isCorrect: true),
            TeacherChoiceOptionDraft(
              localId: ids(),
              text: '',
              isCorrect: false,
            ),
          ],
        ),
      (TeacherQuestionType.trueFalse, TeacherQuestionCheckingMode.automatic) =>
        const TeacherTrueFalseConfigurationDraft(correctValue: true),
      (
        TeacherQuestionType.shortWritten,
        TeacherQuestionCheckingMode.automatic,
      ) =>
        TeacherShortWrittenConfigurationDraft(
          acceptedAnswers: [
            TeacherAcceptedAnswerDraft(localId: ids(), text: ''),
          ],
        ),
      (TeacherQuestionType.shortWritten, TeacherQuestionCheckingMode.manual) ||
      (
        TeacherQuestionType.openWritten,
        TeacherQuestionCheckingMode.manual,
      ) => const TeacherEmptyConfigurationDraft(),
      (TeacherQuestionType.fileBased, TeacherQuestionCheckingMode.manual) =>
        const TeacherFileBasedConfigurationDraft(),
      (TeacherQuestionType.matching, TeacherQuestionCheckingMode.automatic) =>
        TeacherMatchingConfigurationDraft(
          pairs: [
            TeacherMatchingPairDraft(localId: ids(), left: '', right: ''),
          ],
        ),
      (TeacherQuestionType.ordering, TeacherQuestionCheckingMode.automatic) =>
        TeacherOrderingConfigurationDraft(
          items: [
            TeacherOrderingItemDraft(localId: ids(), text: ''),
            TeacherOrderingItemDraft(localId: ids(), text: ''),
          ],
        ),
      (
        TeacherQuestionType.fillInBlank,
        TeacherQuestionCheckingMode.automatic,
      ) =>
        TeacherFillInBlankConfigurationDraft(
          blanks: [
            TeacherFillBlankDraft(
              localId: ids(),
              key: '',
              acceptedAnswers: [
                TeacherAcceptedAnswerDraft(localId: ids(), text: ''),
              ],
            ),
          ],
        ),
      _ => throw ArgumentError(
        'Question type and checking mode are incompatible.',
      ),
    };
  }

  factory TeacherQuestionConfigurationDraft.fromQuestion(
    TeacherQuestion question, {
    TeacherQuestionLocalIdGenerator? nextLocalId,
  }) {
    final ids = _localIds(nextLocalId);
    return switch (question.configuration) {
      TeacherChoiceQuestionConfiguration(:final options) =>
        TeacherChoiceConfigurationDraft(
          options: [
            for (final option in options)
              TeacherChoiceOptionDraft(
                localId: ids(),
                text: option.text,
                isCorrect: option.isCorrect,
              ),
          ],
        ),
      TeacherTrueFalseQuestionConfiguration(:final correctValue) =>
        TeacherTrueFalseConfigurationDraft(correctValue: correctValue),
      TeacherShortWrittenAutomaticConfiguration(:final acceptedAnswers) =>
        TeacherShortWrittenConfigurationDraft(
          acceptedAnswers: [
            for (final answer in acceptedAnswers)
              TeacherAcceptedAnswerDraft(localId: ids(), text: answer),
          ],
        ),
      TeacherEmptyQuestionConfiguration() =>
        const TeacherEmptyConfigurationDraft(),
      TeacherFileBasedQuestionConfiguration() =>
        const TeacherFileBasedConfigurationDraft(),
      TeacherMatchingQuestionConfiguration(:final pairs) =>
        TeacherMatchingConfigurationDraft(
          pairs: [
            for (final pair in pairs)
              TeacherMatchingPairDraft(
                localId: ids(),
                left: pair.left,
                right: pair.right,
              ),
          ],
        ),
      TeacherOrderingQuestionConfiguration(:final items) =>
        TeacherOrderingConfigurationDraft(
          items: [
            for (final item in items)
              TeacherOrderingItemDraft(localId: ids(), text: item.text),
          ],
        ),
      TeacherFillInBlankQuestionConfiguration(:final blanks) =>
        TeacherFillInBlankConfigurationDraft(
          blanks: [
            for (final blank in blanks)
              TeacherFillBlankDraft(
                localId: ids(),
                key: blank.key,
                acceptedAnswers: [
                  for (final answer in blank.acceptedAnswers)
                    TeacherAcceptedAnswerDraft(localId: ids(), text: answer),
                ],
              ),
          ],
        ),
    };
  }

  bool get hasMeaningfulContent;
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other);
  int get semanticHashCode;
}

class TeacherChoiceOptionDraft {
  const TeacherChoiceOptionDraft({
    required this.localId,
    required this.text,
    required this.isCorrect,
  });

  final String localId;
  final String text;
  final bool isCorrect;

  TeacherChoiceOptionDraft copyWith({String? text, bool? isCorrect}) {
    return TeacherChoiceOptionDraft(
      localId: localId,
      text: text ?? this.text,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }

  bool semanticallyEquals(TeacherChoiceOptionDraft other) =>
      text == other.text && isCorrect == other.isCorrect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherChoiceOptionDraft &&
          localId == other.localId &&
          semanticallyEquals(other);

  @override
  int get hashCode => Object.hash(localId, text, isCorrect);
}

final class TeacherChoiceConfigurationDraft
    extends TeacherQuestionConfigurationDraft {
  TeacherChoiceConfigurationDraft({
    required List<TeacherChoiceOptionDraft> options,
  }) : options = List<TeacherChoiceOptionDraft>.unmodifiable(options);

  final List<TeacherChoiceOptionDraft> options;

  TeacherChoiceConfigurationDraft copyWith({
    required List<TeacherChoiceOptionDraft> options,
  }) => TeacherChoiceConfigurationDraft(options: options);

  @override
  bool get hasMeaningfulContent =>
      options.any((option) => option.text.isNotEmpty);

  @override
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other) =>
      other is TeacherChoiceConfigurationDraft &&
      _orderedSemanticEquals(options, other.options, (left, right) {
        return left.semanticallyEquals(right);
      });

  @override
  int get semanticHashCode => Object.hashAll(
    options.map((option) => Object.hash(option.text, option.isCorrect)),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherChoiceConfigurationDraft &&
          _orderedEquals(options, other.options);

  @override
  int get hashCode => Object.hashAll(options);
}

final class TeacherTrueFalseConfigurationDraft
    extends TeacherQuestionConfigurationDraft {
  const TeacherTrueFalseConfigurationDraft({required this.correctValue});

  final bool correctValue;

  TeacherTrueFalseConfigurationDraft copyWith({bool? correctValue}) =>
      TeacherTrueFalseConfigurationDraft(
        correctValue: correctValue ?? this.correctValue,
      );

  @override
  bool get hasMeaningfulContent => true;

  @override
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other) =>
      other is TeacherTrueFalseConfigurationDraft &&
      other.correctValue == correctValue;

  @override
  int get semanticHashCode => correctValue.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherTrueFalseConfigurationDraft &&
          other.correctValue == correctValue;

  @override
  int get hashCode => correctValue.hashCode;
}

class TeacherAcceptedAnswerDraft {
  const TeacherAcceptedAnswerDraft({required this.localId, required this.text});

  final String localId;
  final String text;

  TeacherAcceptedAnswerDraft copyWith({String? text}) =>
      TeacherAcceptedAnswerDraft(localId: localId, text: text ?? this.text);

  bool semanticallyEquals(TeacherAcceptedAnswerDraft other) =>
      text == other.text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherAcceptedAnswerDraft &&
          other.localId == localId &&
          other.text == text;

  @override
  int get hashCode => Object.hash(localId, text);
}

final class TeacherShortWrittenConfigurationDraft
    extends TeacherQuestionConfigurationDraft {
  TeacherShortWrittenConfigurationDraft({
    required List<TeacherAcceptedAnswerDraft> acceptedAnswers,
  }) : acceptedAnswers = List<TeacherAcceptedAnswerDraft>.unmodifiable(
         acceptedAnswers,
       );

  final List<TeacherAcceptedAnswerDraft> acceptedAnswers;

  TeacherShortWrittenConfigurationDraft copyWith({
    required List<TeacherAcceptedAnswerDraft> acceptedAnswers,
  }) => TeacherShortWrittenConfigurationDraft(acceptedAnswers: acceptedAnswers);

  @override
  bool get hasMeaningfulContent =>
      acceptedAnswers.any((answer) => answer.text.isNotEmpty);

  @override
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other) =>
      other is TeacherShortWrittenConfigurationDraft &&
      _orderedSemanticEquals(acceptedAnswers, other.acceptedAnswers, (
        left,
        right,
      ) {
        return left.semanticallyEquals(right);
      });

  @override
  int get semanticHashCode =>
      Object.hashAll(acceptedAnswers.map((answer) => answer.text));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherShortWrittenConfigurationDraft &&
          _orderedEquals(acceptedAnswers, other.acceptedAnswers);

  @override
  int get hashCode => Object.hashAll(acceptedAnswers);
}

final class TeacherEmptyConfigurationDraft
    extends TeacherQuestionConfigurationDraft {
  const TeacherEmptyConfigurationDraft();

  @override
  bool get hasMeaningfulContent => false;

  @override
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other) =>
      other is TeacherEmptyConfigurationDraft;

  @override
  int get semanticHashCode => runtimeType.hashCode;

  @override
  bool operator ==(Object other) => other is TeacherEmptyConfigurationDraft;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class TeacherFileBasedConfigurationDraft
    extends TeacherQuestionConfigurationDraft {
  const TeacherFileBasedConfigurationDraft();

  static const allowedExtensions = ['pdf', 'docx', 'ppt', 'pptx'];

  @override
  bool get hasMeaningfulContent => false;

  @override
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other) =>
      other is TeacherFileBasedConfigurationDraft;

  @override
  int get semanticHashCode => runtimeType.hashCode;

  @override
  bool operator ==(Object other) => other is TeacherFileBasedConfigurationDraft;

  @override
  int get hashCode => runtimeType.hashCode;
}

class TeacherMatchingPairDraft {
  const TeacherMatchingPairDraft({
    required this.localId,
    required this.left,
    required this.right,
  });

  final String localId;
  final String left;
  final String right;

  TeacherMatchingPairDraft copyWith({String? left, String? right}) =>
      TeacherMatchingPairDraft(
        localId: localId,
        left: left ?? this.left,
        right: right ?? this.right,
      );

  bool semanticallyEquals(TeacherMatchingPairDraft other) =>
      left == other.left && right == other.right;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherMatchingPairDraft &&
          other.localId == localId &&
          semanticallyEquals(other);

  @override
  int get hashCode => Object.hash(localId, left, right);
}

final class TeacherMatchingConfigurationDraft
    extends TeacherQuestionConfigurationDraft {
  TeacherMatchingConfigurationDraft({
    required List<TeacherMatchingPairDraft> pairs,
  }) : pairs = List<TeacherMatchingPairDraft>.unmodifiable(pairs);

  final List<TeacherMatchingPairDraft> pairs;

  TeacherMatchingConfigurationDraft copyWith({
    required List<TeacherMatchingPairDraft> pairs,
  }) => TeacherMatchingConfigurationDraft(pairs: pairs);

  @override
  bool get hasMeaningfulContent =>
      pairs.any((pair) => pair.left.isNotEmpty || pair.right.isNotEmpty);

  @override
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other) =>
      other is TeacherMatchingConfigurationDraft &&
      _orderedSemanticEquals(pairs, other.pairs, (left, right) {
        return left.semanticallyEquals(right);
      });

  @override
  int get semanticHashCode =>
      Object.hashAll(pairs.map((pair) => Object.hash(pair.left, pair.right)));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherMatchingConfigurationDraft &&
          _orderedEquals(pairs, other.pairs);

  @override
  int get hashCode => Object.hashAll(pairs);
}

class TeacherOrderingItemDraft {
  const TeacherOrderingItemDraft({required this.localId, required this.text});

  final String localId;
  final String text;

  TeacherOrderingItemDraft copyWith({String? text}) =>
      TeacherOrderingItemDraft(localId: localId, text: text ?? this.text);

  bool semanticallyEquals(TeacherOrderingItemDraft other) => text == other.text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherOrderingItemDraft &&
          other.localId == localId &&
          other.text == text;

  @override
  int get hashCode => Object.hash(localId, text);
}

final class TeacherOrderingConfigurationDraft
    extends TeacherQuestionConfigurationDraft {
  TeacherOrderingConfigurationDraft({
    required List<TeacherOrderingItemDraft> items,
  }) : items = List<TeacherOrderingItemDraft>.unmodifiable(items);

  final List<TeacherOrderingItemDraft> items;

  TeacherOrderingConfigurationDraft copyWith({
    required List<TeacherOrderingItemDraft> items,
  }) => TeacherOrderingConfigurationDraft(items: items);

  @override
  bool get hasMeaningfulContent => items.any((item) => item.text.isNotEmpty);

  @override
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other) =>
      other is TeacherOrderingConfigurationDraft &&
      _orderedSemanticEquals(items, other.items, (left, right) {
        return left.semanticallyEquals(right);
      });

  @override
  int get semanticHashCode => Object.hashAll(items.map((item) => item.text));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherOrderingConfigurationDraft &&
          _orderedEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll(items);
}

class TeacherFillBlankDraft {
  TeacherFillBlankDraft({
    required this.localId,
    required this.key,
    required List<TeacherAcceptedAnswerDraft> acceptedAnswers,
  }) : acceptedAnswers = List<TeacherAcceptedAnswerDraft>.unmodifiable(
         acceptedAnswers,
       );

  final String localId;
  final String key;
  final List<TeacherAcceptedAnswerDraft> acceptedAnswers;

  TeacherFillBlankDraft copyWith({
    String? key,
    List<TeacherAcceptedAnswerDraft>? acceptedAnswers,
  }) => TeacherFillBlankDraft(
    localId: localId,
    key: key ?? this.key,
    acceptedAnswers: acceptedAnswers ?? this.acceptedAnswers,
  );

  bool semanticallyEquals(TeacherFillBlankDraft other) =>
      key == other.key &&
      _orderedSemanticEquals(acceptedAnswers, other.acceptedAnswers, (
        left,
        right,
      ) {
        return left.semanticallyEquals(right);
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherFillBlankDraft &&
          other.localId == localId &&
          other.key == key &&
          _orderedEquals(acceptedAnswers, other.acceptedAnswers);

  @override
  int get hashCode =>
      Object.hash(localId, key, Object.hashAll(acceptedAnswers));
}

final class TeacherFillInBlankConfigurationDraft
    extends TeacherQuestionConfigurationDraft {
  TeacherFillInBlankConfigurationDraft({
    required List<TeacherFillBlankDraft> blanks,
  }) : blanks = List<TeacherFillBlankDraft>.unmodifiable(blanks);

  final List<TeacherFillBlankDraft> blanks;

  TeacherFillInBlankConfigurationDraft copyWith({
    required List<TeacherFillBlankDraft> blanks,
  }) => TeacherFillInBlankConfigurationDraft(blanks: blanks);

  @override
  bool get hasMeaningfulContent => blanks.any(
    (blank) =>
        blank.key.isNotEmpty ||
        blank.acceptedAnswers.any((answer) => answer.text.isNotEmpty),
  );

  @override
  bool semanticallyEqualsDraft(TeacherQuestionConfigurationDraft other) =>
      other is TeacherFillInBlankConfigurationDraft &&
      _orderedSemanticEquals(blanks, other.blanks, (left, right) {
        return left.semanticallyEquals(right);
      });

  @override
  int get semanticHashCode => Object.hashAll(
    blanks.map(
      (blank) => Object.hash(
        blank.key,
        Object.hashAll(blank.acceptedAnswers.map((answer) => answer.text)),
      ),
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherFillInBlankConfigurationDraft &&
          _orderedEquals(blanks, other.blanks);

  @override
  int get hashCode => Object.hashAll(blanks);
}

sealed class TeacherCanonicalQuestionConfiguration {
  const TeacherCanonicalQuestionConfiguration();

  Map<String, Object?> toJson();
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other);
  bool matches(TeacherQuestionConfiguration current);
}

class TeacherCanonicalChoiceOption {
  const TeacherCanonicalChoiceOption({
    required this.text,
    required this.isCorrect,
  });

  final String text;
  final bool isCorrect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCanonicalChoiceOption &&
          other.text == text &&
          other.isCorrect == isCorrect;

  @override
  int get hashCode => Object.hash(text, isCorrect);
}

final class TeacherCanonicalChoiceConfiguration
    extends TeacherCanonicalQuestionConfiguration {
  TeacherCanonicalChoiceConfiguration({
    required List<TeacherCanonicalChoiceOption> options,
  }) : options = List<TeacherCanonicalChoiceOption>.unmodifiable(options);

  final List<TeacherCanonicalChoiceOption> options;

  @override
  Map<String, Object?> toJson() => {
    'options': [
      for (var index = 0; index < options.length; index += 1)
        {
          'text': options[index].text,
          'is_correct': options[index].isCorrect,
          'position': index + 1,
        },
    ],
  };

  @override
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other) =>
      other is TeacherCanonicalChoiceConfiguration &&
      _orderedEquals(options, other.options);

  @override
  bool matches(TeacherQuestionConfiguration current) {
    if (current is! TeacherChoiceQuestionConfiguration ||
        current.options.length != options.length) {
      return false;
    }
    for (var index = 0; index < options.length; index += 1) {
      final expected = options[index];
      final actual = current.options[index];
      if (actual.text != expected.text ||
          actual.isCorrect != expected.isCorrect ||
          actual.position != index + 1) {
        return false;
      }
    }
    return true;
  }
}

final class TeacherCanonicalTrueFalseConfiguration
    extends TeacherCanonicalQuestionConfiguration {
  const TeacherCanonicalTrueFalseConfiguration({required this.correctValue});

  final bool correctValue;

  @override
  Map<String, Object?> toJson() => {'correct_value': correctValue};

  @override
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other) =>
      other is TeacherCanonicalTrueFalseConfiguration &&
      other.correctValue == correctValue;

  @override
  bool matches(TeacherQuestionConfiguration current) =>
      current is TeacherTrueFalseQuestionConfiguration &&
      current.correctValue == correctValue;
}

final class TeacherCanonicalShortWrittenConfiguration
    extends TeacherCanonicalQuestionConfiguration {
  TeacherCanonicalShortWrittenConfiguration({
    required List<String> acceptedAnswers,
  }) : acceptedAnswers = List<String>.unmodifiable(acceptedAnswers);

  final List<String> acceptedAnswers;

  @override
  Map<String, Object?> toJson() => {'accepted_answers': acceptedAnswers};

  @override
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other) =>
      other is TeacherCanonicalShortWrittenConfiguration &&
      _orderedEquals(acceptedAnswers, other.acceptedAnswers);

  @override
  bool matches(TeacherQuestionConfiguration current) =>
      current is TeacherShortWrittenAutomaticConfiguration &&
      _orderedEquals(acceptedAnswers, current.acceptedAnswers);
}

final class TeacherCanonicalEmptyConfiguration
    extends TeacherCanonicalQuestionConfiguration {
  const TeacherCanonicalEmptyConfiguration();

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other) =>
      other is TeacherCanonicalEmptyConfiguration;

  @override
  bool matches(TeacherQuestionConfiguration current) =>
      current is TeacherEmptyQuestionConfiguration;
}

final class TeacherCanonicalFileBasedConfiguration
    extends TeacherCanonicalQuestionConfiguration {
  const TeacherCanonicalFileBasedConfiguration();

  @override
  Map<String, Object?> toJson() => const {
    'allowed_extensions': TeacherFileBasedConfigurationDraft.allowedExtensions,
  };

  @override
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other) =>
      other is TeacherCanonicalFileBasedConfiguration;

  @override
  bool matches(TeacherQuestionConfiguration current) =>
      current is TeacherFileBasedQuestionConfiguration &&
      _orderedEquals(
        current.allowedExtensions,
        TeacherFileBasedConfigurationDraft.allowedExtensions,
      );
}

class TeacherCanonicalMatchingPair {
  const TeacherCanonicalMatchingPair({required this.left, required this.right});

  final String left;
  final String right;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCanonicalMatchingPair &&
          other.left == left &&
          other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

final class TeacherCanonicalMatchingConfiguration
    extends TeacherCanonicalQuestionConfiguration {
  TeacherCanonicalMatchingConfiguration({
    required List<TeacherCanonicalMatchingPair> pairs,
  }) : pairs = List<TeacherCanonicalMatchingPair>.unmodifiable(pairs);

  final List<TeacherCanonicalMatchingPair> pairs;

  @override
  Map<String, Object?> toJson() => {
    'pairs': [
      for (var index = 0; index < pairs.length; index += 1)
        {
          'client_key': 'pair_${index + 1}',
          'left': pairs[index].left,
          'right': pairs[index].right,
        },
    ],
  };

  @override
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other) =>
      other is TeacherCanonicalMatchingConfiguration &&
      _orderedEquals(pairs, other.pairs);

  @override
  bool matches(TeacherQuestionConfiguration current) {
    if (current is! TeacherMatchingQuestionConfiguration ||
        current.pairs.length != pairs.length) {
      return false;
    }
    for (var index = 0; index < pairs.length; index += 1) {
      if (current.pairs[index].left != pairs[index].left ||
          current.pairs[index].right != pairs[index].right) {
        return false;
      }
    }
    return true;
  }
}

final class TeacherCanonicalOrderingConfiguration
    extends TeacherCanonicalQuestionConfiguration {
  TeacherCanonicalOrderingConfiguration({required List<String> items})
    : items = List<String>.unmodifiable(items);

  final List<String> items;

  @override
  Map<String, Object?> toJson() => {
    'items': [
      for (var index = 0; index < items.length; index += 1)
        {'text': items[index], 'correct_position': index + 1},
    ],
  };

  @override
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other) =>
      other is TeacherCanonicalOrderingConfiguration &&
      _orderedEquals(items, other.items);

  @override
  bool matches(TeacherQuestionConfiguration current) {
    if (current is! TeacherOrderingQuestionConfiguration ||
        current.items.length != items.length) {
      return false;
    }
    for (var index = 0; index < items.length; index += 1) {
      if (current.items[index].text != items[index] ||
          current.items[index].correctPosition != index + 1) {
        return false;
      }
    }
    return true;
  }
}

class TeacherCanonicalFillBlank {
  TeacherCanonicalFillBlank({
    required this.key,
    required List<String> acceptedAnswers,
  }) : acceptedAnswers = List<String>.unmodifiable(acceptedAnswers);

  final String key;
  final List<String> acceptedAnswers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCanonicalFillBlank &&
          other.key == key &&
          _orderedEquals(other.acceptedAnswers, acceptedAnswers);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(acceptedAnswers));
}

final class TeacherCanonicalFillInBlankConfiguration
    extends TeacherCanonicalQuestionConfiguration {
  TeacherCanonicalFillInBlankConfiguration({
    required List<TeacherCanonicalFillBlank> blanks,
  }) : blanks = List<TeacherCanonicalFillBlank>.unmodifiable(blanks);

  final List<TeacherCanonicalFillBlank> blanks;

  @override
  Map<String, Object?> toJson() => {
    'blanks': [
      for (var index = 0; index < blanks.length; index += 1)
        {
          'key': blanks[index].key,
          'position': index + 1,
          'accepted_answers': blanks[index].acceptedAnswers,
        },
    ],
  };

  @override
  bool semanticallyEquals(TeacherCanonicalQuestionConfiguration other) =>
      other is TeacherCanonicalFillInBlankConfiguration &&
      _orderedEquals(blanks, other.blanks);

  @override
  bool matches(TeacherQuestionConfiguration current) {
    if (current is! TeacherFillInBlankQuestionConfiguration ||
        current.blanks.length != blanks.length) {
      return false;
    }
    for (var index = 0; index < blanks.length; index += 1) {
      final expected = blanks[index];
      final actual = current.blanks[index];
      if (actual.key != expected.key ||
          actual.position != index + 1 ||
          !_orderedEquals(actual.acceptedAnswers, expected.acceptedAnswers)) {
        return false;
      }
    }
    return true;
  }
}

class _ConfigurationValidation {
  const _ConfigurationValidation({this.value, this.error});

  final TeacherCanonicalQuestionConfiguration? value;
  final String? error;
}

_ConfigurationValidation _validateConfiguration(
  TeacherQuestionDraft draft,
  String normalizedPrompt,
) {
  const genericError = 'Review the Question configuration.';
  final configuration = draft.configurationDraft;

  switch (draft.type) {
    case TeacherQuestionType.singleChoice:
    case TeacherQuestionType.multipleChoice:
      if (draft.checkingMode != TeacherQuestionCheckingMode.automatic ||
          configuration is! TeacherChoiceConfigurationDraft ||
          configuration.options.length < 2 ||
          configuration.options.length >
              TeacherQuestionAuthoringLimits.maxChoiceOptions) {
        return const _ConfigurationValidation(error: genericError);
      }
      final options = <TeacherCanonicalChoiceOption>[];
      for (final option in configuration.options) {
        final text = option.text.trim();
        if (text.isEmpty ||
            text.runes.length >
                TeacherQuestionAuthoringLimits.maxOptionTextLength) {
          return const _ConfigurationValidation(error: genericError);
        }
        options.add(
          TeacherCanonicalChoiceOption(text: text, isCorrect: option.isCorrect),
        );
      }
      final correctCount = options.where((option) => option.isCorrect).length;
      if ((draft.type == TeacherQuestionType.singleChoice &&
              correctCount != 1) ||
          (draft.type == TeacherQuestionType.multipleChoice &&
              correctCount < 1)) {
        return const _ConfigurationValidation(error: genericError);
      }
      return _ConfigurationValidation(
        value: TeacherCanonicalChoiceConfiguration(options: options),
      );

    case TeacherQuestionType.trueFalse:
      if (draft.checkingMode != TeacherQuestionCheckingMode.automatic ||
          configuration is! TeacherTrueFalseConfigurationDraft) {
        return const _ConfigurationValidation(error: genericError);
      }
      return _ConfigurationValidation(
        value: TeacherCanonicalTrueFalseConfiguration(
          correctValue: configuration.correctValue,
        ),
      );

    case TeacherQuestionType.shortWritten:
      if (draft.checkingMode == TeacherQuestionCheckingMode.manual) {
        if (configuration is! TeacherEmptyConfigurationDraft) {
          return const _ConfigurationValidation(error: genericError);
        }
        return const _ConfigurationValidation(
          value: TeacherCanonicalEmptyConfiguration(),
        );
      }
      if (configuration is! TeacherShortWrittenConfigurationDraft ||
          configuration.acceptedAnswers.isEmpty ||
          configuration.acceptedAnswers.length >
              TeacherQuestionAuthoringLimits.maxShortAcceptedAnswers) {
        return const _ConfigurationValidation(error: genericError);
      }
      final answers = _canonicalAnswers(configuration.acceptedAnswers);
      if (answers == null) {
        return const _ConfigurationValidation(error: genericError);
      }
      return _ConfigurationValidation(
        value: TeacherCanonicalShortWrittenConfiguration(
          acceptedAnswers: answers,
        ),
      );

    case TeacherQuestionType.openWritten:
      if (draft.checkingMode != TeacherQuestionCheckingMode.manual ||
          configuration is! TeacherEmptyConfigurationDraft) {
        return const _ConfigurationValidation(error: genericError);
      }
      return const _ConfigurationValidation(
        value: TeacherCanonicalEmptyConfiguration(),
      );

    case TeacherQuestionType.fileBased:
      if (draft.checkingMode != TeacherQuestionCheckingMode.manual ||
          configuration is! TeacherFileBasedConfigurationDraft) {
        return const _ConfigurationValidation(error: genericError);
      }
      return const _ConfigurationValidation(
        value: TeacherCanonicalFileBasedConfiguration(),
      );

    case TeacherQuestionType.matching:
      if (draft.checkingMode != TeacherQuestionCheckingMode.automatic ||
          configuration is! TeacherMatchingConfigurationDraft ||
          configuration.pairs.isEmpty ||
          configuration.pairs.length >
              TeacherQuestionAuthoringLimits.maxMatchingPairs) {
        return const _ConfigurationValidation(error: genericError);
      }
      final pairs = <TeacherCanonicalMatchingPair>[];
      for (final pair in configuration.pairs) {
        final left = pair.left.trim();
        final right = pair.right.trim();
        if (left.isEmpty ||
            right.isEmpty ||
            left.runes.length >
                TeacherQuestionAuthoringLimits.maxMatchingItemTextLength ||
            right.runes.length >
                TeacherQuestionAuthoringLimits.maxMatchingItemTextLength) {
          return const _ConfigurationValidation(error: genericError);
        }
        pairs.add(TeacherCanonicalMatchingPair(left: left, right: right));
      }
      return _ConfigurationValidation(
        value: TeacherCanonicalMatchingConfiguration(pairs: pairs),
      );

    case TeacherQuestionType.ordering:
      if (draft.checkingMode != TeacherQuestionCheckingMode.automatic ||
          configuration is! TeacherOrderingConfigurationDraft ||
          configuration.items.length < 2 ||
          configuration.items.length >
              TeacherQuestionAuthoringLimits.maxOrderingItems) {
        return const _ConfigurationValidation(error: genericError);
      }
      final items = <String>[];
      for (final item in configuration.items) {
        final text = item.text.trim();
        if (text.isEmpty ||
            text.runes.length >
                TeacherQuestionAuthoringLimits.maxOrderingItemTextLength) {
          return const _ConfigurationValidation(error: genericError);
        }
        items.add(text);
      }
      return _ConfigurationValidation(
        value: TeacherCanonicalOrderingConfiguration(items: items),
      );

    case TeacherQuestionType.fillInBlank:
      if (draft.checkingMode != TeacherQuestionCheckingMode.automatic ||
          configuration is! TeacherFillInBlankConfigurationDraft ||
          configuration.blanks.isEmpty ||
          configuration.blanks.length >
              TeacherQuestionAuthoringLimits.maxFillBlanks) {
        return const _ConfigurationValidation(error: genericError);
      }
      final blanks = <TeacherCanonicalFillBlank>[];
      final keys = <String>{};
      for (final blank in configuration.blanks) {
        if (!_fillBlankKeyPattern.hasMatch(blank.key) ||
            !keys.add(blank.key) ||
            blank.acceptedAnswers.isEmpty ||
            blank.acceptedAnswers.length >
                TeacherQuestionAuthoringLimits.maxAcceptedAnswersPerBlank) {
          return const _ConfigurationValidation(error: genericError);
        }
        final answers = _canonicalAnswers(blank.acceptedAnswers);
        if (answers == null) {
          return const _ConfigurationValidation(error: genericError);
        }
        blanks.add(
          TeacherCanonicalFillBlank(key: blank.key, acceptedAnswers: answers),
        );
      }
      final placeholderKeys = _fillBlankPlaceholderPattern
          .allMatches(normalizedPrompt)
          .map((match) => match.group(1)!)
          .toList(growable: false);
      if (placeholderKeys.length != keys.length ||
          placeholderKeys.toSet().length != placeholderKeys.length ||
          placeholderKeys.toSet().difference(keys).isNotEmpty ||
          keys.difference(placeholderKeys.toSet()).isNotEmpty) {
        return const _ConfigurationValidation(
          error:
              'Each configured blank must appear exactly once in the prompt as {{key}}.',
        );
      }
      return _ConfigurationValidation(
        value: TeacherCanonicalFillInBlankConfiguration(blanks: blanks),
      );
  }
}

List<String>? _canonicalAnswers(List<TeacherAcceptedAnswerDraft> drafts) {
  final answers = <String>[];
  final unique = <String>{};
  for (final draft in drafts) {
    final answer = draft.text.trim();
    if (answer.isEmpty ||
        answer.runes.length >
            TeacherQuestionAuthoringLimits.maxAcceptedAnswerLength ||
        !unique.add(answer)) {
      return null;
    }
    answers.add(answer);
  }
  return List<String>.unmodifiable(answers);
}

TeacherQuestionLocalIdGenerator _localIds(
  TeacherQuestionLocalIdGenerator? generator,
) {
  if (generator != null) {
    return generator;
  }
  final sequence = TeacherQuestionLocalIdSequence();
  return sequence.next;
}

bool _orderedEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _orderedSemanticEquals<T>(
  List<T> left,
  List<T> right,
  bool Function(T left, T right) equals,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (!equals(left[index], right[index])) {
      return false;
    }
  }
  return true;
}

final _pointsPattern = RegExp(r'^\d+(?:\.\d{1,6})?$');
final _fillBlankKeyPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,79}$');
final _fillBlankPlaceholderPattern = RegExp(
  r'\{\{([A-Za-z][A-Za-z0-9_-]{0,79})\}\}',
);

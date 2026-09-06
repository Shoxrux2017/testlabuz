import 'teacher_question.dart';
import 'teacher_question_authoring.dart';

enum TeacherQuestionMutationOperation { add, update, delete, reorder }

class TeacherQuestionMutationOutcomeUnknownException implements Exception {
  const TeacherQuestionMutationOutcomeUnknownException(this.operation);

  final TeacherQuestionMutationOperation operation;
}

enum TeacherQuestionMutationField {
  type('type'),
  prompt('prompt'),
  instructions('instructions'),
  points('points'),
  checkingMode('checking_mode'),
  configuration('configuration');

  const TeacherQuestionMutationField(this.requestKey);

  final String requestKey;

  static TeacherQuestionMutationField? fromRequestKey(String key) {
    return switch (key) {
      'type' => TeacherQuestionMutationField.type,
      'prompt' => TeacherQuestionMutationField.prompt,
      'instructions' => TeacherQuestionMutationField.instructions,
      'points' => TeacherQuestionMutationField.points,
      'checking_mode' => TeacherQuestionMutationField.checkingMode,
      'configuration' => TeacherQuestionMutationField.configuration,
      _ => null,
    };
  }
}

class TeacherQuestionCreateRequest {
  const TeacherQuestionCreateRequest._({
    required this.validatedDraft,
    required this.position,
  });

  factory TeacherQuestionCreateRequest.fromDraft({
    required TeacherQuestionDraft draft,
    required int position,
  }) {
    return TeacherQuestionCreateRequest.fromValidated(
      validatedDraft: draft.validate().requireValidated(),
      position: position,
    );
  }

  factory TeacherQuestionCreateRequest.fromValidated({
    required TeacherValidatedQuestionDraft validatedDraft,
    required int position,
  }) {
    if (position < 1 ||
        position > TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment) {
      throw ArgumentError.value(
        position,
        'position',
        'Question position must be between 1 and ${TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment}.',
      );
    }
    return TeacherQuestionCreateRequest._(
      validatedDraft: validatedDraft,
      position: position,
    );
  }

  final TeacherValidatedQuestionDraft validatedDraft;
  final int position;

  TeacherQuestionType get type => validatedDraft.type;
  String get prompt => validatedDraft.prompt;
  String? get instructions => validatedDraft.instructions;
  double get points => validatedDraft.points.value;
  TeacherQuestionCheckingMode get checkingMode => validatedDraft.checkingMode;
  TeacherCanonicalQuestionConfiguration get configuration =>
      validatedDraft.configuration;

  Map<String, Object?> toJson() => {
    'type': type.value,
    'prompt': prompt,
    'instructions': instructions,
    'points': points,
    'position': position,
    'checking_mode': checkingMode.value,
    'configuration': configuration.toJson(),
  };
}

class TeacherQuestionEditSnapshot {
  const TeacherQuestionEditSnapshot({
    required this.type,
    required this.prompt,
    required this.instructions,
    required this.points,
    required this.checkingMode,
    required this.configuration,
  });

  factory TeacherQuestionEditSnapshot.fromQuestion(TeacherQuestion question) {
    final validated = TeacherQuestionDraft.fromQuestion(
      question,
    ).validate().requireValidated();
    return TeacherQuestionEditSnapshot(
      type: validated.type,
      prompt: validated.prompt,
      instructions: validated.instructions,
      points: validated.points.value,
      checkingMode: validated.checkingMode,
      configuration: validated.configuration,
    );
  }

  final TeacherQuestionType type;
  final String prompt;
  final String? instructions;
  final double points;
  final TeacherQuestionCheckingMode checkingMode;
  final TeacherCanonicalQuestionConfiguration configuration;
}

class TeacherQuestionEditRequest {
  TeacherQuestionEditRequest._({
    required this.validatedDraft,
    required Set<TeacherQuestionMutationField> changedFields,
  }) : changedFields = Set<TeacherQuestionMutationField>.unmodifiable(
         changedFields,
       );

  factory TeacherQuestionEditRequest.fromDraft({
    required TeacherQuestionDraft draft,
    required TeacherQuestionEditSnapshot initial,
  }) {
    return TeacherQuestionEditRequest.fromValidated(
      validatedDraft: draft.validate().requireValidated(),
      initial: initial,
    );
  }

  factory TeacherQuestionEditRequest.fromValidated({
    required TeacherValidatedQuestionDraft validatedDraft,
    required TeacherQuestionEditSnapshot initial,
  }) {
    final changed = <TeacherQuestionMutationField>{};
    final typeChanged = validatedDraft.type != initial.type;
    final checkingModeChanged =
        validatedDraft.checkingMode != initial.checkingMode;

    if (typeChanged) {
      changed.add(TeacherQuestionMutationField.type);
    }
    if (validatedDraft.prompt != initial.prompt) {
      changed.add(TeacherQuestionMutationField.prompt);
    }
    if (validatedDraft.instructions != initial.instructions) {
      changed.add(TeacherQuestionMutationField.instructions);
    }
    if (validatedDraft.points.value != initial.points) {
      changed.add(TeacherQuestionMutationField.points);
    }
    if (checkingModeChanged) {
      changed.add(TeacherQuestionMutationField.checkingMode);
    }
    if (typeChanged ||
        checkingModeChanged ||
        !validatedDraft.configuration.semanticallyEquals(
          initial.configuration,
        )) {
      changed.add(TeacherQuestionMutationField.configuration);
    }

    return TeacherQuestionEditRequest._(
      validatedDraft: validatedDraft,
      changedFields: changed,
    );
  }

  final TeacherValidatedQuestionDraft validatedDraft;
  final Set<TeacherQuestionMutationField> changedFields;

  bool get isEmpty => changedFields.isEmpty;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    for (final field in TeacherQuestionMutationField.values) {
      if (!changedFields.contains(field)) {
        continue;
      }
      json[field.requestKey] = switch (field) {
        TeacherQuestionMutationField.type => validatedDraft.type.value,
        TeacherQuestionMutationField.prompt => validatedDraft.prompt,
        TeacherQuestionMutationField.instructions =>
          validatedDraft.instructions,
        TeacherQuestionMutationField.points => validatedDraft.points.value,
        TeacherQuestionMutationField.checkingMode =>
          validatedDraft.checkingMode.value,
        TeacherQuestionMutationField.configuration =>
          validatedDraft.configuration.toJson(),
      };
    }
    return json;
  }

  bool matches(TeacherQuestion current) {
    for (final field in changedFields) {
      final matches = switch (field) {
        TeacherQuestionMutationField.type =>
          current.type == validatedDraft.type,
        TeacherQuestionMutationField.prompt =>
          current.prompt == validatedDraft.prompt,
        TeacherQuestionMutationField.instructions =>
          current.instructions == validatedDraft.instructions,
        TeacherQuestionMutationField.points =>
          current.points == validatedDraft.points.value,
        TeacherQuestionMutationField.checkingMode =>
          current.checkingMode == validatedDraft.checkingMode,
        TeacherQuestionMutationField.configuration =>
          validatedDraft.configuration.matches(current.configuration),
      };
      if (!matches) {
        return false;
      }
    }
    return true;
  }
}

class TeacherQuestionReorderRequest {
  TeacherQuestionReorderRequest({required List<String> questionIds})
    : questionIds = List<String>.unmodifiable(questionIds) {
    final canonicalIds = <String>{};
    for (final id in this.questionIds) {
      if (!_canonicalUuidPattern.hasMatch(id) ||
          !canonicalIds.add(id.toLowerCase())) {
        throw ArgumentError.value(
          questionIds,
          'questionIds',
          'Question IDs must be unique canonical UUIDs.',
        );
      }
    }
  }

  final List<String> questionIds;

  Map<String, Object?> toJson() => {'question_ids': questionIds};
}

final _canonicalUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

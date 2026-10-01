import '../../domain/teacher_question.dart';
import '../../domain/teacher_submission.dart';
import '../../domain/teacher_submission_detail.dart';
import 'teacher_dto_parse.dart';
import 'teacher_question_dto.dart';
import 'teacher_submission_dto.dart';

const _fileExtensions = ['pdf', 'docx', 'ppt', 'pptx'];
const _maxFileBytes = 15728640;
final _blankKeyPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,79}$');

/// A strictly parsed submission detail (`S09-DOC-001` §10.3): the queue item,
/// the submit time and every Question with the Student's answer.
class TeacherSubmissionDetailDto {
  const TeacherSubmissionDetailDto._(this._detail);

  factory TeacherSubmissionDetailDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher submission detail',
      keys: const {..._itemKeys, 'submitted_at', 'questions'},
    );
    final submission = TeacherSubmissionDto.fromJson(
      Map<String, Object?>.of(map)
        ..remove('submitted_at')
        ..remove('questions'),
    ).toDomain();
    final rawQuestions = map['questions'];
    if (rawQuestions is! List<Object?>) {
      throw const FormatException('Submission questions must be an array.');
    }
    final questions = rawQuestions.map(_readQuestionEntry).toList();
    _requireQuestionOrder(questions);
    _requireConsistentSubmission(submission, questions);

    return TeacherSubmissionDetailDto._(
      TeacherSubmissionDetail(
        submission: submission,
        submittedAt: readTeacherNullableUtcTimestamp(map, 'submitted_at'),
        questions: questions,
      ),
    );
  }

  final TeacherSubmissionDetail _detail;

  TeacherSubmissionDetail toDomain() => _detail;
}

const _itemKeys = {
  'id',
  'assessment',
  'official',
  'topic',
  'group',
  'student',
  'attempt_number',
  'status',
  'official_score_eligible',
  'finalization_reason',
  'finalized_at',
  'review',
  'review_due_at',
  'review_overdue',
  'score',
};

TeacherReviewQuestion _readQuestionEntry(Object? json) {
  final entry = readExactTeacherMap(
    json,
    context: 'Submission question entry',
    keys: const {'question', 'answer'},
  );
  final map = readExactTeacherMap(
    entry['question'],
    context: 'Submission question',
    keys: const {
      'id',
      'type',
      'position',
      'prompt',
      'points',
      'checking_mode',
      'configuration',
    },
  );
  final rawType = map['type'];
  final rawMode = map['checking_mode'];
  if (rawType is! String || rawMode is! String) {
    throw const FormatException('Question type and mode must be strings.');
  }
  final type = TeacherQuestionType.parse(rawType);
  final mode = TeacherQuestionCheckingMode.parse(rawMode);
  if (!_allowsMode(type, mode)) {
    throw const FormatException('The checking mode is not allowed here.');
  }
  final position = readTeacherInt(map, 'position');
  if (position < 1) {
    throw const FormatException('Question position must be positive.');
  }
  final points = readTeacherNonNegativeNumber(map, 'points');
  final configuration = _readConfiguration(map['configuration'], type, mode);
  final rawAnswer = entry['answer'];

  return TeacherReviewQuestion(
    id: readTeacherCanonicalUuid(map, 'id'),
    type: type,
    position: position,
    prompt: readTeacherNonBlankString(map, 'prompt'),
    points: points,
    checkingMode: mode,
    configuration: configuration,
    answer: rawAnswer == null
        ? null
        : _readAnswer(rawAnswer, type, mode, configuration, points),
  );
}

bool _allowsMode(TeacherQuestionType type, TeacherQuestionCheckingMode mode) {
  return switch (type) {
    TeacherQuestionType.shortWritten => true,
    TeacherQuestionType.openWritten ||
    TeacherQuestionType.fileBased => mode == TeacherQuestionCheckingMode.manual,
    _ => mode == TeacherQuestionCheckingMode.automatic,
  };
}

TeacherReviewConfiguration _readConfiguration(
  Object? json,
  TeacherQuestionType type,
  TeacherQuestionCheckingMode mode,
) {
  const context = 'Question configuration';
  switch (type) {
    case TeacherQuestionType.singleChoice:
    case TeacherQuestionType.multipleChoice:
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'options'},
      );
      final options = _readRows(map, 'options', 2, 20).map((row) {
        final option = readExactTeacherMap(
          row,
          context: 'Choice option',
          keys: const {'id', 'text', 'is_correct', 'position'},
        );
        return TeacherReviewOption(
          id: readTeacherCanonicalUuid(option, 'id'),
          text: readTeacherNonBlankString(option, 'text'),
          isCorrect: _readBool(option, 'is_correct'),
          position: readTeacherInt(option, 'position'),
        );
      }).toList();
      _requireSequence(options.map((option) => option.position));
      _requireUnique(options.map((option) => option.id));
      final correct = options.where((option) => option.isCorrect).length;
      if (type == TeacherQuestionType.singleChoice
          ? correct != 1
          : correct < 1) {
        throw const FormatException('Choice options have a wrong key.');
      }
      return TeacherReviewChoiceConfiguration(options);
    case TeacherQuestionType.trueFalse:
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'correct_value'},
      );
      return TeacherReviewTrueFalseConfiguration(
        _readBool(map, 'correct_value'),
      );
    case TeacherQuestionType.shortWritten:
      if (mode == TeacherQuestionCheckingMode.manual) {
        readExactTeacherMap(json, context: context, keys: const {});
        return TeacherReviewShortWrittenConfiguration(const []);
      }
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'accepted_answers'},
      );
      return TeacherReviewShortWrittenConfiguration(
        _readStrings(map, 'accepted_answers', 1, 20),
      );
    case TeacherQuestionType.openWritten:
      readExactTeacherMap(json, context: context, keys: const {});
      return const TeacherReviewOpenWrittenConfiguration();
    case TeacherQuestionType.fileBased:
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'allowed_extensions'},
      );
      final extensions = _readStrings(map, 'allowed_extensions', 4, 4);
      for (var index = 0; index < extensions.length; index += 1) {
        if (extensions[index] != _fileExtensions[index]) {
          throw const FormatException('File extensions are unexpected.');
        }
      }
      return TeacherReviewFileConfiguration(extensions);
    case TeacherQuestionType.matching:
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'pairs'},
      );
      final pairs = _readRows(map, 'pairs', 1, null).map((row) {
        final pair = readExactTeacherMap(
          row,
          context: 'Matching pair',
          keys: const {
            'client_key',
            'left',
            'right',
            'left_item_id',
            'right_item_id',
          },
        );
        readTeacherCanonicalUuid(pair, 'client_key');
        return TeacherReviewMatchingPair(
          left: readTeacherNonBlankString(pair, 'left'),
          right: readTeacherNonBlankString(pair, 'right'),
          leftItemId: readTeacherCanonicalUuid(pair, 'left_item_id'),
          rightItemId: readTeacherCanonicalUuid(pair, 'right_item_id'),
        );
      }).toList();
      _requireUnique([
        for (final pair in pairs) ...[pair.leftItemId, pair.rightItemId],
      ]);
      return TeacherReviewMatchingConfiguration(pairs);
    case TeacherQuestionType.ordering:
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'items'},
      );
      final items = _readRows(map, 'items', 2, null).map((row) {
        final item = readExactTeacherMap(
          row,
          context: 'Ordering item',
          keys: const {'id', 'text', 'correct_position'},
        );
        return TeacherReviewOrderingItem(
          id: readTeacherCanonicalUuid(item, 'id'),
          text: readTeacherNonBlankString(item, 'text'),
          correctPosition: readTeacherInt(item, 'correct_position'),
        );
      }).toList();
      _requireSequence(items.map((item) => item.correctPosition));
      _requireUnique(items.map((item) => item.id));
      return TeacherReviewOrderingConfiguration(items);
    case TeacherQuestionType.fillInBlank:
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'blanks'},
      );
      final blanks = _readRows(map, 'blanks', 1, null).map((row) {
        final blank = readExactTeacherMap(
          row,
          context: 'Fill-in-the-blank blank',
          keys: const {'id', 'key', 'position', 'accepted_answers'},
        );
        final key = readTeacherNonBlankString(blank, 'key');
        if (!_blankKeyPattern.hasMatch(key)) {
          throw const FormatException('A blank key is invalid.');
        }
        return TeacherReviewBlank(
          id: readTeacherCanonicalUuid(blank, 'id'),
          key: key,
          position: readTeacherInt(blank, 'position'),
          acceptedAnswers: _readStrings(blank, 'accepted_answers', 1, null),
        );
      }).toList();
      _requireSequence(blanks.map((blank) => blank.position));
      _requireUnique(blanks.map((blank) => blank.id));
      // Blank keys are case-sensitive, like their placeholders.
      final keys = blanks.map((blank) => blank.key).toList();
      if (keys.toSet().length != keys.length) {
        throw const FormatException('Blank keys must be unique.');
      }
      return TeacherReviewFillInBlankConfiguration(blanks);
  }
}

TeacherReviewAnswer _readAnswer(
  Object? json,
  TeacherQuestionType type,
  TeacherQuestionCheckingMode mode,
  TeacherReviewConfiguration configuration,
  double points,
) {
  final map = readExactTeacherMap(
    json,
    context: 'Submission answer',
    keys: const {
      'id',
      'value',
      'checking_status',
      'awarded_points',
      'feedback',
      'checked_by',
      'checked_at',
    },
  );
  final rawStatus = map['checking_status'];
  final status = rawStatus is String
      ? TeacherReviewAnswerStatus.fromValue(rawStatus)
      : null;
  if (status == null) {
    throw const FormatException('Answer checking status is unknown.');
  }
  final awarded = map['awarded_points'] == null
      ? null
      : readTeacherNonNegativeNumber(map, 'awarded_points');
  if (awarded != null && awarded > points) {
    throw const FormatException('Awarded points exceed the Question points.');
  }
  final feedback = readTeacherNullableString(map, 'feedback');
  if (feedback != null && feedback.isEmpty) {
    throw const FormatException('Answer feedback cannot be empty.');
  }
  final checkedAt = readTeacherNullableUtcTimestamp(map, 'checked_at');
  final checkedBy = map['checked_by'] == null
      ? null
      : _readReviewer(map['checked_by']);

  final valid = switch (status) {
    TeacherReviewAnswerStatus.pending ||
    TeacherReviewAnswerStatus.waitingForTeacherReview =>
      awarded == null &&
          feedback == null &&
          checkedBy == null &&
          checkedAt == null,
    TeacherReviewAnswerStatus.autoChecked =>
      awarded != null &&
          checkedAt != null &&
          feedback == null &&
          checkedBy == null,
    TeacherReviewAnswerStatus.teacherChecked =>
      awarded != null && checkedAt != null && checkedBy != null,
  };
  // Only manual Questions are reviewed by a Teacher.
  final reviewed =
      status == TeacherReviewAnswerStatus.waitingForTeacherReview ||
      status == TeacherReviewAnswerStatus.teacherChecked;
  if (!valid || (reviewed && mode != TeacherQuestionCheckingMode.manual)) {
    throw const FormatException('Answer fields contradict its status.');
  }

  return TeacherReviewAnswer(
    id: readTeacherCanonicalUuid(map, 'id'),
    value: _readValue(map['value'], type, configuration),
    checkingStatus: status,
    awardedPoints: awarded,
    feedback: feedback,
    checkedBy: checkedBy,
    checkedAt: checkedAt,
  );
}

TeacherReviewer _readReviewer(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Answer reviewer',
    keys: const {'id', 'full_name'},
  );
  return TeacherReviewer(
    id: readTeacherCanonicalUuid(map, 'id'),
    fullName: readTeacherNonBlankString(map, 'full_name'),
  );
}

TeacherReviewAnswerValue _readValue(
  Object? json,
  TeacherQuestionType type,
  TeacherReviewConfiguration configuration,
) {
  const context = 'Answer value';
  switch (configuration) {
    case TeacherReviewChoiceConfiguration(:final options):
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'selected_option_ids'},
      );
      final selected = _readIds(map, 'selected_option_ids');
      final known = {for (final option in options) option.id};
      final correct = options.where((option) => option.isCorrect).length;
      final maxSelections = type == TeacherQuestionType.singleChoice
          ? 1
          : correct;
      if (!known.containsAll(selected) || selected.length > maxSelections) {
        throw const FormatException('Selected options are invalid.');
      }
      return TeacherReviewChoiceValue(selected);
    case TeacherReviewTrueFalseConfiguration():
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'value'},
      );
      return TeacherReviewTrueFalseValue(_readBool(map, 'value'));
    case TeacherReviewShortWrittenConfiguration() ||
        TeacherReviewOpenWrittenConfiguration():
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'text'},
      );
      return TeacherReviewTextValue(readTeacherNonBlankString(map, 'text'));
    case TeacherReviewFileConfiguration(:final allowedExtensions):
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'file'},
      );
      final file = readExactTeacherMap(
        map['file'],
        context: 'Answer file',
        keys: const {'id', 'original_name', 'extension', 'size_bytes'},
      );
      final name = readTeacherNonBlankString(file, 'original_name');
      final extension = readTeacherNonBlankString(file, 'extension');
      final size = readTeacherInt(file, 'size_bytes');
      if (name.runes.length > 500 ||
          !allowedExtensions.contains(extension) ||
          size < 1 ||
          size > _maxFileBytes) {
        throw const FormatException('The answer file is invalid.');
      }
      return TeacherReviewFileValue(
        TeacherReviewFile(
          id: readTeacherCanonicalUuid(file, 'id'),
          originalName: name,
          extension: extension,
          sizeBytes: size,
        ),
      );
    case TeacherReviewMatchingConfiguration(:final pairs):
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'pairs'},
      );
      final selections = _readRows(map, 'pairs', 1, null).map((row) {
        final pair = readExactTeacherMap(
          row,
          context: 'Answer matching pair',
          keys: const {'left_item_id', 'right_item_id'},
        );
        return TeacherReviewMatchingSelection(
          leftItemId: readTeacherCanonicalUuid(pair, 'left_item_id'),
          rightItemId: readTeacherCanonicalUuid(pair, 'right_item_id'),
        );
      }).toList();
      final lefts = {for (final pair in pairs) pair.leftItemId};
      final rights = {for (final pair in pairs) pair.rightItemId};
      _requireUnique(selections.map((pair) => pair.leftItemId));
      _requireUnique(selections.map((pair) => pair.rightItemId));
      if (selections.any(
        (pair) =>
            !lefts.contains(pair.leftItemId) ||
            !rights.contains(pair.rightItemId),
      )) {
        throw const FormatException('Matched items are unknown.');
      }
      return TeacherReviewMatchingValue(selections);
    case TeacherReviewOrderingConfiguration(:final items):
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'items'},
      );
      final selections = _readRows(map, 'items', 1, items.length).map((row) {
        final item = readExactTeacherMap(
          row,
          context: 'Answer ordering item',
          keys: const {'item_id', 'position'},
        );
        return TeacherReviewOrderingSelection(
          itemId: readTeacherCanonicalUuid(item, 'item_id'),
          position: readTeacherInt(item, 'position'),
        );
      }).toList();
      final known = {for (final item in items) item.id};
      _requireUnique(selections.map((item) => item.itemId));
      _requireUnique(selections.map((item) => '${item.position}'));
      if (selections.any(
        (item) =>
            !known.contains(item.itemId) ||
            item.position < 1 ||
            item.position > items.length,
      )) {
        throw const FormatException('Ordered items are invalid.');
      }
      return TeacherReviewOrderingValue(selections);
    case TeacherReviewFillInBlankConfiguration(:final blanks):
      final map = readExactTeacherMap(
        json,
        context: context,
        keys: const {'values'},
      );
      final values = _readRows(map, 'values', 1, blanks.length).map((row) {
        final value = readExactTeacherMap(
          row,
          context: 'Answer blank value',
          keys: const {'blank_id', 'text'},
        );
        return TeacherReviewBlankValue(
          blankId: readTeacherCanonicalUuid(value, 'blank_id'),
          text: readTeacherNonBlankString(value, 'text'),
        );
      }).toList();
      final known = {for (final blank in blanks) blank.id};
      _requireUnique(values.map((value) => value.blankId));
      if (values.any((value) => !known.contains(value.blankId))) {
        throw const FormatException('Answered blanks are unknown.');
      }
      return TeacherReviewFillInBlankValue(values);
  }
}

void _requireQuestionOrder(List<TeacherReviewQuestion> questions) {
  _requireUnique(questions.map((question) => question.id));
  for (var index = 1; index < questions.length; index += 1) {
    if (questions[index].position <= questions[index - 1].position) {
      throw const FormatException('Questions are not in position order.');
    }
  }
}

void _requireConsistentSubmission(
  TeacherSubmission submission,
  List<TeacherReviewQuestion> questions,
) {
  final statuses = [
    for (final question in questions)
      if (question.answer case final answer?) answer.checkingStatus,
  ];
  int count(TeacherReviewAnswerStatus status) =>
      statuses.where((candidate) => candidate == status).length;
  final waiting = count(TeacherReviewAnswerStatus.waitingForTeacherReview);
  final pending = count(TeacherReviewAnswerStatus.pending);
  final consistent =
      submission.waitingAnswers == waiting &&
      submission.reviewedAnswers ==
          count(TeacherReviewAnswerStatus.teacherChecked) &&
      switch (submission.status) {
        TeacherSubmissionStatus.checked => waiting == 0 && pending == 0,
        TeacherSubmissionStatus.waitingForTeacherReview =>
          waiting > 0 && pending == 0,
        TeacherSubmissionStatus.submitted ||
        TeacherSubmissionStatus.timedOutFinalized => pending == statuses.length,
      };
  if (!consistent) {
    throw const FormatException('Answers contradict the submission state.');
  }
}

List<Object?> _readRows(
  Map<String, Object?> map,
  String key,
  int min,
  int? max,
) {
  final value = map[key];
  if (value is! List<Object?> ||
      value.length < min ||
      (max != null && value.length > max)) {
    throw FormatException('$key has an invalid number of rows.');
  }
  return value;
}

List<String> _readStrings(
  Map<String, Object?> map,
  String key,
  int min,
  int? max,
) {
  return _readRows(map, key, min, max).map((value) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must contain non-blank strings.');
    }
    return value;
  }).toList();
}

List<String> _readIds(Map<String, Object?> map, String key) {
  final ids = _readRows(map, key, 1, null).map((value) {
    if (value is! String || !canonicalUuidPattern.hasMatch(value)) {
      throw FormatException('$key must contain canonical UUIDs.');
    }
    return value;
  }).toList();
  _requireUnique(ids);
  return ids;
}

bool _readBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a boolean.');
}

void _requireSequence(Iterable<int> positions) {
  var expected = 1;
  for (final position in positions) {
    if (position != expected) {
      throw const FormatException('Positions must run from 1 in order.');
    }
    expected += 1;
  }
}

void _requireUnique(Iterable<String> values) {
  final seen = <String>{};
  for (final value in values) {
    if (!seen.add(value.toLowerCase())) {
      throw const FormatException('Values must be unique.');
    }
  }
}

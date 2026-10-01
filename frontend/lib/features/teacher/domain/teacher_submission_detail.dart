import 'teacher_question.dart';
import 'teacher_submission.dart';

/// The checking state of one answer (`S09-DOC-001` §10.3).
enum TeacherReviewAnswerStatus {
  pending('pending'),
  autoChecked('auto_checked'),
  waitingForTeacherReview('waiting_for_teacher_review'),
  teacherChecked('teacher_checked');

  const TeacherReviewAnswerStatus(this.value);

  final String value;

  static TeacherReviewAnswerStatus? fromValue(String value) {
    for (final status in values) {
      if (status.value == value) {
        return status;
      }
    }
    return null;
  }
}

/// One submission with every Question and the Student's answers, as the
/// Teacher reviews it.
class TeacherSubmissionDetail {
  TeacherSubmissionDetail({
    required this.submission,
    required this.submittedAt,
    required List<TeacherReviewQuestion> questions,
  }) : questions = List<TeacherReviewQuestion>.unmodifiable(questions);

  final TeacherSubmission submission;

  /// Null when a timeout or a close finalized the Attempt.
  final DateTime? submittedAt;

  /// In position order.
  final List<TeacherReviewQuestion> questions;
}

class TeacherReviewQuestion {
  const TeacherReviewQuestion({
    required this.id,
    required this.type,
    required this.position,
    required this.prompt,
    required this.points,
    required this.checkingMode,
    required this.configuration,
    required this.answer,
  });

  final String id;
  final TeacherQuestionType type;
  final int position;
  final String prompt;
  final double points;
  final TeacherQuestionCheckingMode checkingMode;
  final TeacherReviewConfiguration configuration;

  /// Null when the Student did not answer.
  final TeacherReviewAnswer? answer;
}

/// The Teacher Question configuration with the ids that answers refer to.
sealed class TeacherReviewConfiguration {
  const TeacherReviewConfiguration();
}

class TeacherReviewChoiceConfiguration extends TeacherReviewConfiguration {
  TeacherReviewChoiceConfiguration(List<TeacherReviewOption> options)
    : options = List<TeacherReviewOption>.unmodifiable(options);

  /// In position order.
  final List<TeacherReviewOption> options;
}

class TeacherReviewOption {
  const TeacherReviewOption({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.position,
  });

  final String id;
  final String text;
  final bool isCorrect;
  final int position;
}

class TeacherReviewTrueFalseConfiguration extends TeacherReviewConfiguration {
  const TeacherReviewTrueFalseConfiguration(this.correctValue);

  final bool correctValue;
}

class TeacherReviewShortWrittenConfiguration
    extends TeacherReviewConfiguration {
  TeacherReviewShortWrittenConfiguration(List<String> acceptedAnswers)
    : acceptedAnswers = List<String>.unmodifiable(acceptedAnswers);

  /// Empty when the Question is checked manually.
  final List<String> acceptedAnswers;
}

class TeacherReviewOpenWrittenConfiguration extends TeacherReviewConfiguration {
  const TeacherReviewOpenWrittenConfiguration();
}

class TeacherReviewFileConfiguration extends TeacherReviewConfiguration {
  TeacherReviewFileConfiguration(List<String> allowedExtensions)
    : allowedExtensions = List<String>.unmodifiable(allowedExtensions);

  final List<String> allowedExtensions;
}

class TeacherReviewMatchingConfiguration extends TeacherReviewConfiguration {
  TeacherReviewMatchingConfiguration(List<TeacherReviewMatchingPair> pairs)
    : pairs = List<TeacherReviewMatchingPair>.unmodifiable(pairs);

  /// Each pair is a correct match.
  final List<TeacherReviewMatchingPair> pairs;
}

class TeacherReviewMatchingPair {
  const TeacherReviewMatchingPair({
    required this.left,
    required this.right,
    required this.leftItemId,
    required this.rightItemId,
  });

  final String left;
  final String right;
  final String leftItemId;
  final String rightItemId;
}

class TeacherReviewOrderingConfiguration extends TeacherReviewConfiguration {
  TeacherReviewOrderingConfiguration(List<TeacherReviewOrderingItem> items)
    : items = List<TeacherReviewOrderingItem>.unmodifiable(items);

  /// In correct order.
  final List<TeacherReviewOrderingItem> items;
}

class TeacherReviewOrderingItem {
  const TeacherReviewOrderingItem({
    required this.id,
    required this.text,
    required this.correctPosition,
  });

  final String id;
  final String text;
  final int correctPosition;
}

class TeacherReviewFillInBlankConfiguration extends TeacherReviewConfiguration {
  TeacherReviewFillInBlankConfiguration(List<TeacherReviewBlank> blanks)
    : blanks = List<TeacherReviewBlank>.unmodifiable(blanks);

  /// In position order.
  final List<TeacherReviewBlank> blanks;
}

class TeacherReviewBlank {
  TeacherReviewBlank({
    required this.id,
    required this.key,
    required this.position,
    required List<String> acceptedAnswers,
  }) : acceptedAnswers = List<String>.unmodifiable(acceptedAnswers);

  final String id;
  final String key;
  final int position;
  final List<String> acceptedAnswers;
}

class TeacherReviewAnswer {
  const TeacherReviewAnswer({
    required this.id,
    required this.value,
    required this.checkingStatus,
    required this.awardedPoints,
    required this.feedback,
    required this.checkedBy,
    required this.checkedAt,
  });

  final String id;
  final TeacherReviewAnswerValue value;
  final TeacherReviewAnswerStatus checkingStatus;

  /// Set once the answer is checked automatically or by a Teacher.
  final double? awardedPoints;
  final String? feedback;

  /// The last reviewing Teacher; null for automatic results.
  final TeacherReviewer? checkedBy;
  final DateTime? checkedAt;
}

class TeacherReviewer {
  const TeacherReviewer({required this.id, required this.fullName});

  final String id;
  final String fullName;
}

/// The Student's answer, shaped by its Question type.
sealed class TeacherReviewAnswerValue {
  const TeacherReviewAnswerValue();
}

class TeacherReviewChoiceValue extends TeacherReviewAnswerValue {
  TeacherReviewChoiceValue(List<String> selectedOptionIds)
    : selectedOptionIds = List<String>.unmodifiable(selectedOptionIds);

  final List<String> selectedOptionIds;
}

class TeacherReviewTrueFalseValue extends TeacherReviewAnswerValue {
  const TeacherReviewTrueFalseValue(this.value);

  final bool value;
}

class TeacherReviewTextValue extends TeacherReviewAnswerValue {
  const TeacherReviewTextValue(this.text);

  final String text;
}

class TeacherReviewMatchingValue extends TeacherReviewAnswerValue {
  TeacherReviewMatchingValue(List<TeacherReviewMatchingSelection> pairs)
    : pairs = List<TeacherReviewMatchingSelection>.unmodifiable(pairs);

  final List<TeacherReviewMatchingSelection> pairs;
}

class TeacherReviewMatchingSelection {
  const TeacherReviewMatchingSelection({
    required this.leftItemId,
    required this.rightItemId,
  });

  final String leftItemId;
  final String rightItemId;
}

class TeacherReviewOrderingValue extends TeacherReviewAnswerValue {
  TeacherReviewOrderingValue(List<TeacherReviewOrderingSelection> items)
    : items = List<TeacherReviewOrderingSelection>.unmodifiable(items);

  final List<TeacherReviewOrderingSelection> items;
}

class TeacherReviewOrderingSelection {
  const TeacherReviewOrderingSelection({
    required this.itemId,
    required this.position,
  });

  final String itemId;
  final int position;
}

class TeacherReviewFillInBlankValue extends TeacherReviewAnswerValue {
  TeacherReviewFillInBlankValue(List<TeacherReviewBlankValue> values)
    : values = List<TeacherReviewBlankValue>.unmodifiable(values);

  final List<TeacherReviewBlankValue> values;
}

class TeacherReviewBlankValue {
  const TeacherReviewBlankValue({required this.blankId, required this.text});

  final String blankId;
  final String text;
}

class TeacherReviewFileValue extends TeacherReviewAnswerValue {
  const TeacherReviewFileValue(this.file);

  final TeacherReviewFile file;
}

class TeacherReviewFile {
  const TeacherReviewFile({
    required this.id,
    required this.originalName,
    required this.extension,
    required this.sizeBytes,
  });

  final String id;
  final String originalName;
  final String extension;
  final int sizeBytes;
}

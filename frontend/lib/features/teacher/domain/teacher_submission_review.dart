import 'teacher_question_authoring.dart';
import 'teacher_submission_detail.dart';

/// The most feedback characters, counted as Unicode code points as the
/// server counts them.
const teacherReviewFeedbackMaxLength = 2000;

/// What the Teacher typed for one answer. A null field is untouched and shows
/// the saved value.
class TeacherAnswerReviewDraft {
  const TeacherAnswerReviewDraft({this.pointsText, this.feedbackText});

  final String? pointsText;
  final String? feedbackText;

  TeacherAnswerReviewDraft withPoints(String text) =>
      TeacherAnswerReviewDraft(pointsText: text, feedbackText: feedbackText);

  TeacherAnswerReviewDraft withFeedback(String text) =>
      TeacherAnswerReviewDraft(pointsText: pointsText, feedbackText: text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherAnswerReviewDraft &&
          other.pointsText == pointsText &&
          other.feedbackText == feedbackText;

  @override
  int get hashCode => Object.hash(pointsText, feedbackText);
}

/// Trims [text] exactly as the server's PHP `trim` does, so a saved value
/// compares equal to what was sent; an empty result is null.
String? normalizeTeacherReviewFeedback(String text) {
  bool trimmed(int unit) =>
      unit == 0x20 ||
      unit == 0x09 ||
      unit == 0x0A ||
      unit == 0x0D ||
      unit == 0x00 ||
      unit == 0x0B;
  var start = 0;
  var end = text.length;
  while (start < end && trimmed(text.codeUnitAt(start))) {
    start += 1;
  }
  while (end > start && trimmed(text.codeUnitAt(end - 1))) {
    end -= 1;
  }
  return start == end ? null : text.substring(start, end);
}

/// Whether the Teacher may review [answer]: it waits for review or was
/// already reviewed (a correction).
bool isTeacherReviewableAnswer(TeacherReviewAnswer answer) =>
    answer.checkingStatus ==
        TeacherReviewAnswerStatus.waitingForTeacherReview ||
    answer.checkingStatus == TeacherReviewAnswerStatus.teacherChecked;

/// The points field text of a saved answer: empty while it waits for review.
String teacherReviewSavedPointsText(TeacherReviewAnswer answer) =>
    answer.checkingStatus == TeacherReviewAnswerStatus.teacherChecked
    ? formatTeacherQuestionPoints(answer.awardedPoints!)
    : '';

class TeacherAnswerReviewItem {
  const TeacherAnswerReviewItem({
    required this.answerId,
    required this.awardedPoints,
    required this.feedback,
  });

  final String answerId;
  final double awardedPoints;
  final String? feedback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherAnswerReviewItem &&
          other.answerId == answerId &&
          other.awardedPoints == awardedPoints &&
          other.feedback == feedback;

  @override
  int get hashCode => Object.hash(answerId, awardedPoints, feedback);
}

/// The body of `PUT /teacher/submissions/{id}/review`. Its values are
/// absolute, so sending it again stores the same answers.
class TeacherSubmissionReviewRequest {
  TeacherSubmissionReviewRequest(List<TeacherAnswerReviewItem> items)
    : items = List.unmodifiable(items) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'Must not be empty.');
    }
    final ids = {for (final item in items) item.answerId.toLowerCase()};
    if (ids.length != items.length) {
      throw ArgumentError.value(items, 'items', 'Answer ids must be unique.');
    }
  }

  final List<TeacherAnswerReviewItem> items;

  Map<String, Object?> toJson() => {
    'answers': [
      for (final item in items)
        {
          'answer_id': item.answerId,
          'awarded_points': item.awardedPoints,
          'feedback': item.feedback,
        },
    ],
  };

  /// Whether [detail] holds every sent answer as reviewed with these values.
  bool matches(TeacherSubmissionDetail detail) {
    final answers = {
      for (final answer in detail.questions.map((q) => q.answer).nonNulls)
        answer.id.toLowerCase(): answer,
    };
    return items.every((item) {
      final answer = answers[item.answerId.toLowerCase()];
      return answer != null &&
          answer.checkingStatus == TeacherReviewAnswerStatus.teacherChecked &&
          answer.awardedPoints == item.awardedPoints &&
          answer.feedback == item.feedback;
    });
  }
}

class TeacherSubmissionReviewOutcomeUnknownException implements Exception {
  const TeacherSubmissionReviewOutcomeUnknownException();
}

enum TeacherReviewPointsError { missing, invalid }

class TeacherAnswerReviewErrors {
  const TeacherAnswerReviewErrors({
    this.points,
    this.feedbackTooLong = false,
    this.notReviewable = false,
  });

  final TeacherReviewPointsError? points;
  final bool feedbackTooLong;
  final bool notReviewable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherAnswerReviewErrors &&
          other.points == points &&
          other.feedbackTooLong == feedbackTooLong &&
          other.notReviewable == notReviewable;

  @override
  int get hashCode => Object.hash(points, feedbackTooLong, notReviewable);
}

/// The changed answers of a review: each one is either a valid item or has
/// errors.
class TeacherSubmissionReviewBuild {
  const TeacherSubmissionReviewBuild({
    required this.items,
    required this.errors,
  });

  /// In Question position order.
  final List<TeacherAnswerReviewItem> items;

  /// Keyed by answer id.
  final Map<String, TeacherAnswerReviewErrors> errors;

  int get changedCount => items.length + errors.length;
}

/// Compares [drafts] with the saved answers of [detail] and validates every
/// changed reviewable answer.
TeacherSubmissionReviewBuild buildTeacherSubmissionReview(
  TeacherSubmissionDetail detail,
  Map<String, TeacherAnswerReviewDraft> drafts,
) {
  final items = <TeacherAnswerReviewItem>[];
  final errors = <String, TeacherAnswerReviewErrors>{};
  for (final question in detail.questions) {
    final answer = question.answer;
    final draft = answer == null ? null : drafts[answer.id];
    if (answer == null || draft == null || !isTeacherReviewableAnswer(answer)) {
      continue;
    }

    final savedPoints = teacherReviewSavedPointsText(answer).trim();
    final pointsText = (draft.pointsText ?? savedPoints).trim();
    final parsed = TeacherQuestionPoints.tryParse(pointsText);
    final savedParsed = TeacherQuestionPoints.tryParse(savedPoints);
    final pointsChanged = parsed != null && savedParsed != null
        ? parsed.value != savedParsed.value
        : pointsText != savedPoints;
    final feedback = normalizeTeacherReviewFeedback(
      draft.feedbackText ?? answer.feedback ?? '',
    );
    if (!pointsChanged && feedback == answer.feedback) {
      continue;
    }

    final pointsError = pointsText.isEmpty
        ? TeacherReviewPointsError.missing
        : parsed == null || parsed.value > question.points
        ? TeacherReviewPointsError.invalid
        : null;
    final feedbackTooLong =
        feedback != null &&
        feedback.runes.length > teacherReviewFeedbackMaxLength;
    if (pointsError != null || feedbackTooLong) {
      errors[answer.id] = TeacherAnswerReviewErrors(
        points: pointsError,
        feedbackTooLong: feedbackTooLong,
      );
      continue;
    }
    items.add(
      TeacherAnswerReviewItem(
        answerId: answer.id,
        awardedPoints: parsed!.value,
        feedback: feedback,
      ),
    );
  }
  return TeacherSubmissionReviewBuild(
    items: List.unmodifiable(items),
    errors: Map.unmodifiable(errors),
  );
}

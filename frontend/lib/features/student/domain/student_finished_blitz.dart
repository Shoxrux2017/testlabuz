import 'student_blitz.dart';

enum StudentFinishedBlitzStatus {
  closed('closed'),
  archived('archived');

  const StudentFinishedBlitzStatus(this.apiValue);

  final String apiValue;

  static StudentFinishedBlitzStatus? fromValue(String value) {
    for (final status in values) {
      if (status.apiValue == value) {
        return status;
      }
    }
    return null;
  }
}

/// The Teacher's feedback on one answer of the counting Attempt.
class StudentFinishedBlitzFeedback {
  const StudentFinishedBlitzFeedback({
    required this.questionId,
    required this.position,
    required this.text,
  });

  final String questionId;
  final int position;
  final String text;
}

/// The result of the Attempt that counts: replacement Attempt 2 after an
/// approved exception, otherwise Attempt 1. Hidden results carry no score and
/// no feedback (`S09-D3`, `S09-D5`).
class StudentFinishedBlitzResult {
  StudentFinishedBlitzResult({
    required this.attemptNumber,
    required this.visible,
    required this.normalizedScore,
    required List<StudentFinishedBlitzFeedback> feedback,
  }) : feedback = List.unmodifiable(feedback);

  final int attemptNumber;
  final bool visible;
  final double? normalizedScore;

  /// In Question position order.
  final List<StudentFinishedBlitzFeedback> feedback;
}

class StudentFinishedBlitz {
  const StudentFinishedBlitz({
    required this.id,
    required this.topic,
    required this.title,
    required this.status,
    required this.closedAt,
    required this.attemptException,
    required this.result,
  });

  final String id;
  final StudentBlitzTopicSummary topic;
  final String title;
  final StudentFinishedBlitzStatus status;
  final DateTime closedAt;

  /// An approved exception invalidated Attempt 1 (`S09-D4`).
  final bool attemptException;

  /// Null when no Attempt counts.
  final StudentFinishedBlitzResult? result;
}

class StudentFinishedBlitzPage {
  StudentFinishedBlitzPage({
    required List<StudentFinishedBlitz> items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  }) : items = List.unmodifiable(items);

  final List<StudentFinishedBlitz> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;
}

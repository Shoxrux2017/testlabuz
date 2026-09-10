import 'student_homework.dart';
import 'student_topic.dart';

enum StudentHomeworkSort {
  createdAt('created_at'),
  title('title'),
  deadlineAt('deadline_at'),
  status('status');

  const StudentHomeworkSort(this.apiValue);
  final String apiValue;
}

enum StudentHomeworkSortDirection {
  asc('asc'),
  desc('desc');

  const StudentHomeworkSortDirection(this.apiValue);
  final String apiValue;
}

class StudentHomeworkListQuery {
  StudentHomeworkListQuery({
    required this.topicId,
    this.status,
    this.page = 1,
    this.perPage = 20,
    this.sort = StudentHomeworkSort.createdAt,
    this.direction = StudentHomeworkSortDirection.desc,
  }) {
    if (!isCanonicalStudentTopicId(topicId)) {
      throw ArgumentError.value(
        topicId,
        'topicId',
        'Must be a canonical UUID.',
      );
    }
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'Must be at least 1.');
    }
    if (perPage < 1 || perPage > 100) {
      throw ArgumentError.value(
        perPage,
        'perPage',
        'Must be between 1 and 100.',
      );
    }
  }

  final String topicId;
  final StudentHomeworkStatus? status;
  final int page;
  final int perPage;
  final StudentHomeworkSort sort;
  final StudentHomeworkSortDirection direction;

  Map<String, Object> toQueryParameters() => Map<String, Object>.unmodifiable({
    'topic_id': topicId,
    'page': page,
    'per_page': perPage,
    'sort': sort.apiValue,
    'direction': direction.apiValue,
    if (status case final selectedStatus?) 'status': selectedStatus.apiValue,
  });

  StudentHomeworkListQuery withStatus(StudentHomeworkStatus? value) =>
      StudentHomeworkListQuery(
        topicId: topicId,
        status: value,
        perPage: perPage,
        sort: sort,
        direction: direction,
      );

  StudentHomeworkListQuery withPage(int value) => StudentHomeworkListQuery(
    topicId: topicId,
    status: status,
    page: value,
    perPage: perPage,
    sort: sort,
    direction: direction,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentHomeworkListQuery &&
          other.topicId.toLowerCase() == topicId.toLowerCase() &&
          other.status == status &&
          other.page == page &&
          other.perPage == perPage &&
          other.sort == sort &&
          other.direction == direction;

  @override
  int get hashCode => Object.hash(
    topicId.toLowerCase(),
    status,
    page,
    perPage,
    sort,
    direction,
  );
}

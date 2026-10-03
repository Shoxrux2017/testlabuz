import 'teacher_submission.dart';

enum TeacherSubmissionCheckingFilter {
  waitingForTeacherReview('waiting_for_teacher_review'),
  automaticCheckingPending('automatic_checking_pending'),
  checked('checked');

  const TeacherSubmissionCheckingFilter(this.value);

  final String value;
}

enum TeacherSubmissionSort {
  recommended('default'),
  finalizedAt('finalized_at'),
  studentName('student_name'),
  reviewDueAt('review_due_at');

  const TeacherSubmissionSort(this.value);

  final String value;
}

enum TeacherSubmissionSortDirection {
  asc('asc'),
  desc('desc');

  const TeacherSubmissionSortDirection(this.value);

  final String value;
}

/// The review queue filters, sort and page (`S09-DOC-001` §10.2).
class TeacherSubmissionListQuery {
  const TeacherSubmissionListQuery._({
    required this.topicId,
    required this.assessmentId,
    required this.groupId,
    required this.studentId,
    required this.checkingStatus,
    required this.type,
    required this.official,
    required this.overdueOnly,
    required this.sort,
    required this.direction,
    required this.page,
    required this.perPage,
  });

  const TeacherSubmissionListQuery.initial({
    String? topicId,
    String? assessmentId,
    String? studentId,
    TeacherSubmissionCheckingFilter? checkingStatus =
        TeacherSubmissionCheckingFilter.waitingForTeacherReview,
  }) : this._(
         topicId: topicId,
         assessmentId: assessmentId,
         groupId: null,
         studentId: studentId,
         checkingStatus: checkingStatus,
         type: null,
         official: null,
         overdueOnly: false,
         sort: TeacherSubmissionSort.recommended,
         direction: TeacherSubmissionSortDirection.asc,
         page: initialPage,
         perPage: defaultPerPage,
       );

  static const initialPage = 1;
  static const defaultPerPage = 25;

  /// Fixed by a task-scoped queue; the global queue may filter by Topic.
  final String? topicId;

  /// Fixed by a task-scoped queue.
  final String? assessmentId;

  /// Row filters (`CL9-5`); a Student-scoped queue fixes [studentId].
  final String? groupId;
  final String? studentId;

  /// Null lists every terminal status.
  final TeacherSubmissionCheckingFilter? checkingStatus;
  final TeacherSubmissionTaskType? type;

  /// Null lists official and practice work.
  final bool? official;
  final bool overdueOnly;
  final TeacherSubmissionSort sort;

  /// Ignored by the server for the recommended order, so it is not sent then.
  final TeacherSubmissionSortDirection direction;
  final int page;
  final int perPage;

  Map<String, Object> toQueryParameters() {
    return Map<String, Object>.unmodifiable(<String, Object>{
      'topic_id': ?topicId,
      'assessment_id': ?assessmentId,
      'group_id': ?groupId,
      'student_id': ?studentId,
      if (checkingStatus case final status?) 'checking_status': status.value,
      if (type case final selectedType?) 'type': selectedType.value,
      if (official case final selectedOfficial?)
        'official': selectedOfficial ? 'true' : 'false',
      if (overdueOnly) 'overdue': 'true',
      'sort': sort.value,
      if (sort != TeacherSubmissionSort.recommended)
        'direction': direction.value,
      'page': page,
      'per_page': perPage,
    });
  }

  TeacherSubmissionListQuery withTopic(String? value) => _copy(topicId: value);

  TeacherSubmissionListQuery withGroup(String? value) => _copy(groupId: value);

  TeacherSubmissionListQuery withStudent(String? value) =>
      _copy(studentId: value);

  TeacherSubmissionListQuery withCheckingStatus(
    TeacherSubmissionCheckingFilter? value,
  ) => _copy(checkingStatus: value);

  TeacherSubmissionListQuery withType(TeacherSubmissionTaskType? value) =>
      _copy(type: value);

  TeacherSubmissionListQuery withOfficial(bool? value) =>
      _copy(official: value);

  TeacherSubmissionListQuery withOverdueOnly(bool value) =>
      _copy(overdueOnly: value);

  TeacherSubmissionListQuery withSort(TeacherSubmissionSort value) {
    return _copy(
      sort: value,
      direction: value == TeacherSubmissionSort.recommended
          ? TeacherSubmissionSortDirection.asc
          : direction,
    );
  }

  TeacherSubmissionListQuery withDirection(
    TeacherSubmissionSortDirection value,
  ) => _copy(direction: value);

  TeacherSubmissionListQuery withPage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'value', 'Page must be at least 1.');
    }
    return _copy(page: value);
  }

  TeacherSubmissionListQuery _copy({
    Object? topicId = _sentinel,
    Object? groupId = _sentinel,
    Object? studentId = _sentinel,
    Object? checkingStatus = _sentinel,
    Object? type = _sentinel,
    Object? official = _sentinel,
    bool? overdueOnly,
    TeacherSubmissionSort? sort,
    TeacherSubmissionSortDirection? direction,
    int? page,
  }) {
    return TeacherSubmissionListQuery._(
      topicId: identical(topicId, _sentinel)
          ? this.topicId
          : topicId as String?,
      assessmentId: assessmentId,
      groupId: identical(groupId, _sentinel)
          ? this.groupId
          : groupId as String?,
      studentId: identical(studentId, _sentinel)
          ? this.studentId
          : studentId as String?,
      checkingStatus: identical(checkingStatus, _sentinel)
          ? this.checkingStatus
          : checkingStatus as TeacherSubmissionCheckingFilter?,
      type: identical(type, _sentinel)
          ? this.type
          : type as TeacherSubmissionTaskType?,
      official: identical(official, _sentinel)
          ? this.official
          : official as bool?,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
      // Any filter or sort change starts again from the first page.
      page: page ?? initialPage,
      perPage: perPage,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherSubmissionListQuery &&
            other.topicId == topicId &&
            other.assessmentId == assessmentId &&
            other.groupId == groupId &&
            other.studentId == studentId &&
            other.checkingStatus == checkingStatus &&
            other.type == type &&
            other.official == official &&
            other.overdueOnly == overdueOnly &&
            other.sort == sort &&
            other.direction == direction &&
            other.page == page &&
            other.perPage == perPage;
  }

  @override
  int get hashCode => Object.hash(
    topicId,
    assessmentId,
    groupId,
    studentId,
    checkingStatus,
    type,
    official,
    overdueOnly,
    sort,
    direction,
    page,
    perPage,
  );
}

const _sentinel = Object();

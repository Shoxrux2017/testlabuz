import 'teacher_homework.dart';

class TeacherHomeworkListQuery {
  const TeacherHomeworkListQuery._({
    required this.search,
    required this.status,
    required this.assignmentMode,
    required this.page,
    required this.perPage,
    required this.sort,
    required this.direction,
  });

  const TeacherHomeworkListQuery.initial()
    : this._(
        search: null,
        status: null,
        assignmentMode: null,
        page: initialPage,
        perPage: defaultPerPage,
        sort: defaultSort,
        direction: defaultDirection,
      );

  static const initialPage = 1;
  static const defaultPerPage = 20;
  static const maxPerPage = 100;
  static const maxSearchLength = 160;
  static const defaultSort = 'created_at';
  static const defaultDirection = 'desc';

  final String? search;
  final TeacherHomeworkStatus? status;
  final TeacherHomeworkAssignmentMode? assignmentMode;
  final int page;
  final int perPage;
  final String sort;
  final String direction;

  bool get hasFilters =>
      search != null || status != null || assignmentMode != null;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{
      'page': page,
      'per_page': perPage,
      'sort': sort,
      'direction': direction,
    };
    if (search case final committedSearch?) {
      parameters['search'] = committedSearch;
    }
    if (status case final selectedStatus?) {
      parameters['status'] = selectedStatus.value;
    }
    if (assignmentMode case final selectedAssignmentMode?) {
      parameters['assignment_mode'] = selectedAssignmentMode.value;
    }
    return Map<String, Object>.unmodifiable(parameters);
  }

  TeacherHomeworkListQuery withSearch(String? value) {
    final normalized = normalizeSearch(value ?? '');
    if (normalized != null && normalized.runes.length > maxSearchLength) {
      throw ArgumentError.value(value, 'value', 'Search is too long.');
    }
    return _copy(search: normalized, page: initialPage);
  }

  TeacherHomeworkListQuery withStatus(TeacherHomeworkStatus? value) {
    return _copy(status: value, page: initialPage);
  }

  TeacherHomeworkListQuery withAssignmentMode(
    TeacherHomeworkAssignmentMode? value,
  ) {
    return _copy(assignmentMode: value, page: initialPage);
  }

  TeacherHomeworkListQuery withPage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'value', 'Page must be at least 1.');
    }
    return _copy(page: value);
  }

  TeacherHomeworkListQuery withPerPage(int value) {
    if (value < 1 || value > maxPerPage) {
      throw ArgumentError.value(value, 'value', 'Per-page must be 1 to 100.');
    }
    return _copy(perPage: value, page: initialPage);
  }

  TeacherHomeworkListQuery _copy({
    Object? search = _sentinel,
    Object? status = _sentinel,
    Object? assignmentMode = _sentinel,
    int? page,
    int? perPage,
  }) {
    return TeacherHomeworkListQuery._(
      search: identical(search, _sentinel) ? this.search : search as String?,
      status: identical(status, _sentinel)
          ? this.status
          : status as TeacherHomeworkStatus?,
      assignmentMode: identical(assignmentMode, _sentinel)
          ? this.assignmentMode
          : assignmentMode as TeacherHomeworkAssignmentMode?,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      sort: defaultSort,
      direction: defaultDirection,
    );
  }

  static String? normalizeSearch(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static bool isSearchInputValid(String value) {
    return (normalizeSearch(value)?.runes.length ?? 0) <= maxSearchLength;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherHomeworkListQuery &&
            other.search == search &&
            other.status == status &&
            other.assignmentMode == assignmentMode &&
            other.page == page &&
            other.perPage == perPage &&
            other.sort == sort &&
            other.direction == direction;
  }

  @override
  int get hashCode {
    return Object.hash(
      search,
      status,
      assignmentMode,
      page,
      perPage,
      sort,
      direction,
    );
  }
}

const _sentinel = Object();

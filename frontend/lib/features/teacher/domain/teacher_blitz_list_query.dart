import 'teacher_blitz.dart';

/// UI-owned Blitz list filters; the Topic scope is supplied separately.
class TeacherBlitzListQuery {
  const TeacherBlitzListQuery._({
    required this.status,
    required this.page,
    required this.perPage,
  });

  const TeacherBlitzListQuery.initial()
    : this._(status: null, page: initialPage, perPage: defaultPerPage);

  static const initialPage = 1;
  static const defaultPerPage = 20;
  static const maxPerPage = 100;

  final TeacherBlitzStatus? status;
  final int page;
  final int perPage;

  bool get hasStatusFilter => status != null;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{'page': page, 'per_page': perPage};
    if (status case final selectedStatus?) {
      parameters['status'] = selectedStatus.value;
    }
    return Map<String, Object>.unmodifiable(parameters);
  }

  TeacherBlitzListQuery withStatus(TeacherBlitzStatus? value) {
    return TeacherBlitzListQuery._(
      status: value,
      page: initialPage,
      perPage: perPage,
    );
  }

  TeacherBlitzListQuery withPage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'value', 'Page must be at least 1.');
    }
    return TeacherBlitzListQuery._(
      status: status,
      page: value,
      perPage: perPage,
    );
  }

  TeacherBlitzListQuery withPerPage(int value) {
    if (value < 1 || value > maxPerPage) {
      throw ArgumentError.value(value, 'value', 'Per-page must be 1 to 100.');
    }
    return TeacherBlitzListQuery._(
      status: status,
      page: initialPage,
      perPage: value,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherBlitzListQuery &&
            other.status == status &&
            other.page == page &&
            other.perPage == perPage;
  }

  @override
  int get hashCode => Object.hash(status, page, perPage);
}

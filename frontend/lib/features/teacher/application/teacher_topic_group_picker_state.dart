import '../../../core/network/api_failure.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_group_list.dart';
import '../domain/teacher_group_list_query.dart';

enum TeacherTopicGroupPickerStatus { initial, loading, data, empty, error }

class TeacherTopicGroupPickerState {
  const TeacherTopicGroupPickerState({
    this.status = TeacherTopicGroupPickerStatus.initial,
    this.query = const TeacherGroupListQuery.initial(),
    this.searchDraft = '',
    this.result,
    this.selectedGroup,
    this.failure,
    this.searchErrorText,
  });

  final TeacherTopicGroupPickerStatus status;
  final TeacherGroupListQuery query;
  final String searchDraft;
  final TeacherGroupListPage? result;
  final TeacherGroupSummary? selectedGroup;
  final ApiFailure? failure;
  final String? searchErrorText;

  bool get isLoading => status == TeacherTopicGroupPickerStatus.loading;
  bool get canPrevious =>
      !isLoading && searchErrorText == null && query.page > 1;
  bool get canNext =>
      !isLoading &&
      searchErrorText == null &&
      result != null &&
      result!.groups.isNotEmpty &&
      result!.pagination.page < result!.pagination.lastPage;

  TeacherTopicGroupPickerState copyWith({
    TeacherTopicGroupPickerStatus? status,
    TeacherGroupListQuery? query,
    String? searchDraft,
    Object? result = _unchanged,
    Object? selectedGroup = _unchanged,
    Object? failure = _unchanged,
    Object? searchErrorText = _unchanged,
  }) {
    return TeacherTopicGroupPickerState(
      status: status ?? this.status,
      query: query ?? this.query,
      searchDraft: searchDraft ?? this.searchDraft,
      result: identical(result, _unchanged)
          ? this.result
          : result as TeacherGroupListPage?,
      selectedGroup: identical(selectedGroup, _unchanged)
          ? this.selectedGroup
          : selectedGroup as TeacherGroupSummary?,
      failure: identical(failure, _unchanged)
          ? this.failure
          : failure as ApiFailure?,
      searchErrorText: identical(searchErrorText, _unchanged)
          ? this.searchErrorText
          : searchErrorText as String?,
    );
  }
}

const _unchanged = Object();

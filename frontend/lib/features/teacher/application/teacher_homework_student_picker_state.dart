import '../../../core/network/api_failure.dart';
import '../domain/teacher_group_student.dart';
import '../domain/teacher_group_student_list.dart';
import '../domain/teacher_group_student_list_query.dart';

enum TeacherHomeworkStudentPickerStatus { initial, loading, data, empty, error }

class TeacherHomeworkStudentPickerState {
  TeacherHomeworkStudentPickerState({
    this.status = TeacherHomeworkStudentPickerStatus.initial,
    this.query = const TeacherGroupStudentListQuery.initial(),
    this.searchDraft = '',
    this.result,
    this.failure,
    Set<String> selectedIds = const {},
    Map<String, TeacherGroupStudent> resolvedStudentsById = const {},
    this.searchErrorText,
  }) : selectedIds = Set<String>.unmodifiable(selectedIds),
       resolvedStudentsById = Map<String, TeacherGroupStudent>.unmodifiable(
         resolvedStudentsById,
       );

  final TeacherHomeworkStudentPickerStatus status;
  final TeacherGroupStudentListQuery query;
  final String searchDraft;
  final TeacherGroupStudentList? result;
  final ApiFailure? failure;
  final Set<String> selectedIds;
  final Map<String, TeacherGroupStudent> resolvedStudentsById;
  final String? searchErrorText;

  bool get isLoading => status == TeacherHomeworkStudentPickerStatus.loading;
  bool get canPrevious =>
      !isLoading && searchErrorText == null && query.page > 1;
  bool get canNext =>
      !isLoading &&
      searchErrorText == null &&
      result != null &&
      result!.pagination.page < result!.pagination.lastPage;

  TeacherGroupStudent? resolvedStudent(String studentId) {
    for (final entry in resolvedStudentsById.entries) {
      if (entry.key.toLowerCase() == studentId.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  TeacherHomeworkStudentPickerState copyWith({
    TeacherHomeworkStudentPickerStatus? status,
    TeacherGroupStudentListQuery? query,
    String? searchDraft,
    Object? result = _unchanged,
    Object? failure = _unchanged,
    Set<String>? selectedIds,
    Map<String, TeacherGroupStudent>? resolvedStudentsById,
    Object? searchErrorText = _unchanged,
  }) {
    return TeacherHomeworkStudentPickerState(
      status: status ?? this.status,
      query: query ?? this.query,
      searchDraft: searchDraft ?? this.searchDraft,
      result: identical(result, _unchanged)
          ? this.result
          : result as TeacherGroupStudentList?,
      failure: identical(failure, _unchanged)
          ? this.failure
          : failure as ApiFailure?,
      selectedIds: selectedIds ?? this.selectedIds,
      resolvedStudentsById: resolvedStudentsById ?? this.resolvedStudentsById,
      searchErrorText: identical(searchErrorText, _unchanged)
          ? this.searchErrorText
          : searchErrorText as String?,
    );
  }
}

const _unchanged = Object();

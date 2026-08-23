enum TeacherMaterialMutationOperation { upload, replace, updateTitle, remove }

enum TeacherMaterialMutationStatus {
  idle,
  submitting,
  reconciling,
  confirmedSuccess,
  definiteFailure,
  notEditable,
  unconfirmedCurrentState,
  outcomeUnknown,
  noChanges,
}

class TeacherMaterialMutationState {
  TeacherMaterialMutationState({
    this.status = TeacherMaterialMutationStatus.idle,
    this.operation,
    this.materialId,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.feedback,
    Map<String, String> fieldErrors = const {},
  }) : fieldErrors = Map<String, String>.unmodifiable(fieldErrors);

  final TeacherMaterialMutationStatus status;
  final TeacherMaterialMutationOperation? operation;
  final String? materialId;
  final int sentBytes;
  final int totalBytes;
  final String? feedback;
  final Map<String, String> fieldErrors;

  bool get isBusy =>
      status == TeacherMaterialMutationStatus.submitting ||
      status == TeacherMaterialMutationStatus.reconciling;
  bool get canCheckCurrent =>
      status == TeacherMaterialMutationStatus.outcomeUnknown &&
      operation != null;
  double? get progress {
    if (totalBytes <= 0) {
      return null;
    }
    return (sentBytes / totalBytes).clamp(0, 1);
  }

  TeacherMaterialMutationState copyWith({
    TeacherMaterialMutationStatus? status,
    Object? operation = _unchanged,
    Object? materialId = _unchanged,
    int? sentBytes,
    int? totalBytes,
    Object? feedback = _unchanged,
    Map<String, String>? fieldErrors,
  }) {
    return TeacherMaterialMutationState(
      status: status ?? this.status,
      operation: identical(operation, _unchanged)
          ? this.operation
          : operation as TeacherMaterialMutationOperation?,
      materialId: identical(materialId, _unchanged)
          ? this.materialId
          : materialId as String?,
      sentBytes: sentBytes ?? this.sentBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      feedback: identical(feedback, _unchanged)
          ? this.feedback
          : feedback as String?,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}

const _unchanged = Object();

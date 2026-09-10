enum StudentSubmissionTransferAction { open, saveAs }

enum StudentSubmissionTransferStatus {
  idle,
  downloading,
  opening,
  saving,
  failure,
}

class StudentSubmissionTransferState {
  const StudentSubmissionTransferState({
    this.status = StudentSubmissionTransferStatus.idle,
    this.action,
    this.questionId,
    this.fileId,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.feedback,
  });

  final StudentSubmissionTransferStatus status;
  final StudentSubmissionTransferAction? action;
  final String? questionId;
  final String? fileId;
  final int receivedBytes;
  final int totalBytes;
  final String? feedback;

  bool get isBusy =>
      status == StudentSubmissionTransferStatus.downloading ||
      status == StudentSubmissionTransferStatus.opening ||
      status == StudentSubmissionTransferStatus.saving;

  bool isBusyForQuestion(String id) =>
      isBusy && questionId?.toLowerCase() == id.toLowerCase();

  double? get progress =>
      status == StudentSubmissionTransferStatus.downloading && totalBytes > 0
      ? (receivedBytes / totalBytes).clamp(0, 1)
      : null;

  StudentSubmissionTransferState copyWith({
    StudentSubmissionTransferStatus? status,
    int? receivedBytes,
    int? totalBytes,
    Object? feedback = _unchanged,
  }) => StudentSubmissionTransferState(
    status: status ?? this.status,
    action: action,
    questionId: questionId,
    fileId: fileId,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    feedback: identical(feedback, _unchanged)
        ? this.feedback
        : feedback as String?,
  );
}

const _unchanged = Object();

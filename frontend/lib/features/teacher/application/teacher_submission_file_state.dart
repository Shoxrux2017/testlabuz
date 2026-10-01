enum TeacherSubmissionFileStatus { idle, downloading, saving, failure }

class TeacherSubmissionFileState {
  const TeacherSubmissionFileState({
    this.status = TeacherSubmissionFileStatus.idle,
    this.fileId,
    this.feedback,
  });

  final TeacherSubmissionFileStatus status;

  /// The file being transferred, or the one that failed.
  final String? fileId;

  /// `File saved.` after a save, or the failure message.
  final String? feedback;

  bool get isBusy =>
      status == TeacherSubmissionFileStatus.downloading ||
      status == TeacherSubmissionFileStatus.saving;
}

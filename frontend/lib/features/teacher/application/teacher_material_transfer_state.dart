enum TeacherMaterialTransferAction { saveAs, open }

enum TeacherMaterialTransferStatus {
  idle,
  downloading,
  saving,
  opening,
  failure,
}

class TeacherMaterialTransferState {
  const TeacherMaterialTransferState({
    this.status = TeacherMaterialTransferStatus.idle,
    this.action,
    this.materialId,
    this.fileId,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.feedback,
  });

  final TeacherMaterialTransferStatus status;
  final TeacherMaterialTransferAction? action;
  final String? materialId;
  final String? fileId;
  final int receivedBytes;
  final int totalBytes;
  final String? feedback;

  bool get isBusy =>
      status == TeacherMaterialTransferStatus.downloading ||
      status == TeacherMaterialTransferStatus.saving ||
      status == TeacherMaterialTransferStatus.opening;
  bool isBusyForMaterial(String targetMaterialId) {
    return isBusy &&
        materialId?.toLowerCase() == targetMaterialId.toLowerCase();
  }

  double? get progress {
    if (status != TeacherMaterialTransferStatus.downloading ||
        totalBytes <= 0) {
      return null;
    }
    return (receivedBytes / totalBytes).clamp(0, 1);
  }

  TeacherMaterialTransferState copyWith({
    TeacherMaterialTransferStatus? status,
    int? receivedBytes,
    int? totalBytes,
    Object? feedback = _unchanged,
  }) {
    return TeacherMaterialTransferState(
      status: status ?? this.status,
      action: action,
      materialId: materialId,
      fileId: fileId,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      feedback: identical(feedback, _unchanged)
          ? this.feedback
          : feedback as String?,
    );
  }
}

const _unchanged = Object();

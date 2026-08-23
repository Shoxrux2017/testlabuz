enum StudentMaterialTransferAction { saveAs, open }

enum StudentMaterialTransferStatus {
  idle,
  downloading,
  saving,
  opening,
  failure,
}

class StudentMaterialTransferState {
  const StudentMaterialTransferState({
    this.status = StudentMaterialTransferStatus.idle,
    this.action,
    this.materialId,
    this.fileId,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.feedback,
  });

  final StudentMaterialTransferStatus status;
  final StudentMaterialTransferAction? action;
  final String? materialId;
  final String? fileId;
  final int receivedBytes;
  final int totalBytes;
  final String? feedback;

  bool get isBusy =>
      status == StudentMaterialTransferStatus.downloading ||
      status == StudentMaterialTransferStatus.saving ||
      status == StudentMaterialTransferStatus.opening;

  bool isBusyForMaterial(String targetMaterialId) {
    return isBusy &&
        materialId?.toLowerCase() == targetMaterialId.toLowerCase();
  }

  double? get progress {
    if (status != StudentMaterialTransferStatus.downloading ||
        totalBytes <= 0) {
      return null;
    }
    return (receivedBytes / totalBytes).clamp(0, 1);
  }

  StudentMaterialTransferState copyWith({
    StudentMaterialTransferStatus? status,
    int? receivedBytes,
    int? totalBytes,
    Object? feedback = _unchanged,
  }) {
    return StudentMaterialTransferState(
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

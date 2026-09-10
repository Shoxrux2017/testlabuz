import 'student_question.dart';

typedef StudentSubmissionUploadProgress = void Function(int sent, int total);

class StudentSubmissionUploadFile {
  const StudentSubmissionUploadFile({
    required this.name,
    required this.length,
    required this.openRead,
  });

  final String name;
  final int length;
  final Stream<List<int>> Function() openRead;

  String? get extension {
    final suffix = name.lastIndexOf('.');
    if (suffix < 0 || suffix == name.length - 1) {
      return null;
    }
    return name.substring(suffix + 1).toLowerCase();
  }
}

enum StudentSubmissionSelectionError {
  emptyFile,
  unsupportedExtension,
  tooLarge,
  filenameTooLong,
  invalidFilename,
}

StudentSubmissionSelectionError? validateStudentSubmissionSelection(
  StudentSubmissionUploadFile file,
  StudentFileAnswerUi answerUi,
) {
  if (file.name.isEmpty || file.name == '.' || file.name == '..') {
    return StudentSubmissionSelectionError.invalidFilename;
  }
  if (file.name.runes.length > 500) {
    return StudentSubmissionSelectionError.filenameTooLong;
  }
  final extension = file.extension;
  if (extension == null || !answerUi.allowedExtensions.contains(extension)) {
    return StudentSubmissionSelectionError.unsupportedExtension;
  }
  if (file.length <= 0) {
    return StudentSubmissionSelectionError.emptyFile;
  }
  if (file.length > answerUi.maxSizeBytes) {
    return StudentSubmissionSelectionError.tooLarge;
  }
  return null;
}

/// A local source read failed; this does not describe a server commit outcome.
class StudentSubmissionSourceUnavailable implements Exception {
  const StudentSubmissionSourceUnavailable();
}

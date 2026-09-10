import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/student_submission_upload.dart';

final studentSubmissionFilePickerProvider =
    Provider<StudentSubmissionFilePicker>(
      (ref) => const NativeStudentSubmissionFilePicker(),
    );

abstract interface class StudentSubmissionFilePicker {
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  });
}

class NativeStudentSubmissionFilePicker implements StudentSubmissionFilePicker {
  const NativeStudentSubmissionFilePicker();

  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) async {
    final platformFile = await FilePicker.pickFile(
      dialogTitle: 'Choose an answer file',
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (platformFile == null) {
      return null;
    }
    return StudentSubmissionUploadFile(
      name: platformFile.name,
      length: await platformFile.length(),
      openRead: platformFile.readAsByteStream,
    );
  }
}

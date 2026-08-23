import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/teacher_learning_material_mutation.dart';

final teacherMaterialFilePickerProvider = Provider<TeacherMaterialFilePicker>((
  ref,
) {
  return const NativeTeacherMaterialFilePicker();
});

abstract interface class TeacherMaterialFilePicker {
  Future<TeacherMaterialUploadFile?> pickFile();
}

class NativeTeacherMaterialFilePicker implements TeacherMaterialFilePicker {
  const NativeTeacherMaterialFilePicker();

  @override
  Future<TeacherMaterialUploadFile?> pickFile() async {
    final platformFile = await FilePicker.pickFile(
      dialogTitle: 'Choose a learning material',
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'ppt', 'pptx'],
    );
    if (platformFile == null) {
      return null;
    }
    final length = await platformFile.length();
    return TeacherMaterialUploadFile(
      name: platformFile.name,
      length: length,
      openRead: platformFile.readAsByteStream,
    );
  }
}

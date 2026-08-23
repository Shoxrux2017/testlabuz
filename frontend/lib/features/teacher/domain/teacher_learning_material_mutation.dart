typedef TeacherMaterialUploadProgress = void Function(int sent, int total);

class TeacherMaterialUploadFile {
  const TeacherMaterialUploadFile({
    required this.name,
    required this.length,
    required this.openRead,
  });

  final String name;
  final int length;
  final Stream<List<int>> Function() openRead;

  String? get extension {
    final index = name.lastIndexOf('.');
    if (index < 1 || index == name.length - 1) {
      return null;
    }
    return name.substring(index + 1).toLowerCase();
  }
}

class TeacherMaterialMutationOutcomeUnknownException implements Exception {
  const TeacherMaterialMutationOutcomeUnknownException();
}

import '../../../core/files/protected_download_metadata.dart';

final canonicalTeacherMaterialIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isCanonicalTeacherMaterialId(String value) {
  return canonicalTeacherMaterialIdPattern.hasMatch(value);
}

class TeacherLearningMaterialFile {
  const TeacherLearningMaterialFile({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.extension,
    required this.sizeBytes,
  });

  final String id;
  final String originalName;
  final String mimeType;
  final String extension;
  final int sizeBytes;
}

class TeacherLearningMaterial {
  const TeacherLearningMaterial({
    required this.id,
    required this.topicId,
    required this.title,
    required this.file,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String topicId;
  final String? title;
  final TeacherLearningMaterialFile file;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => title ?? file.originalName;
}

class TeacherMaterialUploadCapability {
  TeacherMaterialUploadCapability({
    required this.maxSizeBytes,
    required this.platformMaxSizeBytes,
    required List<String> allowedExtensions,
  }) : allowedExtensions = List<String>.unmodifiable(allowedExtensions);

  final int maxSizeBytes;
  final int platformMaxSizeBytes;
  final List<String> allowedExtensions;
}

class TeacherLearningMaterialCollection {
  TeacherLearningMaterialCollection({
    required List<TeacherLearningMaterial> materials,
    required this.uploadCapability,
  }) : materials = List<TeacherLearningMaterial>.unmodifiable(materials);

  final List<TeacherLearningMaterial> materials;
  final TeacherMaterialUploadCapability uploadCapability;

  TeacherLearningMaterial? materialById(String materialId) {
    for (final material in materials) {
      if (material.id.toLowerCase() == materialId.toLowerCase()) {
        return material;
      }
    }
    return null;
  }
}

bool teacherMaterialFileMetadataIsCanonical(String extension, String mimeType) {
  return protectedMaterialFileTypeForExtension(extension)?.mimeType == mimeType;
}

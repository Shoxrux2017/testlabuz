import '../../../../core/files/protected_download_metadata.dart';
import '../../domain/teacher_learning_material.dart';
import 'teacher_dto_parse.dart';

class TeacherLearningMaterialFileDto {
  const TeacherLearningMaterialFileDto({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.extension,
    required this.sizeBytes,
  });

  factory TeacherLearningMaterialFileDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Learning Material File resource',
      keys: _fileKeys,
    );
    final originalName = readTeacherNonBlankString(map, 'original_name');
    final mimeType = readTeacherNonBlankString(map, 'mime_type');
    final extension = readTeacherNonBlankString(map, 'extension');
    final canonical = protectedMaterialFileTypeForExtension(extension);
    final sizeBytes = readTeacherInt(map, 'size_bytes');
    if (canonical == null ||
        extension != canonical.extension ||
        mimeType != canonical.mimeType ||
        sizeBytes < 1) {
      throw const FormatException(
        'Teacher Learning Material File metadata is invalid.',
      );
    }

    return TeacherLearningMaterialFileDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      originalName: originalName,
      mimeType: mimeType,
      extension: extension,
      sizeBytes: sizeBytes,
    );
  }

  final String id;
  final String originalName;
  final String mimeType;
  final String extension;
  final int sizeBytes;

  TeacherLearningMaterialFile toDomain() {
    return TeacherLearningMaterialFile(
      id: id,
      originalName: originalName,
      mimeType: mimeType,
      extension: extension,
      sizeBytes: sizeBytes,
    );
  }
}

class TeacherLearningMaterialDto {
  const TeacherLearningMaterialDto({
    required this.id,
    required this.topicId,
    required this.title,
    required this.file,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherLearningMaterialDto.fromJson(
    Object? json, {
    required String expectedTopicId,
  }) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Learning Material resource',
      keys: _materialKeys,
    );
    final topicId = readTeacherCanonicalUuid(map, 'topic_id');
    if (topicId.toLowerCase() != expectedTopicId.toLowerCase()) {
      throw const FormatException(
        'Teacher Learning Material Topic does not match the request.',
      );
    }
    final title = readTeacherNullableString(map, 'title');
    if (title != null && title.trim().isEmpty) {
      throw const FormatException(
        'Teacher Learning Material title must be non-empty when present.',
      );
    }

    return TeacherLearningMaterialDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      topicId: topicId,
      title: title,
      file: TeacherLearningMaterialFileDto.fromJson(map['file']),
      createdAt: readTeacherRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: readTeacherRequiredUtcTimestamp(map, 'updated_at'),
    );
  }

  final String id;
  final String topicId;
  final String? title;
  final TeacherLearningMaterialFileDto file;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeacherLearningMaterial toDomain() {
    return TeacherLearningMaterial(
      id: id,
      topicId: topicId,
      title: title,
      file: file.toDomain(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class TeacherLearningMaterialListDto {
  TeacherLearningMaterialListDto({
    required List<TeacherLearningMaterialDto> materials,
    required this.uploadCapability,
  }) : materials = List<TeacherLearningMaterialDto>.unmodifiable(materials);

  factory TeacherLearningMaterialListDto.fromJson(
    Object? json, {
    required String expectedTopicId,
  }) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Learning Material list envelope',
      keys: const {'data', 'meta'},
    );
    final rawMaterials = envelope['data'];
    if (rawMaterials is! List) {
      throw const FormatException(
        'Teacher Learning Material list data must be an array.',
      );
    }
    final materials = rawMaterials
        .map(
          (item) => TeacherLearningMaterialDto.fromJson(
            item,
            expectedTopicId: expectedTopicId,
          ),
        )
        .toList(growable: false);
    if (materials.map((item) => item.id.toLowerCase()).toSet().length !=
            materials.length ||
        materials.map((item) => item.file.id.toLowerCase()).toSet().length !=
            materials.length) {
      throw const FormatException(
        'Teacher Learning Material list contains duplicate identities.',
      );
    }
    final meta = readExactTeacherMap(
      envelope['meta'],
      context: 'Teacher Learning Material list meta',
      keys: const {'upload'},
    );

    return TeacherLearningMaterialListDto(
      materials: materials,
      uploadCapability: TeacherMaterialUploadCapabilityDto.fromJson(
        meta['upload'],
      ),
    );
  }

  final List<TeacherLearningMaterialDto> materials;
  final TeacherMaterialUploadCapabilityDto uploadCapability;

  TeacherLearningMaterialCollection toDomain() {
    return TeacherLearningMaterialCollection(
      materials: materials.map((item) => item.toDomain()).toList(),
      uploadCapability: uploadCapability.toDomain(),
    );
  }
}

class TeacherMaterialUploadCapabilityDto {
  TeacherMaterialUploadCapabilityDto({
    required this.maxSizeBytes,
    required this.platformMaxSizeBytes,
    required List<String> allowedExtensions,
  }) : allowedExtensions = List<String>.unmodifiable(allowedExtensions);

  factory TeacherMaterialUploadCapabilityDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Material upload capability',
      keys: const {
        'max_size_bytes',
        'platform_max_size_bytes',
        'allowed_extensions',
      },
    );
    final maxSizeBytes = readTeacherInt(map, 'max_size_bytes');
    final platformMaxSizeBytes = readTeacherInt(map, 'platform_max_size_bytes');
    final rawExtensions = map['allowed_extensions'];
    if (rawExtensions is! List ||
        rawExtensions.any((item) => item is! String)) {
      throw const FormatException(
        'Teacher Material allowed extensions are invalid.',
      );
    }
    final allowedExtensions = rawExtensions.cast<String>();
    const expected = {'pdf', 'docx', 'ppt', 'pptx'};
    if (maxSizeBytes < 1 ||
        platformMaxSizeBytes != maximumProtectedMaterialBytes ||
        maxSizeBytes > platformMaxSizeBytes ||
        allowedExtensions.length != expected.length ||
        allowedExtensions.toSet().length != allowedExtensions.length ||
        allowedExtensions.toSet().difference(expected).isNotEmpty) {
      throw const FormatException(
        'Teacher Material upload capability is invalid.',
      );
    }

    return TeacherMaterialUploadCapabilityDto(
      maxSizeBytes: maxSizeBytes,
      platformMaxSizeBytes: platformMaxSizeBytes,
      allowedExtensions: allowedExtensions,
    );
  }

  final int maxSizeBytes;
  final int platformMaxSizeBytes;
  final List<String> allowedExtensions;

  TeacherMaterialUploadCapability toDomain() {
    return TeacherMaterialUploadCapability(
      maxSizeBytes: maxSizeBytes,
      platformMaxSizeBytes: platformMaxSizeBytes,
      allowedExtensions: allowedExtensions,
    );
  }
}

class TeacherLearningMaterialMutationDto {
  const TeacherLearningMaterialMutationDto({required this.material});

  factory TeacherLearningMaterialMutationDto.fromJson(
    Object? json, {
    required String expectedTopicId,
    String? expectedMessage,
  }) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Learning Material mutation envelope',
      keys: expectedMessage == null
          ? const {'data'}
          : const {'data', 'message'},
    );
    if (expectedMessage != null && envelope['message'] != expectedMessage) {
      throw const FormatException(
        'Teacher Learning Material mutation message is invalid.',
      );
    }
    return TeacherLearningMaterialMutationDto(
      material: TeacherLearningMaterialDto.fromJson(
        envelope['data'],
        expectedTopicId: expectedTopicId,
      ),
    );
  }

  final TeacherLearningMaterialDto material;
}

const _materialKeys = <String>{
  'id',
  'topic_id',
  'title',
  'file',
  'created_at',
  'updated_at',
};

const _fileKeys = <String>{
  'id',
  'original_name',
  'mime_type',
  'extension',
  'size_bytes',
};

import '../../domain/student_topic.dart';
import '../../domain/student_topic_list.dart';
import '../../domain/student_topic_list_query.dart';
import 'student_dto_parse.dart';

class StudentGroupDto {
  const StudentGroupDto({
    required this.id,
    required this.name,
    required this.level,
    required this.subjectDirection,
    required this.status,
  });

  factory StudentGroupDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Group resource',
      keys: _groupKeys,
    );

    return StudentGroupDto(
      id: readStudentCanonicalUuid(map, 'id'),
      name: readStudentNonBlankString(map, 'name'),
      level: readStudentNullableString(map, 'level'),
      subjectDirection: readStudentNullableString(map, 'subject_direction'),
      status: StudentGroupStatus.parse(
        readStudentNonBlankString(map, 'status'),
      ),
    );
  }

  final String id;
  final String name;
  final String? level;
  final String? subjectDirection;
  final StudentGroupStatus status;

  StudentGroupSummary toDomain() {
    return StudentGroupSummary(
      id: id,
      name: name,
      level: level,
      subjectDirection: subjectDirection,
      status: status,
    );
  }
}

class StudentTopicSummaryDto {
  const StudentTopicSummaryDto({
    required this.id,
    required this.group,
    required this.title,
    required this.subject,
    required this.lessonAt,
    required this.status,
  });

  factory StudentTopicSummaryDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Topic summary',
      keys: _summaryKeys,
    );

    return StudentTopicSummaryDto(
      id: readStudentCanonicalUuid(map, 'id'),
      group: StudentGroupDto.fromJson(map['group']),
      title: readStudentNonBlankString(map, 'title'),
      subject: readStudentNonBlankString(map, 'subject'),
      lessonAt: readStudentNullableUtcTimestamp(map, 'lesson_at'),
      status: StudentTopicStatus.parse(
        readStudentNonBlankString(map, 'status'),
      ),
    );
  }

  final String id;
  final StudentGroupDto group;
  final String title;
  final String subject;
  final DateTime? lessonAt;
  final StudentTopicStatus status;

  StudentTopicSummary toDomain() {
    return StudentTopicSummary(
      id: id,
      group: group.toDomain(),
      title: title,
      subject: subject,
      lessonAt: lessonAt,
      status: status,
    );
  }
}

class StudentLearningMaterialDto {
  const StudentLearningMaterialDto({
    required this.id,
    required this.title,
    required this.file,
  });

  factory StudentLearningMaterialDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Learning Material resource',
      keys: _materialKeys,
    );
    final title = readStudentNullableString(map, 'title');
    if (title != null && title.trim().isEmpty) {
      throw const FormatException(
        'Student Learning Material title cannot be blank.',
      );
    }

    return StudentLearningMaterialDto(
      id: readStudentCanonicalUuid(map, 'id'),
      title: title,
      file: StudentLearningMaterialFileDto.fromJson(map['file']),
    );
  }

  final String id;
  final String? title;
  final StudentLearningMaterialFileDto file;

  StudentLearningMaterial toDomain() {
    return StudentLearningMaterial(id: id, title: title, file: file.toDomain());
  }
}

class StudentLearningMaterialFileDto {
  const StudentLearningMaterialFileDto({
    required this.id,
    required this.originalName,
    required this.extension,
    required this.sizeBytes,
  });

  factory StudentLearningMaterialFileDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Learning Material File resource',
      keys: _fileKeys,
    );
    final extension = readStudentNonBlankString(map, 'extension');
    if (!_allowedExtensions.contains(extension)) {
      throw const FormatException(
        'Student Learning Material File extension is unsupported.',
      );
    }
    final sizeBytes = readStudentInt(map, 'size_bytes');
    if (sizeBytes < 1) {
      throw const FormatException(
        'Student Learning Material File size must be positive.',
      );
    }

    return StudentLearningMaterialFileDto(
      id: readStudentCanonicalUuid(map, 'id'),
      originalName: readStudentNonBlankString(map, 'original_name'),
      extension: extension,
      sizeBytes: sizeBytes,
    );
  }

  final String id;
  final String originalName;
  final String extension;
  final int sizeBytes;

  StudentLearningMaterialFile toDomain() {
    return StudentLearningMaterialFile(
      id: id,
      originalName: originalName,
      extension: extension,
      sizeBytes: sizeBytes,
    );
  }
}

class StudentTopicDetailDto {
  StudentTopicDetailDto({
    required this.id,
    required this.group,
    required this.title,
    required this.description,
    required this.subject,
    required this.studentInstructions,
    required this.lessonAt,
    required this.status,
    required List<StudentLearningMaterialDto> materials,
  }) : materials = List<StudentLearningMaterialDto>.unmodifiable(materials);

  factory StudentTopicDetailDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Topic detail',
      keys: _detailKeys,
    );
    final rawMaterials = map['materials'];
    if (rawMaterials is! List) {
      throw const FormatException('Student Topic materials must be an array.');
    }
    final materials = List<StudentLearningMaterialDto>.unmodifiable(
      rawMaterials.map(StudentLearningMaterialDto.fromJson),
    );
    final materialIds = materials
        .map((material) => material.id.toLowerCase())
        .toSet();
    final fileIds = materials
        .map((material) => material.file.id.toLowerCase())
        .toSet();
    if (materialIds.length != materials.length) {
      throw const FormatException(
        'Student Topic materials contain duplicate Material IDs.',
      );
    }
    if (fileIds.length != materials.length) {
      throw const FormatException(
        'Student Topic materials contain duplicate File IDs.',
      );
    }
    final homework = map['homework'];
    if (homework is! List || homework.isNotEmpty) {
      throw const FormatException(
        'Student Topic homework placeholder must be an empty array.',
      );
    }
    if (map['blitz_status'] != 'not_available' ||
        map['result_status'] != 'waiting_for_homework') {
      throw const FormatException(
        'Student Topic placeholder status is unsupported.',
      );
    }

    return StudentTopicDetailDto(
      id: readStudentCanonicalUuid(map, 'id'),
      group: StudentGroupDto.fromJson(map['group']),
      title: readStudentNonBlankString(map, 'title'),
      description: readStudentNullableString(map, 'description'),
      subject: readStudentNonBlankString(map, 'subject'),
      studentInstructions: readStudentNonBlankString(
        map,
        'student_instructions',
      ),
      lessonAt: readStudentNullableUtcTimestamp(map, 'lesson_at'),
      status: StudentTopicStatus.parse(
        readStudentNonBlankString(map, 'status'),
      ),
      materials: materials,
    );
  }

  final String id;
  final StudentGroupDto group;
  final String title;
  final String? description;
  final String subject;
  final String studentInstructions;
  final DateTime? lessonAt;
  final StudentTopicStatus status;
  final List<StudentLearningMaterialDto> materials;

  StudentTopicDetail toDomain() {
    return StudentTopicDetail(
      id: id,
      group: group.toDomain(),
      title: title,
      description: description,
      subject: subject,
      studentInstructions: studentInstructions,
      lessonAt: lessonAt,
      status: status,
      materials: materials.map((material) => material.toDomain()).toList(),
    );
  }
}

class StudentTopicListDto {
  StudentTopicListDto({
    required List<StudentTopicSummaryDto> topics,
    required this.pagination,
  }) : topics = List<StudentTopicSummaryDto>.unmodifiable(topics);

  factory StudentTopicListDto.fromJson(
    Object? json, {
    required StudentTopicListQuery requestedQuery,
  }) {
    final envelope = readExactStudentMap(
      json,
      context: 'Student Topic list envelope',
      keys: const {'data', 'meta'},
    );
    final rawTopics = envelope['data'];
    if (rawTopics is! List) {
      throw const FormatException('Student Topic list data must be an array.');
    }
    final meta = readExactStudentMap(
      envelope['meta'],
      context: 'Student Topic list meta',
      keys: const {'pagination'},
    );
    final pagination = StudentListPaginationDto.fromJson(
      meta['pagination'],
      requestedPage: requestedQuery.page,
      rowCount: rawTopics.length,
    );
    final topics = List<StudentTopicSummaryDto>.unmodifiable(
      rawTopics.map(StudentTopicSummaryDto.fromJson),
    );
    final ids = topics.map((topic) => topic.id.toLowerCase()).toSet();
    if (ids.length != topics.length) {
      throw const FormatException(
        'Student Topic list contains duplicate Topic IDs.',
      );
    }

    return StudentTopicListDto(topics: topics, pagination: pagination);
  }

  final List<StudentTopicSummaryDto> topics;
  final StudentListPaginationDto pagination;

  StudentTopicListPage toDomain() {
    return StudentTopicListPage(
      topics: topics.map((topic) => topic.toDomain()).toList(),
      pagination: pagination.toDomain(),
    );
  }
}

class StudentListPaginationDto {
  const StudentListPaginationDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory StudentListPaginationDto.fromJson(
    Object? json, {
    required int requestedPage,
    required int rowCount,
  }) {
    final map = readExactStudentMap(
      json,
      context: 'Student Topic list pagination',
      keys: const {'page', 'per_page', 'total', 'last_page'},
    );
    final page = readStudentInt(map, 'page');
    final perPage = readStudentInt(map, 'per_page');
    final total = readStudentInt(map, 'total');
    final lastPage = readStudentInt(map, 'last_page');
    if (page != requestedPage || page < 1) {
      throw const FormatException(
        'Pagination page does not match the request.',
      );
    }
    if (perPage != StudentTopicListQuery.perPage) {
      throw const FormatException(
        'Pagination per_page does not match the request.',
      );
    }
    if (total < 0 || lastPage < 1) {
      throw const FormatException('Pagination values are out of range.');
    }
    final expectedLastPage = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
    if (lastPage != expectedLastPage) {
      throw const FormatException('Pagination last_page is contradictory.');
    }
    if (rowCount > perPage || rowCount > total) {
      throw const FormatException(
        'Student Topic row count exceeds pagination.',
      );
    }
    if (page > lastPage && rowCount != 0) {
      throw const FormatException('An out-of-range page must be empty.');
    }

    return StudentListPaginationDto(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }

  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  StudentListPagination toDomain() {
    return StudentListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }
}

const _groupKeys = <String>{
  'id',
  'name',
  'level',
  'subject_direction',
  'status',
};
const _summaryKeys = <String>{
  'id',
  'group',
  'title',
  'subject',
  'lesson_at',
  'status',
};
const _materialKeys = <String>{'id', 'title', 'file'};
const _fileKeys = <String>{'id', 'original_name', 'extension', 'size_bytes'};
const _detailKeys = <String>{
  'id',
  'group',
  'title',
  'description',
  'subject',
  'student_instructions',
  'lesson_at',
  'status',
  'materials',
  'homework',
  'blitz_status',
  'result_status',
};
const _allowedExtensions = <String>{'pdf', 'docx', 'ppt', 'pptx'};

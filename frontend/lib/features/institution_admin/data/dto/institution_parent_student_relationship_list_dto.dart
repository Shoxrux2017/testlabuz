import '../../domain/institution_parent_student_relationship.dart';
import '../../domain/institution_parent_student_relationship_list.dart';
import '../../domain/institution_parent_student_relationship_query.dart';
import 'institution_parent_student_relationship_dto.dart';

class InstitutionParentStudentRelationshipListDto {
  const InstitutionParentStudentRelationshipListDto({
    required this.relationships,
    required this.pagination,
  });

  factory InstitutionParentStudentRelationshipListDto.fromJson(
    Object? json, {
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
    required InstitutionParentStudentRelationshipQuery requestedQuery,
  }) {
    final envelope = readExactParentStudentMap(
      json,
      context: 'Parent-Student relationship list envelope',
      keys: const {'data', 'meta'},
    );
    final rawRelationships = envelope['data'];
    if (rawRelationships is! List<Object?>) {
      throw const FormatException('Relationship list data must be an array.');
    }
    final meta = readExactParentStudentMap(
      envelope['meta'],
      context: 'Parent-Student relationship list meta',
      keys: const {'pagination'},
    );
    final pagination =
        InstitutionParentStudentRelationshipListPaginationDto.fromJson(
          meta['pagination'],
          requestedQuery: requestedQuery,
          rowCount: rawRelationships.length,
        );
    final relationships =
        List<InstitutionParentStudentRelationshipDto>.unmodifiable(
          rawRelationships.map(
            (item) => InstitutionParentStudentRelationshipDto.fromJson(
              item,
              perspective: perspective,
              anchorId: anchorId,
            ),
          ),
        );
    final ids = <String>{};
    for (final relationship in relationships) {
      if (!ids.add(relationship.id.toLowerCase())) {
        throw const FormatException(
          'Relationship list contains duplicate relationship IDs.',
        );
      }
    }
    return InstitutionParentStudentRelationshipListDto(
      relationships: relationships,
      pagination: pagination,
    );
  }

  final List<InstitutionParentStudentRelationshipDto> relationships;
  final InstitutionParentStudentRelationshipListPaginationDto pagination;

  InstitutionParentStudentRelationshipListPage toDomain() =>
      InstitutionParentStudentRelationshipListPage(
        relationships: List.unmodifiable(
          relationships.map((relationship) => relationship.toDomain()),
        ),
        pagination: pagination.toDomain(),
      );
}

class InstitutionParentStudentRelationshipListPaginationDto {
  const InstitutionParentStudentRelationshipListPaginationDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory InstitutionParentStudentRelationshipListPaginationDto.fromJson(
    Object? json, {
    required InstitutionParentStudentRelationshipQuery requestedQuery,
    required int rowCount,
  }) {
    final map = readExactParentStudentMap(
      json,
      context: 'Parent-Student relationship list pagination',
      keys: const {'page', 'per_page', 'total', 'last_page'},
    );
    final page = _readInt(map, 'page');
    final perPage = _readInt(map, 'per_page');
    final total = _readInt(map, 'total');
    final lastPage = _readInt(map, 'last_page');
    if (page < 1 || page != requestedQuery.page) {
      throw const FormatException('Pagination page contradicts the request.');
    }
    if (perPage < 1 || perPage > 100 || perPage != requestedQuery.perPage) {
      throw const FormatException(
        'Pagination per_page contradicts the request.',
      );
    }
    if (total < 0) {
      throw const FormatException('Pagination total cannot be negative.');
    }
    final expectedLastPage = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
    if (lastPage != expectedLastPage) {
      throw const FormatException('Pagination last_page is contradictory.');
    }
    if (rowCount > perPage || (total > 0 && rowCount > total)) {
      throw const FormatException('Relationship row count exceeds pagination.');
    }
    if (total == 0 && rowCount != 0) {
      throw const FormatException('A zero-total page must be empty.');
    }
    if (page > lastPage && rowCount != 0) {
      throw const FormatException('An out-of-range page must be empty.');
    }
    return InstitutionParentStudentRelationshipListPaginationDto(
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

  InstitutionParentStudentRelationshipListPagination toDomain() =>
      InstitutionParentStudentRelationshipListPagination(
        page: page,
        perPage: perPage,
        total: total,
        lastPage: lastPage,
      );
}

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key must be a JSON integer.');
}

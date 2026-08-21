import '../../domain/institution_group.dart';
import '../../domain/institution_group_list.dart';
import '../../domain/institution_group_list_query.dart';
import 'institution_group_dto.dart';

export 'institution_group_dto.dart';

class InstitutionGroupListDto {
  const InstitutionGroupListDto({
    required this.groups,
    required this.pagination,
  });

  factory InstitutionGroupListDto.fromJson(
    Object? json, {
    required InstitutionGroupListQuery requestedQuery,
  }) {
    final envelope = _readExactMap(
      json,
      context: 'Institution Group list envelope',
      keys: const {'data', 'meta'},
    );
    final rawGroups = envelope['data'];
    if (rawGroups is! List<Object?>) {
      throw const FormatException(
        'Institution Group list data must be an array.',
      );
    }

    final meta = _readExactMap(
      envelope['meta'],
      context: 'Institution Group list meta',
      keys: const {'pagination'},
    );
    final pagination = InstitutionGroupListPaginationDto.fromJson(
      meta['pagination'],
      requestedQuery: requestedQuery,
      rowCount: rawGroups.length,
    );
    final groups = List<InstitutionGroupDto>.unmodifiable(
      rawGroups.map(InstitutionGroupDto.fromJson),
    );
    final ids = groups.map((group) => group.id).toSet();
    if (ids.length != groups.length) {
      throw const FormatException(
        'Institution Group list contains duplicate IDs.',
      );
    }

    return InstitutionGroupListDto(groups: groups, pagination: pagination);
  }

  final List<InstitutionGroupDto> groups;
  final InstitutionGroupListPaginationDto pagination;

  InstitutionGroupListPage toDomain() {
    return InstitutionGroupListPage(
      groups: List<InstitutionGroup>.unmodifiable(
        groups.map((group) => group.toDomain()),
      ),
      pagination: pagination.toDomain(),
    );
  }
}

class InstitutionGroupListPaginationDto {
  const InstitutionGroupListPaginationDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory InstitutionGroupListPaginationDto.fromJson(
    Object? json, {
    required InstitutionGroupListQuery requestedQuery,
    required int rowCount,
  }) {
    final map = _readExactMap(
      json,
      context: 'Institution Group list pagination',
      keys: const {'page', 'per_page', 'total', 'last_page'},
    );
    final page = _readInt(map, 'page');
    final perPage = _readInt(map, 'per_page');
    final total = _readInt(map, 'total');
    final lastPage = _readInt(map, 'last_page');

    if (page < 1 || page != requestedQuery.page) {
      throw const FormatException(
        'Pagination page does not match the request.',
      );
    }
    if (perPage < 1 || perPage > 100 || perPage != requestedQuery.perPage) {
      throw const FormatException(
        'Pagination per_page does not match the request.',
      );
    }
    if (total < 0) {
      throw const FormatException('Pagination total cannot be negative.');
    }
    final expectedLastPage = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
    if (lastPage < 1 || lastPage != expectedLastPage) {
      throw const FormatException('Pagination last_page is contradictory.');
    }
    if (rowCount > perPage || (total > 0 && rowCount > total)) {
      throw const FormatException(
        'Institution Group row count exceeds pagination.',
      );
    }
    if (total == 0 && rowCount != 0) {
      throw const FormatException('A zero-total page cannot contain Groups.');
    }
    if (page > lastPage && rowCount != 0) {
      throw const FormatException('An out-of-range page must be empty.');
    }

    return InstitutionGroupListPaginationDto(
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

  InstitutionGroupListPagination toDomain() {
    return InstitutionGroupListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }
}

Map<String, Object?> _readExactMap(
  Object? value, {
  required String context,
  required Set<String> keys,
}) {
  if (value is! Map) {
    throw FormatException('$context must be an object.');
  }

  final map = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw FormatException('$context contains a non-string key.');
    }
    map[key] = entry.value;
  }

  if (map.length != keys.length || !map.keys.toSet().containsAll(keys)) {
    throw FormatException('$context has missing or unknown keys.');
  }

  return map;
}

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }

  throw FormatException('$key must be a JSON integer.');
}

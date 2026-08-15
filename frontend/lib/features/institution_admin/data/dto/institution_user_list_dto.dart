import '../../domain/institution_user.dart';
import '../../domain/institution_user_list.dart';
import '../../domain/institution_user_list_query.dart';
import 'institution_user_dto.dart';

export 'institution_user_dto.dart';

class InstitutionUserListDto {
  const InstitutionUserListDto({required this.users, required this.pagination});

  factory InstitutionUserListDto.fromJson(
    Object? json, {
    required InstitutionUserListQuery requestedQuery,
  }) {
    final envelope = _readExactMap(
      json,
      context: 'Institution User list envelope',
      keys: const {'data', 'meta'},
    );
    final rawUsers = envelope['data'];
    if (rawUsers is! List<Object?>) {
      throw const FormatException(
        'Institution User list data must be an array.',
      );
    }

    final meta = _readExactMap(
      envelope['meta'],
      context: 'Institution User list meta',
      keys: const {'pagination'},
    );
    final pagination = InstitutionUserListPaginationDto.fromJson(
      meta['pagination'],
      requestedQuery: requestedQuery,
      rowCount: rawUsers.length,
    );
    final users = List<InstitutionUserDto>.unmodifiable(
      rawUsers.map(InstitutionUserDto.fromJson),
    );
    final ids = users.map((user) => user.id).toSet();
    if (ids.length != users.length) {
      throw const FormatException(
        'Institution User list contains duplicate IDs.',
      );
    }

    return InstitutionUserListDto(users: users, pagination: pagination);
  }

  final List<InstitutionUserDto> users;
  final InstitutionUserListPaginationDto pagination;

  InstitutionUserListPage toDomain() {
    return InstitutionUserListPage(
      users: List<InstitutionUser>.unmodifiable(
        users.map((user) => user.toDomain()),
      ),
      pagination: pagination.toDomain(),
    );
  }
}

class InstitutionUserListPaginationDto {
  const InstitutionUserListPaginationDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory InstitutionUserListPaginationDto.fromJson(
    Object? json, {
    required InstitutionUserListQuery requestedQuery,
    required int rowCount,
  }) {
    final map = _readExactMap(
      json,
      context: 'Institution User list pagination',
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
        'Institution User row count exceeds pagination.',
      );
    }
    if (total == 0 && rowCount != 0) {
      throw const FormatException('A zero-total page cannot contain Users.');
    }
    if (page > lastPage && rowCount != 0) {
      throw const FormatException('An out-of-range page must be empty.');
    }

    return InstitutionUserListPaginationDto(
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

  InstitutionUserListPagination toDomain() {
    return InstitutionUserListPagination(
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

import '../../domain/institution_group_membership.dart';
import '../../domain/institution_group_membership_list.dart';
import '../../domain/institution_group_membership_query.dart';
import 'institution_group_membership_dto.dart';

class InstitutionGroupMembershipListDto {
  const InstitutionGroupMembershipListDto({
    required this.memberships,
    required this.pagination,
  });

  factory InstitutionGroupMembershipListDto.fromJson(
    Object? json, {
    required InstitutionGroupMembershipQuery requestedQuery,
  }) {
    final envelope = readExactMembershipMap(
      json,
      context: 'Institution Group membership list envelope',
      keys: const {'data', 'meta'},
    );
    final rawMemberships = envelope['data'];
    if (rawMemberships is! List<Object?>) {
      throw const FormatException('Membership list data must be an array.');
    }
    final meta = readExactMembershipMap(
      envelope['meta'],
      context: 'Institution Group membership list meta',
      keys: const {'pagination'},
    );
    final pagination = InstitutionGroupMembershipListPaginationDto.fromJson(
      meta['pagination'],
      requestedQuery: requestedQuery,
      rowCount: rawMemberships.length,
    );
    final memberships = List<InstitutionGroupMembershipDto>.unmodifiable(
      rawMemberships.map(InstitutionGroupMembershipDto.fromJson),
    );
    _requireDistinctIds(memberships);
    return InstitutionGroupMembershipListDto(
      memberships: memberships,
      pagination: pagination,
    );
  }

  final List<InstitutionGroupMembershipDto> memberships;
  final InstitutionGroupMembershipListPaginationDto pagination;

  InstitutionGroupMembershipListPage toDomain() =>
      InstitutionGroupMembershipListPage(
        memberships: List<InstitutionGroupMembership>.unmodifiable(
          memberships.map((membership) => membership.toDomain()),
        ),
        pagination: pagination.toDomain(),
      );
}

class InstitutionGroupMembershipListPaginationDto {
  const InstitutionGroupMembershipListPaginationDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory InstitutionGroupMembershipListPaginationDto.fromJson(
    Object? json, {
    required InstitutionGroupMembershipQuery requestedQuery,
    required int rowCount,
  }) {
    final map = readExactMembershipMap(
      json,
      context: 'Institution Group membership list pagination',
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
    if (lastPage < 1 || lastPage != expectedLastPage) {
      throw const FormatException('Pagination last_page is contradictory.');
    }
    if (rowCount > perPage || (total > 0 && rowCount > total)) {
      throw const FormatException('Membership row count exceeds pagination.');
    }
    if (total == 0 && rowCount != 0) {
      throw const FormatException('A zero-total page must be empty.');
    }
    if (page > lastPage && rowCount != 0) {
      throw const FormatException('An out-of-range page must be empty.');
    }
    return InstitutionGroupMembershipListPaginationDto(
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

  InstitutionGroupMembershipListPagination toDomain() =>
      InstitutionGroupMembershipListPagination(
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

void _requireDistinctIds(List<InstitutionGroupMembershipDto> memberships) {
  final ids = <String>{};
  for (final membership in memberships) {
    if (!ids.add(membership.id.toLowerCase())) {
      throw const FormatException(
        'Membership list contains duplicate member IDs.',
      );
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_list_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_query.dart';

void main() {
  test(
    'repository converts typed DTOs and preserves order and pagination',
    () async {
      final adapter = _Adapter(
        (_) => ResponseBody.fromString(
          jsonEncode({
            'data': [
              _group('00000000-0000-0000-0000-000000000002', 'B'),
              _group('00000000-0000-0000-0000-000000000001', 'A'),
            ],
            'meta': {
              'pagination': {
                'page': 2,
                'per_page': 50,
                'total': 52,
                'last_page': 2,
              },
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter;
      final repository = InstitutionGroupListRepositoryImpl(
        remoteDataSource: InstitutionGroupListRemoteDataSource(
          dio: dio,
          failureMapper: const DioFailureMapper(),
        ),
      );

      final page = await repository.fetchGroups(
        const InstitutionGroupListQuery.initial().copyWith(
          page: 2,
          perPage: 50,
        ),
      );

      expect(page.groups.map((group) => group.name), ['B', 'A']);
      expect(page.pagination.page, 2);
      expect(page.pagination.total, 52);
    },
  );
}

Map<String, Object?> _group(String id, String name) {
  return {
    'id': id,
    'name': name,
    'level': null,
    'subject_direction': null,
    'description': null,
    'status': 'active',
    'teachers_count': 0,
    'students_count': 0,
    'archived_at': null,
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T16:00:00Z',
  };
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

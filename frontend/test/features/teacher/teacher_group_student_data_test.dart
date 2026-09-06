import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_group_student_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_group_student_list_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_list_query.dart';

const _groupId = '10000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherGroupStudentListQuery', () {
    test('normalizes search and serializes only exact query keys', () {
      const initial = TeacherGroupStudentListQuery.initial();
      expect(initial.toQueryParameters(), {'page': 1, 'per_page': 50});

      final query = initial
          .withSearch('  Student % _  ')
          .withPerPage(100)
          .withPage(2);
      expect(query.search, 'Student % _');
      expect(query.toQueryParameters(), {
        'page': 2,
        'per_page': 100,
        'search': 'Student % _',
      });
      expect(query.withSearch('   ').search, isNull);
      expect(query.withSearch('   ').toQueryParameters(), {
        'page': 1,
        'per_page': 100,
      });
    });

    test('enforces search, page, and per-page bounds locally', () {
      final valid = List.filled(100, 'a').join();
      final invalid = '$valid!';

      expect(TeacherGroupStudentListQuery.isSearchInputValid(valid), isTrue);
      expect(TeacherGroupStudentListQuery.isSearchInputValid(invalid), isFalse);
      expect(
        () => const TeacherGroupStudentListQuery.initial().withSearch(invalid),
        throwsArgumentError,
      );
      expect(
        () => const TeacherGroupStudentListQuery.initial().withPage(0),
        throwsArgumentError,
      );
      expect(
        () => const TeacherGroupStudentListQuery.initial().withPerPage(0),
        throwsArgumentError,
      );
      expect(
        () => const TeacherGroupStudentListQuery.initial().withPerPage(101),
        throwsArgumentError,
      );
      expect(
        const TeacherGroupStudentListQuery.initial().withPerPage(1).perPage,
        1,
      );
      expect(
        const TeacherGroupStudentListQuery.initial().withPerPage(100).perPage,
        100,
      );
    });
  });

  group('Teacher Group Student DTO', () {
    test('accepts exactly id, full_name, and login_name', () {
      final student = TeacherGroupStudentDto.fromJson(
        _studentJson(),
      ).toDomain();

      expect(student.id, '20000000-0000-0000-0000-000000000001');
      expect(student.fullName, 'Student One');
      expect(student.loginName, 'student.one');
    });

    test('rejects missing, unknown, malformed, and blank row fields', () {
      final unknown = _studentJson()..['email'] = 'hidden@example.com';
      final missing = _studentJson()..remove('login_name');
      final malformedId = _studentJson()..['id'] = 'invalid';
      final blankName = _studentJson()..['full_name'] = '   ';

      for (final json in [unknown, missing, malformedId, blankName]) {
        expect(
          () => TeacherGroupStudentDto.fromJson(json),
          throwsFormatException,
        );
      }
    });

    test('requires exact collection envelope and pagination', () {
      const query = TeacherGroupStudentListQuery.initial();
      final list = TeacherGroupStudentListDto.fromJson(
        _listJson([_studentJson()]),
        requestedQuery: query,
      ).toDomain();
      expect(list.items.single.loginName, 'student.one');
      expect(list.pagination.perPage, 50);

      final unknown = _listJson([_studentJson()])..['unknown'] = true;
      final wrongPerPage = _listJson([_studentJson()], perPage: 20);
      final wrongLastPage = _listJson([_studentJson()], total: 51, lastPage: 1);
      final duplicate = _listJson([_studentJson(), _studentJson()], total: 2);

      for (final json in [unknown, wrongPerPage, wrongLastPage, duplicate]) {
        expect(
          () =>
              TeacherGroupStudentListDto.fromJson(json, requestedQuery: query),
          throwsFormatException,
        );
      }
    });
  });

  group('TeacherGroupStudentRemoteDataSource', () {
    test(
      'uses exact Teacher roster bodyless GET and normalized query',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(
            200,
            _listJson(const [], page: 2, perPage: 100, total: 100, lastPage: 1),
          ),
        );
        final query = const TeacherGroupStudentListQuery.initial()
            .withSearch('  Student % _  ')
            .withPerPage(100)
            .withPage(2);

        await _source(adapter).fetchGroupStudents(_groupId, query);

        final request = adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.path, '/teacher/groups/$_groupId/students');
        expect(request.uri.path, '/api/v1/teacher/groups/$_groupId/students');
        expect(request.data, isNull);
        expect(request.followRedirects, isFalse);
        expect(request.queryParameters, {
          'page': 2,
          'per_page': 100,
          'search': 'Student % _',
        });
      },
    );

    test('omits empty search and cannot send overlong search', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _listJson(const [], total: 0)),
      );
      final source = _source(adapter);
      final empty = const TeacherGroupStudentListQuery.initial().withSearch(
        '   ',
      );

      await source.fetchGroupStudents(_groupId, empty);
      expect(adapter.requests.single.queryParameters, {
        'page': 1,
        'per_page': 50,
      });

      expect(
        () => empty.withSearch(List.filled(101, 'x').join()),
        throwsArgumentError,
      );
      expect(adapter.requests, hasLength(1));
    });

    test('requires 200 and maps malformed success and Dio failures', () async {
      final malformedSources = [
        _source(
          _RecordingAdapter(
            (_) => _jsonResponse(201, _listJson([_studentJson()])),
          ),
        ),
        _source(
          _RecordingAdapter((_) => _jsonResponse(200, {'data': <Object?>[]})),
        ),
      ];
      for (final source in malformedSources) {
        await expectLater(
          source.fetchGroupStudents(
            _groupId,
            const TeacherGroupStudentListQuery.initial(),
          ),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
      }

      final failed = _source(
        _RecordingAdapter((options) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }),
      );
      await expectLater(
        failed.fetchGroupStudents(
          _groupId,
          const TeacherGroupStudentListQuery.initial(),
        ),
        throwsA(_failureKind(ApiFailureKind.connection)),
      );
    });

    test('rejects malformed Group ID before transport', () {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _listJson(const [], total: 0)),
      );

      expect(
        () => _source(adapter).fetchGroupStudents(
          'invalid',
          const TeacherGroupStudentListQuery.initial(),
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });

  test('Group Student repository converts DTO pages to domain', () async {
    final repository = TeacherGroupStudentRepositoryImpl(
      remoteDataSource: _source(
        _RecordingAdapter(
          (_) => _jsonResponse(200, _listJson([_studentJson()])),
        ),
      ),
    );

    final list = await repository.fetchGroupStudents(
      _groupId,
      const TeacherGroupStudentListQuery.initial(),
    );

    expect(list.items.single.fullName, 'Student One');
    expect(list.pagination.total, 1);
  });
}

TeacherGroupStudentRemoteDataSource _source(_RecordingAdapter adapter) {
  return TeacherGroupStudentRemoteDataSource(
    dio: _dio(adapter),
    failureMapper: const DioFailureMapper(),
  );
}

Matcher _failureKind(ApiFailureKind kind) {
  return isA<ApiRequestException>().having(
    (error) => error.failure.kind,
    'kind',
    kind,
  );
}

Dio _dio(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, Object?> _studentJson() {
  return {
    'id': '20000000-0000-0000-0000-000000000001',
    'full_name': 'Student One',
    'login_name': 'student.one',
  };
}

Map<String, Object?> _listJson(
  List<Object?> rows, {
  int page = 1,
  int perPage = 50,
  int total = 1,
  int lastPage = 1,
}) {
  return {
    'data': rows,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': perPage,
        'total': total,
        'last_page': lastPage,
      },
    },
  };
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

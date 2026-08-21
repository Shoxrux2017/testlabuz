import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_mutation_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_mutation.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'PATCH sends exact changed JSON without query and rejects redirects',
    () async {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(200, {
          'data': groupResource(name: '10-B'),
          'message': 'Group updated successfully.',
        }),
      );
      final source = _source(adapter);

      await source.updateGroup(
        testGroupId,
        InstitutionGroupEditRequest({'name': '10-B'}),
      );

      expect(adapter.request.method, 'PATCH');
      expect(adapter.request.path, '/institution/groups/$testGroupId');
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.data, {'name': '10-B'});
      expect(adapter.request.followRedirects, isFalse);
    },
  );

  test('archive POST has no query and no data argument', () async {
    final adapter = RecordingAdapter(
      (_) => jsonResponse(200, {
        'data': groupResource(
          status: 'archived',
          archivedAt: '2026-08-21T10:00:00Z',
        ),
        'message': 'Group archived successfully.',
      }),
    );

    await _source(adapter).archiveGroup(testGroupId);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/institution/groups/$testGroupId/archive');
    expect(adapter.request.queryParameters, isEmpty);
    expect(adapter.request.data, isNull);
    expect(adapter.request.followRedirects, isFalse);
  });

  test('recognizes only exact definite status and code pairs', () async {
    final pairs = <(int, String)>[
      (401, ApiErrorCodes.authenticationRequired),
      (403, ApiErrorCodes.forbidden),
      (403, ApiErrorCodes.passwordChangeRequired),
      (403, ApiErrorCodes.userInactive),
      (403, ApiErrorCodes.institutionInactive),
      (404, ApiErrorCodes.resourceNotFound),
      (409, ApiErrorCodes.businessConflict),
      (422, ApiErrorCodes.validationFailed),
      (429, ApiErrorCodes.rateLimited),
    ];
    for (final (status, code) in pairs) {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(status, {
          'message': 'Private backend message.',
          'code': code,
          'errors': status == 422
              ? {
                  'name': ['Private field message.'],
                }
              : <String, Object?>{},
        }),
      );

      await expectLater(
        _source(adapter).archiveGroup(testGroupId),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.serverCode,
            'server code',
            code,
          ),
        ),
      );
    }
  });

  test(
    'malformed errors, 5xx, and unexpected success are unknown outcomes',
    () async {
      for (final response in <ResponseBody>[
        jsonResponse(409, {
          'message': 'Conflict',
          'code': ApiErrorCodes.businessConflict,
          'errors': <String, Object?>{},
          'extra': true,
        }),
        jsonResponse(403, {
          'message': 'Forbidden',
          'code': ApiErrorCodes.forbidden,
          'errors': {
            'name': ['must be empty for non-422'],
          },
        }),
        jsonResponse(500, {
          'message': 'Server',
          'code': ApiErrorCodes.serverError,
          'errors': <String, Object?>{},
        }),
        jsonResponse(201, {
          'data': groupResource(),
          'message': 'Group archived successfully.',
        }),
      ]) {
        final adapter = RecordingAdapter((_) => response);
        await expectLater(
          _source(adapter).archiveGroup(testGroupId),
          throwsA(isA<InstitutionGroupMutationOutcomeUnknownException>()),
        );
      }
    },
  );

  test('invalid target and empty PATCH fail before dispatch', () async {
    final adapter = RecordingAdapter(
      (_) => throw StateError('must not dispatch'),
    );
    final source = _source(adapter);
    expect(
      () =>
          source.updateGroup('bad', InstitutionGroupEditRequest({'name': 'x'})),
      throwsArgumentError,
    );
    expect(
      () => source.updateGroup(testGroupId, InstitutionGroupEditRequest({})),
      throwsArgumentError,
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'unexpected dispatch exception is an unknown mutation outcome',
    () async {
      final adapter = RecordingAdapter(
        (_) => throw ArgumentError('Unexpected transport failure.'),
      );

      await expectLater(
        _source(adapter).archiveGroup(testGroupId),
        throwsA(isA<InstitutionGroupMutationOutcomeUnknownException>()),
      );
    },
  );
}

InstitutionGroupMutationRemoteDataSource _source(RecordingAdapter adapter) {
  return InstitutionGroupMutationRemoteDataSource(
    dio: testDio(adapter),
    failureMapper: const DioFailureMapper(),
  );
}

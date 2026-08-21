import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_parent_student_relationship_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_query.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  test('GET uses exact directional path/query and zero body', () async {
    final adapter = RecordingAdapter(
      (_) => jsonResponse(200, relationshipListEnvelope()),
    );
    await _source(adapter).fetchRelationships(
      perspective: InstitutionParentStudentPerspective.byParent,
      anchorId: testParentId,
      query: const InstitutionParentStudentRelationshipQuery.initial().copyWith(
        search: 'Ali %',
        status: InstitutionParentStudentRelationshipStatusFilter.active,
      ),
    );
    expect(adapter.request.path, '/institution/parents/$testParentId/students');
    expect(adapter.request.method, 'GET');
    expect(adapter.request.data, isNull);
    expect(adapter.request.queryParameters, {
      'search': 'Ali %',
      'status': 'active',
      'page': 1,
      'per_page': 20,
      'sort': 'full_name',
      'direction': 'asc',
    });
  });

  test('POST sends exact pair and accepts strict 200/201 success', () async {
    for (final status in [200, 201]) {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(status, _mutationSuccess()),
      );
      await _source(adapter).connect(
        InstitutionParentStudentConnectRequest(
          parentId: testParentId,
          studentId: testStudentId,
        ),
      );
      expect(adapter.request.method, 'POST');
      expect(adapter.request.path, '/institution/parent-student-relationships');
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.data, {
        'parent_id': testParentId,
        'student_id': testStudentId,
      });
      expect(adapter.request.followRedirects, isFalse);
      expect(adapter.request.contentType, Headers.jsonContentType);
    }
  });

  test(
    'malformed or unexpected connect success is unknown without replay',
    () async {
      for (final response in <ResponseBody>[
        jsonResponse(202, _mutationSuccess()),
        jsonResponse(201, {..._mutationSuccess(), 'message': 'Wrong message'}),
        jsonResponse(201, {
          'data': {
            ...(_mutationSuccess()['data']! as Map<String, Object?>),
            'student_id': testParentId,
          },
          'message': 'Parent and student connected successfully.',
        }),
      ]) {
        final adapter = RecordingAdapter((_) => response);
        await expectLater(
          _source(adapter).connect(
            InstitutionParentStudentConnectRequest(
              parentId: testParentId,
              studentId: testStudentId,
            ),
          ),
          throwsA(
            isA<InstitutionParentStudentMutationOutcomeUnknownException>(),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'DELETE targets relationship UUID with zero body and strict empty 204',
    () async {
      final adapter = RecordingAdapter((_) => ResponseBody.fromString('', 204));
      await _source(adapter).disconnect(testRelationshipId);
      expect(adapter.request.method, 'DELETE');
      expect(
        adapter.request.path,
        '/institution/parent-student-relationships/$testRelationshipId',
      );
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.data, isNull);

      final meaningful = RecordingAdapter(
        (_) => jsonResponse(204, <String, Object?>{}),
      );
      await expectLater(
        _source(meaningful).disconnect(testRelationshipId),
        throwsA(isA<InstitutionParentStudentMutationOutcomeUnknownException>()),
      );
    },
  );

  test('only exact status/code error envelopes are definite', () async {
    for (final pair in <(int, String)>[
      (401, ApiErrorCodes.authenticationRequired),
      (403, ApiErrorCodes.forbidden),
      (403, ApiErrorCodes.passwordChangeRequired),
      (403, ApiErrorCodes.userInactive),
      (403, ApiErrorCodes.institutionInactive),
      (404, ApiErrorCodes.resourceNotFound),
      (409, ApiErrorCodes.businessConflict),
      (422, ApiErrorCodes.validationFailed),
      (429, ApiErrorCodes.rateLimited),
    ]) {
      final (status, code) = pair;
      final adapter = RecordingAdapter(
        (_) => jsonResponse(status, {
          'message': 'Private',
          'code': code,
          'errors': status == 422
              ? {
                  'parent_id': ['Private'],
                }
              : <String, Object?>{},
        }),
      );
      await expectLater(
        _source(adapter).connect(
          InstitutionParentStudentConnectRequest(
            parentId: testParentId,
            studentId: testStudentId,
          ),
        ),
        throwsA(
          isA<ApiRequestException>().having(
            (exception) => exception.failure.serverCode,
            'serverCode',
            code,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test('malformed errors and 5xx are unknown without replay', () async {
    for (final response in <ResponseBody>[
      jsonResponse(409, {
        'message': 'Conflict',
        'code': ApiErrorCodes.businessConflict,
        'errors': <String, Object?>{},
        'extra': true,
      }),
      jsonResponse(500, {
        'message': 'Server',
        'code': ApiErrorCodes.serverError,
        'errors': <String, Object?>{},
      }),
    ]) {
      final adapter = RecordingAdapter((_) => response);
      await expectLater(
        _source(adapter).connect(
          InstitutionParentStudentConnectRequest(
            parentId: testParentId,
            studentId: testStudentId,
          ),
        ),
        throwsA(isA<InstitutionParentStudentMutationOutcomeUnknownException>()),
      );
      expect(adapter.requests, hasLength(1));
    }
  });
}

InstitutionParentStudentRelationshipRemoteDataSource _source(
  RecordingAdapter adapter,
) => InstitutionParentStudentRelationshipRemoteDataSource(
  dio: testDio(adapter),
  failureMapper: const DioFailureMapper(),
);

Map<String, Object?> _mutationSuccess() => {
  'data': {
    'id': testRelationshipId,
    'parent_id': testParentId,
    'student_id': testStudentId,
    'started_at': '2026-08-21T10:15:00Z',
    'ended_at': null,
  },
  'message': 'Parent and student connected successfully.',
};

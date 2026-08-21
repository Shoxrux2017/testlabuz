import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_membership_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_query.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'GET uses exact kind path query and zero body and accepts only 200',
    () async {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(200, _listEnvelope()),
      );
      await _source(adapter).fetchMemberships(
        groupId: testGroupId,
        kind: InstitutionGroupMemberKind.teacher,
        query: const InstitutionGroupMembershipQuery.initial().copyWith(
          search: 'Ali %',
          status: InstitutionGroupMembershipStatusFilter.active,
        ),
      );
      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/institution/groups/$testGroupId/teachers');
      expect(adapter.request.queryParameters, {
        'search': 'Ali %',
        'status': 'active',
        'page': 1,
        'per_page': 20,
        'sort': 'full_name',
        'direction': 'asc',
      });
      expect(adapter.request.data, isNull);

      final unexpected = RecordingAdapter(
        (_) => jsonResponse(201, _listEnvelope()),
      );
      await expectLater(
        _source(unexpected).fetchMemberships(
          groupId: testGroupId,
          kind: InstitutionGroupMemberKind.student,
          query: const InstitutionGroupMembershipQuery.initial(),
        ),
        throwsA(isA<ApiRequestException>()),
      );
    },
  );

  test(
    'POST sends one exact kind key and accepts strict 200 or 201 response',
    () async {
      for (final status in [200, 201]) {
        final adapter = RecordingAdapter(
          (_) => jsonResponse(status, {
            'data': [membershipResource()],
            'message': 'Teachers assigned to group successfully.',
          }),
        );
        await _source(adapter).assignMemberships(
          groupId: testGroupId,
          kind: InstitutionGroupMemberKind.teacher,
          request: InstitutionGroupMembershipAssignmentRequest([testTeacherId]),
        );
        expect(adapter.request.method, 'POST');
        expect(
          adapter.request.path,
          '/institution/groups/$testGroupId/teachers',
        );
        expect(adapter.request.queryParameters, isEmpty);
        expect(adapter.request.data, {
          'teacher_ids': [testTeacherId],
        });
        expect(adapter.request.followRedirects, isFalse);
        expect(adapter.request.contentType, Headers.jsonContentType);
      }
    },
  );

  test(
    'assignment rejects malformed message IDs order and unexpected success',
    () async {
      for (final response in <ResponseBody>[
        jsonResponse(202, {
          'data': [membershipResource()],
          'message': 'Teachers assigned to group successfully.',
        }),
        jsonResponse(201, {
          'data': [membershipResource(id: testStudentId)],
          'message': 'Teachers assigned to group successfully.',
        }),
        jsonResponse(201, {
          'data': [membershipResource()],
          'message': 'Wrong message',
        }),
      ]) {
        final adapter = RecordingAdapter((_) => response);
        await expectLater(
          _source(adapter).assignMemberships(
            groupId: testGroupId,
            kind: InstitutionGroupMemberKind.teacher,
            request: InstitutionGroupMembershipAssignmentRequest([
              testTeacherId,
            ]),
          ),
          throwsA(
            isA<InstitutionGroupMembershipMutationOutcomeUnknownException>(),
          ),
        );
      }
    },
  );

  test('DELETE sends zero body and accepts only exact empty 204', () async {
    final adapter = RecordingAdapter((_) => ResponseBody.fromString('', 204));
    await _source(adapter).removeMembership(
      groupId: testGroupId,
      kind: InstitutionGroupMemberKind.student,
      memberId: testStudentId,
    );
    expect(adapter.request.method, 'DELETE');
    expect(
      adapter.request.path,
      '/institution/groups/$testGroupId/students/$testStudentId',
    );
    expect(adapter.request.queryParameters, isEmpty);
    expect(adapter.request.data, isNull);

    final body = RecordingAdapter(
      (_) => jsonResponse(204, <String, Object?>{}),
    );
    await expectLater(
      _source(body).removeMembership(
        groupId: testGroupId,
        kind: InstitutionGroupMemberKind.student,
        memberId: testStudentId,
      ),
      throwsA(isA<InstitutionGroupMembershipMutationOutcomeUnknownException>()),
    );
  });

  test(
    'only exact status code error envelopes are definite and never replay',
    () async {
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
                    'teacher_ids': ['Private'],
                  }
                : <String, Object?>{},
            'request_id': 'req-1',
          }),
        );
        await expectLater(
          _source(adapter).assignMemberships(
            groupId: testGroupId,
            kind: InstitutionGroupMemberKind.teacher,
            request: InstitutionGroupMembershipAssignmentRequest([
              testTeacherId,
            ]),
          ),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.serverCode,
              'code',
              code,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'malformed error pair timeout cancellation and 5xx are unknown',
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
            'teacher_ids': ['not empty'],
          },
        }),
        jsonResponse(500, {
          'message': 'Server',
          'code': ApiErrorCodes.serverError,
          'errors': <String, Object?>{},
        }),
      ]) {
        final adapter = RecordingAdapter((_) => response);
        await expectLater(
          _source(adapter).assignMemberships(
            groupId: testGroupId,
            kind: InstitutionGroupMemberKind.teacher,
            request: InstitutionGroupMembershipAssignmentRequest([
              testTeacherId,
            ]),
          ),
          throwsA(
            isA<InstitutionGroupMembershipMutationOutcomeUnknownException>(),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

InstitutionGroupMembershipRemoteDataSource _source(RecordingAdapter adapter) =>
    InstitutionGroupMembershipRemoteDataSource(
      dio: testDio(adapter),
      failureMapper: const DioFailureMapper(),
    );

Map<String, Object?> _listEnvelope() => {
  'data': [membershipResource()],
  'meta': {
    'pagination': {'page': 1, 'per_page': 20, 'total': 1, 'last_page': 1},
  },
};

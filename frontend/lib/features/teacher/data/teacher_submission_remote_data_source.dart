import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_submission_list_query.dart';
import '../domain/teacher_submission_review.dart';
import 'dto/teacher_dto_parse.dart';
import 'dto/teacher_official_score_dto.dart';
import 'dto/teacher_submission_detail_dto.dart';
import 'dto/teacher_submission_dto.dart';
import 'teacher_mutation_transport.dart';

final teacherSubmissionRemoteDataSourceProvider =
    Provider<TeacherSubmissionRemoteDataSource>((ref) {
      return TeacherSubmissionRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

const _reviewSavedMessage = 'Submission review saved successfully.';

class TeacherSubmissionRemoteDataSource {
  const TeacherSubmissionRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherSubmissionListDto> fetchSubmissions(
    TeacherSubmissionListQuery query,
  ) {
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/submissions',
        queryParameters: query.toQueryParameters(),
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher submission list success status must be 200.',
        );
      }

      return TeacherSubmissionListDto.fromJson(
        response.data,
        requestedQuery: query,
      );
    });
  }

  Future<TeacherSubmissionDetailDto> fetchSubmission(String submissionId) {
    if (!canonicalUuidPattern.hasMatch(submissionId)) {
      throw ArgumentError.value(
        submissionId,
        'submissionId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/submissions/${Uri.encodeComponent(submissionId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher submission detail success status must be 200.',
        );
      }
      final envelope = readExactTeacherMap(
        response.data,
        context: 'Teacher submission detail envelope',
        keys: const {'data'},
      );
      return TeacherSubmissionDetailDto.fromJson(envelope['data']);
    });
  }

  Future<TeacherOfficialScoreDto> fetchOfficialScore(
    String assessmentId,
    String studentId,
  ) {
    if (!canonicalUuidPattern.hasMatch(assessmentId) ||
        !canonicalUuidPattern.hasMatch(studentId)) {
      throw ArgumentError('Official score ids must be canonical UUIDs.');
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/assessments/${Uri.encodeComponent(assessmentId)}'
        '/students/${Uri.encodeComponent(studentId)}/official-score',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher official score success status must be 200.',
        );
      }
      final envelope = readExactTeacherMap(
        response.data,
        context: 'Teacher official score envelope',
        keys: const {'data'},
      );
      return TeacherOfficialScoreDto.fromJson(envelope['data']);
    });
  }

  /// Sends the review once; an unproven outcome throws
  /// [TeacherSubmissionReviewOutcomeUnknownException].
  Future<TeacherSubmissionDetailDto> saveReview(
    String submissionId,
    TeacherSubmissionReviewRequest request,
  ) {
    if (!canonicalUuidPattern.hasMatch(submissionId)) {
      throw ArgumentError.value(
        submissionId,
        'submissionId',
        'Must be a canonical UUID.',
      );
    }
    return sendTeacherMutation(
      send: () => dio.put<Object?>(
        '/teacher/submissions/${Uri.encodeComponent(submissionId)}/review',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      parse: (data) {
        final envelope = readExactTeacherMap(
          data,
          context: 'Teacher submission review envelope',
          keys: const {'data', 'message'},
        );
        if (envelope['message'] != _reviewSavedMessage) {
          throw const FormatException(
            'Teacher submission review message is unexpected.',
          );
        }
        return TeacherSubmissionDetailDto.fromJson(envelope['data']);
      },
      conflictCodes: const {
        ApiErrorCodes.automaticCheckingPending,
        ApiErrorCodes.resultClosed,
      },
      failureMapper: failureMapper,
      outcomeUnknown: () =>
          const TeacherSubmissionReviewOutcomeUnknownException(),
    );
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw ApiRequestException(failureMapper.map(exception));
    } on FormatException catch (exception) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: exception.message,
        ),
      );
    }
  }
}

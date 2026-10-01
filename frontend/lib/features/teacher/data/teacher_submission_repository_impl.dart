import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/teacher_official_score.dart';
import '../domain/teacher_submission_detail.dart';
import '../domain/teacher_submission_list.dart';
import '../domain/teacher_submission_list_query.dart';
import '../domain/teacher_submission_repository.dart';
import '../domain/teacher_submission_review.dart';
import 'teacher_submission_remote_data_source.dart';

final teacherSubmissionRepositoryProvider =
    Provider<TeacherSubmissionRepository>((ref) {
      return TeacherSubmissionRepositoryImpl(
        remoteDataSource: ref.watch(teacherSubmissionRemoteDataSourceProvider),
      );
    });

class TeacherSubmissionRepositoryImpl implements TeacherSubmissionRepository {
  const TeacherSubmissionRepositoryImpl({required this.remoteDataSource});

  final TeacherSubmissionRemoteDataSource remoteDataSource;

  @override
  Future<TeacherSubmissionList> fetchSubmissions(
    TeacherSubmissionListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchSubmissions(query);
    return dto.toDomain();
  }

  @override
  Future<TeacherSubmissionDetail> fetchSubmission(String submissionId) async {
    final dto = await remoteDataSource.fetchSubmission(submissionId);
    final detail = dto.toDomain();
    if (detail.submission.id.toLowerCase() != submissionId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'The submission detail belongs to another submission.',
        ),
      );
    }
    return detail;
  }

  @override
  Future<TeacherOfficialScore> fetchOfficialScore(
    TeacherOfficialScoreTarget target,
  ) async {
    final dto = await remoteDataSource.fetchOfficialScore(
      target.assessmentId,
      target.studentId,
    );
    final score = dto.toDomain();
    if (!score.matches(target)) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'The official score belongs to another task or Student.',
        ),
      );
    }
    return score;
  }

  @override
  Future<TeacherSubmissionDetail> saveReview(
    String submissionId,
    TeacherSubmissionReviewRequest request,
  ) async {
    final dto = await remoteDataSource.saveReview(submissionId, request);
    return dto.toDomain();
  }
}

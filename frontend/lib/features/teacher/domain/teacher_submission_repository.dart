import 'teacher_submission_detail.dart';
import 'teacher_submission_list.dart';
import 'teacher_submission_list_query.dart';
import 'teacher_submission_review.dart';

abstract interface class TeacherSubmissionRepository {
  Future<TeacherSubmissionList> fetchSubmissions(
    TeacherSubmissionListQuery query,
  );

  Future<TeacherSubmissionDetail> fetchSubmission(String submissionId);

  Future<TeacherSubmissionDetail> saveReview(
    String submissionId,
    TeacherSubmissionReviewRequest request,
  );
}

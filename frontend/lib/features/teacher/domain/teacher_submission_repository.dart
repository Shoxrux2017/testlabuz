import 'teacher_submission_detail.dart';
import 'teacher_submission_list.dart';
import 'teacher_submission_list_query.dart';

abstract interface class TeacherSubmissionRepository {
  Future<TeacherSubmissionList> fetchSubmissions(
    TeacherSubmissionListQuery query,
  );

  Future<TeacherSubmissionDetail> fetchSubmission(String submissionId);
}

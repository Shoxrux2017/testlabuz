import 'package:testlabuz_client/features/teacher/domain/teacher_list_pagination.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_repository.dart';

const submissionId = '70000000-0000-0000-0000-000000000001';

/// A queue item as `GET /teacher/submissions` returns it; an official checked Homework by default.
Map<String, Object?> submissionJson({
  String id = submissionId,
  String status = 'checked',
  String type = 'homework',
  bool official = true,
  bool eligible = true,
  String reason = 'student_submit',
  num? earned = 15,
  num? normalized = 75,
  num possible = 20,
  String? reviewDueAt = '2026-10-02T13:00:00Z',
  bool overdue = false,
  int attemptNumber = 2,
  int waiting = 0,
  int reviewed = 2,
  String studentName = 'Aziza Karimova',
  String taskTitle = 'Equation practice',
}) {
  return {
    'id': id,
    'assessment': <String, Object?>{
      'id': '50000000-0000-0000-0000-000000000001',
      'type': type,
      'title': taskTitle,
    },
    'official': official,
    'topic': <String, Object?>{
      'id': '10000000-0000-0000-0000-000000000001',
      'title': 'Internet Basics',
    },
    'group': <String, Object?>{
      'id': '20000000-0000-0000-0000-000000000001',
      'name': '7-A',
    },
    'student': <String, Object?>{
      'id': '60000000-0000-0000-0000-000000000001',
      'full_name': studentName,
    },
    'attempt_number': attemptNumber,
    'status': status,
    'official_score_eligible': eligible,
    'finalization_reason': reason,
    'finalized_at': '2026-09-30T10:00:00Z',
    'review': <String, Object?>{
      'waiting_answers': waiting,
      'reviewed_answers': reviewed,
    },
    'review_due_at': reviewDueAt,
    'review_overdue': overdue,
    'score': <String, Object?>{
      'earned_points': earned,
      'possible_points': possible,
      'normalized_score': normalized,
    },
  };
}

Map<String, Object?> submissionListJson(
  List<Map<String, Object?>> rows, {
  int page = 1,
  int perPage = 25,
  int? total,
}) {
  final count = total ?? rows.length;
  return {
    'data': rows,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': perPage,
        'total': count,
        'last_page': count == 0 ? 1 : (count + perPage - 1) ~/ perPage,
      },
    },
  };
}

TeacherSubmission teacherSubmission({
  String id = submissionId,
  TeacherSubmissionStatus status = TeacherSubmissionStatus.checked,
  TeacherSubmissionTaskType taskType = TeacherSubmissionTaskType.homework,
  bool official = true,
  bool officialScoreEligible = true,
  int attemptNumber = 2,
  int waitingAnswers = 0,
  int reviewedAnswers = 2,
  DateTime? reviewDueAt,
  bool reviewOverdue = false,
  double? normalizedScore = 75,
  String studentName = 'Aziza Karimova',
  String taskTitle = 'Equation practice',
}) {
  final checked = status == TeacherSubmissionStatus.checked;
  return TeacherSubmission(
    id: id,
    assessmentId: '50000000-0000-0000-0000-000000000001',
    taskType: taskType,
    taskTitle: taskTitle,
    official: official,
    topicId: '10000000-0000-0000-0000-000000000001',
    topicTitle: 'Internet Basics',
    groupId: '20000000-0000-0000-0000-000000000001',
    groupName: '7-A',
    studentId: '60000000-0000-0000-0000-000000000001',
    studentName: studentName,
    attemptNumber: attemptNumber,
    status: status,
    officialScoreEligible: officialScoreEligible,
    finalizationReason: TeacherSubmissionFinalizationReason.studentSubmit,
    finalizedAt: DateTime.utc(2026, 9, 30, 10),
    waitingAnswers: waitingAnswers,
    reviewedAnswers: reviewedAnswers,
    reviewDueAt: reviewDueAt,
    reviewOverdue: reviewOverdue,
    earnedPoints: checked ? 15 : null,
    possiblePoints: 20,
    normalizedScore: checked ? normalizedScore : null,
  );
}

TeacherSubmissionList teacherSubmissionList(
  List<TeacherSubmission> items, {
  int page = 1,
  int perPage = 25,
  int? total,
}) {
  final count = total ?? items.length;
  return TeacherSubmissionList(
    items: items,
    pagination: TeacherListPagination(
      page: page,
      perPage: perPage,
      total: count,
      lastPage: count == 0 ? 1 : (count + perPage - 1) ~/ perPage,
    ),
  );
}

class FakeTeacherSubmissionRepository implements TeacherSubmissionRepository {
  FakeTeacherSubmissionRepository({this.onFetch});

  Future<TeacherSubmissionList> Function(TeacherSubmissionListQuery query)?
  onFetch;
  final queries = <TeacherSubmissionListQuery>[];

  @override
  Future<TeacherSubmissionList> fetchSubmissions(
    TeacherSubmissionListQuery query,
  ) {
    queries.add(query);
    return onFetch?.call(query) ??
        Future.value(teacherSubmissionList([teacherSubmission()]));
  }
}

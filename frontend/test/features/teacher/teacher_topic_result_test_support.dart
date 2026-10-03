import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_result_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_result_list_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_repository.dart';

const teacherResultTopicId = '10000000-0000-0000-0000-000000000001';
const teacherResultStudentId = '60000000-0000-0000-0000-000000000001';
const teacherResultHomeworkId = '50000000-0000-0000-0000-000000000001';
const teacherResultBlitzId = '80000000-0000-0000-0000-000000000001';
const teacherResultHomeworkAttemptId = '70000000-0000-0000-0000-000000000001';
const teacherResultBlitzAttemptId = '70000000-0000-0000-0000-000000000002';
const teacherResultActorId = '90000000-0000-0000-0000-000000000001';

const _understoodWell = {'code': 'understood_well', 'label': 'Understood well'};
const _notCompletedCategory = {
  'code': 'not_completed',
  'label': 'Not completed',
};

Map<String, Object?> teacherResultSideJson({
  String? assessmentId = teacherResultHomeworkId,
  String state = 'ready',
  String? attemptId = teacherResultHomeworkAttemptId,
  int? attemptNumber = 1,
  Object? score = 88,
}) {
  final ready = state == 'ready';
  return {
    'assessment_id': assessmentId,
    'state': state,
    'official_attempt_id': ready ? attemptId : null,
    'attempt_number': ready ? attemptNumber : null,
    'score': ready ? score : null,
  };
}

Map<String, Object?> teacherResultBlitzSideJson({
  String state = 'ready',
  int? attemptNumber = 1,
  Object? score = 84,
}) {
  return teacherResultSideJson(
    assessmentId: state == 'not_designated' ? null : teacherResultBlitzId,
    state: state,
    attemptId: teacherResultBlitzAttemptId,
    attemptNumber: attemptNumber,
    score: score,
  );
}

Map<String, Object?> teacherResultVisibilityJson({
  String? studentMode = 'manual_teacher',
  bool studentVisible = false,
  String? studentReleasedAt,
  bool canReleaseToStudent = true,
  String? parentMode = 'with_student',
  bool parentVisible = false,
  String? parentReleasedAt,
  bool canReleaseToParent = false,
}) {
  return {
    'student_release_mode': studentMode,
    'student_visible': studentVisible,
    'student_released_at': studentReleasedAt,
    'can_release_to_student': canReleaseToStudent,
    'parent_release_mode': parentMode,
    'parent_visible': parentVisible,
    'parent_released_at': parentReleasedAt,
    'can_release_to_parent': canReleaseToParent,
  };
}

/// The docs/09 §25.4 item: by default an open calculated result (H 88, B 84,
/// D 4, T 10, average 86, Understood well) that the Teacher can close.
Map<String, Object?> teacherTopicResultJson({
  String studentId = teacherResultStudentId,
  String fullName = 'Aziza Karimova',
  String status = 'calculated',
  String? closedOutcome,
  String? closedAt,
  String? missingComponent,
  Map<String, Object?>? homework,
  Map<String, Object?>? blitz,
  Object? scoreDifference = 4,
  Object? acceptableDifference = 10,
  String? consistency = 'consistent',
  String? method = 'average',
  Object? finalScore = 86,
  Object? categoryScore = 86,
  Object? category = _understoodWell,
  String? teacherComment,
  Map<String, Object?>? visibility,
  Object? canClose = true,
}) {
  return {
    'student': {'id': studentId, 'full_name': fullName},
    'result_status': status,
    'closed_outcome': closedOutcome,
    'closed_at': closedAt,
    'missing_component': missingComponent,
    'homework': homework ?? teacherResultSideJson(),
    'blitz': blitz ?? teacherResultBlitzSideJson(),
    'score_difference': scoreDifference,
    'acceptable_difference': acceptableDifference,
    'consistency': consistency,
    'calculation_method': method,
    'final_score': finalScore,
    'category_score': categoryScore,
    'category': category,
    'teacher_comment': teacherComment,
    'visibility': visibility ?? teacherResultVisibilityJson(),
    'can_close': canClose,
  };
}

/// An open calculated result whose scores differ by more than T: the final
/// score is the Blitz score.
Map<String, Object?> inconsistentTeacherTopicResultJson({
  String studentId = teacherResultStudentId,
}) {
  return teacherTopicResultJson(
    studentId: studentId,
    homework: teacherResultSideJson(score: 95),
    blitz: teacherResultBlitzSideJson(score: 60),
    scoreDifference: 35,
    consistency: 'inconsistent',
    method: 'blitz',
    finalScore: 60,
    categoryScore: 60,
    category: const {'code': 'needs_revision', 'label': 'Needs revision'},
  );
}

/// A result that still waits: no comparison, final score or category.
Map<String, Object?> waitingTeacherTopicResultJson({
  String studentId = teacherResultStudentId,
  String fullName = 'Aziza Karimova',
  String status = 'waiting_for_blitz',
  String homeworkState = 'ready',
  String blitzState = 'open',
}) {
  return teacherTopicResultJson(
    studentId: studentId,
    fullName: fullName,
    status: status,
    homework: teacherResultSideJson(state: homeworkState),
    blitz: teacherResultBlitzSideJson(state: blitzState),
    scoreDifference: null,
    acceptableDifference: null,
    consistency: null,
    method: null,
    finalScore: null,
    categoryScore: null,
    category: null,
    visibility: teacherResultVisibilityJson(canReleaseToStudent: false),
    canClose: false,
  );
}

/// A Not completed result, open or closed, whose [missing] sides are
/// `missing` and whose other side is ready.
Map<String, Object?> notCompletedTeacherTopicResultJson({
  String studentId = teacherResultStudentId,
  String missing = 'blitz',
  bool closed = false,
  String? closedAt = '2026-10-05T09:00:00Z',
  Map<String, Object?>? visibility,
}) {
  final homeworkMissing = missing == 'homework' || missing == 'both';
  final blitzMissing = missing == 'blitz' || missing == 'both';
  return teacherTopicResultJson(
    studentId: studentId,
    status: closed ? 'closed' : 'not_completed',
    closedOutcome: closed ? 'not_completed' : null,
    closedAt: closed ? closedAt : null,
    missingComponent: missing,
    homework: teacherResultSideJson(
      state: homeworkMissing ? 'missing' : 'ready',
    ),
    blitz: teacherResultBlitzSideJson(
      state: blitzMissing ? 'missing' : 'ready',
    ),
    scoreDifference: null,
    acceptableDifference: null,
    consistency: null,
    method: null,
    finalScore: null,
    categoryScore: null,
    category: _notCompletedCategory,
    visibility: visibility,
    canClose: !closed,
  );
}

/// A calculated result closed by the Teacher.
Map<String, Object?> closedCalculatedTeacherTopicResultJson({
  String studentId = teacherResultStudentId,
  Map<String, Object?>? visibility,
}) {
  return teacherTopicResultJson(
    studentId: studentId,
    status: 'closed',
    closedOutcome: 'calculated',
    closedAt: '2026-10-05T09:00:00Z',
    visibility:
        visibility ??
        teacherResultVisibilityJson(
          studentVisible: true,
          studentReleasedAt: '2026-10-04T08:00:00Z',
          canReleaseToStudent: false,
          parentVisible: true,
        ),
    canClose: false,
  );
}

/// The docs/09 §25.6 detail: [item] plus its actors and closure reason.
Map<String, Object?> teacherTopicResultDetailJson({
  Map<String, Object?>? item,
  String? commentUpdatedAt,
  Object? commentUpdatedBy,
  Object? studentReleasedBy,
  Object? parentReleasedBy,
  Object? closedBy,
  String? closureReason,
}) {
  return {
    ...item ?? teacherTopicResultJson(),
    'teacher_comment_updated_at': commentUpdatedAt,
    'teacher_comment_updated_by': commentUpdatedBy,
    'student_released_by': studentReleasedBy,
    'parent_released_by': parentReleasedBy,
    'closed_by': closedBy,
    'closure_reason': closureReason,
  };
}

Map<String, Object?> teacherResultActorJson({
  String id = teacherResultActorId,
  String fullName = 'Dilnoza Teacher',
}) {
  return {'id': id, 'full_name': fullName};
}

Map<String, Object?> teacherResultCountsJson({
  int waitingForHomework = 0,
  int waitingForBlitz = 0,
  int waitingForTeacherReview = 0,
  int waitingForSettings = 0,
  int calculated = 0,
  int notCompleted = 0,
  int closed = 0,
}) {
  return {
    'waiting_for_homework': waitingForHomework,
    'waiting_for_blitz': waitingForBlitz,
    'waiting_for_teacher_review': waitingForTeacherReview,
    'waiting_for_settings': waitingForSettings,
    'calculated': calculated,
    'not_completed': notCompleted,
    'closed': closed,
  };
}

/// One page of `GET /teacher/topics/{topic}/results`; by default one
/// calculated result and its count.
Map<String, Object?> teacherTopicResultListJson({
  List<Map<String, Object?>>? items,
  int page = 1,
  int perPage = 25,
  int? total,
  int? lastPage,
  Map<String, Object?>? counts,
}) {
  final rows = items ?? [teacherTopicResultJson()];
  final resolvedTotal = total ?? rows.length;
  return {
    'data': rows,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': perPage,
        'total': resolvedTotal,
        'last_page':
            lastPage ??
            (resolvedTotal == 0 ? 1 : (resolvedTotal + perPage - 1) ~/ perPage),
      },
      'counts': counts ?? teacherResultCountsJson(calculated: resolvedTotal),
    },
  };
}

TeacherTopicResult teacherTopicResult([Map<String, Object?>? json]) {
  return TeacherTopicResultDto.fromJson(
    json ?? teacherTopicResultJson(),
  ).toDomain();
}

TeacherTopicResultDetail teacherTopicResultDetail([
  Map<String, Object?>? json,
]) {
  return TeacherTopicResultDetailDto.fromJson(
    json ?? teacherTopicResultDetailJson(),
  ).toDomain();
}

TeacherTopicResultList teacherTopicResultList({
  List<Map<String, Object?>>? items,
  TeacherTopicResultListQuery query = const TeacherTopicResultListQuery(),
  int? total,
  Map<String, Object?>? counts,
}) {
  return TeacherTopicResultListDto.fromJson(
    teacherTopicResultListJson(
      items: items,
      page: query.page,
      perPage: TeacherTopicResultListQuery.perPage,
      total: total,
      counts: counts,
    ),
    query: query,
  ).toDomain();
}

TeacherTopicResultList emptyTeacherTopicResultList({
  TeacherTopicResultListQuery query = const TeacherTopicResultListQuery(),
}) {
  return teacherTopicResultList(
    items: const [],
    query: query,
    counts: teacherResultCountsJson(),
  );
}

class FakeTeacherTopicResultRepository implements TeacherTopicResultRepository {
  FakeTeacherTopicResultRepository({this.onFetchResults, this.onFetchResult});

  Future<TeacherTopicResultList> Function(
    String topicId,
    TeacherTopicResultListQuery query,
  )?
  onFetchResults;
  Future<TeacherTopicResultDetail> Function(String topicId, String studentId)?
  onFetchResult;
  final listRequests =
      <({String topicId, TeacherTopicResultListQuery query})>[];
  final detailRequests = <({String topicId, String studentId})>[];

  @override
  Future<TeacherTopicResultList> fetchResults(
    String topicId,
    TeacherTopicResultListQuery query,
  ) {
    listRequests.add((topicId: topicId, query: query));
    return onFetchResults?.call(topicId, query) ??
        Future.value(emptyTeacherTopicResultList(query: query));
  }

  @override
  Future<TeacherTopicResultDetail> fetchResult(
    String topicId,
    String studentId,
  ) {
    detailRequests.add((topicId: topicId, studentId: studentId));
    return onFetchResult?.call(topicId, studentId) ??
        Future.value(
          teacherTopicResultDetail(
            teacherTopicResultDetailJson(
              item: teacherTopicResultJson(studentId: studentId),
            ),
          ),
        );
  }
}

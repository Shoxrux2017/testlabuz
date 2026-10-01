import 'package:testlabuz_client/features/teacher/data/dto/teacher_submission_detail_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_list_pagination.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_detail.dart';
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

  Future<TeacherSubmissionDetail> Function(String submissionId)? onFetchDetail;
  final detailIds = <String>[];

  @override
  Future<TeacherSubmissionDetail> fetchSubmission(String submissionId) {
    detailIds.add(submissionId);
    return onFetchDetail?.call(submissionId) ??
        Future.value(
          TeacherSubmissionDetailDto.fromJson(
            submissionDetailJson(),
          ).toDomain(),
        );
  }

  @override
  Future<TeacherSubmissionList> fetchSubmissions(
    TeacherSubmissionListQuery query,
  ) {
    queries.add(query);
    return onFetch?.call(query) ??
        Future.value(teacherSubmissionList([teacherSubmission()]));
  }
}

// ---------------------------------------------------------------------------
// Submission detail fixtures (S09-FE-003A).

const detailTeacherId = '30000000-0000-0000-0000-000000000001';
const detailFileId = '90000000-0000-0000-0000-000000000001';

String detailId(int n) =>
    'a0000000-0000-0000-0000-${n.toString().padLeft(12, '0')}';

Map<String, Object?> _detailQuestion(
  int position,
  String type,
  num points,
  String mode,
  Map<String, Object?> configuration, {
  String? prompt,
}) {
  return <String, Object?>{
    'id': detailId(100 + position),
    'type': type,
    'position': position,
    'prompt': prompt ?? 'Question $position prompt',
    'points': points,
    'checking_mode': mode,
    'configuration': configuration,
  };
}

Map<String, Object?> _detailAnswer(
  int position,
  Map<String, Object?> value, {
  String status = 'auto_checked',
  num? awarded,
  String? feedback,
  bool reviewed = false,
}) {
  final checked = status == 'auto_checked' || status == 'teacher_checked';
  return <String, Object?>{
    'id': detailId(200 + position),
    'value': value,
    'checking_status': status,
    'awarded_points': checked ? awarded : null,
    'feedback': feedback,
    'checked_by': reviewed
        ? <String, Object?>{
            'id': detailTeacherId,
            'full_name': 'Dilnoza Teacher',
          }
        : null,
    'checked_at': checked ? '2026-09-30T11:00:00Z' : null,
  };
}

/// Every question type once, with an unanswered open question at the end.
/// The submission waits for review: Q5 is reviewed and Q6 (a file) waits.
List<Map<String, Object?>> submissionDetailQuestions() {
  return [
    <String, Object?>{
      'question': _detailQuestion(
        1,
        'single_choice',
        1,
        'automatic',
        <String, Object?>{
          'options': [
            <String, Object?>{
              'id': detailId(1),
              'text': 'Paris',
              'is_correct': true,
              'position': 1,
            },
            <String, Object?>{
              'id': detailId(2),
              'text': 'Rome',
              'is_correct': false,
              'position': 2,
            },
          ],
        },
      ),
      'answer': _detailAnswer(1, <String, Object?>{
        'selected_option_ids': [detailId(1)],
      }, awarded: 1),
    },
    <String, Object?>{
      'question': _detailQuestion(
        2,
        'multiple_choice',
        1,
        'automatic',
        <String, Object?>{
          'options': [
            <String, Object?>{
              'id': detailId(3),
              'text': 'TCP',
              'is_correct': true,
              'position': 1,
            },
            <String, Object?>{
              'id': detailId(4),
              'text': 'UDP',
              'is_correct': true,
              'position': 2,
            },
            <String, Object?>{
              'id': detailId(5),
              'text': 'HTML',
              'is_correct': false,
              'position': 3,
            },
          ],
        },
      ),
      'answer': _detailAnswer(2, <String, Object?>{
        'selected_option_ids': [detailId(3)],
      }, awarded: 0.5),
    },
    <String, Object?>{
      'question': _detailQuestion(
        3,
        'true_false',
        1,
        'automatic',
        <String, Object?>{'correct_value': false},
      ),
      'answer': _detailAnswer(3, <String, Object?>{'value': true}, awarded: 0),
    },
    <String, Object?>{
      'question': _detailQuestion(
        4,
        'short_written',
        1,
        'automatic',
        <String, Object?>{
          'accepted_answers': ['DNS', 'Domain Name System'],
        },
      ),
      'answer': _detailAnswer(4, <String, Object?>{'text': 'dns'}, awarded: 1),
    },
    <String, Object?>{
      'question': _detailQuestion(
        5,
        'open_written',
        3,
        'manual',
        <String, Object?>{},
      ),
      'answer': _detailAnswer(
        5,
        <String, Object?>{'text': 'An essay about DNS.'},
        status: 'teacher_checked',
        awarded: 2.5,
        feedback: 'Good start.',
        reviewed: true,
      ),
    },
    <String, Object?>{
      'question': _detailQuestion(
        6,
        'file_based',
        2,
        'manual',
        <String, Object?>{
          'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
        },
      ),
      'answer': _detailAnswer(6, <String, Object?>{
        'file': <String, Object?>{
          'id': detailFileId,
          'original_name': 'report.pdf',
          'extension': 'pdf',
          'size_bytes': 2048,
        },
      }, status: 'waiting_for_teacher_review'),
    },
    <String, Object?>{
      'question': _detailQuestion(
        7,
        'matching',
        2,
        'automatic',
        <String, Object?>{
          'pairs': [
            <String, Object?>{
              'client_key': detailId(10),
              'left': 'HTTP',
              'right': 'Web',
              'left_item_id': detailId(11),
              'right_item_id': detailId(12),
            },
            <String, Object?>{
              'client_key': detailId(13),
              'left': 'SMTP',
              'right': 'Mail',
              'left_item_id': detailId(14),
              'right_item_id': detailId(15),
            },
          ],
        },
      ),
      'answer': _detailAnswer(7, <String, Object?>{
        'pairs': [
          <String, Object?>{
            'left_item_id': detailId(11),
            'right_item_id': detailId(15),
          },
        ],
      }, awarded: 0),
    },
    <String, Object?>{
      'question': _detailQuestion(
        8,
        'ordering',
        1,
        'automatic',
        <String, Object?>{
          'items': [
            <String, Object?>{
              'id': detailId(20),
              'text': 'Plan',
              'correct_position': 1,
            },
            <String, Object?>{
              'id': detailId(21),
              'text': 'Build',
              'correct_position': 2,
            },
          ],
        },
      ),
      'answer': _detailAnswer(8, <String, Object?>{
        'items': [
          <String, Object?>{'item_id': detailId(21), 'position': 1},
          <String, Object?>{'item_id': detailId(20), 'position': 2},
        ],
      }, awarded: 0),
    },
    <String, Object?>{
      'question': _detailQuestion(
        9,
        'fill_in_blank',
        1,
        'automatic',
        <String, Object?>{
          'blanks': [
            <String, Object?>{
              'id': detailId(30),
              'key': 'proto',
              'position': 1,
              'accepted_answers': ['HTTP'],
            },
          ],
        },
        prompt: 'The {{proto}} protocol',
      ),
      'answer': _detailAnswer(9, <String, Object?>{
        'values': [
          <String, Object?>{'blank_id': detailId(30), 'text': 'http'},
        ],
      }, awarded: 1),
    },
    <String, Object?>{
      'question': _detailQuestion(
        10,
        'open_written',
        1,
        'manual',
        <String, Object?>{},
      ),
      'answer': null,
    },
  ];
}

/// `GET /teacher/submissions/{id}` data: a Homework waiting for review.
Map<String, Object?> submissionDetailJson({
  List<Map<String, Object?>>? questions,
  String status = 'waiting_for_teacher_review',
  int waiting = 1,
  int reviewed = 1,
  String? submittedAt = '2026-09-30T10:00:00Z',
}) {
  final item = submissionJson(
    status: status,
    earned: null,
    normalized: null,
    possible: 14,
    waiting: waiting,
    reviewed: reviewed,
  );
  return <String, Object?>{
    ...item,
    'submitted_at': submittedAt,
    'questions': questions ?? submissionDetailQuestions(),
  };
}

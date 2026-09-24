import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';

const blitzJsonTopicId = '10000000-0000-0000-0000-000000000001';
const blitzJsonGroupId = '00000000-0000-0000-0000-000000000001';
const blitzJsonId = '80000000-0000-0000-0000-000000000001';
const blitzJsonDurationSeconds = 600;
const blitzJsonScheduledAt = '2026-09-18T04:00:00Z';
const blitzJsonActivatedAt = '2026-09-18T04:01:00Z';
const blitzJsonSynchronizedEndsAt = '2026-09-18T04:11:00Z';
const blitzJsonClosedAt = '2026-09-18T04:12:00Z';
const blitzJsonArchivedAt = '2026-09-18T05:00:00Z';

/// A canonical full Teacher Blitz resource for [status].
///
/// Activated shapes use [timerMode]; `archivedBeforeActivation` selects the
/// preactivation archive shape instead of the post-close archive shape.
Map<String, Object?> teacherBlitzJson({
  TeacherBlitzStatus status = TeacherBlitzStatus.draft,
  TeacherBlitzTimerStartMode timerMode =
      TeacherBlitzTimerStartMode.synchronized,
  bool archivedBeforeActivation = false,
  List<Object?>? questions,
}) {
  final activated = switch (status) {
    TeacherBlitzStatus.draft || TeacherBlitzStatus.scheduled => false,
    TeacherBlitzStatus.active || TeacherBlitzStatus.closed => true,
    TeacherBlitzStatus.archived => !archivedBeforeActivation,
  };
  final closed =
      status == TeacherBlitzStatus.closed ||
      (status == TeacherBlitzStatus.archived && activated);

  return {
    'id': blitzJsonId,
    'topic_id': blitzJsonTopicId,
    'group_id': blitzJsonGroupId,
    'title': 'Equation Blitz',
    'description': null,
    'student_instructions': 'Answer quickly and carefully.',
    'assignment_mode': 'group',
    'student_ids': <Object?>[],
    'total_possible_points': 18.5,
    'duration_seconds': blitzJsonDurationSeconds,
    'scheduled_at': status == TeacherBlitzStatus.draft
        ? null
        : blitzJsonScheduledAt,
    'institution_timezone': 'Asia/Tashkent',
    'status': status.value,
    'timer_start_mode_snapshot': activated ? timerMode.value : null,
    'attempt_policy': {
      'normal_attempts': 1,
      'max_additional_exception_attempts': 1,
    },
    'activated_at': activated ? blitzJsonActivatedAt : null,
    'synchronized_ends_at':
        activated && timerMode == TeacherBlitzTimerStartMode.synchronized
        ? blitzJsonSynchronizedEndsAt
        : null,
    'closed_at': closed ? blitzJsonClosedAt : null,
    'archived_at': status == TeacherBlitzStatus.archived
        ? blitzJsonArchivedAt
        : null,
    'created_at': '2026-09-17T10:00:00Z',
    'updated_at': '2026-09-17T11:00:00Z',
    'questions': questions ?? teacherBlitzAllQuestionsJson(),
  };
}

Map<String, Object?> teacherBlitzSummaryJson({
  String id = blitzJsonId,
  String topicId = blitzJsonTopicId,
  String status = 'draft',
  Object? scheduledAt,
}) {
  return {
    'id': id,
    'topic_id': topicId,
    'group_id': blitzJsonGroupId,
    'title': 'Equation Blitz',
    'assignment_mode': 'group',
    'total_possible_points': 18.5,
    'question_count': 9,
    'duration_seconds': blitzJsonDurationSeconds,
    'scheduled_at': scheduledAt,
    'institution_timezone': 'Asia/Tashkent',
    'status': status,
    'created_at': '2026-09-17T10:00:00Z',
    'updated_at': '2026-09-17T11:00:00Z',
  };
}

Map<String, Object?> teacherBlitzListJson(
  List<Object?> rows, {
  int page = 1,
  int perPage = 20,
  int? total,
  int? lastPage,
}) {
  final resolvedTotal = total ?? rows.length;
  return <String, Object?>{
    'data': rows,
    'meta': <String, Object?>{
      'pagination': <String, Object?>{
        'page': page,
        'per_page': perPage,
        'total': resolvedTotal,
        'last_page':
            lastPage ??
            (resolvedTotal == 0 ? 1 : (resolvedTotal + perPage - 1) ~/ perPage),
      },
    },
  };
}

/// One Teacher Question resource of every type, in canonical positions.
List<Object?> teacherBlitzAllQuestionsJson() {
  return [
    for (var index = 0; index < TeacherQuestionType.values.length; index += 1)
      teacherBlitzQuestionJson(TeacherQuestionType.values[index], index + 1),
  ];
}

Map<String, Object?> teacherBlitzQuestionJson(
  TeacherQuestionType type,
  int position,
) {
  final checkingMode = switch (type) {
    TeacherQuestionType.openWritten ||
    TeacherQuestionType.fileBased => 'manual',
    _ => 'automatic',
  };
  final prompt = type == TeacherQuestionType.fillInBlank
      ? 'The capital is {{capital}}.'
      : 'Blitz prompt $position';
  final configuration = switch (type) {
    TeacherQuestionType.singleChoice => {
      'options': [
        {'text': 'A', 'is_correct': true, 'position': 1},
        {'text': 'B', 'is_correct': false, 'position': 2},
      ],
    },
    TeacherQuestionType.multipleChoice => {
      'options': [
        {'text': 'A', 'is_correct': true, 'position': 1},
        {'text': 'B', 'is_correct': true, 'position': 2},
      ],
    },
    TeacherQuestionType.trueFalse => {'correct_value': true},
    TeacherQuestionType.shortWritten => {
      'accepted_answers': ['Answer', 'Alternate'],
    },
    TeacherQuestionType.openWritten => <String, Object?>{},
    TeacherQuestionType.fileBased => {
      'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
    },
    TeacherQuestionType.matching => {
      'pairs': [
        {
          'client_key': '40000000-0000-0000-0000-000000000001',
          'left': 'Left',
          'right': 'Right',
        },
      ],
    },
    TeacherQuestionType.ordering => {
      'items': [
        {'text': 'First', 'correct_position': 1},
        {'text': 'Second', 'correct_position': 2},
      ],
    },
    TeacherQuestionType.fillInBlank => {
      'blanks': [
        {
          'key': 'capital',
          'position': 1,
          'accepted_answers': ['Tashkent'],
        },
      ],
    },
  };
  return {
    'id': '90000000-0000-0000-0000-${position.toString().padLeft(12, '0')}',
    'type': type.value,
    'prompt': prompt,
    'instructions': position.isEven ? null : 'Read carefully.',
    'points': position == 1 ? 0 : 2.5,
    'position': position,
    'checking_mode': checkingMode,
    'configuration': configuration,
  };
}

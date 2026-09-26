import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_lifecycle.dart';

import 'teacher_test_support.dart';

const _group = TeacherBlitzAssignmentMode.group;
const _selected = TeacherBlitzAssignmentMode.selectedStudents;

void main() {
  group('lifecycle action projection', () {
    test(
      'Draft and Scheduled offer Schedule, Activate and practice Archive',
      () {
        for (final status in [
          TeacherBlitzStatus.draft,
          TeacherBlitzStatus.scheduled,
        ]) {
          expect(
            teacherBlitzLifecycleActions(
              teacherBlitz(status: status),
              official: TeacherBlitzOfficialKnowledge.notOfficial,
            ),
            [
              TeacherBlitzLifecycleAction.schedule,
              TeacherBlitzLifecycleAction.activate,
              TeacherBlitzLifecycleAction.archive,
            ],
            reason: status.value,
          );
        }
      },
    );

    test('Active offers only Close; Closed only Archive; Archived none', () {
      expect(
        teacherBlitzLifecycleActions(
          teacherBlitz(status: TeacherBlitzStatus.active),
          official: TeacherBlitzOfficialKnowledge.official,
        ),
        [TeacherBlitzLifecycleAction.close],
      );
      for (final official in TeacherBlitzOfficialKnowledge.values) {
        expect(
          teacherBlitzLifecycleActions(
            teacherBlitz(status: TeacherBlitzStatus.closed),
            official: official,
          ),
          [TeacherBlitzLifecycleAction.archive],
        );
        expect(
          teacherBlitzLifecycleActions(
            teacherBlitz(status: TeacherBlitzStatus.archived),
            official: official,
          ),
          isEmpty,
        );
      }
    });
  });

  group('preparation Archive visibility', () {
    TeacherBlitz blitz(
      TeacherBlitzStatus status,
      TeacherBlitzAssignmentMode mode,
    ) {
      return teacherBlitz(status: status, assignmentMode: mode);
    }

    bool showsArchive(
      TeacherBlitz blitz,
      TeacherBlitzOfficialKnowledge official,
    ) {
      return teacherBlitzLifecycleActions(
        blitz,
        official: official,
      ).contains(TeacherBlitzLifecycleAction.archive);
    }

    test('selected-Student Draft/Scheduled can always be archived', () {
      for (final status in [
        TeacherBlitzStatus.draft,
        TeacherBlitzStatus.scheduled,
      ]) {
        for (final official in TeacherBlitzOfficialKnowledge.values) {
          expect(showsArchive(blitz(status, _selected), official), isTrue);
        }
      }
    });

    test('group Draft/Scheduled needs confirmed non-official status', () {
      for (final status in [
        TeacherBlitzStatus.draft,
        TeacherBlitzStatus.scheduled,
      ]) {
        expect(
          showsArchive(
            blitz(status, _group),
            TeacherBlitzOfficialKnowledge.notOfficial,
          ),
          isTrue,
        );
        expect(
          showsArchive(
            blitz(status, _group),
            TeacherBlitzOfficialKnowledge.official,
          ),
          isFalse,
        );
        expect(
          showsArchive(
            blitz(status, _group),
            TeacherBlitzOfficialKnowledge.unconfirmed,
          ),
          isFalse,
        );
      }
    });

    test('Active is never archived; Closed always is', () {
      expect(
        showsArchive(
          blitz(TeacherBlitzStatus.active, _selected),
          TeacherBlitzOfficialKnowledge.notOfficial,
        ),
        isFalse,
      );
      expect(
        showsArchive(
          blitz(TeacherBlitzStatus.closed, _group),
          TeacherBlitzOfficialKnowledge.official,
        ),
        isTrue,
      );
    });
  });

  group('activation acceptance', () {
    test('a fresh send accepts only a confirmed Active activation', () {
      expect(
        isAcceptedTeacherBlitzActivation(
          teacherBlitz(status: TeacherBlitzStatus.active),
          TeacherBlitzActivationSendKind.initialSend,
        ),
        isTrue,
      );
      for (final status in [
        TeacherBlitzStatus.draft,
        TeacherBlitzStatus.scheduled,
        TeacherBlitzStatus.closed,
        TeacherBlitzStatus.archived,
      ]) {
        expect(
          isAcceptedTeacherBlitzActivation(
            teacherBlitz(status: status),
            TeacherBlitzActivationSendKind.initialSend,
          ),
          isFalse,
          reason: status.value,
        );
      }
    });

    test('a same-key replay accepts the current post-activation lifecycle', () {
      for (final status in [
        TeacherBlitzStatus.active,
        TeacherBlitzStatus.closed,
        TeacherBlitzStatus.archived,
      ]) {
        expect(
          isAcceptedTeacherBlitzActivation(
            teacherBlitz(status: status),
            TeacherBlitzActivationSendKind.sameKeyRetry,
          ),
          isTrue,
          reason: status.value,
        );
      }
      final activated = teacherBlitz(status: TeacherBlitzStatus.active);
      for (final blitz in [
        _withStatus(activated, TeacherBlitzStatus.draft),
        _withStatus(activated, TeacherBlitzStatus.scheduled),
        teacherBlitz(
          status: TeacherBlitzStatus.archived,
          archivedBeforeActivation: true,
        ),
      ]) {
        expect(
          isAcceptedTeacherBlitzActivation(
            blitz,
            TeacherBlitzActivationSendKind.sameKeyRetry,
          ),
          isFalse,
          reason: blitz.status.value,
        );
      }
    });
  });
}

/// A Blitz carrying activation evidence under another lifecycle status.
TeacherBlitz _withStatus(TeacherBlitz source, TeacherBlitzStatus status) {
  return TeacherBlitz(
    id: source.id,
    topicId: source.topicId,
    groupId: source.groupId,
    title: source.title,
    description: source.description,
    studentInstructions: source.studentInstructions,
    assignmentMode: source.assignmentMode,
    studentIds: source.studentIds,
    totalPossiblePoints: source.totalPossiblePoints,
    durationSeconds: source.durationSeconds,
    scheduledAt: source.scheduledAt,
    institutionTimezone: source.institutionTimezone,
    status: status,
    timerStartModeSnapshot: source.timerStartModeSnapshot,
    attemptPolicy: source.attemptPolicy,
    activatedAt: source.activatedAt,
    synchronizedEndsAt: source.synchronizedEndsAt,
    closedAt: source.closedAt,
    archivedAt: source.archivedAt,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
    questions: source.questions,
  );
}

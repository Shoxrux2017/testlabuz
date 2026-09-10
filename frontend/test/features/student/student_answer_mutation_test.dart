import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

void main() {
  test(
    'initialization retains no fabricated answer and all safe blank fields',
    () {
      for (final type in StudentQuestionType.values.where(
        (type) => type != StudentQuestionType.fileBased,
      )) {
        final question = _question(type);
        final draft = StudentAnswerDraft.fromAnswer(question, null);
        expect(draft.type, type);
        expect(draft.isDirty(question, null), isFalse);
        expect(
          draft.canClear,
          type != StudentQuestionType.singleChoice &&
              type != StudentQuestionType.trueFalse,
        );
        if (draft is StudentFillBlankDraft) {
          expect(draft.blankTextById, {_id(1): '', _id(2): '', _id(3): ''});
        }
      }
    },
  );

  test('single sends one safe ID, requires selection and never clears', () {
    final question = _question(StudentQuestionType.singleChoice);
    final draft = StudentSingleChoiceDraft(selectedOptionId: _id(2));
    expect(draft.validate(question), isNull);
    expect(draft.toMutation(question).toJson(), {
      'type': 'single_choice',
      'selected_option_ids': [_id(2)],
    });
    expect(const StudentSingleChoiceDraft().validate(question), isNotNull);
    expect(
      StudentSingleChoiceDraft(selectedOptionId: _id(99)).validate(question),
      isNotNull,
    );
    expect(() => draft.clear(question), throwsStateError);
    expect(
      draft.isDirty(
        question,
        StudentChoiceAnswerValue(selectedOptionIds: [_id(2)]),
      ),
      isFalse,
    );
  });

  test(
    'multiple canonicalizes display order, enforces cap and supports clear',
    () {
      final question = _question(StudentQuestionType.multipleChoice);
      final draft = StudentMultipleChoiceDraft(
        selectedOptionIds: {_id(3), _id(1)},
      );
      expect(draft.toMutation(question).toJson(), {
        'type': 'multiple_choice',
        'selected_option_ids': [_id(1), _id(3)],
      });
      expect(
        draft.isDirty(
          question,
          StudentChoiceAnswerValue(selectedOptionIds: [_id(3), _id(1)]),
        ),
        isFalse,
      );
      final clear = draft.clear(question);
      expect(clear.toMutation(question).toJson(), {
        'type': 'multiple_choice',
        'selected_option_ids': <String>[],
      });
      expect(clear.isDirty(question, null), isFalse);
      expect(
        StudentMultipleChoiceDraft(
          selectedOptionIds: {_id(1), _id(2), _id(3)},
        ).validate(question),
        isNotNull,
      );
      expect(
        StudentMultipleChoiceDraft(
          selectedOptionIds: {_id(99)},
        ).validate(question),
        isNotNull,
      );
    },
  );

  test('true and false serialize exact booleans, with no nullable clear', () {
    final question = _question(StudentQuestionType.trueFalse);
    for (final value in [true, false]) {
      final draft = StudentTrueFalseDraft(value: value);
      expect(draft.toMutation(question).toJson(), {
        'type': 'true_false',
        'value': value,
      });
      expect(
        draft.isDirty(question, StudentBooleanAnswerValue(value: value)),
        isFalse,
      );
      expect(() => draft.clear(question), throwsStateError);
    }
    expect(const StudentTrueFalseDraft().validate(question), isNotNull);
  });

  for (final type in [
    StudentQuestionType.shortWritten,
    StudentQuestionType.openWritten,
  ]) {
    test(
      '${type.apiValue} preserves exact text, whitespace and Unicode scalars',
      () {
        final question = _question(type);
        final maximum = type == StudentQuestionType.shortWritten ? 1000 : 20000;
        for (final text in ['  Exact Student TEXT\n🙂 ', ' \t\n', '']) {
          final draft = _written(type, text);
          expect(draft.toMutation(question).toJson(), {
            'type': type.apiValue,
            'text': text,
          });
          final restored = StudentAnswerDraft.fromMutation(
            question,
            draft.toMutation(question),
          );
          expect(restored.toMutation(question).toJson()['text'], text);
          expect(draft.isDirty(question, null), text.trim().isNotEmpty);
          expect(
            draft.isDirty(
              question,
              const StudentTextAnswerValue(text: 'saved'),
            ),
            isTrue,
          );
        }
        expect(_written(type, '🙂' * maximum).validate(question), isNull);
        expect(
          _written(type, '🙂' * (maximum + 1)).validate(question),
          isNotNull,
        );
        expect(
          _written(
            type,
            'Exact ',
          ).isDirty(question, const StudentTextAnswerValue(text: 'Exact')),
          isTrue,
        );
        expect(
          _written(
            type,
            'Exact ',
          ).isDirty(question, const StudentTextAnswerValue(text: 'Exact ')),
          isFalse,
        );
        expect(
          _written(type, 'saved').clear(question).isDirty(question, null),
          isFalse,
        );
      },
    );
  }

  test(
    'matching uses left display order, preserves partial and validates sides',
    () {
      final question = _question(StudentQuestionType.matching);
      final draft = StudentMatchingDraft(
        leftToRight: {_id(3): _id(5), _id(1): _id(6)},
      );
      expect(draft.toMutation(question).toJson(), {
        'type': 'matching',
        'pairs': [
          {'left_item_id': _id(1), 'right_item_id': _id(6)},
          {'left_item_id': _id(3), 'right_item_id': _id(5)},
        ],
      });
      expect(
        draft.isDirty(
          question,
          StudentMatchingAnswerValue(
            pairs: [
              StudentMatchingAnswerPair(
                leftItemId: _id(3),
                rightItemId: _id(5),
              ),
              StudentMatchingAnswerPair(
                leftItemId: _id(1),
                rightItemId: _id(6),
              ),
            ],
          ),
        ),
        isFalse,
      );
      expect(draft.clear(question).toMutation(question).toJson(), {
        'type': 'matching',
        'pairs': <Object?>[],
      });
      for (final pairs in [
        {_id(1): _id(4), _id(2): _id(4)},
        {_id(4): _id(1)},
        {_id(1): _id(99)},
      ]) {
        final invalid = StudentMatchingDraft(leftToRight: pairs);
        expect(invalid.validate(question), isNotNull);
        expect(invalid.isDirty(question, null), isTrue);
        expect(() => invalid.toMutation(question), throwsArgumentError);
      }
    },
  );

  test(
    'ordering sorts by position and supports partial, empty, unique range',
    () {
      final question = _question(StudentQuestionType.ordering);
      final draft = StudentOrderingDraft(
        itemToPosition: {_id(1): 3, _id(3): 1},
      );
      expect(draft.toMutation(question).toJson(), {
        'type': 'ordering',
        'items': [
          {'item_id': _id(3), 'position': 1},
          {'item_id': _id(1), 'position': 3},
        ],
      });
      expect(
        draft.isDirty(
          question,
          StudentOrderingAnswerValue(
            items: [
              StudentOrderingAnswerItem(itemId: _id(1), position: 3),
              StudentOrderingAnswerItem(itemId: _id(3), position: 1),
            ],
          ),
        ),
        isFalse,
      );
      expect(draft.clear(question).toMutation(question).toJson(), {
        'type': 'ordering',
        'items': <Object?>[],
      });
      for (final positions in [
        {_id(1): 1, _id(2): 1},
        {_id(1): 0},
        {_id(1): 4},
        {_id(99): 1},
      ]) {
        final invalid = StudentOrderingDraft(itemToPosition: positions);
        expect(invalid.validate(question), isNotNull);
        expect(invalid.isDirty(question, null), isTrue);
        expect(() => invalid.toMutation(question), throwsArgumentError);
      }
    },
  );

  test(
    'fill uses blank positions, omits whitespace and keeps exact partial text',
    () {
      final question = _question(StudentQuestionType.fillInBlank);
      final draft = StudentFillBlankDraft(
        blankTextById: {
          _id(3): ' third ',
          _id(1): ' First 🙂 ',
          _id(2): ' \t\n',
        },
      );
      expect(draft.toMutation(question).toJson(), {
        'type': 'fill_in_blank',
        'values': [
          {'blank_id': _id(1), 'text': ' First 🙂 '},
          {'blank_id': _id(3), 'text': ' third '},
        ],
      });
      expect(
        draft.isDirty(
          question,
          StudentFillBlankAnswerValue(
            values: [
              StudentFillBlankAnswerEntry(blankId: _id(3), text: ' third '),
              StudentFillBlankAnswerEntry(blankId: _id(1), text: ' First 🙂 '),
            ],
          ),
        ),
        isFalse,
      );
      expect(draft.clear(question).toMutation(question).toJson(), {
        'type': 'fill_in_blank',
        'values': <Object?>[],
      });
      expect(
        StudentFillBlankDraft(
          blankTextById: {_id(1): ' ' * 1001},
        ).validate(question),
        isNull,
      );
      expect(
        StudentFillBlankDraft(
          blankTextById: {_id(1): '🙂' * 1000},
        ).validate(question),
        isNull,
      );
      expect(
        StudentFillBlankDraft(
          blankTextById: {_id(1): '🙂' * 1001},
        ).validate(question),
        isNotNull,
      );
      expect(
        StudentFillBlankDraft(
          blankTextById: {_id(99): 'answer'},
        ).validate(question),
        isNotNull,
      );
      expect(
        StudentFillBlankDraft(
          blankTextById: {_id(1): ' \n'},
        ).isDirty(question, null),
        isFalse,
      );
    },
  );

  test('draft and mutation collections are immutable snapshots', () {
    final ids = {_id(1)};
    final draft = StudentMultipleChoiceDraft(selectedOptionIds: ids);
    ids.add(_id(2));
    final mutation =
        draft.toMutation(_question(StudentQuestionType.multipleChoice))
            as StudentMultipleChoiceMutation;
    expect(draft.selectedOptionIds, {_id(1)});
    expect(() => draft.selectedOptionIds.add(_id(2)), throwsUnsupportedError);
    expect(
      () => mutation.selectedOptionIds.add(_id(2)),
      throwsUnsupportedError,
    );
    final positions = {_id(1): 2};
    final ordering = StudentOrderingDraft(itemToPosition: positions);
    positions[_id(1)] = 3;
    expect(ordering.itemToPosition, {_id(1): 2});
    expect(() => ordering.itemToPosition[_id(2)] = 1, throwsUnsupportedError);
  });

  test(
    'pending mutation restoration retains intent removed from new safe UI',
    () {
      final question = _question(StudentQuestionType.multipleChoice);
      final pending = StudentMultipleChoiceMutation(
        selectedOptionIds: [_id(99)],
      );
      final draft = StudentAnswerDraft.fromMutation(question, pending);
      expect((draft as StudentMultipleChoiceDraft).selectedOptionIds, {
        _id(99),
      });
      expect(draft.isDirty(question, null), isTrue);
      expect(draft.validate(question), isNotNull);
    },
  );

  test('answer type mismatch is invalid and file has no editor draft', () {
    final question = _question(StudentQuestionType.trueFalse);
    expect(
      const StudentShortWrittenDraft(text: 'text').validate(question),
      isNotNull,
    );
    expect(
      const StudentShortWrittenDraft(text: 'text').isDirty(question, null),
      isTrue,
    );
    expect(
      () => StudentAnswerDraft.fromAnswer(
        _question(StudentQuestionType.fileBased),
        null,
      ),
      throwsArgumentError,
    );
  });

  test(
    'saved child removed from current question remains invalid draft intent',
    () {
      final question = _question(StudentQuestionType.singleChoice);
      final draft = StudentAnswerDraft.fromAnswer(
        question,
        StudentChoiceAnswerValue(selectedOptionIds: [_id(99)]),
      );
      expect((draft as StudentSingleChoiceDraft).selectedOptionId, _id(99));
      expect(draft.validate(question), isNotNull);
    },
  );
}

StudentAnswerDraft _written(StudentQuestionType type, String text) =>
    type == StudentQuestionType.shortWritten
    ? StudentShortWrittenDraft(text: text)
    : StudentOpenWrittenDraft(text: text);

StudentQuestion _question(StudentQuestionType type) => StudentQuestion(
  id: _id(50),
  type: type,
  prompt: 'Question',
  instructions: null,
  points: 1,
  position: 1,
  answerUi: switch (type) {
    StudentQuestionType.singleChoice ||
    StudentQuestionType.multipleChoice => StudentChoiceAnswerUi(
      options: [
        for (var id = 1; id <= 3; id++)
          StudentChoiceOption(id: _id(id), text: 'Option $id'),
      ],
      maxSelections: type == StudentQuestionType.multipleChoice ? 2 : null,
    ),
    StudentQuestionType.matching => StudentMatchingAnswerUi(
      leftItems: [
        for (var id = 1; id <= 3; id++)
          StudentMatchingItem(id: _id(id), text: 'Left $id'),
      ],
      rightItems: [
        for (var id = 4; id <= 6; id++)
          StudentMatchingItem(id: _id(id), text: 'Right $id'),
      ],
    ),
    StudentQuestionType.ordering => StudentOrderingAnswerUi(
      items: [
        for (var id = 1; id <= 3; id++)
          StudentOrderingItem(id: _id(id), text: 'Item $id'),
      ],
    ),
    StudentQuestionType.fillInBlank => StudentFillBlankAnswerUi(
      blanks: [
        for (final id in [3, 1, 2])
          StudentFillBlank(id: _id(id), key: 'blank$id', position: id),
      ],
    ),
    _ => const StudentEmptyAnswerUi(),
  },
);

String _id(int number) =>
    'a0000000-0000-0000-0000-${number.toString().padLeft(12, '0')}';

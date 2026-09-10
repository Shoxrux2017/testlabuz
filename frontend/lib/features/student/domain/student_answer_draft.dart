import 'student_answer_mutation.dart';
import 'student_homework_attempt.dart';
import 'student_question.dart';

sealed class StudentAnswerDraft {
  const StudentAnswerDraft();

  factory StudentAnswerDraft.fromAnswer(
    StudentQuestion question,
    StudentAttemptAnswerValue? answer,
  ) => switch (question.type) {
    StudentQuestionType.singleChoice => StudentSingleChoiceDraft(
      selectedOptionId: answer == null
          ? null
          : _questionId(
              (question.answerUi as StudentChoiceAnswerUi).options.map(
                (option) => option.id,
              ),
              (answer as StudentChoiceAnswerValue).selectedOptionIds.single,
            ),
    ),
    StudentQuestionType.multipleChoice => StudentMultipleChoiceDraft(
      selectedOptionIds: answer == null
          ? {}
          : {
              for (final id
                  in (answer as StudentChoiceAnswerValue).selectedOptionIds)
                _questionId(
                  (question.answerUi as StudentChoiceAnswerUi).options.map(
                    (option) => option.id,
                  ),
                  id,
                ),
            },
    ),
    StudentQuestionType.trueFalse => StudentTrueFalseDraft(
      value: (answer as StudentBooleanAnswerValue?)?.value,
    ),
    StudentQuestionType.shortWritten => StudentShortWrittenDraft(
      text: (answer as StudentTextAnswerValue?)?.text ?? '',
    ),
    StudentQuestionType.openWritten => StudentOpenWrittenDraft(
      text: (answer as StudentTextAnswerValue?)?.text ?? '',
    ),
    StudentQuestionType.matching => StudentMatchingDraft(
      leftToRight: {
        for (final pair
            in (answer as StudentMatchingAnswerValue?)?.pairs ??
                <StudentMatchingAnswerPair>[])
          _questionId(
            (question.answerUi as StudentMatchingAnswerUi).leftItems.map(
              (item) => item.id,
            ),
            pair.leftItemId,
          ): _questionId(
            (question.answerUi as StudentMatchingAnswerUi).rightItems.map(
              (item) => item.id,
            ),
            pair.rightItemId,
          ),
      },
    ),
    StudentQuestionType.ordering => StudentOrderingDraft(
      itemToPosition: {
        for (final item
            in (answer as StudentOrderingAnswerValue?)?.items ??
                <StudentOrderingAnswerItem>[])
          _questionId(
            (question.answerUi as StudentOrderingAnswerUi).items.map(
              (item) => item.id,
            ),
            item.itemId,
          ): item.position,
      },
    ),
    StudentQuestionType.fillInBlank => StudentFillBlankDraft(
      blankTextById: {
        for (final blank
            in (question.answerUi as StudentFillBlankAnswerUi).blanks)
          blank.id: '',
        for (final value
            in (answer as StudentFillBlankAnswerValue?)?.values ??
                <StudentFillBlankAnswerEntry>[])
          _questionId(
            (question.answerUi as StudentFillBlankAnswerUi).blanks.map(
              (blank) => blank.id,
            ),
            value.blankId,
          ): value.text,
      },
    ),
    StudentQuestionType.fileBased => throw ArgumentError(
      'File answers do not have a non-file draft.',
    ),
  };

  factory StudentAnswerDraft.fromMutation(
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) {
    if (question.type != mutation.type) {
      throw ArgumentError('Mutation type does not match its Question.');
    }
    return switch (mutation) {
      StudentSingleChoiceMutation() => StudentSingleChoiceDraft(
        selectedOptionId: mutation.selectedOptionId,
      ),
      StudentMultipleChoiceMutation() => StudentMultipleChoiceDraft(
        selectedOptionIds: mutation.selectedOptionIds.toSet(),
      ),
      StudentTrueFalseMutation() => StudentTrueFalseDraft(
        value: mutation.value,
      ),
      StudentShortWrittenMutation() => StudentShortWrittenDraft(
        text: mutation.text,
      ),
      StudentOpenWrittenMutation() => StudentOpenWrittenDraft(
        text: mutation.text,
      ),
      StudentMatchingMutation() => StudentMatchingDraft(
        leftToRight: {
          for (final pair in mutation.pairs) pair.leftItemId: pair.rightItemId,
        },
      ),
      StudentOrderingMutation() => StudentOrderingDraft(
        itemToPosition: {
          for (final item in mutation.items) item.itemId: item.position,
        },
      ),
      StudentFillBlankMutation() => StudentFillBlankDraft(
        blankTextById: {
          for (final blank
              in (question.answerUi as StudentFillBlankAnswerUi).blanks)
            blank.id: '',
          for (final value in mutation.values) value.blankId: value.text,
        },
      ),
    };
  }

  StudentQuestionType get type;

  bool get canClear => switch (type) {
    StudentQuestionType.singleChoice || StudentQuestionType.trueFalse => false,
    _ => true,
  };

  StudentAnswerDraft clear(StudentQuestion question) {
    if (!canClear) throw StateError('This answer cannot be cleared.');
    return StudentAnswerDraft.fromAnswer(question, null);
  }

  String? validate(StudentQuestion question) {
    if (question.type != type) {
      return 'Answer type does not match the question.';
    }
    return switch (this) {
      StudentSingleChoiceDraft(:final selectedOptionId) =>
        selectedOptionId == null ||
                !_validIds(
                  [selectedOptionId],
                  (question.answerUi as StudentChoiceAnswerUi).options.map(
                    (option) => option.id,
                  ),
                )
            ? 'Select one answer.'
            : null,
      StudentMultipleChoiceDraft(:final selectedOptionIds) =>
        !_validIds(
              selectedOptionIds,
              (question.answerUi as StudentChoiceAnswerUi).options.map(
                (option) => option.id,
              ),
            )
            ? 'Select only options from this question.'
            : selectedOptionIds.length >
                  (question.answerUi as StudentChoiceAnswerUi).maxSelections!
            ? 'Select up to ${(question.answerUi as StudentChoiceAnswerUi).maxSelections} options.'
            : null,
      StudentTrueFalseDraft(:final value) =>
        value == null ? 'Select True or False.' : null,
      StudentShortWrittenDraft(:final text) =>
        text.runes.length > 1000 ? 'Use at most 1000 characters.' : null,
      StudentOpenWrittenDraft(:final text) =>
        text.runes.length > 20000 ? 'Use at most 20000 characters.' : null,
      StudentMatchingDraft(:final leftToRight) =>
        !_validIds(
                  leftToRight.keys,
                  (question.answerUi as StudentMatchingAnswerUi).leftItems.map(
                    (item) => item.id,
                  ),
                ) ||
                !_validIds(
                  leftToRight.values,
                  (question.answerUi as StudentMatchingAnswerUi).rightItems.map(
                    (item) => item.id,
                  ),
                )
            ? 'Match each item to a unique item from this question.'
            : null,
      StudentOrderingDraft(:final itemToPosition) =>
        !_validIds(
                  itemToPosition.keys,
                  (question.answerUi as StudentOrderingAnswerUi).items.map(
                    (item) => item.id,
                  ),
                ) ||
                itemToPosition.values.toSet().length != itemToPosition.length ||
                itemToPosition.values.any(
                  (position) =>
                      position < 1 ||
                      position >
                          (question.answerUi as StudentOrderingAnswerUi)
                              .items
                              .length,
                )
            ? 'Assign unique positions within the question item count.'
            : null,
      StudentFillBlankDraft(:final blankTextById) =>
        !_validIds(
              blankTextById.keys,
              (question.answerUi as StudentFillBlankAnswerUi).blanks.map(
                (blank) => blank.id,
              ),
            )
            ? 'Use only blanks from this question.'
            : blankTextById.values.any(
                (text) => text.trim().isNotEmpty && text.runes.length > 1000,
              )
            ? 'Use at most 1000 characters in each blank.'
            : null,
    };
  }

  bool isDirty(StudentQuestion question, StudentAttemptAnswerValue? answer) {
    if (question.type != type) return true;
    final base = StudentAnswerDraft.fromAnswer(question, answer);
    return switch (this) {
      StudentSingleChoiceDraft(:final selectedOptionId) =>
        selectedOptionId?.toLowerCase() !=
            (base as StudentSingleChoiceDraft).selectedOptionId?.toLowerCase(),
      StudentMultipleChoiceDraft(:final selectedOptionIds) => !_sameIds(
        selectedOptionIds,
        (base as StudentMultipleChoiceDraft).selectedOptionIds,
      ),
      StudentTrueFalseDraft(:final value) =>
        value != (base as StudentTrueFalseDraft).value,
      StudentShortWrittenDraft(:final text) =>
        _semanticText(text) !=
            _semanticText((base as StudentShortWrittenDraft).text),
      StudentOpenWrittenDraft(:final text) =>
        _semanticText(text) !=
            _semanticText((base as StudentOpenWrittenDraft).text),
      StudentMatchingDraft(:final leftToRight) => !_sameMap(
        {
          for (final entry in leftToRight.entries)
            entry.key.toLowerCase(): entry.value.toLowerCase(),
        },
        {
          for (final entry
              in (base as StudentMatchingDraft).leftToRight.entries)
            entry.key.toLowerCase(): entry.value.toLowerCase(),
        },
      ),
      StudentOrderingDraft(:final itemToPosition) => !_sameMap(
        {
          for (final entry in itemToPosition.entries)
            entry.key.toLowerCase(): entry.value,
        },
        {
          for (final entry
              in (base as StudentOrderingDraft).itemToPosition.entries)
            entry.key.toLowerCase(): entry.value,
        },
      ),
      StudentFillBlankDraft(:final blankTextById) => !_sameMap(
        _nonEmptyBlanks(blankTextById),
        _nonEmptyBlanks((base as StudentFillBlankDraft).blankTextById),
      ),
    };
  }

  StudentAnswerMutation toMutation(StudentQuestion question) {
    final error = validate(question);
    if (error != null) throw ArgumentError(error);
    return switch (this) {
      StudentSingleChoiceDraft(:final selectedOptionId) =>
        StudentSingleChoiceMutation(selectedOptionId: selectedOptionId!),
      StudentMultipleChoiceDraft(:final selectedOptionIds) =>
        StudentMultipleChoiceMutation(
          selectedOptionIds: [
            for (final option
                in (question.answerUi as StudentChoiceAnswerUi).options)
              if (_containsId(selectedOptionIds, option.id)) option.id,
          ],
        ),
      StudentTrueFalseDraft(:final value) => StudentTrueFalseMutation(
        value: value!,
      ),
      StudentShortWrittenDraft(:final text) => StudentShortWrittenMutation(
        text: text,
      ),
      StudentOpenWrittenDraft(:final text) => StudentOpenWrittenMutation(
        text: text,
      ),
      StudentMatchingDraft(:final leftToRight) => StudentMatchingMutation(
        pairs: [
          for (final left
              in (question.answerUi as StudentMatchingAnswerUi).leftItems)
            if (_containsId(leftToRight.keys, left.id))
              StudentMatchingAnswerPair(
                leftItemId: left.id,
                rightItemId: _questionId(
                  (question.answerUi as StudentMatchingAnswerUi).rightItems.map(
                    (item) => item.id,
                  ),
                  _valueForId(leftToRight, left.id),
                ),
              ),
        ],
      ),
      StudentOrderingDraft(:final itemToPosition) => StudentOrderingMutation(
        items: [
          for (final item
              in (question.answerUi as StudentOrderingAnswerUi).items)
            if (_containsId(itemToPosition.keys, item.id))
              StudentOrderingAnswerItem(
                itemId: item.id,
                position: _valueForId(itemToPosition, item.id),
              ),
        ],
      ),
      StudentFillBlankDraft(:final blankTextById) => StudentFillBlankMutation(
        values: [
          for (final blank in ([
            ...(question.answerUi as StudentFillBlankAnswerUi).blanks,
          ]..sort((a, b) => a.position.compareTo(b.position))))
            if (_containsId(blankTextById.keys, blank.id) &&
                _valueForId(blankTextById, blank.id).trim().isNotEmpty)
              StudentFillBlankAnswerEntry(
                blankId: blank.id,
                text: _valueForId(blankTextById, blank.id),
              ),
        ],
      ),
    };
  }
}

class StudentSingleChoiceDraft extends StudentAnswerDraft {
  const StudentSingleChoiceDraft({this.selectedOptionId});
  final String? selectedOptionId;
  @override
  StudentQuestionType get type => StudentQuestionType.singleChoice;
}

class StudentMultipleChoiceDraft extends StudentAnswerDraft {
  StudentMultipleChoiceDraft({Set<String> selectedOptionIds = const {}})
    : selectedOptionIds = Set.unmodifiable(selectedOptionIds);
  final Set<String> selectedOptionIds;
  @override
  StudentQuestionType get type => StudentQuestionType.multipleChoice;
}

class StudentTrueFalseDraft extends StudentAnswerDraft {
  const StudentTrueFalseDraft({this.value});
  final bool? value;
  @override
  StudentQuestionType get type => StudentQuestionType.trueFalse;
}

class StudentShortWrittenDraft extends StudentAnswerDraft {
  const StudentShortWrittenDraft({this.text = ''});
  final String text;
  @override
  StudentQuestionType get type => StudentQuestionType.shortWritten;
}

class StudentOpenWrittenDraft extends StudentAnswerDraft {
  const StudentOpenWrittenDraft({this.text = ''});
  final String text;
  @override
  StudentQuestionType get type => StudentQuestionType.openWritten;
}

class StudentMatchingDraft extends StudentAnswerDraft {
  StudentMatchingDraft({Map<String, String> leftToRight = const {}})
    : leftToRight = Map.unmodifiable(leftToRight);
  final Map<String, String> leftToRight;
  @override
  StudentQuestionType get type => StudentQuestionType.matching;
}

class StudentOrderingDraft extends StudentAnswerDraft {
  StudentOrderingDraft({Map<String, int> itemToPosition = const {}})
    : itemToPosition = Map.unmodifiable(itemToPosition);
  final Map<String, int> itemToPosition;
  @override
  StudentQuestionType get type => StudentQuestionType.ordering;
}

class StudentFillBlankDraft extends StudentAnswerDraft {
  StudentFillBlankDraft({Map<String, String> blankTextById = const {}})
    : blankTextById = Map.unmodifiable(blankTextById);
  final Map<String, String> blankTextById;
  @override
  StudentQuestionType get type => StudentQuestionType.fillInBlank;
}

bool _containsId(Iterable<String> ids, String target) =>
    ids.any((id) => id.toLowerCase() == target.toLowerCase());

String _questionId(Iterable<String> ids, String target) => ids.firstWhere(
  (id) => id.toLowerCase() == target.toLowerCase(),
  orElse: () => target,
);

T _valueForId<T>(Map<String, T> values, String id) =>
    values[_questionId(values.keys, id)] as T;

bool _validIds(Iterable<String> ids, Iterable<String> safeIds) {
  final values = ids.map((id) => id.toLowerCase()).toList();
  final allowed = safeIds.map((id) => id.toLowerCase()).toSet();
  return values.toSet().length == values.length && allowed.containsAll(values);
}

bool _sameIds(Iterable<String> first, Iterable<String> second) {
  final firstIds = first.map((id) => id.toLowerCase()).toSet();
  final secondIds = second.map((id) => id.toLowerCase()).toSet();
  return firstIds.length == secondIds.length && firstIds.containsAll(secondIds);
}

bool _sameMap<T>(Map<String, T> first, Map<String, T> second) =>
    first.length == second.length &&
    first.entries.every(
      (entry) =>
          second.containsKey(entry.key) && second[entry.key] == entry.value,
    );

String? _semanticText(String text) => text.trim().isEmpty ? null : text;

Map<String, String> _nonEmptyBlanks(Map<String, String> values) => {
  for (final entry in values.entries)
    if (entry.value.trim().isNotEmpty) entry.key.toLowerCase(): entry.value,
};

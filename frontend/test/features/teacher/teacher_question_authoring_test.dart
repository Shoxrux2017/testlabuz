import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_authoring.dart';

void main() {
  group('Teacher Question common authoring', () {
    test('exposes the exact frozen limits', () {
      expect(TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment, 100);
      expect(TeacherQuestionAuthoringLimits.maxPromptLength, 10000);
      expect(TeacherQuestionAuthoringLimits.maxInstructionsLength, 5000);
      expect(TeacherQuestionAuthoringLimits.maxChoiceOptions, 20);
      expect(TeacherQuestionAuthoringLimits.maxOptionTextLength, 2000);
      expect(TeacherQuestionAuthoringLimits.maxShortAcceptedAnswers, 20);
      expect(TeacherQuestionAuthoringLimits.maxAcceptedAnswerLength, 1000);
      expect(TeacherQuestionAuthoringLimits.maxMatchingPairs, 50);
      expect(TeacherQuestionAuthoringLimits.maxMatchingItemTextLength, 2000);
      expect(TeacherQuestionAuthoringLimits.maxClientKeyLength, 80);
      expect(TeacherQuestionAuthoringLimits.maxOrderingItems, 50);
      expect(TeacherQuestionAuthoringLimits.maxOrderingItemTextLength, 2000);
      expect(TeacherQuestionAuthoringLimits.maxFillBlanks, 50);
      expect(TeacherQuestionAuthoringLimits.maxAcceptedAnswersPerBlank, 20);
      expect(TeacherQuestionAuthoringLimits.maxPoints, 999999.999999);
      expect(TeacherQuestionAuthoringLimits.maxPointsFractionDigits, 6);
    });

    test('add defaults use an immutable Single Choice skeleton', () {
      final draft = TeacherQuestionDraft.forAdd();

      expect(draft.type, TeacherQuestionType.singleChoice);
      expect(draft.prompt, '');
      expect(draft.instructions, '');
      expect(draft.pointsText, '1');
      expect(draft.checkingMode, TeacherQuestionCheckingMode.automatic);
      final configuration =
          draft.configurationDraft as TeacherChoiceConfigurationDraft;
      expect(configuration.options, hasLength(2));
      expect(configuration.options.first.isCorrect, isTrue);
      expect(configuration.options.last.isCorrect, isFalse);
      expect(
        () => configuration.options.add(
          const TeacherChoiceOptionDraft(
            localId: 'extra',
            text: '',
            isCorrect: false,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('normalizes only contract-defined common fields', () {
      final result = _validDraft(TeacherQuestionType.singleChoice)
          .copyWith(prompt: '  Choose A  ', instructions: '  Keep spaces  ')
          .validate();

      expect(result.isValid, isTrue);
      expect(result.validatedDraft!.prompt, 'Choose A');
      expect(result.validatedDraft!.instructions, '  Keep spaces  ');
      expect(
        _validDraft(
          TeacherQuestionType.singleChoice,
        ).copyWith(instructions: '').validate().validatedDraft!.instructions,
        isNull,
      );
      expect(
        _validDraft(
          TeacherQuestionType.singleChoice,
        ).copyWith(instructions: '   ').validate().errors,
        contains(TeacherQuestionDraftField.instructions),
      );
    });

    test('counts Unicode scalar values for prompt and instructions', () {
      final emoji = String.fromCharCode(0x1f600);
      final maxPrompt = List.filled(
        TeacherQuestionAuthoringLimits.maxPromptLength,
        emoji,
      ).join();
      final maxInstructions = List.filled(
        TeacherQuestionAuthoringLimits.maxInstructionsLength,
        emoji,
      ).join();

      expect(
        _validDraft(TeacherQuestionType.singleChoice)
            .copyWith(prompt: maxPrompt, instructions: maxInstructions)
            .validate()
            .isValid,
        isTrue,
      );
      expect(
        _validDraft(TeacherQuestionType.singleChoice)
            .copyWith(prompt: '$maxPrompt$emoji')
            .validate()
            .errorFor(TeacherQuestionDraftField.prompt),
        isNotNull,
      );
      expect(
        _validDraft(TeacherQuestionType.singleChoice)
            .copyWith(instructions: '$maxInstructions$emoji')
            .validate()
            .errorFor(TeacherQuestionDraftField.instructions),
        isNotNull,
      );
    });

    test('accepts only the approved points grammar and range', () {
      for (final value in ['0', '1', '1.5', '0001.500000', '999999.999999']) {
        expect(TeacherQuestionPoints.tryParse(value), isNotNull, reason: value);
      }
      for (final value in [
        '',
        ' ',
        '-1',
        '+1',
        '.5',
        '1.',
        '1.1234567',
        '1e2',
        '1,5',
        '1000000',
        'NaN',
        'Infinity',
      ]) {
        expect(TeacherQuestionPoints.tryParse(value), isNull, reason: value);
      }
      expect(formatTeacherQuestionPoints(1.5), '1.5');
      expect(formatTeacherQuestionPoints(0), '0');
      expect(formatTeacherQuestionPoints(999999.999999), '999999.999999');
    });

    test('enforces fixed modes while allowing both Short Written modes', () {
      final invalidFixed = _validDraft(
        TeacherQuestionType.singleChoice,
      ).copyWith(checkingMode: TeacherQuestionCheckingMode.manual).validate();
      expect(
        invalidFixed.errors,
        contains(TeacherQuestionDraftField.checkingMode),
      );

      expect(
        _validDraft(TeacherQuestionType.shortWritten).validate().isValid,
        isTrue,
      );
      expect(
        _validDraft(
          TeacherQuestionType.shortWritten,
          checkingMode: TeacherQuestionCheckingMode.manual,
        ).validate().isValid,
        isTrue,
      );
      expect(
        _validDraft(TeacherQuestionType.openWritten).checkingMode,
        TeacherQuestionCheckingMode.manual,
      );
    });
  });

  group('Teacher Question type transitions', () {
    test('type change preserves common fields and resets configuration', () {
      final ids = TeacherQuestionLocalIdSequence(initialValue: 40);
      final original = _validDraft(TeacherQuestionType.singleChoice).copyWith(
        prompt: 'Prompt',
        instructions: 'Instructions',
        pointsText: '2.5',
      );

      expect(
        original.requiresTypeChangeConfirmation(
          TeacherQuestionType.openWritten,
        ),
        isTrue,
      );
      final changed = original.changeType(
        TeacherQuestionType.shortWritten,
        nextLocalId: ids.next,
      );
      expect(changed.prompt, original.prompt);
      expect(changed.instructions, original.instructions);
      expect(changed.pointsText, original.pointsText);
      expect(changed.checkingMode, TeacherQuestionCheckingMode.automatic);
      final configuration =
          changed.configurationDraft as TeacherShortWrittenConfigurationDraft;
      expect(configuration.acceptedAnswers, hasLength(1));
      expect(configuration.acceptedAnswers.single.text, isEmpty);
      expect(configuration.acceptedAnswers.single.localId, 'question_row_41');
    });

    test('blank skeleton does not require destructive-change confirmation', () {
      final draft = TeacherQuestionDraft.forAdd();

      expect(
        draft.requiresTypeChangeConfirmation(TeacherQuestionType.matching),
        isFalse,
      );
      expect(
        draft.changeType(TeacherQuestionType.openWritten).checkingMode,
        TeacherQuestionCheckingMode.manual,
      );
    });

    test('Short Written mode reset has the required confirmation behavior', () {
      final automatic = _validDraft(TeacherQuestionType.shortWritten);
      expect(
        automatic.requiresCheckingModeChangeConfirmation(
          TeacherQuestionCheckingMode.manual,
        ),
        isTrue,
      );

      final manual = automatic.changeCheckingMode(
        TeacherQuestionCheckingMode.manual,
      );
      expect(manual.configurationDraft, isA<TeacherEmptyConfigurationDraft>());
      expect(manual.validate().isValid, isTrue);

      final automaticAgain = manual.changeCheckingMode(
        TeacherQuestionCheckingMode.automatic,
      );
      final configuration =
          automaticAgain.configurationDraft
              as TeacherShortWrittenConfigurationDraft;
      expect(configuration.acceptedAnswers.single.text, isEmpty);
      expect(automaticAgain.validate().isValid, isFalse);
      expect(
        () => automatic.changeCheckingMode(TeacherQuestionCheckingMode.manual),
        returnsNormally,
      );
      expect(
        () => _validDraft(
          TeacherQuestionType.singleChoice,
        ).changeCheckingMode(TeacherQuestionCheckingMode.manual),
        throwsArgumentError,
      );
    });

    test('semantic draft equality ignores UI-only row identities', () {
      final left = _validDraft(TeacherQuestionType.matching);
      final right = TeacherQuestionDraft(
        type: left.type,
        prompt: left.prompt,
        instructions: left.instructions,
        pointsText: left.pointsText,
        checkingMode: left.checkingMode,
        configurationDraft: TeacherMatchingConfigurationDraft(
          pairs: const [
            TeacherMatchingPairDraft(
              localId: 'different-id',
              left: 'DNS',
              right: 'Domain Name System',
            ),
          ],
        ),
      );

      expect(left.semanticallyEqualsDraft(right), isTrue);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('readback conversion discards Matching clientKey authority', () {
      final question = TeacherQuestion(
        id: '70000000-0000-0000-0000-000000000001',
        type: TeacherQuestionType.matching,
        prompt: 'Match.',
        instructions: null,
        points: 1.5,
        position: 3,
        checkingMode: TeacherQuestionCheckingMode.automatic,
        configuration: TeacherMatchingQuestionConfiguration(
          pairs: const [
            TeacherMatchingPair(
              clientKey: '80000000-0000-0000-0000-000000000001',
              left: 'DNS',
              right: 'Domain Name System',
            ),
          ],
        ),
      );
      final draft = TeacherQuestionDraft.fromQuestion(question);
      final pair =
          (draft.configurationDraft as TeacherMatchingConfigurationDraft)
              .pairs
              .single;

      expect(pair.localId, 'question_row_1');
      expect(pair.localId, isNot(contains('80000000')));
      expect(pair.left, 'DNS');
      expect(pair.right, 'Domain Name System');
      expect(draft.pointsText, '1.5');
    });
  });

  group('Teacher Question typed configuration validation', () {
    test(
      'Single and Multiple Choice enforce counts, text, and correctness',
      () {
        final tooFew = _choiceDraft(TeacherQuestionType.singleChoice, const [
          TeacherChoiceOptionDraft(localId: '1', text: 'Only', isCorrect: true),
        ]);
        expect(tooFew.validate().isValid, isFalse);

        final maxOptions = [
          for (
            var index = 0;
            index < TeacherQuestionAuthoringLimits.maxChoiceOptions;
            index += 1
          )
            TeacherChoiceOptionDraft(
              localId: '$index',
              text: 'Option $index',
              isCorrect: index == 0,
            ),
        ];
        expect(
          _choiceDraft(
            TeacherQuestionType.singleChoice,
            maxOptions,
          ).validate().isValid,
          isTrue,
        );
        expect(
          _choiceDraft(TeacherQuestionType.singleChoice, [
            ...maxOptions,
            maxOptions.first,
          ]).validate().isValid,
          isFalse,
        );
        expect(
          _choiceDraft(TeacherQuestionType.singleChoice, const [
            TeacherChoiceOptionDraft(
              localId: '1',
              text: '   ',
              isCorrect: true,
            ),
            TeacherChoiceOptionDraft(localId: '2', text: 'B', isCorrect: false),
          ]).validate().isValid,
          isFalse,
        );
        expect(
          _choiceDraft(TeacherQuestionType.singleChoice, const [
            TeacherChoiceOptionDraft(localId: '1', text: 'A', isCorrect: true),
            TeacherChoiceOptionDraft(localId: '2', text: 'B', isCorrect: true),
          ]).validate().isValid,
          isFalse,
        );
        expect(
          _choiceDraft(TeacherQuestionType.multipleChoice, const [
            TeacherChoiceOptionDraft(localId: '1', text: 'A', isCorrect: false),
            TeacherChoiceOptionDraft(localId: '2', text: 'B', isCorrect: false),
          ]).validate().isValid,
          isFalse,
        );
        expect(
          _choiceDraft(TeacherQuestionType.multipleChoice, const [
            TeacherChoiceOptionDraft(localId: '1', text: 'A', isCorrect: true),
            TeacherChoiceOptionDraft(localId: '2', text: 'B', isCorrect: false),
          ]).validate().isValid,
          isTrue,
        );
        expect(
          _choiceDraft(TeacherQuestionType.multipleChoice, const [
            TeacherChoiceOptionDraft(localId: '1', text: 'A', isCorrect: true),
            TeacherChoiceOptionDraft(localId: '2', text: 'B', isCorrect: true),
            TeacherChoiceOptionDraft(localId: '3', text: 'C', isCorrect: false),
          ]).validate().isValid,
          isTrue,
        );
        expect(
          _choiceDraft(TeacherQuestionType.multipleChoice, const [
            TeacherChoiceOptionDraft(localId: '1', text: 'A', isCorrect: true),
            TeacherChoiceOptionDraft(localId: '2', text: 'B', isCorrect: true),
          ]).validate().isValid,
          isTrue,
        );
        expect(
          _choiceDraft(TeacherQuestionType.singleChoice, [
            const TeacherChoiceOptionDraft(
              localId: '1',
              text: 'A',
              isCorrect: true,
            ),
            TeacherChoiceOptionDraft(
              localId: '2',
              text: List.filled(
                TeacherQuestionAuthoringLimits.maxOptionTextLength + 1,
                'x',
              ).join(),
              isCorrect: false,
            ),
          ]).validate().isValid,
          isFalse,
        );
      },
    );

    test('Short Written validates canonical answers and count', () {
      expect(_shortDraft(const [' DNS ', 'DNS']).validate().isValid, isFalse);
      expect(_shortDraft(const ['']).validate().isValid, isFalse);
      expect(
        _shortDraft(
          List.filled(
            TeacherQuestionAuthoringLimits.maxShortAcceptedAnswers,
            'answer',
          ).indexed.map((entry) => '${entry.$2}${entry.$1}').toList(),
        ).validate().isValid,
        isTrue,
      );
      expect(
        _shortDraft(
          List.generate(
            TeacherQuestionAuthoringLimits.maxShortAcceptedAnswers + 1,
            (index) => 'answer$index',
          ),
        ).validate().isValid,
        isFalse,
      );
    });

    test('Matching validates pair limits and scalar-value text lengths', () {
      final emoji = String.fromCharCode(0x1f600);
      final maxText = List.filled(
        TeacherQuestionAuthoringLimits.maxMatchingItemTextLength,
        emoji,
      ).join();
      expect(_matchingDraft(const []).validate().isValid, isFalse);
      expect(_matchingDraft(const [('DNS', '')]).validate().isValid, isFalse);
      expect(_matchingDraft([(maxText, 'R')]).validate().isValid, isTrue);
      expect(
        _matchingDraft([('$maxText$emoji', 'R')]).validate().isValid,
        isFalse,
      );
      expect(
        _matchingDraft(
          List.generate(
            TeacherQuestionAuthoringLimits.maxMatchingPairs,
            (index) => ('L$index', 'R$index'),
          ),
        ).validate().isValid,
        isTrue,
      );
      expect(
        _matchingDraft(
          List.generate(
            TeacherQuestionAuthoringLimits.maxMatchingPairs + 1,
            (index) => ('L$index', 'R$index'),
          ),
        ).validate().isValid,
        isFalse,
      );
    });

    test('Ordering validates min/max and derives semantic order', () {
      final emoji = String.fromCharCode(0x1f600);
      final maxText = List.filled(
        TeacherQuestionAuthoringLimits.maxOrderingItemTextLength,
        emoji,
      ).join();
      expect(_orderingDraft(const ['Only']).validate().isValid, isFalse);
      expect(
        _orderingDraft(const ['First', '   ']).validate().isValid,
        isFalse,
      );
      expect(
        _orderingDraft(const [' First ', ' Second ']).validate().isValid,
        isTrue,
      );
      expect(
        _orderingDraft(
          List.generate(
            TeacherQuestionAuthoringLimits.maxOrderingItems,
            (index) => 'Item $index',
          ),
        ).validate().isValid,
        isTrue,
      );
      expect(
        _orderingDraft(
          List.generate(
            TeacherQuestionAuthoringLimits.maxOrderingItems + 1,
            (index) => '$index',
          ),
        ).validate().isValid,
        isFalse,
      );
      expect(_orderingDraft([maxText, 'Second']).validate().isValid, isTrue);
      expect(
        _orderingDraft(['$maxText$emoji', 'Second']).validate().isValid,
        isFalse,
      );
    });

    test('Fill Blank enforces key, answer, and placeholder correspondence', () {
      expect(
        _fillDraft(
          prompt: '{{one}} {{two}}',
          blanks: const [
            ('one', ['1']),
            ('two', ['2']),
          ],
        ).validate().isValid,
        isTrue,
      );
      for (final draft in [
        _fillDraft(
          prompt: '{{one}}',
          blanks: const [
            ('1bad', ['1']),
          ],
        ),
        _fillDraft(
          prompt: '{{one}}',
          blanks: const [
            ('one', ['1']),
            ('one', ['2']),
          ],
        ),
        _fillDraft(
          prompt: '{{one}} and {{one}}',
          blanks: const [
            ('one', ['1']),
          ],
        ),
        _fillDraft(
          prompt: '{{one}} and {{extra}}',
          blanks: const [
            ('one', ['1']),
          ],
        ),
        _fillDraft(
          prompt: 'No placeholder',
          blanks: const [
            ('one', ['1']),
          ],
        ),
        _fillDraft(
          prompt: '{{one}}',
          blanks: const [
            ('one', [' x ', 'x']),
          ],
        ),
      ]) {
        expect(draft.validate().isValid, isFalse);
      }
      final invalidPlaceholder = _fillDraft(
        prompt: '{{one}} and {{one}}',
        blanks: const [
          ('one', ['1']),
        ],
      ).validate();
      expect(
        invalidPlaceholder.errorFor(TeacherQuestionDraftField.configuration),
        'Each configured blank must appear exactly once in the prompt as {{key}}.',
      );

      final maxBlanks = List.generate(
        TeacherQuestionAuthoringLimits.maxFillBlanks,
        (index) => ('blank$index', ['answer']),
      );
      final maxBlankPrompt = maxBlanks
          .map((blank) => '{{${blank.$1}}}')
          .join(' ');
      expect(
        _fillDraft(
          prompt: maxBlankPrompt,
          blanks: maxBlanks,
        ).validate().isValid,
        isTrue,
      );
      final tooManyBlanks = [
        ...maxBlanks,
        ('overflow', ['answer']),
      ];
      expect(
        _fillDraft(
          prompt: '$maxBlankPrompt {{overflow}}',
          blanks: tooManyBlanks,
        ).validate().isValid,
        isFalse,
      );

      final maxAnswers = List.generate(
        TeacherQuestionAuthoringLimits.maxAcceptedAnswersPerBlank,
        (index) => 'answer$index',
      );
      expect(
        _fillDraft(
          prompt: '{{one}}',
          blanks: [('one', maxAnswers)],
        ).validate().isValid,
        isTrue,
      );
      expect(
        _fillDraft(
          prompt: '{{one}}',
          blanks: [
            ('one', [...maxAnswers, 'overflow']),
          ],
        ).validate().isValid,
        isFalse,
      );

      final emoji = String.fromCharCode(0x1f600);
      final maxAnswer = List.filled(
        TeacherQuestionAuthoringLimits.maxAcceptedAnswerLength,
        emoji,
      ).join();
      expect(
        _fillDraft(
          prompt: '{{one}}',
          blanks: [
            ('one', [maxAnswer]),
          ],
        ).validate().isValid,
        isTrue,
      );
      expect(
        _fillDraft(
          prompt: '{{one}}',
          blanks: [
            ('one', ['$maxAnswer$emoji']),
          ],
        ).validate().isValid,
        isFalse,
      );
    });

    test(
      'all nine type skeletons are typed and validation-safe when filled',
      () {
        for (final type in TeacherQuestionType.values) {
          expect(
            _validDraft(type).validate().isValid,
            isTrue,
            reason: type.value,
          );
        }
      },
    );
  });
}

TeacherQuestionDraft _validDraft(
  TeacherQuestionType type, {
  TeacherQuestionCheckingMode? checkingMode,
}) {
  final mode = checkingMode ?? teacherQuestionDefaultCheckingMode(type);
  final configuration = switch ((type, mode)) {
    (
      TeacherQuestionType.singleChoice || TeacherQuestionType.multipleChoice,
      TeacherQuestionCheckingMode.automatic,
    ) =>
      TeacherChoiceConfigurationDraft(
        options: [
          const TeacherChoiceOptionDraft(
            localId: 'option-1',
            text: 'A',
            isCorrect: true,
          ),
          TeacherChoiceOptionDraft(
            localId: 'option-2',
            text: 'B',
            isCorrect: type == TeacherQuestionType.multipleChoice,
          ),
        ],
      ),
    (TeacherQuestionType.trueFalse, TeacherQuestionCheckingMode.automatic) =>
      const TeacherTrueFalseConfigurationDraft(correctValue: true),
    (TeacherQuestionType.shortWritten, TeacherQuestionCheckingMode.automatic) =>
      TeacherShortWrittenConfigurationDraft(
        acceptedAnswers: const [
          TeacherAcceptedAnswerDraft(localId: 'answer-1', text: 'Answer'),
        ],
      ),
    (TeacherQuestionType.shortWritten, TeacherQuestionCheckingMode.manual) ||
    (
      TeacherQuestionType.openWritten,
      TeacherQuestionCheckingMode.manual,
    ) => const TeacherEmptyConfigurationDraft(),
    (TeacherQuestionType.fileBased, TeacherQuestionCheckingMode.manual) =>
      const TeacherFileBasedConfigurationDraft(),
    (TeacherQuestionType.matching, TeacherQuestionCheckingMode.automatic) =>
      TeacherMatchingConfigurationDraft(
        pairs: const [
          TeacherMatchingPairDraft(
            localId: 'pair-1',
            left: 'DNS',
            right: 'Domain Name System',
          ),
        ],
      ),
    (TeacherQuestionType.ordering, TeacherQuestionCheckingMode.automatic) =>
      TeacherOrderingConfigurationDraft(
        items: const [
          TeacherOrderingItemDraft(localId: 'item-1', text: 'First'),
          TeacherOrderingItemDraft(localId: 'item-2', text: 'Second'),
        ],
      ),
    (TeacherQuestionType.fillInBlank, TeacherQuestionCheckingMode.automatic) =>
      TeacherFillInBlankConfigurationDraft(
        blanks: [
          TeacherFillBlankDraft(
            localId: 'blank-1',
            key: 'answer',
            acceptedAnswers: const [
              TeacherAcceptedAnswerDraft(localId: 'answer-1', text: 'value'),
            ],
          ),
        ],
      ),
    _ => throw StateError('Unsupported test type/mode.'),
  };
  return TeacherQuestionDraft(
    type: type,
    prompt: type == TeacherQuestionType.fillInBlank
        ? 'Complete {{answer}}.'
        : 'Question prompt',
    instructions: '',
    pointsText: '1',
    checkingMode: mode,
    configurationDraft: configuration,
  );
}

TeacherQuestionDraft _choiceDraft(
  TeacherQuestionType type,
  List<TeacherChoiceOptionDraft> options,
) {
  return _validDraft(type).copyWith(
    configurationDraft: TeacherChoiceConfigurationDraft(options: options),
  );
}

TeacherQuestionDraft _shortDraft(List<String> answers) {
  return _validDraft(TeacherQuestionType.shortWritten).copyWith(
    configurationDraft: TeacherShortWrittenConfigurationDraft(
      acceptedAnswers: [
        for (var index = 0; index < answers.length; index += 1)
          TeacherAcceptedAnswerDraft(
            localId: 'answer-$index',
            text: answers[index],
          ),
      ],
    ),
  );
}

TeacherQuestionDraft _matchingDraft(List<(String, String)> pairs) {
  return _validDraft(TeacherQuestionType.matching).copyWith(
    configurationDraft: TeacherMatchingConfigurationDraft(
      pairs: [
        for (var index = 0; index < pairs.length; index += 1)
          TeacherMatchingPairDraft(
            localId: 'pair-$index',
            left: pairs[index].$1,
            right: pairs[index].$2,
          ),
      ],
    ),
  );
}

TeacherQuestionDraft _orderingDraft(List<String> items) {
  return _validDraft(TeacherQuestionType.ordering).copyWith(
    configurationDraft: TeacherOrderingConfigurationDraft(
      items: [
        for (var index = 0; index < items.length; index += 1)
          TeacherOrderingItemDraft(localId: 'item-$index', text: items[index]),
      ],
    ),
  );
}

TeacherQuestionDraft _fillDraft({
  required String prompt,
  required List<(String, List<String>)> blanks,
}) {
  return _validDraft(TeacherQuestionType.fillInBlank).copyWith(
    prompt: prompt,
    configurationDraft: TeacherFillInBlankConfigurationDraft(
      blanks: [
        for (var blankIndex = 0; blankIndex < blanks.length; blankIndex += 1)
          TeacherFillBlankDraft(
            localId: 'blank-$blankIndex',
            key: blanks[blankIndex].$1,
            acceptedAnswers: [
              for (
                var answerIndex = 0;
                answerIndex < blanks[blankIndex].$2.length;
                answerIndex += 1
              )
                TeacherAcceptedAnswerDraft(
                  localId: 'answer-$blankIndex-$answerIndex',
                  text: blanks[blankIndex].$2[answerIndex],
                ),
            ],
          ),
      ],
    ),
  );
}

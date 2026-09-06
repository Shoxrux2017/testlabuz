import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_authoring.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

const _questionId = '70000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherQuestionCreateRequest', () {
    test('serializes exact common keys and normalized JSON values', () {
      final request = TeacherQuestionCreateRequest.fromDraft(
        draft: _draft(TeacherQuestionType.singleChoice).copyWith(
          prompt: '  Pick one.  ',
          instructions: '  Preserve me.  ',
          pointsText: '1.500000',
        ),
        position: 4,
      );

      expect(request.toJson(), {
        'type': 'single_choice',
        'prompt': 'Pick one.',
        'instructions': '  Preserve me.  ',
        'points': 1.5,
        'position': 4,
        'checking_mode': 'automatic',
        'configuration': {
          'options': [
            {'text': 'A', 'is_correct': true, 'position': 1},
            {'text': 'B', 'is_correct': false, 'position': 2},
          ],
        },
      });
      expect(request.toJson().keys, hasLength(7));
      expect(request.toJson(), isNot(contains('client_key')));
    });

    test('serializes every typed configuration exactly', () {
      final cases = <(TeacherQuestionDraft, Object)>[
        (
          _draft(TeacherQuestionType.singleChoice),
          {
            'options': [
              {'text': 'A', 'is_correct': true, 'position': 1},
              {'text': 'B', 'is_correct': false, 'position': 2},
            ],
          },
        ),
        (
          _draft(TeacherQuestionType.multipleChoice),
          {
            'options': [
              {'text': 'A', 'is_correct': true, 'position': 1},
              {'text': 'B', 'is_correct': true, 'position': 2},
            ],
          },
        ),
        (_draft(TeacherQuestionType.trueFalse), {'correct_value': false}),
        (
          _draft(TeacherQuestionType.shortWritten),
          {
            'accepted_answers': ['DNS', 'Domain Name System'],
          },
        ),
        (
          _draft(
            TeacherQuestionType.shortWritten,
            checkingMode: TeacherQuestionCheckingMode.manual,
          ),
          <String, Object?>{},
        ),
        (_draft(TeacherQuestionType.openWritten), <String, Object?>{}),
        (
          _draft(TeacherQuestionType.fileBased),
          {
            'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
          },
        ),
        (
          _draft(TeacherQuestionType.matching),
          {
            'pairs': [
              {
                'client_key': 'pair_1',
                'left': 'DNS',
                'right': 'Domain Name System',
              },
              {
                'client_key': 'pair_2',
                'left': 'HTTP',
                'right': 'Hypertext Transfer Protocol',
              },
            ],
          },
        ),
        (
          _draft(TeacherQuestionType.ordering),
          {
            'items': [
              {'text': 'First', 'correct_position': 1},
              {'text': 'Second', 'correct_position': 2},
            ],
          },
        ),
        (
          _draft(TeacherQuestionType.fillInBlank),
          {
            'blanks': [
              {
                'key': 'host',
                'position': 1,
                'accepted_answers': ['server'],
              },
              {
                'key': 'address',
                'position': 2,
                'accepted_answers': ['IP'],
              },
            ],
          },
        ),
      ];

      for (final mutationCase in cases) {
        final json = TeacherQuestionCreateRequest.fromDraft(
          draft: mutationCase.$1,
          position: 1,
        ).toJson();
        expect(
          json['configuration'],
          mutationCase.$2,
          reason: mutationCase.$1.type.value,
        );
      }
    });

    test('Matching generates request-only keys from current pair order', () {
      const serverKey = '80000000-0000-0000-0000-000000000001';
      final question = TeacherQuestion(
        id: _questionId,
        type: TeacherQuestionType.matching,
        prompt: 'Match.',
        instructions: null,
        points: 1,
        position: 1,
        checkingMode: TeacherQuestionCheckingMode.automatic,
        configuration: TeacherMatchingQuestionConfiguration(
          pairs: const [
            TeacherMatchingPair(
              clientKey: serverKey,
              left: 'DNS',
              right: 'Domain Name System',
            ),
          ],
        ),
      );

      final configuration =
          TeacherQuestionCreateRequest.fromDraft(
                draft: TeacherQuestionDraft.fromQuestion(question),
                position: 2,
              ).toJson()['configuration']
              as Map<String, Object?>;
      final pairs = configuration['pairs']! as List<Object?>;
      final pair = pairs.single as Map<String, Object?>;
      expect(pair['client_key'], 'pair_1');
      expect(pair.values, isNot(contains(serverKey)));
    });

    test('rejects invalid drafts and out-of-range append positions', () {
      expect(
        () => TeacherQuestionCreateRequest.fromDraft(
          draft: TeacherQuestionDraft.forAdd(),
          position: 1,
        ),
        throwsA(isA<TeacherQuestionDraftValidationException>()),
      );
      for (final position in [0, 101]) {
        expect(
          () => TeacherQuestionCreateRequest.fromDraft(
            draft: _draft(TeacherQuestionType.trueFalse),
            position: position,
          ),
          throwsArgumentError,
        );
      }
      expect(
        TeacherQuestionCreateRequest.fromDraft(
          draft: _draft(TeacherQuestionType.trueFalse),
          position: 100,
        ).position,
        100,
      );
    });
  });

  group('TeacherQuestionEditRequest', () {
    test(
      'an authoritative readback round trip is a no-op without position',
      () {
        final question = _question();
        final request = TeacherQuestionEditRequest.fromDraft(
          draft: TeacherQuestionDraft.fromQuestion(question),
          initial: TeacherQuestionEditSnapshot.fromQuestion(question),
        );

        expect(request.isEmpty, isTrue);
        expect(request.toJson(), isEmpty);
        expect(request.toJson(), isNot(contains('position')));
        expect(request.matches(question), isTrue);
      },
    );

    test('serializes each changed common field only when changed', () {
      final question = _question();
      final initial = TeacherQuestionEditSnapshot.fromQuestion(question);
      final base = TeacherQuestionDraft.fromQuestion(question);
      final cases = <(TeacherQuestionDraft, Map<String, Object?>)>[
        (base.copyWith(prompt: ' Changed '), {'prompt': 'Changed'}),
        (base.copyWith(instructions: ''), {'instructions': null}),
        (base.copyWith(pointsText: '2.25'), {'points': 2.25}),
      ];

      for (final mutationCase in cases) {
        final request = TeacherQuestionEditRequest.fromDraft(
          draft: mutationCase.$1,
          initial: initial,
        );
        expect(request.toJson(), mutationCase.$2);
        expect(request.toJson(), isNot(contains('position')));
      }
    });

    test('configuration-only edit sends canonical configuration only', () {
      final question = _question();
      final initial = TeacherQuestionEditSnapshot.fromQuestion(question);
      final base = TeacherQuestionDraft.fromQuestion(question);
      final configuration =
          base.configurationDraft as TeacherChoiceConfigurationDraft;
      final changed = base.copyWith(
        configurationDraft: configuration.copyWith(
          options: [
            configuration.options.first.copyWith(text: 'Changed A'),
            configuration.options.last,
          ],
        ),
      );

      final request = TeacherQuestionEditRequest.fromDraft(
        draft: changed,
        initial: initial,
      );

      expect(request.toJson().keys, [
        TeacherQuestionMutationField.configuration.requestKey,
      ]);
      expect(request.toJson(), isNot(contains('position')));
    });

    test(
      'type and checking-mode changes always include full configuration',
      () {
        final question = _question();
        final initial = TeacherQuestionEditSnapshot.fromQuestion(question);
        final changedType = TeacherQuestionDraft.fromQuestion(
          question,
        ).changeType(TeacherQuestionType.openWritten);
        final typeRequest = TeacherQuestionEditRequest.fromDraft(
          draft: changedType,
          initial: initial,
        );
        expect(typeRequest.toJson(), {
          'type': 'open_written',
          'checking_mode': 'manual',
          'configuration': <String, Object?>{},
        });

        final shortQuestion = _shortQuestion();
        final modeRequest = TeacherQuestionEditRequest.fromDraft(
          draft: TeacherQuestionDraft.fromQuestion(
            shortQuestion,
          ).changeCheckingMode(TeacherQuestionCheckingMode.manual),
          initial: TeacherQuestionEditSnapshot.fromQuestion(shortQuestion),
        );
        expect(modeRequest.toJson(), {
          'checking_mode': 'manual',
          'configuration': <String, Object?>{},
        });
      },
    );

    test('matches only fields present and ignores position', () {
      final original = _question();
      final request = TeacherQuestionEditRequest.fromDraft(
        draft: TeacherQuestionDraft.fromQuestion(
          original,
        ).copyWith(prompt: 'Changed'),
        initial: TeacherQuestionEditSnapshot.fromQuestion(original),
      );

      expect(
        request.matches(_question(prompt: 'Changed', position: 99)),
        isTrue,
      );
      expect(request.matches(_question(prompt: 'Other', position: 1)), isFalse);
    });

    test('Matching semantic comparison ignores server readback keys', () {
      final original = _matchingQuestion(
        clientKey: '80000000-0000-0000-0000-000000000001',
      );
      final draft = TeacherQuestionDraft.fromQuestion(
        original,
      ).copyWith(prompt: 'Changed prompt');
      final request = TeacherQuestionEditRequest.fromDraft(
        draft: draft,
        initial: TeacherQuestionEditSnapshot.fromQuestion(original),
      );
      final current = _matchingQuestion(
        clientKey: '80000000-0000-0000-0000-000000000099',
        prompt: 'Changed prompt',
      );

      expect(request.toJson(), {'prompt': 'Changed prompt'});
      expect(request.matches(current), isTrue);

      final pairChangedDraft = draft.copyWith(
        configurationDraft: TeacherMatchingConfigurationDraft(
          pairs: const [
            TeacherMatchingPairDraft(
              localId: 'local',
              left: 'DNS',
              right: 'Changed semantic right',
            ),
          ],
        ),
      );
      final pairRequest = TeacherQuestionEditRequest.fromDraft(
        draft: pairChangedDraft,
        initial: TeacherQuestionEditSnapshot.fromQuestion(original),
      );
      expect(pairRequest.matches(current), isFalse);
    });
  });

  group('TeacherQuestionReorderRequest', () {
    test('serializes exact immutable ordered Question IDs', () {
      final request = TeacherQuestionReorderRequest(
        questionIds: const [
          '70000000-0000-0000-0000-000000000002',
          '70000000-0000-0000-0000-000000000001',
        ],
      );

      expect(request.toJson(), {
        'question_ids': [
          '70000000-0000-0000-0000-000000000002',
          '70000000-0000-0000-0000-000000000001',
        ],
      });
      expect(request.toJson().keys, hasLength(1));
      expect(
        () => request.questionIds.add(_questionId),
        throwsUnsupportedError,
      );
    });

    test('rejects malformed and case-insensitive duplicate IDs locally', () {
      expect(
        () => TeacherQuestionReorderRequest(questionIds: const ['invalid']),
        throwsArgumentError,
      );
      expect(
        () => TeacherQuestionReorderRequest(
          questionIds: const [
            '7a000000-0000-0000-0000-000000000001',
            '7A000000-0000-0000-0000-000000000001',
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  test('Question unknown-outcome exception preserves operation identity', () {
    for (final operation in TeacherQuestionMutationOperation.values) {
      final exception = TeacherQuestionMutationOutcomeUnknownException(
        operation,
      );
      expect(exception.operation, operation);
    }
  });
}

TeacherQuestionDraft _draft(
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
            localId: 'choice-a',
            text: ' A ',
            isCorrect: true,
          ),
          TeacherChoiceOptionDraft(
            localId: 'choice-b',
            text: ' B ',
            isCorrect: type == TeacherQuestionType.multipleChoice,
          ),
        ],
      ),
    (TeacherQuestionType.trueFalse, TeacherQuestionCheckingMode.automatic) =>
      const TeacherTrueFalseConfigurationDraft(correctValue: false),
    (TeacherQuestionType.shortWritten, TeacherQuestionCheckingMode.automatic) =>
      TeacherShortWrittenConfigurationDraft(
        acceptedAnswers: const [
          TeacherAcceptedAnswerDraft(localId: 'answer-1', text: ' DNS '),
          TeacherAcceptedAnswerDraft(
            localId: 'answer-2',
            text: 'Domain Name System',
          ),
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
            localId: 'server-looking-but-local',
            left: ' DNS ',
            right: ' Domain Name System ',
          ),
          TeacherMatchingPairDraft(
            localId: 'another-local-id',
            left: 'HTTP',
            right: 'Hypertext Transfer Protocol',
          ),
        ],
      ),
    (TeacherQuestionType.ordering, TeacherQuestionCheckingMode.automatic) =>
      TeacherOrderingConfigurationDraft(
        items: const [
          TeacherOrderingItemDraft(localId: 'item-1', text: ' First '),
          TeacherOrderingItemDraft(localId: 'item-2', text: ' Second '),
        ],
      ),
    (TeacherQuestionType.fillInBlank, TeacherQuestionCheckingMode.automatic) =>
      TeacherFillInBlankConfigurationDraft(
        blanks: [
          TeacherFillBlankDraft(
            localId: 'blank-1',
            key: 'host',
            acceptedAnswers: const [
              TeacherAcceptedAnswerDraft(localId: 'host-1', text: ' server '),
            ],
          ),
          TeacherFillBlankDraft(
            localId: 'blank-2',
            key: 'address',
            acceptedAnswers: const [
              TeacherAcceptedAnswerDraft(localId: 'address-1', text: 'IP'),
            ],
          ),
        ],
      ),
    _ => throw StateError('Unsupported test draft.'),
  };
  return TeacherQuestionDraft(
    type: type,
    prompt: type == TeacherQuestionType.fillInBlank
        ? 'DNS converts {{host}} into an {{address}}.'
        : 'Question prompt',
    instructions: '',
    pointsText: '1',
    checkingMode: mode,
    configurationDraft: configuration,
  );
}

TeacherQuestion _question({String prompt = 'Pick one.', int position = 3}) {
  return TeacherQuestion(
    id: _questionId,
    type: TeacherQuestionType.singleChoice,
    prompt: prompt,
    instructions: 'Read carefully.',
    points: 1,
    position: position,
    checkingMode: TeacherQuestionCheckingMode.automatic,
    configuration: TeacherChoiceQuestionConfiguration(
      options: const [
        TeacherChoiceOption(text: 'A', isCorrect: true, position: 1),
        TeacherChoiceOption(text: 'B', isCorrect: false, position: 2),
      ],
    ),
  );
}

TeacherQuestion _shortQuestion() {
  return TeacherQuestion(
    id: _questionId,
    type: TeacherQuestionType.shortWritten,
    prompt: 'Expand DNS.',
    instructions: null,
    points: 1,
    position: 1,
    checkingMode: TeacherQuestionCheckingMode.automatic,
    configuration: TeacherShortWrittenAutomaticConfiguration(
      acceptedAnswers: const ['Domain Name System'],
    ),
  );
}

TeacherQuestion _matchingQuestion({
  required String clientKey,
  String prompt = 'Match.',
}) {
  return TeacherQuestion(
    id: _questionId,
    type: TeacherQuestionType.matching,
    prompt: prompt,
    instructions: null,
    points: 1,
    position: 1,
    checkingMode: TeacherQuestionCheckingMode.automatic,
    configuration: TeacherMatchingQuestionConfiguration(
      pairs: [
        TeacherMatchingPair(
          clientKey: clientKey,
          left: 'DNS',
          right: 'Domain Name System',
        ),
      ],
    ),
  );
}

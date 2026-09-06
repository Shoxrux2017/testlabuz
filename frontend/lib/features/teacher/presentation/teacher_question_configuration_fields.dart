import 'package:flutter/material.dart';

import '../application/teacher_question_editor_controller.dart';
import '../domain/teacher_question.dart';
import '../domain/teacher_question_authoring.dart';

class TeacherQuestionConfigurationFields extends StatelessWidget {
  const TeacherQuestionConfigurationFields({
    required this.draft,
    required this.enabled,
    required this.errorText,
    required this.focusNode,
    required this.controller,
    super.key,
  });

  final TeacherQuestionDraft draft;
  final bool enabled;
  final String? errorText;
  final FocusNode focusNode;
  final TeacherQuestionEditorController controller;

  @override
  Widget build(BuildContext context) {
    final fields = switch (draft.configurationDraft) {
      TeacherChoiceConfigurationDraft(:final options) => _ChoiceFields(
        options: options,
        multiple: draft.type == TeacherQuestionType.multipleChoice,
        enabled: enabled,
        controller: controller,
      ),
      TeacherTrueFalseConfigurationDraft(:final correctValue) =>
        _TrueFalseFields(
          correctValue: correctValue,
          enabled: enabled,
          controller: controller,
        ),
      TeacherShortWrittenConfigurationDraft(:final acceptedAnswers) =>
        _OrderedTextFields(
          heading: 'Accepted answers',
          itemName: 'Answer',
          keyPrefix: 'teacherQuestionShortAnswer',
          values: [
            for (final answer in acceptedAnswers)
              (localId: answer.localId, text: answer.text),
          ],
          maxItems: TeacherQuestionAuthoringLimits.maxShortAcceptedAnswers,
          minItems: 1,
          maxTextLength: TeacherQuestionAuthoringLimits.maxAcceptedAnswerLength,
          enabled: enabled,
          onChanged: controller.updateShortAnswer,
          onAdd: controller.addShortAnswer,
          onRemove: controller.removeShortAnswer,
          onMove: controller.moveShortAnswer,
        ),
      TeacherEmptyConfigurationDraft() => const _ManualReviewFields(),
      TeacherFileBasedConfigurationDraft() => const _FileBasedFields(),
      TeacherMatchingConfigurationDraft(:final pairs) => _MatchingFields(
        pairs: pairs,
        enabled: enabled,
        controller: controller,
      ),
      TeacherOrderingConfigurationDraft(:final items) => _OrderedTextFields(
        heading: 'Correct order',
        itemName: 'Item',
        keyPrefix: 'teacherQuestionOrderingItem',
        values: [
          for (final item in items) (localId: item.localId, text: item.text),
        ],
        maxItems: TeacherQuestionAuthoringLimits.maxOrderingItems,
        minItems: 2,
        maxTextLength: TeacherQuestionAuthoringLimits.maxOrderingItemTextLength,
        enabled: enabled,
        onChanged: controller.updateOrderingText,
        onAdd: controller.addOrderingItem,
        onRemove: controller.removeOrderingItem,
        onMove: controller.moveOrderingItem,
      ),
      TeacherFillInBlankConfigurationDraft(:final blanks) => _FillBlankFields(
        blanks: blanks,
        enabled: enabled,
        controller: controller,
      ),
    };

    return Focus(
      focusNode: focusNode,
      child: Column(
        key: const Key('teacherQuestionConfigurationSection'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Answer configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            _ConfigurationError(message: errorText!),
          ],
          const SizedBox(height: 10),
          fields,
        ],
      ),
    );
  }
}

class _ChoiceFields extends StatelessWidget {
  const _ChoiceFields({
    required this.options,
    required this.multiple,
    required this.enabled,
    required this.controller,
  });

  final List<TeacherChoiceOptionDraft> options;
  final bool multiple;
  final bool enabled;
  final TeacherQuestionEditorController controller;

  @override
  Widget build(BuildContext context) {
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < options.length; index += 1) ...[
          Card(
            key: ValueKey('teacherQuestionChoiceRow${options[index].localId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: ValueKey(
                      'teacherQuestionChoiceText${options[index].localId}',
                    ),
                    initialValue: options[index].text,
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: 'Option ${index + 1}',
                      helperText:
                          'Maximum ${TeacherQuestionAuthoringLimits.maxOptionTextLength} characters.',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        controller.updateChoiceText(index, value),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Semantics(
                        label: 'Correct Option ${index + 1}',
                        selected: options[index].isCorrect,
                        child: multiple
                            ? Checkbox(
                                key: ValueKey(
                                  'teacherQuestionChoiceCorrect${options[index].localId}',
                                ),
                                value: options[index].isCorrect,
                                onChanged: enabled
                                    ? (value) => controller.setChoiceCorrect(
                                        index,
                                        value ?? false,
                                      )
                                    : null,
                              )
                            : Radio<int>(
                                key: ValueKey(
                                  'teacherQuestionChoiceCorrect${options[index].localId}',
                                ),
                                value: index,
                                enabled: enabled,
                              ),
                      ),
                      Expanded(
                        child: Text(
                          options[index].isCorrect
                              ? 'Correct answer'
                              : 'Mark as correct',
                        ),
                      ),
                      _OrderedRowActions(
                        itemName: 'Option',
                        ordinal: index + 1,
                        enabled: enabled,
                        canMoveUp: index > 0,
                        canMoveDown: index < options.length - 1,
                        canRemove: options.length > 2,
                        onMoveUp: () => controller.moveChoiceOption(index, -1),
                        onMoveDown: () => controller.moveChoiceOption(index, 1),
                        onRemove: () => controller.removeChoiceOption(index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('teacherQuestionAddChoiceOptionButton'),
            onPressed:
                enabled &&
                    options.length <
                        TeacherQuestionAuthoringLimits.maxChoiceOptions
                ? controller.addChoiceOption
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add option'),
          ),
        ),
        if (multiple) ...[
          const SizedBox(height: 8),
          const Text(
            'Students may select up to the number of correct options.',
          ),
        ],
      ],
    );

    if (multiple) {
      return rows;
    }
    final selected = options.indexWhere((option) => option.isCorrect);
    return RadioGroup<int>(
      groupValue: selected < 0 ? null : selected,
      onChanged: enabled
          ? (index) {
              if (index != null) {
                controller.setChoiceCorrect(index, true);
              }
            }
          : (_) {},
      child: rows,
    );
  }
}

class _TrueFalseFields extends StatelessWidget {
  const _TrueFalseFields({
    required this.correctValue,
    required this.enabled,
    required this.controller,
  });

  final bool correctValue;
  final bool enabled;
  final TeacherQuestionEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Correct answer:'),
        const SizedBox(height: 8),
        Semantics(
          label: 'Correct answer',
          child: SegmentedButton<bool>(
            key: const Key('teacherQuestionTrueFalseControl'),
            segments: const [
              ButtonSegment(value: true, label: Text('True')),
              ButtonSegment(value: false, label: Text('False')),
            ],
            selected: {correctValue},
            onSelectionChanged: enabled
                ? (selection) => controller.setTrueFalseValue(selection.single)
                : null,
          ),
        ),
      ],
    );
  }
}

class _OrderedTextFields extends StatelessWidget {
  const _OrderedTextFields({
    required this.heading,
    required this.itemName,
    required this.keyPrefix,
    required this.values,
    required this.maxItems,
    required this.minItems,
    required this.maxTextLength,
    required this.enabled,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
  });

  final String heading;
  final String itemName;
  final String keyPrefix;
  final List<({String localId, String text})> values;
  final int maxItems;
  final int minItems;
  final int maxTextLength;
  final bool enabled;
  final void Function(int index, String value) onChanged;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index, int delta) onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        for (var index = 0; index < values.length; index += 1) ...[
          Card(
            key: ValueKey('$keyPrefix${values[index].localId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: ValueKey('${keyPrefix}Text${values[index].localId}'),
                    initialValue: values[index].text,
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: '$itemName ${index + 1}',
                      helperText: 'Maximum $maxTextLength characters.',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => onChanged(index, value),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _OrderedRowActions(
                      itemName: itemName,
                      ordinal: index + 1,
                      enabled: enabled,
                      canMoveUp: index > 0,
                      canMoveDown: index < values.length - 1,
                      canRemove: values.length > minItems,
                      onMoveUp: () => onMove(index, -1),
                      onMoveDown: () => onMove(index, 1),
                      onRemove: () => onRemove(index),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: Key('${keyPrefix}AddButton'),
            onPressed: enabled && values.length < maxItems ? onAdd : null,
            icon: const Icon(Icons.add),
            label: Text('Add ${itemName.toLowerCase()}'),
          ),
        ),
      ],
    );
  }
}

class _ManualReviewFields extends StatelessWidget {
  const _ManualReviewFields();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'This Question is reviewed manually.',
      key: Key('teacherQuestionManualReviewMessage'),
    );
  }
}

class _FileBasedFields extends StatelessWidget {
  const _FileBasedFields();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('teacherQuestionFileBasedConfiguration'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Allowed files:'),
        SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('PDF')),
            Chip(label: Text('DOCX')),
            Chip(label: Text('PPT')),
            Chip(label: Text('PPTX')),
          ],
        ),
        SizedBox(height: 8),
        Text('Manual review'),
      ],
    );
  }
}

class _MatchingFields extends StatelessWidget {
  const _MatchingFields({
    required this.pairs,
    required this.enabled,
    required this.controller,
  });

  final List<TeacherMatchingPairDraft> pairs;
  final bool enabled;
  final TeacherQuestionEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < pairs.length; index += 1) ...[
          Card(
            key: ValueKey('teacherQuestionMatchingPair${pairs[index].localId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: ValueKey(
                      'teacherQuestionMatchingLeft${pairs[index].localId}',
                    ),
                    initialValue: pairs[index].left,
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: 'Pair ${index + 1} left',
                      helperText:
                          'Maximum ${TeacherQuestionAuthoringLimits.maxMatchingItemTextLength} characters.',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        controller.updateMatchingLeft(index, value),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: ValueKey(
                      'teacherQuestionMatchingRight${pairs[index].localId}',
                    ),
                    initialValue: pairs[index].right,
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: 'Pair ${index + 1} right',
                      helperText:
                          'Maximum ${TeacherQuestionAuthoringLimits.maxMatchingItemTextLength} characters.',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        controller.updateMatchingRight(index, value),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _OrderedRowActions(
                      itemName: 'Pair',
                      ordinal: index + 1,
                      enabled: enabled,
                      canMoveUp: index > 0,
                      canMoveDown: index < pairs.length - 1,
                      canRemove: pairs.length > 1,
                      onMoveUp: () => controller.moveMatchingPair(index, -1),
                      onMoveDown: () => controller.moveMatchingPair(index, 1),
                      onRemove: () => controller.removeMatchingPair(index),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('teacherQuestionMatchingAddButton'),
            onPressed:
                enabled &&
                    pairs.length <
                        TeacherQuestionAuthoringLimits.maxMatchingPairs
                ? controller.addMatchingPair
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add pair'),
          ),
        ),
      ],
    );
  }
}

class _FillBlankFields extends StatelessWidget {
  const _FillBlankFields({
    required this.blanks,
    required this.enabled,
    required this.controller,
  });

  final List<TeacherFillBlankDraft> blanks;
  final bool enabled;
  final TeacherQuestionEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Use the placeholder {{key}} in the Question prompt.'),
        const SizedBox(height: 8),
        for (
          var blankIndex = 0;
          blankIndex < blanks.length;
          blankIndex += 1
        ) ...[
          Card(
            key: ValueKey(
              'teacherQuestionFillBlank${blanks[blankIndex].localId}',
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: ValueKey(
                      'teacherQuestionFillBlankKey${blanks[blankIndex].localId}',
                    ),
                    initialValue: blanks[blankIndex].key,
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: 'Blank ${blankIndex + 1} key',
                      helperText:
                          'Do not include braces. Maximum ${TeacherQuestionAuthoringLimits.maxClientKeyLength} characters.',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        controller.updateBlankKey(blankIndex, value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Accepted answers',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  for (
                    var answerIndex = 0;
                    answerIndex < blanks[blankIndex].acceptedAnswers.length;
                    answerIndex += 1
                  ) ...[
                    TextFormField(
                      key: ValueKey(
                        'teacherQuestionFillBlankAnswer'
                        '${blanks[blankIndex].acceptedAnswers[answerIndex].localId}',
                      ),
                      initialValue:
                          blanks[blankIndex].acceptedAnswers[answerIndex].text,
                      enabled: enabled,
                      decoration: InputDecoration(
                        labelText:
                            'Blank ${blankIndex + 1} answer ${answerIndex + 1}',
                        helperText:
                            'Maximum ${TeacherQuestionAuthoringLimits.maxAcceptedAnswerLength} characters.',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => controller.updateBlankAnswer(
                        blankIndex,
                        answerIndex,
                        value,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _OrderedRowActions(
                        itemName: 'Blank ${blankIndex + 1} answer',
                        ordinal: answerIndex + 1,
                        enabled: enabled,
                        canMoveUp: answerIndex > 0,
                        canMoveDown:
                            answerIndex <
                            blanks[blankIndex].acceptedAnswers.length - 1,
                        canRemove:
                            blanks[blankIndex].acceptedAnswers.length > 1,
                        onMoveUp: () => controller.moveBlankAnswer(
                          blankIndex,
                          answerIndex,
                          -1,
                        ),
                        onMoveDown: () => controller.moveBlankAnswer(
                          blankIndex,
                          answerIndex,
                          1,
                        ),
                        onRemove: () => controller.removeBlankAnswer(
                          blankIndex,
                          answerIndex,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    key: ValueKey(
                      'teacherQuestionFillBlankAddAnswer${blanks[blankIndex].localId}',
                    ),
                    onPressed:
                        enabled &&
                            blanks[blankIndex].acceptedAnswers.length <
                                TeacherQuestionAuthoringLimits
                                    .maxAcceptedAnswersPerBlank
                        ? () => controller.addBlankAnswer(blankIndex)
                        : null,
                    icon: const Icon(Icons.add),
                    label: Text('Add answer for Blank ${blankIndex + 1}'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _OrderedRowActions(
                      itemName: 'Blank',
                      ordinal: blankIndex + 1,
                      enabled: enabled,
                      canMoveUp: blankIndex > 0,
                      canMoveDown: blankIndex < blanks.length - 1,
                      canRemove: blanks.length > 1,
                      onMoveUp: () => controller.moveBlank(blankIndex, -1),
                      onMoveDown: () => controller.moveBlank(blankIndex, 1),
                      onRemove: () => controller.removeBlank(blankIndex),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('teacherQuestionFillBlankAddButton'),
            onPressed:
                enabled &&
                    blanks.length < TeacherQuestionAuthoringLimits.maxFillBlanks
                ? controller.addBlank
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add blank'),
          ),
        ),
      ],
    );
  }
}

class _OrderedRowActions extends StatelessWidget {
  const _OrderedRowActions({
    required this.itemName,
    required this.ordinal,
    required this.enabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final String itemName;
  final int ordinal;
  final bool enabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          tooltip: 'Move $itemName $ordinal up',
          onPressed: enabled && canMoveUp ? onMoveUp : null,
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          tooltip: 'Move $itemName $ordinal down',
          onPressed: enabled && canMoveDown ? onMoveDown : null,
          icon: const Icon(Icons.arrow_downward),
        ),
        IconButton(
          tooltip: 'Remove $itemName $ordinal',
          onPressed: enabled && canRemove ? onRemove : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }
}

class _ConfigurationError extends StatelessWidget {
  const _ConfigurationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        key: const Key('teacherQuestionConfigurationError'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

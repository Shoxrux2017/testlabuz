import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_question_draft_commands.dart';
import '../application/teacher_question_editor_state.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_question.dart';
import '../domain/teacher_question_authoring.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_question_configuration_fields.dart';

/// Wires the shared Question editor to one subtype editor controller.
abstract interface class TeacherQuestionEditorBinding {
  /// Assessment noun used in reconciliation copy, such as `Homework`.
  String get assessmentLabel;

  ProviderListenable<TeacherQuestionEditorState> get state;

  TeacherQuestionDraftCommands commands(WidgetRef ref);

  Future<void> submit(WidgetRef ref);

  Future<void> checkCurrent(WidgetRef ref);

  bool isCurrentRouteOwner(WidgetRef ref, TeacherSessionKey owner);
}

/// The single nine-type Question editor dialog used by every assessment type.
class TeacherQuestionEditorShell extends ConsumerStatefulWidget {
  const TeacherQuestionEditorShell({
    required this.binding,
    required this.mode,
    super.key,
  });

  final TeacherQuestionEditorBinding binding;
  final TeacherQuestionEditorMode mode;

  @override
  ConsumerState<TeacherQuestionEditorShell> createState() =>
      _TeacherQuestionEditorShellState();
}

class _TeacherQuestionEditorShellState
    extends ConsumerState<TeacherQuestionEditorShell> {
  late final TextEditingController _promptController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _pointsController;
  final _typeFocusNode = FocusNode();
  final _promptFocusNode = FocusNode();
  final _instructionsFocusNode = FocusNode();
  final _pointsFocusNode = FocusNode();
  final _checkingModeFocusNode = FocusNode();
  final _configurationFocusNode = FocusNode();
  TeacherQuestionDraftField? _handledError;
  var _closeScheduled = false;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _instructionsController = TextEditingController();
    _pointsController = TextEditingController();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _instructionsController.dispose();
    _pointsController.dispose();
    _typeFocusNode.dispose();
    _promptFocusNode.dispose();
    _instructionsFocusNode.dispose();
    _pointsFocusNode.dispose();
    _checkingModeFocusNode.dispose();
    _configurationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.binding.state);
    final commands = widget.binding.commands(ref);
    final draft = state.draft;
    if (draft != null) {
      _syncTextControllers(draft);
    }
    _handleEffects(state);

    final title = widget.mode == TeacherQuestionEditorMode.add
        ? 'Add Question'
        : 'Edit Question';

    return PopScope(
      canPop: !state.blocksNavigation && !state.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && !state.blocksNavigation) {
          await _closeWithGuard(state);
        }
      },
      child: AlertDialog(
        key: const Key('teacherQuestionEditorDialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        title: Text(title),
        content: SizedBox(
          width: 820,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.68,
            ),
            child: _buildContent(state, commands),
          ),
        ),
        actions: _buildActions(state),
      ),
    );
  }

  Widget _buildContent(
    TeacherQuestionEditorState state,
    TeacherQuestionDraftCommands controller,
  ) {
    final draft = state.draft;
    if (draft == null) {
      if (state.status == TeacherQuestionEditorStatus.loading) {
        return const Center(
          child: CircularProgressIndicator(
            key: Key('teacherQuestionEditorLoading'),
            semanticsLabel: 'Loading Question editor',
          ),
        );
      }
      return Center(
        child: Text(
          state.formError ?? 'This Question is no longer available.',
          key: const Key('teacherQuestionEditorUnavailable'),
          textAlign: TextAlign.center,
        ),
      );
    }

    final enabled = switch (state.status) {
      TeacherQuestionEditorStatus.editing ||
      TeacherQuestionEditorStatus.localValidationFailure ||
      TeacherQuestionEditorStatus.serverValidationFailure ||
      TeacherQuestionEditorStatus.definiteFailure => true,
      _ => false,
    };

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: SingleChildScrollView(
        key: const Key('teacherQuestionEditorScroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.formError != null) ...[
              _EditorMessage(
                key: const Key('teacherQuestionEditorFormMessage'),
                message: state.formError!,
                isError: state.formError != 'No changes to save.',
              ),
              const SizedBox(height: 12),
            ],
            if (state.isBusy) ...[
              _EditorMessage(
                key: const Key('teacherQuestionEditorProgressMessage'),
                message: state.status == TeacherQuestionEditorStatus.reconciling
                    ? 'Checking current ${widget.binding.assessmentLabel}'
                    : 'Saving Question',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                key: const Key('teacherQuestionEditorProgress'),
                semanticsLabel:
                    state.status == TeacherQuestionEditorStatus.reconciling
                    ? 'Checking current ${widget.binding.assessmentLabel}'
                    : 'Saving Question',
              ),
              const SizedBox(height: 12),
            ],
            Semantics(
              key: const Key('teacherQuestionTypeField'),
              label: 'Type',
              child: DropdownButtonFormField<TeacherQuestionType>(
                key: ValueKey('teacherQuestionType-${draft.type.value}'),
                focusNode: _typeFocusNode,
                initialValue: draft.type,
                decoration: InputDecoration(
                  labelText: 'Type',
                  errorText: state.fieldErrors[TeacherQuestionDraftField.type],
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final type in TeacherQuestionType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(teacherQuestionTypeLabel(type)),
                    ),
                ],
                onChanged: enabled
                    ? (type) {
                        if (type != null) {
                          _requestTypeChange(controller, type);
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('teacherQuestionPromptField'),
              controller: _promptController,
              focusNode: _promptFocusNode,
              enabled: enabled,
              decoration: InputDecoration(
                labelText: 'Prompt',
                helperText:
                    'Maximum ${TeacherQuestionAuthoringLimits.maxPromptLength} characters.',
                errorText: state.fieldErrors[TeacherQuestionDraftField.prompt],
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 8,
              onChanged: controller.updatePrompt,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('teacherQuestionInstructionsField'),
              controller: _instructionsController,
              focusNode: _instructionsFocusNode,
              enabled: enabled,
              decoration: InputDecoration(
                labelText: 'Instructions',
                helperText:
                    'Optional. Maximum ${TeacherQuestionAuthoringLimits.maxInstructionsLength} characters.',
                errorText:
                    state.fieldErrors[TeacherQuestionDraftField.instructions],
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 6,
              onChanged: controller.updateInstructions,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('teacherQuestionPointsField'),
              controller: _pointsController,
              focusNode: _pointsFocusNode,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Points',
                helperText: 'Use up to 6 decimal places.',
                errorText: state.fieldErrors[TeacherQuestionDraftField.points],
                border: const OutlineInputBorder(),
              ),
              onChanged: controller.updatePoints,
            ),
            const SizedBox(height: 18),
            _CheckingModeFields(
              draft: draft,
              enabled: enabled,
              focusNode: _checkingModeFocusNode,
              errorText:
                  state.fieldErrors[TeacherQuestionDraftField.checkingMode],
              onChanged: (mode) => _requestCheckingModeChange(controller, mode),
            ),
            const SizedBox(height: 18),
            TeacherQuestionConfigurationFields(
              draft: draft,
              enabled: enabled,
              errorText:
                  state.fieldErrors[TeacherQuestionDraftField.configuration],
              focusNode: _configurationFocusNode,
              controller: controller,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(TeacherQuestionEditorState state) {
    return [
      if (state.status == TeacherQuestionEditorStatus.outcomeReview)
        FilledButton.icon(
          key: const Key('teacherQuestionEditorCheckCurrentButton'),
          onPressed: state.isBusy
              ? null
              : () => widget.binding.checkCurrent(ref),
          icon: const Icon(Icons.sync),
          label: Text('Check current ${widget.binding.assessmentLabel}'),
        ),
      TextButton(
        key: const Key('teacherQuestionEditorCancelButton'),
        onPressed: state.blocksNavigation ? null : () => _closeWithGuard(state),
        child: const Text('Cancel'),
      ),
      if (state.draft != null &&
          state.status != TeacherQuestionEditorStatus.unavailable &&
          state.status != TeacherQuestionEditorStatus.lockedReview &&
          state.status != TeacherQuestionEditorStatus.outcomeReview)
        FilledButton.icon(
          key: const Key('teacherQuestionEditorSubmitButton'),
          onPressed: state.canSubmit ? () => widget.binding.submit(ref) : null,
          icon: state.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
    ];
  }

  Future<void> _requestTypeChange(
    TeacherQuestionDraftCommands controller,
    TeacherQuestionType type,
  ) async {
    final owner = _currentSessionOwner();
    if (owner == null || !_isCurrentSessionOwner(owner)) {
      return;
    }
    controller.requestTypeChange(type);
    final state = ref.read(widget.binding.state);
    if (state.pendingType == null) {
      return;
    }
    final change = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Question type?'),
        content: const Text(
          'Changing the type will reset its answer configuration.',
        ),
        actions: [
          TextButton(
            key: const Key('teacherQuestionKeepTypeButton'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep current type'),
          ),
          FilledButton(
            key: const Key('teacherQuestionConfirmTypeButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change type'),
          ),
        ],
      ),
    );
    if (!_isCurrentSessionOwner(owner)) {
      return;
    }
    if (change == true) {
      controller.confirmTypeChange();
    } else {
      controller.cancelTypeChange();
    }
  }

  Future<void> _requestCheckingModeChange(
    TeacherQuestionDraftCommands controller,
    TeacherQuestionCheckingMode mode,
  ) async {
    final owner = _currentSessionOwner();
    if (owner == null || !_isCurrentSessionOwner(owner)) {
      return;
    }
    controller.requestCheckingModeChange(mode);
    final state = ref.read(widget.binding.state);
    if (state.pendingCheckingMode == null) {
      return;
    }
    final change = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change checking mode?'),
        content: const Text(
          'Changing to Manual will remove the accepted-answer configuration.',
        ),
        actions: [
          TextButton(
            key: const Key('teacherQuestionKeepCheckingModeButton'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Automatic'),
          ),
          FilledButton(
            key: const Key('teacherQuestionConfirmCheckingModeButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change to Manual'),
          ),
        ],
      ),
    );
    if (!_isCurrentSessionOwner(owner)) {
      return;
    }
    if (change == true) {
      controller.confirmCheckingModeChange();
    } else {
      controller.cancelCheckingModeChange();
    }
  }

  Future<void> _closeWithGuard(TeacherQuestionEditorState state) async {
    if (state.blocksNavigation) {
      return;
    }
    final owner = _currentSessionOwner();
    if (owner == null || !_isCurrentSessionOwner(owner)) {
      return;
    }
    if (state.isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Question changes?'),
          actions: [
            TextButton(
              key: const Key('teacherQuestionKeepEditingButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('teacherQuestionDiscardChangesButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !_isCurrentSessionOwner(owner)) {
        return;
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleEffects(TeacherQuestionEditorState state) {
    if (!state.shouldClose) {
      _closeScheduled = false;
    } else if (!_closeScheduled) {
      final dialogRoute = ModalRoute.of(context);
      _closeScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final latest = ref.read(widget.binding.state);
        final navigator = dialogRoute?.navigator;
        if (!latest.shouldClose || dialogRoute == null || navigator == null) {
          _closeScheduled = false;
          return;
        }
        if (dialogRoute.isCurrent) {
          if (!navigator.canPop()) {
            _closeScheduled = false;
            return;
          }
          navigator.pop();
          return;
        }
        if (dialogRoute.isActive) {
          navigator.removeRoute(dialogRoute);
          return;
        }
        _closeScheduled = false;
      });
    }

    final firstError = state.fieldErrors.isEmpty
        ? null
        : state.fieldErrors.keys.first;
    if (firstError != null && firstError != _handledError) {
      _handledError = firstError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusFor(firstError).requestFocus();
        }
      });
    } else if (firstError == null) {
      _handledError = null;
    }
  }

  FocusNode _focusFor(TeacherQuestionDraftField field) => switch (field) {
    TeacherQuestionDraftField.type => _typeFocusNode,
    TeacherQuestionDraftField.prompt => _promptFocusNode,
    TeacherQuestionDraftField.instructions => _instructionsFocusNode,
    TeacherQuestionDraftField.points => _pointsFocusNode,
    TeacherQuestionDraftField.checkingMode => _checkingModeFocusNode,
    TeacherQuestionDraftField.configuration => _configurationFocusNode,
  };

  void _syncTextControllers(TeacherQuestionDraft draft) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _setText(_promptController, draft.prompt);
      _setText(_instructionsController, draft.instructions);
      _setText(_pointsController, draft.pointsText);
    });
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  TeacherSessionKey? _currentSessionOwner() {
    return TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
  }

  bool _isCurrentSessionOwner(TeacherSessionKey owner) {
    return mounted &&
        _currentSessionOwner() == owner &&
        widget.binding.isCurrentRouteOwner(ref, owner);
  }
}

class _CheckingModeFields extends StatelessWidget {
  const _CheckingModeFields({
    required this.draft,
    required this.enabled,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
  });

  final TeacherQuestionDraft draft;
  final bool enabled;
  final FocusNode focusNode;
  final String? errorText;
  final ValueChanged<TeacherQuestionCheckingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Checking behavior',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (draft.type == TeacherQuestionType.shortWritten)
            Semantics(
              label: 'Checking',
              child: SegmentedButton<TeacherQuestionCheckingMode>(
                key: const Key('teacherQuestionCheckingModeControl'),
                segments: const [
                  ButtonSegment(
                    value: TeacherQuestionCheckingMode.automatic,
                    label: Text('Automatic'),
                  ),
                  ButtonSegment(
                    value: TeacherQuestionCheckingMode.manual,
                    label: Text('Manual'),
                  ),
                ],
                selected: {draft.checkingMode},
                onSelectionChanged: enabled
                    ? (selection) => onChanged(selection.single)
                    : null,
              ),
            )
          else
            InputChip(
              key: const Key('teacherQuestionFixedCheckingMode'),
              label: Text(teacherQuestionCheckingModeLabel(draft.checkingMode)),
              onPressed: null,
            ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Text(
              errorText!,
              key: const Key('teacherQuestionCheckingModeError'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorMessage extends StatelessWidget {
  const _EditorMessage({
    required this.message,
    this.isError = false,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: isError ? colors.errorContainer : colors.secondaryContainer,
        child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      ),
    );
  }
}

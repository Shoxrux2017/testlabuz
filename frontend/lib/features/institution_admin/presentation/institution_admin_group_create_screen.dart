import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../application/institution_group_create_controller.dart';
import '../application/institution_group_create_state.dart';
import '../domain/institution_group_create.dart';

const _createPadding = 24.0;
const _createMaxWidth = 720.0;

class InstitutionAdminGroupCreateScreen extends ConsumerStatefulWidget {
  const InstitutionAdminGroupCreateScreen({super.key});

  @override
  ConsumerState<InstitutionAdminGroupCreateScreen> createState() =>
      _InstitutionAdminGroupCreateScreenState();
}

class _InstitutionAdminGroupCreateScreenState
    extends ConsumerState<InstitutionAdminGroupCreateScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _levelController;
  late final TextEditingController _subjectDirectionController;
  late final TextEditingController _descriptionController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _levelFocusNode;
  late final FocusNode _subjectDirectionFocusNode;
  late final FocusNode _descriptionFocusNode;
  InstitutionGroupCreateField? _handledFirstError;
  String? _handledSuccessGroupId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _levelController = TextEditingController();
    _subjectDirectionController = TextEditingController();
    _descriptionController = TextEditingController();
    _nameFocusNode = FocusNode();
    _levelFocusNode = FocusNode();
    _subjectDirectionFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    ref.read(institutionGroupCreateControllerProvider.notifier).enterRoute();
  }

  @override
  void dispose() {
    _clearControllers();
    _nameController.dispose();
    _levelController.dispose();
    _subjectDirectionController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _levelFocusNode.dispose();
    _subjectDirectionFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(institutionGroupCreateControllerProvider);
    final controller = ref.read(
      institutionGroupCreateControllerProvider.notifier,
    );
    _handleEffects(state);
    _syncControllers(state.form);

    return PopScope(
      canPop: !state.isRouteBlocking,
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Semantics(
          key: const Key('institutionAdminGroupCreateScreen'),
          container: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(_createPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _createMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Create Group',
                        key: const Key('institutionGroupCreateHeading'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (state.isUnknown)
                      _UnknownGroupCreateOutcome(
                        onReviewRecentGroups: () {
                          if (controller.reviewRecentGroups()) {
                            _clearControllers();
                            context.goNamed(
                              AppRouteNames.institutionAdminGroups,
                            );
                          }
                        },
                      )
                    else
                      _CreateGroupForm(
                        state: state,
                        nameController: _nameController,
                        levelController: _levelController,
                        subjectDirectionController: _subjectDirectionController,
                        descriptionController: _descriptionController,
                        nameFocusNode: _nameFocusNode,
                        levelFocusNode: _levelFocusNode,
                        subjectDirectionFocusNode: _subjectDirectionFocusNode,
                        descriptionFocusNode: _descriptionFocusNode,
                        onNameChanged: controller.updateName,
                        onLevelChanged: controller.updateLevel,
                        onSubjectDirectionChanged:
                            controller.updateSubjectDirection,
                        onDescriptionChanged: controller.updateDescription,
                        onCancel: state.isRouteBlocking
                            ? null
                            : () {
                                controller.leaveRoute();
                                _clearControllers();
                                context.goNamed(
                                  AppRouteNames.institutionAdminGroups,
                                );
                              },
                        onSubmit: state.canSubmit ? controller.submit : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleEffects(InstitutionGroupCreateState state) {
    final firstError = state.firstErrorField;
    if (firstError != null && firstError != _handledFirstError) {
      _handledFirstError = firstError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNodeFor(firstError).requestFocus();
        }
      });
    } else if (firstError == null) {
      _handledFirstError = null;
    }

    final groupId = state.confirmedGroupId;
    if (groupId != null && groupId != _handledSuccessGroupId) {
      _handledSuccessGroupId = groupId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref
                    .read(institutionGroupCreateControllerProvider)
                    .confirmedGroupId !=
                groupId) {
          return;
        }
        _clearControllers();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              key: Key('institutionGroupCreateSuccessSnackBar'),
              content: Text('Group created successfully.'),
            ),
          );
        context.goNamed(
          AppRouteNames.institutionAdminGroupDetail,
          pathParameters: {
            AppRoutePaths.institutionAdminGroupIdParameter: groupId,
          },
        );
      });
    }
  }

  void _syncControllers(InstitutionGroupCreateFormValue form) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _setText(_nameController, form.name);
      _setText(_levelController, form.level);
      _setText(_subjectDirectionController, form.subjectDirection);
      _setText(_descriptionController, form.description);
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

  FocusNode _focusNodeFor(InstitutionGroupCreateField field) {
    return switch (field) {
      InstitutionGroupCreateField.name => _nameFocusNode,
      InstitutionGroupCreateField.level => _levelFocusNode,
      InstitutionGroupCreateField.subjectDirection =>
        _subjectDirectionFocusNode,
      InstitutionGroupCreateField.description => _descriptionFocusNode,
    };
  }

  void _clearControllers() {
    _nameController.clear();
    _levelController.clear();
    _subjectDirectionController.clear();
    _descriptionController.clear();
  }
}

class _CreateGroupForm extends StatelessWidget {
  const _CreateGroupForm({
    required this.state,
    required this.nameController,
    required this.levelController,
    required this.subjectDirectionController,
    required this.descriptionController,
    required this.nameFocusNode,
    required this.levelFocusNode,
    required this.subjectDirectionFocusNode,
    required this.descriptionFocusNode,
    required this.onNameChanged,
    required this.onLevelChanged,
    required this.onSubjectDirectionChanged,
    required this.onDescriptionChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final InstitutionGroupCreateState state;
  final TextEditingController nameController;
  final TextEditingController levelController;
  final TextEditingController subjectDirectionController;
  final TextEditingController descriptionController;
  final FocusNode nameFocusNode;
  final FocusNode levelFocusNode;
  final FocusNode subjectDirectionFocusNode;
  final FocusNode descriptionFocusNode;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onSubjectDirectionChanged;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final canEdit = state.canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.formError case final message?) ...[
          _GroupCreateMessage(
            key: const Key('institutionGroupCreateFormError'),
            message: message,
            isError: true,
          ),
          const SizedBox(height: 16),
        ],
        if (state.status == InstitutionGroupCreateStatus.submitting ||
            state.status ==
                InstitutionGroupCreateStatus.reconcilingUnknown) ...[
          const _GroupCreateMessage(
            key: Key('institutionGroupCreateBusy'),
            message: 'Creating group',
            isError: false,
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          key: const Key('institutionGroupCreateNameField'),
          controller: nameController,
          focusNode: nameFocusNode,
          enabled: canEdit,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: onNameChanged,
          onSubmitted: (_) => levelFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Name',
            errorText: state.errorTextFor(InstitutionGroupCreateField.name),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('institutionGroupCreateLevelField'),
          controller: levelController,
          focusNode: levelFocusNode,
          enabled: canEdit,
          textInputAction: TextInputAction.next,
          onChanged: onLevelChanged,
          onSubmitted: (_) => subjectDirectionFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Level',
            errorText: state.errorTextFor(InstitutionGroupCreateField.level),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('institutionGroupCreateSubjectDirectionField'),
          controller: subjectDirectionController,
          focusNode: subjectDirectionFocusNode,
          enabled: canEdit,
          textInputAction: TextInputAction.next,
          onChanged: onSubjectDirectionChanged,
          onSubmitted: (_) => descriptionFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Subject direction',
            errorText: state.errorTextFor(
              InstitutionGroupCreateField.subjectDirection,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('institutionGroupCreateDescriptionField'),
          controller: descriptionController,
          focusNode: descriptionFocusNode,
          enabled: canEdit,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 4,
          maxLines: 8,
          onChanged: onDescriptionChanged,
          decoration: InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
            errorText: state.errorTextFor(
              InstitutionGroupCreateField.description,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            TextButton(
              key: const Key('institutionGroupCreateCancelButton'),
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('institutionGroupCreateSubmitButton'),
              onPressed: onSubmit,
              icon: state.status == InstitutionGroupCreateStatus.submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add_outlined),
              label: const Text('Create Group'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupCreateMessage extends StatelessWidget {
  const _GroupCreateMessage({
    required super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.error : colors.primary;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.hourglass_top,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnknownGroupCreateOutcome extends StatelessWidget {
  const _UnknownGroupCreateOutcome({required this.onReviewRecentGroups});

  final VoidCallback onReviewRecentGroups;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('institutionGroupCreateUnknownOutcome'),
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Creation outcome unknown',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Group creation could not be confirmed. The request may have succeeded. Review recent groups before creating another group.',
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key(
                    'institutionGroupCreateReviewRecentGroupsButton',
                  ),
                  onPressed: onReviewRecentGroups,
                  child: const Text('Review recent groups'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

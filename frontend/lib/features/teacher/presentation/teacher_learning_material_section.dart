import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_material_file_picker.dart';
import '../application/teacher_material_list_controller.dart';
import '../application/teacher_material_list_state.dart';
import '../application/teacher_material_mutation_activity.dart';
import '../application/teacher_material_mutation_controller.dart';
import '../application/teacher_material_mutation_state.dart';
import '../application/teacher_material_transfer_controller.dart';
import '../application/teacher_material_transfer_state.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_learning_material.dart';
import '../domain/teacher_learning_material_mutation.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_mutation.dart';

class TeacherLearningMaterialSection extends ConsumerWidget {
  const TeacherLearningMaterialSection({
    required this.topic,
    required this.lifecycleBusy,
    super.key,
  });

  final TeacherTopic topic;
  final bool lifecycleBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listProvider = teacherMaterialListControllerProvider(topic.id);
    final mutationProvider = teacherMaterialMutationControllerProvider(
      topic.id,
    );
    final transferProvider = teacherMaterialTransferControllerProvider(
      topic.id,
    );
    final list = ref.watch(listProvider);
    final mutation = ref.watch(mutationProvider);
    final activity = ref.watch(
      teacherMaterialMutationActivityProvider(topic.id),
    );
    final transfer = ref.watch(transferProvider);

    ref.listen<String?>(mutationProvider.select((state) => state.feedback), (
      _,
      feedback,
    ) {
      if (feedback == null || !context.mounted) {
        return;
      }
      _showFeedback(context, feedback);
      ref.read(mutationProvider.notifier).consumeFeedback();
    });
    ref.listen<String?>(transferProvider.select((state) => state.feedback), (
      _,
      feedback,
    ) {
      if (feedback == null || !context.mounted) {
        return;
      }
      _showFeedback(context, feedback);
      ref.read(transferProvider.notifier).consumeFeedback();
    });

    final collection = list.collection;
    final materialMutationsEnabled =
        teacherTopicCanEdit(topic) &&
        !lifecycleBusy &&
        !mutation.isBusy &&
        !activity.isActive;

    return Card(
      key: const Key('teacherLearningMaterialsSection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Learning Materials',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('teacherMaterialsRefreshButton'),
                  tooltip: 'Refresh learning materials',
                  onPressed: list.isLoading || mutation.isBusy
                      ? null
                      : ref.read(listProvider.notifier).refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (list.isLoading || mutation.isBusy) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                label: mutation.isBusy
                    ? 'Updating learning materials'
                    : 'Loading learning materials',
                child: LinearProgressIndicator(
                  key: const Key('teacherMaterialsBusyProgress'),
                  value:
                      mutation.status ==
                              TeacherMaterialMutationStatus.submitting &&
                          mutation.totalBytes > 0
                      ? mutation.progress
                      : null,
                ),
              ),
            ],
            if (list.isStale || list.failure != null) ...[
              const SizedBox(height: 10),
              Text(
                list.isStale
                    ? 'The displayed materials may be out of date. Refresh to check current materials.'
                    : 'Learning materials could not be loaded.',
                key: const Key('teacherMaterialsStaleMessage'),
              ),
            ],
            const SizedBox(height: 10),
            switch (list.status) {
              TeacherMaterialListStatus.initial ||
              TeacherMaterialListStatus.loading => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    key: Key('teacherMaterialsLoading'),
                    semanticsLabel: 'Loading learning materials',
                  ),
                ),
              ),
              TeacherMaterialListStatus.error => _MaterialListError(
                onRetry: ref.read(listProvider.notifier).refresh,
              ),
              TeacherMaterialListStatus.data ||
              TeacherMaterialListStatus.refreshing => _MaterialListContent(
                topic: topic,
                collection: collection!,
                mutationActionsVisible: teacherTopicCanEdit(topic),
                mutationsEnabled: materialMutationsEnabled,
                activity: activity,
                transfer: transfer,
                onUpload: () => _showUploadDialog(context, ref, topic.id),
                onReplace: (material) =>
                    _showReplaceDialog(context, ref, topic, material),
                onEditTitle: (material) =>
                    _showEditTitleDialog(context, ref, topic.id, material),
                onRemove: (material) =>
                    _confirmRemove(context, ref, topic.id, material),
                onSaveAs: ref.read(transferProvider.notifier).saveAs,
                onOpen: ref.read(transferProvider.notifier).open,
                onCheckCurrent: mutation.canCheckCurrent
                    ? ref.read(mutationProvider.notifier).checkCurrentMaterials
                    : null,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _MaterialListContent extends StatelessWidget {
  const _MaterialListContent({
    required this.topic,
    required this.collection,
    required this.mutationActionsVisible,
    required this.mutationsEnabled,
    required this.activity,
    required this.transfer,
    required this.onUpload,
    required this.onReplace,
    required this.onEditTitle,
    required this.onRemove,
    required this.onSaveAs,
    required this.onOpen,
    required this.onCheckCurrent,
  });

  final TeacherTopic topic;
  final TeacherLearningMaterialCollection collection;
  final bool mutationActionsVisible;
  final bool mutationsEnabled;
  final TeacherMaterialMutationActivityState activity;
  final TeacherMaterialTransferState transfer;
  final VoidCallback onUpload;
  final ValueChanged<TeacherLearningMaterial> onReplace;
  final ValueChanged<TeacherLearningMaterial> onEditTitle;
  final ValueChanged<TeacherLearningMaterial> onRemove;
  final ValueChanged<TeacherLearningMaterial> onSaveAs;
  final ValueChanged<TeacherLearningMaterial> onOpen;
  final VoidCallback? onCheckCurrent;

  @override
  Widget build(BuildContext context) {
    final capability = collection.uploadCapability;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Allowed: PDF, DOCX, PPT, PPTX\n'
          'Maximum size: ${formatTeacherMaterialBytes(capability.maxSizeBytes)}',
          key: const Key('teacherMaterialUploadCapability'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (teacherTopicCanEdit(topic))
              FilledButton.icon(
                key: const Key('teacherMaterialUploadButton'),
                onPressed: mutationsEnabled ? onUpload : null,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload material'),
              ),
            if (onCheckCurrent != null)
              OutlinedButton.icon(
                key: const Key('teacherMaterialsCheckCurrentButton'),
                onPressed: onCheckCurrent,
                icon: const Icon(Icons.sync),
                label: const Text('Check current materials'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (collection.materials.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No learning materials are currently available.',
              key: Key('teacherMaterialsEmpty'),
            ),
          )
        else
          for (var index = 0; index < collection.materials.length; index++) ...[
            if (index > 0) const Divider(height: 24),
            _MaterialRow(
              material: collection.materials[index],
              mutationActionsVisible: mutationActionsVisible,
              mutationsEnabled: mutationsEnabled,
              activity: activity,
              transfer: transfer,
              onReplace: onReplace,
              onEditTitle: onEditTitle,
              onRemove: onRemove,
              onSaveAs: onSaveAs,
              onOpen: onOpen,
            ),
          ],
      ],
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.mutationActionsVisible,
    required this.mutationsEnabled,
    required this.activity,
    required this.transfer,
    required this.onReplace,
    required this.onEditTitle,
    required this.onRemove,
    required this.onSaveAs,
    required this.onOpen,
  });

  final TeacherLearningMaterial material;
  final bool mutationActionsVisible;
  final bool mutationsEnabled;
  final TeacherMaterialMutationActivityState activity;
  final TeacherMaterialTransferState transfer;
  final ValueChanged<TeacherLearningMaterial> onReplace;
  final ValueChanged<TeacherLearningMaterial> onEditTitle;
  final ValueChanged<TeacherLearningMaterial> onRemove;
  final ValueChanged<TeacherLearningMaterial> onSaveAs;
  final ValueChanged<TeacherLearningMaterial> onOpen;

  @override
  Widget build(BuildContext context) {
    final transferBusy = transfer.isBusyForMaterial(material.id);
    final transferBlocked = activity.blocksTransfer(material.id);
    return Column(
      key: ValueKey('teacherMaterial${material.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          material.displayName,
          key: ValueKey('teacherMaterialName${material.id}'),
          softWrap: true,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (material.title != null) ...[
          const SizedBox(height: 3),
          Text(material.file.originalName, softWrap: true),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(material.file.extension.toUpperCase())),
            Chip(
              label: Text(formatTeacherMaterialBytes(material.file.sizeBytes)),
            ),
          ],
        ),
        if (transferBusy) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            label: 'Downloading ${material.displayName}',
            child: LinearProgressIndicator(
              key: ValueKey('teacherMaterialTransferProgress${material.id}'),
              value: transfer.progress,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: ValueKey('teacherMaterialOpen${material.id}'),
              onPressed: transferBusy || transferBlocked
                  ? null
                  : () => onOpen(material),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open'),
            ),
            OutlinedButton.icon(
              key: ValueKey('teacherMaterialSave${material.id}'),
              onPressed: transferBusy || transferBlocked
                  ? null
                  : () => onSaveAs(material),
              icon: const Icon(Icons.save_alt),
              label: const Text('Save as…'),
            ),
            if (mutationActionsVisible) ...[
              TextButton.icon(
                key: ValueKey('teacherMaterialReplace${material.id}'),
                onPressed: !mutationsEnabled || transferBusy
                    ? null
                    : () => onReplace(material),
                icon: const Icon(Icons.change_circle_outlined),
                label: const Text('Replace file'),
              ),
              TextButton.icon(
                key: ValueKey('teacherMaterialEditTitle${material.id}'),
                onPressed: mutationsEnabled
                    ? () => onEditTitle(material)
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit title'),
              ),
              TextButton.icon(
                key: ValueKey('teacherMaterialRemove${material.id}'),
                onPressed: !mutationsEnabled || transferBusy
                    ? null
                    : () => onRemove(material),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Remove material'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _MaterialListError extends StatelessWidget {
  const _MaterialListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Learning materials could not be loaded.',
          key: Key('teacherMaterialsError'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('teacherMaterialsRetryButton'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _UploadMaterialDialog extends ConsumerStatefulWidget {
  const _UploadMaterialDialog({required this.topicId, required this.owner});

  final String topicId;
  final TeacherSessionKey owner;

  @override
  ConsumerState<_UploadMaterialDialog> createState() =>
      _UploadMaterialDialogState();
}

class _UploadMaterialDialogState extends ConsumerState<_UploadMaterialDialog> {
  final _titleController = TextEditingController();
  final _titleFocus = FocusNode();
  final _fileFocus = FocusNode();
  TeacherMaterialUploadFile? _file;
  String? _pickerError;

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    _fileFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_stillOwned()) {
      _closeStaleDialog(context);
      return const SizedBox.shrink();
    }
    final mutation = ref.watch(
      teacherMaterialMutationControllerProvider(widget.topicId),
    );
    final capability = ref
        .watch(teacherMaterialListControllerProvider(widget.topicId))
        .collection!
        .uploadCapability;
    final fileError = _pickerError ?? mutation.fieldErrors['file'];
    return AlertDialog(
      key: const Key('teacherMaterialUploadDialog'),
      title: const Text('Upload material'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                key: const Key('teacherMaterialChooseFileButton'),
                focusNode: _fileFocus,
                onPressed: mutation.isBusy ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_file?.name ?? 'Choose file *'),
              ),
              if (fileError != null) _FieldError(fileError),
              const SizedBox(height: 8),
              TextField(
                key: const Key('teacherMaterialUploadTitleField'),
                controller: _titleController,
                focusNode: _titleFocus,
                maxLength: TeacherMaterialMutationController.titleMaxLength,
                decoration: InputDecoration(
                  labelText: 'Title (optional)',
                  helperText:
                      'Leave the title empty to use the original file name.',
                  errorText: mutation.fieldErrors['title'],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Allowed: PDF, DOCX, PPT, PPTX\n'
                'Maximum size: ${formatTeacherMaterialBytes(capability.maxSizeBytes)}',
              ),
              if (mutation.fieldErrors['form'] case final error?)
                _FieldError(error),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: mutation.isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherMaterialUploadSubmitButton'),
          onPressed: mutation.isBusy ? null : _submit,
          child: const Text('Upload'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final file = await ref.read(teacherMaterialFilePickerProvider).pickFile();
      if (!mounted || file == null || !_stillOwned()) {
        return;
      }
      setState(() {
        _file = file;
        _pickerError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _pickerError = 'The file picker could not be opened.');
      }
    }
  }

  Future<void> _submit() async {
    if (!_stillOwned()) {
      Navigator.of(context).pop();
      return;
    }
    final file = _file;
    if (file == null) {
      setState(() => _pickerError = 'Select a file.');
      _fileFocus.requestFocus();
      return;
    }
    final controller = ref.read(
      teacherMaterialMutationControllerProvider(widget.topicId).notifier,
    );
    final success = await controller.uploadMaterial(
      file: file,
      title: _titleController.text,
    );
    if (!mounted) {
      return;
    }
    final state = ref.read(
      teacherMaterialMutationControllerProvider(widget.topicId),
    );
    if (success) {
      Navigator.of(context).pop();
    } else {
      _focusFirstError(state);
    }
  }

  void _focusFirstError(TeacherMaterialMutationState state) {
    if (state.fieldErrors.containsKey('file')) {
      _fileFocus.requestFocus();
    } else if (state.fieldErrors.containsKey('title')) {
      _titleFocus.requestFocus();
    }
  }

  bool _stillOwned() => _currentOwner(ref) == widget.owner;
}

class _ReplaceMaterialDialog extends ConsumerStatefulWidget {
  const _ReplaceMaterialDialog({
    required this.topic,
    required this.material,
    required this.owner,
  });

  final TeacherTopic topic;
  final TeacherLearningMaterial material;
  final TeacherSessionKey owner;

  @override
  ConsumerState<_ReplaceMaterialDialog> createState() =>
      _ReplaceMaterialDialogState();
}

class _ReplaceMaterialDialogState
    extends ConsumerState<_ReplaceMaterialDialog> {
  final _fileFocus = FocusNode();
  TeacherMaterialUploadFile? _file;
  String? _pickerError;

  @override
  void dispose() {
    _fileFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_stillOwned()) {
      _closeStaleDialog(context);
      return const SizedBox.shrink();
    }
    final mutation = ref.watch(
      teacherMaterialMutationControllerProvider(widget.topic.id),
    );
    final capability = ref
        .watch(teacherMaterialListControllerProvider(widget.topic.id))
        .collection!
        .uploadCapability;
    return AlertDialog(
      key: const Key('teacherMaterialReplaceDialog'),
      title: const Text('Replace this file?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.topic.status == TeacherTopicStatus.active) ...[
              const Text(
                'Students may already be using this material. The current file will be replaced.',
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              key: const Key('teacherMaterialReplaceChooseFileButton'),
              focusNode: _fileFocus,
              onPressed: mutation.isBusy ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_file?.name ?? 'Choose replacement file *'),
            ),
            if (_pickerError ?? mutation.fieldErrors['file'] case final error?)
              _FieldError(error),
            const SizedBox(height: 8),
            Text(
              'Allowed: PDF, DOCX, PPT, PPTX\n'
              'Maximum size: ${formatTeacherMaterialBytes(capability.maxSizeBytes)}',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: mutation.isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherMaterialReplaceConfirmButton'),
          onPressed: mutation.isBusy ? null : _submit,
          child: const Text('Replace file'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final file = await ref.read(teacherMaterialFilePickerProvider).pickFile();
      if (!mounted || file == null || !_stillOwned()) {
        return;
      }
      setState(() {
        _file = file;
        _pickerError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _pickerError = 'The file picker could not be opened.');
      }
    }
  }

  Future<void> _submit() async {
    if (!_stillOwned()) {
      Navigator.of(context).pop();
      return;
    }
    final file = _file;
    if (file == null) {
      setState(() => _pickerError = 'Select a replacement file.');
      _fileFocus.requestFocus();
      return;
    }
    final success = await ref
        .read(
          teacherMaterialMutationControllerProvider(widget.topic.id).notifier,
        )
        .replaceMaterialFile(current: widget.material, file: file);
    if (success && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      _fileFocus.requestFocus();
    }
  }

  bool _stillOwned() => _currentOwner(ref) == widget.owner;
}

class _EditMaterialTitleDialog extends ConsumerStatefulWidget {
  const _EditMaterialTitleDialog({
    required this.topicId,
    required this.material,
    required this.owner,
  });

  final String topicId;
  final TeacherLearningMaterial material;
  final TeacherSessionKey owner;

  @override
  ConsumerState<_EditMaterialTitleDialog> createState() =>
      _EditMaterialTitleDialogState();
}

class _EditMaterialTitleDialogState
    extends ConsumerState<_EditMaterialTitleDialog> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  late bool _useOriginal;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.material.title ?? '');
    _useOriginal = widget.material.title == null;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentOwner(ref) != widget.owner) {
      _closeStaleDialog(context);
      return const SizedBox.shrink();
    }
    final mutation = ref.watch(
      teacherMaterialMutationControllerProvider(widget.topicId),
    );
    return AlertDialog(
      key: const Key('teacherMaterialEditTitleDialog'),
      title: const Text('Edit title'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('teacherMaterialEditTitleField'),
              controller: _controller,
              focusNode: _focus,
              enabled: !_useOriginal && !mutation.isBusy,
              autofocus: !_useOriginal,
              maxLength: TeacherMaterialMutationController.titleMaxLength,
              decoration: InputDecoration(
                labelText: 'Title',
                errorText: mutation.fieldErrors['title'],
              ),
            ),
            CheckboxListTile(
              key: const Key('teacherMaterialUseOriginalNameCheckbox'),
              value: _useOriginal,
              contentPadding: EdgeInsets.zero,
              title: const Text('Use original file name'),
              onChanged: mutation.isBusy
                  ? null
                  : (value) => setState(() => _useOriginal = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: mutation.isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherMaterialEditTitleSaveButton'),
          onPressed: mutation.isBusy ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_currentOwner(ref) != widget.owner) {
      Navigator.of(context).pop();
      return;
    }
    final provider = teacherMaterialMutationControllerProvider(widget.topicId);
    final success = await ref
        .read(provider.notifier)
        .updateMaterialTitle(
          current: widget.material,
          title: _controller.text,
          useOriginalFileName: _useOriginal,
        );
    if (!mounted) {
      return;
    }
    final state = ref.read(provider);
    if (success || state.status == TeacherMaterialMutationStatus.noChanges) {
      Navigator.of(context).pop();
    } else if (state.fieldErrors.containsKey('title')) {
      _focus.requestFocus();
    }
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

Future<void> _showUploadDialog(
  BuildContext context,
  WidgetRef ref,
  String topicId,
) async {
  final owner = _currentOwner(ref);
  if (owner == null) {
    return;
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UploadMaterialDialog(topicId: topicId, owner: owner),
  );
}

Future<void> _showReplaceDialog(
  BuildContext context,
  WidgetRef ref,
  TeacherTopic topic,
  TeacherLearningMaterial material,
) async {
  final owner = _currentOwner(ref);
  if (owner == null) {
    return;
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ReplaceMaterialDialog(topic: topic, material: material, owner: owner),
  );
}

Future<void> _showEditTitleDialog(
  BuildContext context,
  WidgetRef ref,
  String topicId,
  TeacherLearningMaterial material,
) async {
  final owner = _currentOwner(ref);
  if (owner == null) {
    return;
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EditMaterialTitleDialog(
      topicId: topicId,
      material: material,
      owner: owner,
    ),
  );
}

Future<void> _confirmRemove(
  BuildContext context,
  WidgetRef ref,
  String topicId,
  TeacherLearningMaterial material,
) async {
  final owner = _currentOwner(ref);
  if (owner == null) {
    return;
  }
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove this learning material?'),
      content: const Text(
        'The material will no longer be available through the current Topic. Historical server records are preserved.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherMaterialRemoveConfirmButton'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remove material'),
        ),
      ],
    ),
  );
  if (accepted == true && context.mounted && _currentOwner(ref) == owner) {
    await ref
        .read(teacherMaterialMutationControllerProvider(topicId).notifier)
        .removeMaterial(material);
  }
}

TeacherSessionKey? _currentOwner(WidgetRef ref) {
  return TeacherSessionSnapshot.fromSession(
    ref.read(authSessionControllerProvider),
    ref.read(appDeviceSurfaceProvider),
  ).eligibleKey;
}

void _closeStaleDialog(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  });
}

String formatTeacherMaterialBytes(int bytes) {
  const mebibyte = 1024 * 1024;
  if (bytes >= mebibyte) {
    final value = bytes / mebibyte;
    return '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} MiB';
  }
  const kibibyte = 1024;
  if (bytes >= kibibyte) {
    return '${(bytes / kibibyte).toStringAsFixed(1)} KiB';
  }
  return '$bytes bytes';
}

void _showFeedback(BuildContext context, String feedback) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(feedback)));
}

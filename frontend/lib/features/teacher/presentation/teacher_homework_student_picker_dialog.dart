import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/teacher_homework_student_picker_controller.dart';
import '../application/teacher_homework_student_picker_state.dart';
import '../application/teacher_homework_student_picker_target.dart';
import '../domain/teacher_group_student.dart';
import '../domain/teacher_group_student_list_query.dart';

Future<Set<String>?> showTeacherHomeworkStudentPicker({
  required BuildContext context,
  required TeacherHomeworkStudentPickerTarget target,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => TeacherHomeworkStudentPickerDialog(target: target),
  );
}

class TeacherHomeworkStudentPickerDialog extends ConsumerStatefulWidget {
  const TeacherHomeworkStudentPickerDialog({required this.target, super.key});

  final TeacherHomeworkStudentPickerTarget target;

  @override
  ConsumerState<TeacherHomeworkStudentPickerDialog> createState() =>
      _TeacherHomeworkStudentPickerDialogState();
}

class _TeacherHomeworkStudentPickerDialogState
    extends ConsumerState<TeacherHomeworkStudentPickerDialog> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = teacherHomeworkStudentPickerControllerProvider(
      widget.target,
    );
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (_searchController.text != state.searchDraft) {
      _searchController.value = TextEditingValue(
        text: state.searchDraft,
        selection: TextSelection.collapsed(offset: state.searchDraft.length),
      );
    }
    final contentHeight = (MediaQuery.sizeOf(context).height - 220)
        .clamp(320.0, 520.0)
        .toDouble();

    return AlertDialog(
      key: const Key('teacherHomeworkStudentPickerDialog'),
      title: const Text('Choose Students'),
      content: SizedBox(
        width: 680,
        height: contentHeight,
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('teacherHomeworkStudentPickerSearchField'),
                controller: _searchController,
                maxLength: TeacherGroupStudentListQuery.maxSearchLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search eligible Students',
                  errorText: state.searchErrorText,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: controller.updateSearchDraft,
                onSubmitted: (_) => controller.submitSearch(),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${state.selectedIds.length} '
                      '${state.selectedIds.length == 1 ? 'Student' : 'Students'} '
                      'selected',
                      key: const Key(
                        'teacherHomeworkStudentPickerSelectedCount',
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const Key('teacherHomeworkStudentPickerSearchButton'),
                    tooltip: 'Search Students',
                    onPressed: state.searchErrorText == null
                        ? controller.submitSearch
                        : null,
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.selectedIds.isNotEmpty) ...[
                _SelectedStudentsSummary(
                  state: state,
                  onRemove: controller.removeSelectedStudent,
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: _StudentPickerBody(
                  state: state,
                  onRetry: controller.refresh,
                  onSelectionChanged: controller.setStudentSelected,
                ),
              ),
              const SizedBox(height: 8),
              _StudentPickerPagination(
                state: state,
                onPrevious: controller.previousPage,
                onNext: controller.nextPage,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('teacherHomeworkStudentPickerCancelButton'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherHomeworkStudentPickerApplyButton'),
          onPressed: () {
            final selection = controller.completeSelection();
            if (selection != null) {
              Navigator.of(context).pop(selection);
            }
          },
          child: const Text('Apply selection'),
        ),
      ],
    );
  }
}

class _SelectedStudentsSummary extends StatelessWidget {
  const _SelectedStudentsSummary({required this.state, required this.onRemove});

  final TeacherHomeworkStudentPickerState state;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedIds = state.selectedIds.toList()..sort();

    return Semantics(
      container: true,
      label: 'Current selected Students',
      child: Container(
        constraints: const BoxConstraints(maxHeight: 150),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView.builder(
          key: const Key('teacherHomeworkStudentPickerSelectedStudents'),
          shrinkWrap: true,
          itemCount: selectedIds.length,
          itemBuilder: (context, index) {
            final id = selectedIds[index];
            final student = state.resolvedStudent(id);
            final title = student?.fullName ?? 'Selected student ${index + 1}';
            final subtitle =
                student?.loginName ??
                'Name not loaded in the current eligible roster view.';

            return ListTile(
              dense: true,
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: IconButton(
                key: ValueKey(
                  'teacherHomeworkStudentPickerRemoveSelected$index',
                ),
                tooltip: 'Remove $title',
                onPressed: () => onRemove(id),
                icon: const Icon(Icons.close),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StudentPickerBody extends StatelessWidget {
  const _StudentPickerBody({
    required this.state,
    required this.onRetry,
    required this.onSelectionChanged,
  });

  final TeacherHomeworkStudentPickerState state;
  final VoidCallback onRetry;
  final void Function(String studentId, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if ((state.status == TeacherHomeworkStudentPickerStatus.initial ||
            state.status == TeacherHomeworkStudentPickerStatus.loading) &&
        state.result == null) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('teacherHomeworkStudentPickerLoading'),
          semanticsLabel: 'Loading eligible Students',
        ),
      );
    }
    if (state.status == TeacherHomeworkStudentPickerStatus.error &&
        state.result == null) {
      return _StudentPickerError(onRetry: onRetry);
    }

    final students = state.result?.items ?? const <TeacherGroupStudent>[];
    if (students.isEmpty) {
      return const Center(
        child: Text(
          'No eligible Students match the current search.',
          key: Key('teacherHomeworkStudentPickerEmpty'),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.status == TeacherHomeworkStudentPickerStatus.error) ...[
          _StudentPickerError(onRetry: onRetry),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: ListView.builder(
            key: const Key('teacherHomeworkStudentPickerResults'),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final selected = state.selectedIds.any(
                (id) => id.toLowerCase() == student.id.toLowerCase(),
              );
              return Semantics(
                label: '${student.fullName}, ${student.loginName}',
                child: CheckboxListTile(
                  key: ValueKey('teacherHomeworkPickerStudent${student.id}'),
                  value: selected,
                  title: Text(student.fullName),
                  subtitle: Text(student.loginName),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      onSelectionChanged(student.id, value ?? false),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StudentPickerPagination extends StatelessWidget {
  const _StudentPickerPagination({
    required this.state,
    required this.onPrevious,
    required this.onNext,
  });

  final TeacherHomeworkStudentPickerState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final page = state.result?.pagination.page ?? state.query.page;
    final lastPage = state.result?.pagination.lastPage ?? page;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton(
          key: const Key('teacherHomeworkStudentPickerPreviousButton'),
          onPressed: state.canPrevious ? onPrevious : null,
          child: const Text('Previous'),
        ),
        Text(
          'Page $page of $lastPage',
          key: const Key('teacherHomeworkStudentPickerPageLabel'),
        ),
        OutlinedButton(
          key: const Key('teacherHomeworkStudentPickerNextButton'),
          onPressed: state.canNext ? onNext : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class _StudentPickerError extends StatelessWidget {
  const _StudentPickerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The eligible Student roster could not be loaded.',
            key: Key('teacherHomeworkStudentPickerError'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('teacherHomeworkStudentPickerRetryButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

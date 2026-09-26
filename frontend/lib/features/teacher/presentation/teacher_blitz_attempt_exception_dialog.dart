import 'package:flutter/material.dart';

import '../domain/teacher_blitz_attempt_exception.dart';
import 'teacher_blitz_formatters.dart';

/// Collects the reason for one additional-attempt grant. Returns null when
/// cancelled; the caller re-checks ownership before sending anything.
Future<TeacherBlitzAttemptExceptionRequest?>
showTeacherBlitzAttemptExceptionDialog({
  required BuildContext context,
  required String studentName,
}) {
  return showDialog<TeacherBlitzAttemptExceptionRequest>(
    context: context,
    builder: (_) =>
        TeacherBlitzAttemptExceptionDialog(studentName: studentName),
  );
}

class TeacherBlitzAttemptExceptionDialog extends StatefulWidget {
  const TeacherBlitzAttemptExceptionDialog({
    required this.studentName,
    super.key,
  });

  final String studentName;

  @override
  State<TeacherBlitzAttemptExceptionDialog> createState() =>
      _TeacherBlitzAttemptExceptionDialogState();
}

class _TeacherBlitzAttemptExceptionDialogState
    extends State<TeacherBlitzAttemptExceptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _reasonTypeFocusNode = FocusNode();
  final _reasonFocusNode = FocusNode();
  TeacherBlitzAttemptExceptionReasonType? _reasonType;

  @override
  void dispose() {
    _reasonController.dispose();
    _reasonTypeFocusNode.dispose();
    _reasonFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final reasonType = _reasonType;
    if (!_formKey.currentState!.validate() || reasonType == null) {
      (reasonType == null ? _reasonTypeFocusNode : _reasonFocusNode)
          .requestFocus();
      return;
    }
    Navigator.of(context).pop(
      TeacherBlitzAttemptExceptionRequest(
        reasonType: reasonType,
        reason: _reasonController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('teacherBlitzAttemptExceptionDialog'),
      title: const Text('Grant additional Blitz attempt'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.studentName,
                key: const Key('teacherBlitzAttemptExceptionStudent'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TeacherBlitzAttemptExceptionReasonType>(
                key: const Key('teacherBlitzAttemptExceptionReasonType'),
                focusNode: _reasonTypeFocusNode,
                initialValue: _reasonType,
                decoration: const InputDecoration(
                  labelText: 'Reason type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type
                      in TeacherBlitzAttemptExceptionReasonType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(
                        teacherBlitzAttemptExceptionReasonTypeLabel(type),
                      ),
                    ),
                ],
                validator: (type) =>
                    type == null ? 'Choose a reason type.' : null,
                onChanged: (type) => setState(() => _reasonType = type),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('teacherBlitzAttemptExceptionReason'),
                controller: _reasonController,
                focusNode: _reasonFocusNode,
                minLines: 3,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  helperText:
                      'Up to $teacherBlitzAttemptExceptionReasonMaxLength '
                      'characters.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    TeacherBlitzAttemptExceptionRequest.validateReason(
                      value ?? '',
                    ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The original attempt remains in history.\nThis grant allows '
                'one replacement attempt only.\nThe replacement attempt is '
                'created only when the Student starts it.',
                key: Key('teacherBlitzAttemptExceptionHelper'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherBlitzAttemptExceptionSubmit'),
          onPressed: _submit,
          child: const Text('Grant additional attempt'),
        ),
      ],
    );
  }
}

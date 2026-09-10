import 'package:flutter/material.dart';

class StudentWrittenAnswerEditor extends StatefulWidget {
  const StudentWrittenAnswerEditor({
    required this.text,
    required this.label,
    required this.enabled,
    required this.onChanged,
    this.multiline = false,
    this.errorText,
    super.key,
  });

  final String text;
  final String label;
  final bool enabled;
  final bool multiline;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  State<StudentWrittenAnswerEditor> createState() =>
      _StudentWrittenAnswerEditorState();
}

class _StudentWrittenAnswerEditorState
    extends State<StudentWrittenAnswerEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(covariant StudentWrittenAnswerEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    enabled: widget.enabled,
    minLines: widget.multiline ? 5 : 1,
    maxLines: widget.multiline ? null : 4,
    decoration: InputDecoration(
      labelText: widget.label,
      alignLabelWithHint: widget.multiline,
      errorText: widget.errorText,
      errorMaxLines: 4,
      border: const OutlineInputBorder(),
    ),
    onChanged: widget.onChanged,
  );
}

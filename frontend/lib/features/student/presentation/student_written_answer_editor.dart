import 'package:flutter/material.dart';

class StudentWrittenAnswerEditor extends StatefulWidget {
  const StudentWrittenAnswerEditor({
    required this.text,
    required this.label,
    required this.enabled,
    required this.onChanged,
    this.multiline = false,
    this.errorText,
    this.onFocusLost,
    super.key,
  });

  final String text;
  final String label;
  final bool enabled;
  final bool multiline;
  final String? errorText;
  final ValueChanged<String> onChanged;

  /// Called when the field loses focus, so the answer is saved at once.
  final VoidCallback? onFocusLost;

  @override
  State<StudentWrittenAnswerEditor> createState() =>
      _StudentWrittenAnswerEditorState();
}

class _StudentWrittenAnswerEditorState
    extends State<StudentWrittenAnswerEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);

  void _onFocusChange() {
    if (!_focus.hasFocus) widget.onFocusLost?.call();
  }

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
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
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

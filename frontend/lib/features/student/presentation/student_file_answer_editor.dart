import 'package:flutter/material.dart';

import '../../../core/network/api_error_codes.dart';
import '../application/student_file_answer_state.dart';
import '../application/student_submission_transfer_state.dart';
import '../domain/student_question.dart';
import 'student_homework_formatters.dart';
import 'student_question_answer_editor.dart';

class StudentFileAnswerEditor extends StatefulWidget {
  const StudentFileAnswerEditor({
    required this.state,
    required this.isTerminal,
    required this.canChoose,
    required this.canUpload,
    required this.canDiscard,
    required this.isReconciling,
    required this.canTransfer,
    required this.transferState,
    required this.onChoose,
    required this.onUpload,
    required this.onDiscard,
    required this.onReload,
    required this.onOpen,
    required this.onSaveAs,
    super.key,
  });

  final StudentFileQuestionAnswerState state;
  final bool isTerminal;
  final bool canChoose;
  final bool canUpload;
  final bool canDiscard;
  final bool isReconciling;
  final bool canTransfer;
  final StudentSubmissionTransferState transferState;
  final Future<void> Function() onChoose;
  final VoidCallback onUpload;
  final VoidCallback onDiscard;
  final VoidCallback onReload;
  final VoidCallback onOpen;
  final VoidCallback onSaveAs;

  @override
  State<StudentFileAnswerEditor> createState() =>
      _StudentFileAnswerEditorState();
}

class _StudentFileAnswerEditorState extends State<StudentFileAnswerEditor> {
  final _chooseFocus = FocusNode();

  @override
  void dispose() {
    _chooseFocus.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final questionId = widget.state.question.id;
    await widget.onChoose();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.state.question.id == questionId &&
          widget.canChoose &&
          !widget.isTerminal) {
        _chooseFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final question = state.question;
    final policy = question.answerUi as StudentFileAnswerUi;
    final saved = state.serverFile;
    final selected = state.selectedFile;
    final uncertain = state.status == StudentFileAnswerStatus.uncertain;
    final uploading = state.status == StudentFileAnswerStatus.uploading;
    final progress = state.totalBytes > 0
        ? (state.sentBytes / state.totalBytes).clamp(0.0, 1.0)
        : null;
    final transfer = widget.transferState;
    final transferring = transfer.isBusyForQuestion(question.id);
    final allowTransfer = widget.canTransfer && !uploading && !uncertain;
    final retry =
        state.status == StudentFileAnswerStatus.failure &&
        state.failure?.serverCode == ApiErrorCodes.fileUploadFailed;
    return StudentQuestionAnswerCard(
      key: ValueKey('studentFileAnswerCard${question.id}'),
      question: question,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.isTerminal) ...[
            Text(
              'Allowed files: ${policy.allowedExtensions.join(', ').toUpperCase()}',
            ),
            Text(
              'Maximum upload size: ${formatStudentSubmissionBytes(policy.maxSizeBytes)}',
            ),
            const SizedBox(height: 12),
          ],
          if (saved == null)
            Text(
              widget.isTerminal
                  ? 'No file was submitted.'
                  : 'No file uploaded.',
            )
          else ...[
            const Text('Current file:'),
            SelectableText(saved.originalName),
            Text(
              '${saved.extension.toUpperCase()} · ${formatStudentSubmissionBytes(saved.sizeBytes)}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Semantics(
                  label:
                      'Question ${question.position}: Open current submitted file',
                  child: OutlinedButton(
                    onPressed: allowTransfer ? widget.onOpen : null,
                    child: const Text('Open'),
                  ),
                ),
                Semantics(
                  label:
                      'Question ${question.position}: Save current submitted file as',
                  child: OutlinedButton(
                    onPressed: allowTransfer ? widget.onSaveAs : null,
                    child: const Text('Save As…'),
                  ),
                ),
              ],
            ),
          ],
          if (selected != null && !widget.isTerminal) ...[
            const SizedBox(height: 12),
            Text(saved == null ? 'Selected:' : 'Selected replacement:'),
            SelectableText(selected.name),
            Text(formatStudentSubmissionBytes(selected.length)),
          ],
          if (state.selectionError case final error?) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(studentSubmissionSelectionErrorMessage(error)),
            ),
          ],
          if (state.localFailure case final failure?) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(switch (failure) {
                StudentFileAnswerLocalFailure.pickerUnavailable =>
                  'The file picker could not be opened.',
                StudentFileAnswerLocalFailure.sourceUnavailable =>
                  'The selected file is no longer available. Choose the file again.',
              }),
            ),
          ] else if (!uncertain && state.failure != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(studentFileAnswerFailureMessage(state.failure!)),
            ),
          ],
          if (state.status == StudentFileAnswerStatus.selecting) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: const Text('Opening file picker…'),
            ),
          ],
          if (uploading) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: const Text('Uploading file…')),
            if (progress != null) Text('${(progress * 100).round()}%'),
            LinearProgressIndicator(
              value: progress,
              semanticsLabel: 'Question ${question.position}: Uploading file',
              semanticsValue: progress == null
                  ? null
                  : '${(progress * 100).round()}%',
            ),
          ],
          if (state.status == StudentFileAnswerStatus.uploaded) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: const Text('File answer uploaded.'),
            ),
          ],
          if (uncertain) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: const Text(
                'We could not confirm whether this file was uploaded.',
              ),
            ),
            if (widget.isReconciling)
              const LinearProgressIndicator(
                semanticsLabel: 'Reloading Attempt',
              ),
          ],
          if (transferring) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(switch (transfer.status) {
                StudentSubmissionTransferStatus.downloading =>
                  'Downloading submitted file…',
                StudentSubmissionTransferStatus.opening =>
                  'Opening submitted file…',
                StudentSubmissionTransferStatus.saving =>
                  'Saving submitted file…',
                _ => '',
              }),
            ),
            LinearProgressIndicator(
              value: transfer.progress,
              semanticsLabel:
                  'Question ${question.position}: Transferring submitted file',
            ),
          ],
          if (transfer.questionId == question.id.toLowerCase() &&
              transfer.feedback != null) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: Text(transfer.feedback!)),
          ],
          if (!widget.isTerminal) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (uncertain)
                  FilledButton(
                    onPressed: widget.isReconciling ? null : widget.onReload,
                    child: const Text('Reload attempt'),
                  )
                else ...[
                  Semantics(
                    label:
                        'Question ${question.position}: ${saved == null ? 'Choose file' : 'Choose replacement'}',
                    child: OutlinedButton(
                      focusNode: _chooseFocus,
                      onPressed: widget.canChoose ? _choose : null,
                      child: Text(
                        saved == null ? 'Choose file' : 'Choose replacement',
                      ),
                    ),
                  ),
                  if (selected != null) ...[
                    FilledButton(
                      onPressed: widget.canUpload ? widget.onUpload : null,
                      child: Text(
                        retry
                            ? 'Retry upload'
                            : saved == null
                            ? 'Upload answer'
                            : 'Upload replacement',
                      ),
                    ),
                    if (!uploading)
                      TextButton(
                        onPressed: widget.canDiscard ? widget.onDiscard : null,
                        child: const Text('Discard selected file'),
                      ),
                  ],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

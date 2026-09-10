import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

void main() {
  final policy = StudentFileAnswerUi(
    allowedExtensions: const ['pdf', 'docx', 'ppt', 'pptx'],
    maxSizeBytes: 1024,
  );

  test('extracts only the final suffix and lowercases it', () {
    expect(_file(name: 'lesson.revision.PdF').extension, 'pdf');
    expect(_file(name: 'presentation.PPTX').extension, 'pptx');
    expect(_file(name: '.pdf').extension, 'pdf');
    for (final name in ['answer', 'answer.', '', '.', '..']) {
      expect(_file(name: name).extension, isNull);
    }
  });

  test('all safe Question extensions are accepted after selection', () {
    for (final extension in policy.allowedExtensions) {
      expect(
        validateStudentSubmissionSelection(
          _file(name: 'answer.${extension.toUpperCase()}'),
          policy,
        ),
        isNull,
      );
    }
  });

  test('missing and disallowed suffixes return typed selection error', () {
    for (final name in ['answer', 'answer.', 'answer.exe', 'answer.pdf.exe']) {
      expect(
        validateStudentSubmissionSelection(_file(name: name), policy),
        StudentSubmissionSelectionError.unsupportedExtension,
      );
    }
    expect(
      validateStudentSubmissionSelection(
        _file(name: 'answer.docx'),
        StudentFileAnswerUi(
          allowedExtensions: const ['pdf'],
          maxSizeBytes: 1024,
        ),
      ),
      StudentSubmissionSelectionError.unsupportedExtension,
    );
  });

  test(
    'size uses the current Question limit with exact inclusive boundary',
    () {
      for (final length in [0, -1]) {
        expect(
          validateStudentSubmissionSelection(_file(length: length), policy),
          StudentSubmissionSelectionError.emptyFile,
        );
      }
      expect(
        validateStudentSubmissionSelection(_file(length: 1024), policy),
        isNull,
      );
      expect(
        validateStudentSubmissionSelection(_file(length: 1025), policy),
        StudentSubmissionSelectionError.tooLarge,
      );
      expect(
        validateStudentSubmissionSelection(
          _file(length: 1024),
          StudentFileAnswerUi(
            allowedExtensions: const ['pdf'],
            maxSizeBytes: 128,
          ),
        ),
        StudentSubmissionSelectionError.tooLarge,
      );
    },
  );

  test(
    'filename boundary is 500 Unicode runes, not UTF-16 or UTF-8 length',
    () {
      final exact = '${List.filled(496, '🙂').join()}.pdf';
      expect(exact.runes.length, 500);
      expect(exact.length, greaterThan(500));
      expect(
        validateStudentSubmissionSelection(_file(name: exact), policy),
        isNull,
      );
      expect(
        validateStudentSubmissionSelection(_file(name: '🙂$exact'), policy),
        StudentSubmissionSelectionError.filenameTooLong,
      );
      const unicode = 'Домашняя работа — Oʻzbekcha 🙂.PDF';
      final selected = _file(name: unicode);
      expect(validateStudentSubmissionSelection(selected, policy), isNull);
      expect(selected.name, unicode);
    },
  );

  test('empty and dot names return invalidFilename without renaming', () {
    for (final name in ['', '.', '..']) {
      final selected = _file(name: name);
      expect(
        validateStudentSubmissionSelection(selected, policy),
        StudentSubmissionSelectionError.invalidFilename,
      );
      expect(selected.name, name);
    }
  });

  test('local validation never reads file content', () {
    final selected = StudentSubmissionUploadFile(
      name: 'answer.pdf',
      length: 1,
      openRead: () => throw StateError('Validation must not read local bytes.'),
    );
    expect(validateStudentSubmissionSelection(selected, policy), isNull);
  });
}

StudentSubmissionUploadFile _file({
  String name = 'answer.pdf',
  int length = 128,
}) => StudentSubmissionUploadFile(
  name: name,
  length: length,
  openRead: () => Stream.value(List.filled(length > 0 ? length : 0, 1)),
);

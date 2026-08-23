import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';

import 'protected_download_metadata.dart';

final localFileActionsProvider = Provider<LocalFileActions>((ref) {
  return LocalFileActions(platform: const NativeLocalFilePlatformAdapter());
});

enum LocalFileOpenOutcome { opened, noApplication }

abstract interface class LocalFilePlatformAdapter {
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  });
}

class NativeLocalFilePlatformAdapter implements LocalFilePlatformAdapter {
  const NativeLocalFilePlatformAdapter({
    this.temporaryRoot,
    this.openFile,
    this.saveFileDialog,
  });

  final Directory? temporaryRoot;
  final Future<OpenResult> Function(String path, String mimeType)? openFile;
  final Future<Uri?> Function(
    String fileName,
    Uint8List bytes,
    String mimeType,
  )?
  saveFileDialog;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) {
    final override = saveFileDialog;
    if (override != null) {
      return override(fileName, bytes, mimeType);
    }
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: 'Save learning material',
    );
  }

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (!_uuidPattern.hasMatch(fileId) ||
        protectedMaterialFileTypeForExtension(extension)?.mimeType !=
            mimeType) {
      return LocalFileOpenOutcome.noApplication;
    }
    try {
      final directory = Directory(
        '${(temporaryRoot ?? Directory.systemTemp).path}${Platform.pathSeparator}TestLabUz',
      );
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}${Platform.pathSeparator}${fileId.toLowerCase()}.$extension',
      );
      await file.writeAsBytes(bytes, flush: true);
      final result =
          await (openFile?.call(file.path, mimeType) ??
              OpenFile.open(file.path, type: mimeType));
      return result.type == ResultType.done
          ? LocalFileOpenOutcome.opened
          : LocalFileOpenOutcome.noApplication;
    } catch (_) {
      return LocalFileOpenOutcome.noApplication;
    }
  }
}

class LocalFileActions {
  const LocalFileActions({required this.platform});

  final LocalFilePlatformAdapter platform;

  Future<bool> saveAs(TrustedDownloadedFile file) async {
    final location = await platform.saveFile(
      fileName: file.filename,
      bytes: file.bytes,
      mimeType: file.mimeType,
    );
    return location != null;
  }

  Future<LocalFileOpenOutcome> open(String fileId, TrustedDownloadedFile file) {
    return platform.openTemporaryFile(
      fileId: fileId,
      extension: file.extension,
      mimeType: file.mimeType,
      bytes: file.bytes,
    );
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

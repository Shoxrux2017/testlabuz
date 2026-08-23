import 'dart:convert';
import 'dart:typed_data';

const maximumProtectedMaterialBytes = 26_214_400;

class ProtectedMaterialFileType {
  const ProtectedMaterialFileType({
    required this.extension,
    required this.mimeType,
  });

  final String extension;
  final String mimeType;
}

const protectedMaterialFileTypes = <ProtectedMaterialFileType>[
  ProtectedMaterialFileType(extension: 'pdf', mimeType: 'application/pdf'),
  ProtectedMaterialFileType(
    extension: 'docx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ),
  ProtectedMaterialFileType(
    extension: 'ppt',
    mimeType: 'application/vnd.ms-powerpoint',
  ),
  ProtectedMaterialFileType(
    extension: 'pptx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  ),
];

ProtectedMaterialFileType? protectedMaterialFileTypeForExtension(
  String extension,
) {
  final normalized = extension.toLowerCase();
  for (final type in protectedMaterialFileTypes) {
    if (type.extension == normalized) {
      return type;
    }
  }
  return null;
}

ProtectedMaterialFileType? protectedMaterialFileTypeForMimeType(
  String mimeType,
) {
  for (final type in protectedMaterialFileTypes) {
    if (type.mimeType == mimeType) {
      return type;
    }
  }
  return null;
}

class TrustedDownloadedFile {
  TrustedDownloadedFile({
    required List<int> bytes,
    required this.filename,
    required this.mimeType,
    required this.extension,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final String extension;
}

TrustedDownloadedFile parseTrustedProtectedDownload({
  required int? statusCode,
  required Map<String, List<String>> headers,
  required Object? data,
}) {
  if (statusCode != 200) {
    throw const FormatException('Protected download status must be 200.');
  }
  final contentType = _singleHeader(headers, 'content-type');
  final fileType = contentType == null
      ? null
      : protectedMaterialFileTypeForMimeType(contentType);
  if (fileType == null) {
    throw const FormatException(
      'Protected download Content-Type is unsupported.',
    );
  }
  final disposition = _singleHeader(headers, 'content-disposition');
  if (disposition == null ||
      !RegExp(
        r'^\s*attachment(?:\s*;|\s*$)',
        caseSensitive: false,
      ).hasMatch(disposition)) {
    throw const FormatException(
      'Protected download Content-Disposition is invalid.',
    );
  }
  if (_singleHeader(headers, 'cache-control')?.toLowerCase().trim() !=
          'private, no-store' ||
      _singleHeader(headers, 'x-content-type-options')?.toLowerCase().trim() !=
          'nosniff') {
    throw const FormatException(
      'Protected download security headers are invalid.',
    );
  }
  if (data is! List<int> ||
      data.isEmpty ||
      data.length > maximumProtectedMaterialBytes) {
    throw const FormatException('Protected download bytes are invalid.');
  }

  return TrustedDownloadedFile(
    bytes: data,
    filename: parseProtectedDownloadFilename(disposition, fileType),
    mimeType: fileType.mimeType,
    extension: fileType.extension,
  );
}

String parseProtectedDownloadFilename(
  String contentDisposition,
  ProtectedMaterialFileType fileType,
) {
  final extendedMatch = RegExp(
    r"(?:^|;)\s*filename\*\s*=\s*UTF-8''([^;]*)",
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  final extended = extendedMatch == null
      ? null
      : _decodeExtendedFilename(extendedMatch.group(1)!);
  final regular = _readRegularFilename(contentDisposition);
  final sanitized = _sanitizeFilename(extended ?? regular ?? '');
  if (sanitized.isEmpty ||
      sanitized == '.' ||
      sanitized == '..' ||
      !_hasCanonicalExtension(sanitized, fileType.extension)) {
    return 'download.${fileType.extension}';
  }
  return sanitized;
}

String? _singleHeader(Map<String, List<String>> headers, String requestedName) {
  List<String>? values;
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == requestedName) {
      if (values != null) {
        return null;
      }
      values = entry.value;
    }
  }
  if (values == null || values.length != 1) {
    return null;
  }
  final value = values.single;
  return value.isEmpty ? null : value;
}

String? _decodeExtendedFilename(String encoded) {
  try {
    final bytes = <int>[];
    for (var index = 0; index < encoded.length; index += 1) {
      final codeUnit = encoded.codeUnitAt(index);
      if (codeUnit == 0x25) {
        if (index + 2 >= encoded.length) {
          return null;
        }
        final value = int.tryParse(
          encoded.substring(index + 1, index + 3),
          radix: 16,
        );
        if (value == null) {
          return null;
        }
        bytes.add(value);
        index += 2;
      } else if (codeUnit <= 0x7f) {
        bytes.add(codeUnit);
      } else {
        return null;
      }
    }
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return null;
  }
}

String? _readRegularFilename(String contentDisposition) {
  final quoted = RegExp(
    r'(?:^|;)\s*filename\s*=\s*"((?:\\.|[^"\\])*)"',
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  if (quoted != null) {
    return quoted
        .group(1)!
        .replaceAllMapped(RegExp(r'\\(.)'), (match) => match.group(1)!);
  }
  return RegExp(
    r'(?:^|;)\s*filename\s*=\s*([^;\s]+)',
    caseSensitive: false,
  ).firstMatch(contentDisposition)?.group(1);
}

String _sanitizeFilename(String value) {
  final buffer = StringBuffer();
  for (final rune in value.trim().runes) {
    final forbidden =
        rune < 0x20 ||
        rune == 0x7f ||
        rune == 0x2f ||
        rune == 0x5c ||
        rune == 0x3a ||
        rune == 0x2a ||
        rune == 0x3f ||
        rune == 0x22 ||
        rune == 0x3c ||
        rune == 0x3e ||
        rune == 0x7c;
    buffer.writeCharCode(forbidden ? 0x5f : rune);
  }
  return buffer.toString().replaceFirst(RegExp(r'[. ]+$'), '').trim();
}

bool _hasCanonicalExtension(String filename, String extension) {
  return filename.toLowerCase().endsWith('.$extension');
}

import 'dart:convert';

class ApiErrorResponse {
  ApiErrorResponse({
    required this.message,
    required this.code,
    required Map<String, List<String>> fieldErrors,
    required this.requestId,
  }) : fieldErrors = _freezeFieldErrors(fieldErrors);

  static ApiErrorResponse? tryParse(Object? json) {
    if (json is Map) {
      return _tryParseMap(json);
    }
    if (json is! List<int> || json.length > _maximumBinaryErrorBytes) {
      return null;
    }

    try {
      final decoded = jsonDecode(utf8.decode(json, allowMalformed: false));
      if (decoded is! Map) {
        return null;
      }
      return _tryParseMap(decoded);
    } on FormatException {
      return null;
    }
  }

  static ApiErrorResponse? _tryParseMap(Map json) {
    final message = json['message'];
    if (message is! String || message.trim().isEmpty) {
      return null;
    }

    final code = json['code'];
    final requestId = json['request_id'];

    return ApiErrorResponse(
      message: message,
      code: code is String && code.isNotEmpty ? code : null,
      fieldErrors: _parseFieldErrors(json['errors']),
      requestId: requestId is String && requestId.isNotEmpty ? requestId : null,
    );
  }

  final String message;
  final String? code;
  final Map<String, List<String>> fieldErrors;
  final String? requestId;

  static Map<String, List<String>> _parseFieldErrors(Object? rawErrors) {
    if (rawErrors is! Map) {
      return const {};
    }

    final parsed = <String, List<String>>{};

    for (final MapEntry(key: key, value: value) in rawErrors.entries) {
      if (key is! String) {
        continue;
      }

      final List<String> messages = switch (value) {
        final List<Object?> values => values.whereType<String>().toList(),
        final String message => <String>[message],
        _ => <String>[],
      };

      if (messages.isNotEmpty) {
        parsed[key] = messages;
      }
    }

    return parsed;
  }

  static Map<String, List<String>> _freezeFieldErrors(
    Map<String, List<String>> fieldErrors,
  ) {
    final frozen = <String, List<String>>{};

    for (final entry in fieldErrors.entries) {
      frozen[entry.key] = List<String>.unmodifiable(entry.value);
    }

    return Map<String, List<String>>.unmodifiable(frozen);
  }
}

const _maximumBinaryErrorBytes = 64 * 1024;

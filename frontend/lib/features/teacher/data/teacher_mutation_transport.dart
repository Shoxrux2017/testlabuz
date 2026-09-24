import 'package:dio/dio.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_failure_mapper.dart';

/// Sends one non-idempotent Teacher mutation exactly once.
///
/// Only an exact documented failure envelope proves that the server rejected
/// the mutation, and it is rethrown as [ApiRequestException]. Any other
/// failure, an unexpected success status or a malformed success body leaves
/// the outcome unknown, so the caller must reconcile instead of replaying.
Future<T> sendTeacherMutation<T>({
  required Future<Response<Object?>> Function() send,
  required int expectedStatus,
  required T Function(Object? data) parse,
  required Set<String> conflictCodes,
  required DioFailureMapper failureMapper,
  required Exception Function() outcomeUnknown,
}) async {
  final Response<Object?> response;
  try {
    response = await send();
  } on DioException catch (exception) {
    if (isExactTeacherMutationFailure(
      exception.response,
      conflictCodes: conflictCodes,
    )) {
      throw ApiRequestException(failureMapper.map(exception));
    }
    throw outcomeUnknown();
  } catch (_) {
    throw outcomeUnknown();
  }
  if (response.statusCode != expectedStatus) {
    throw outcomeUnknown();
  }
  try {
    return parse(response.data);
  } catch (_) {
    throw outcomeUnknown();
  }
}

/// Whether [response] is an exact documented definite mutation failure.
bool isExactTeacherMutationFailure(
  Response<Object?>? response, {
  required Set<String> conflictCodes,
}) {
  final status = response?.statusCode;
  final envelope = _readExactErrorEnvelope(response?.data);
  if (status == null || envelope == null) {
    return false;
  }

  final code = envelope.code;
  final recognized = switch (status) {
    401 => code == ApiErrorCodes.authenticationRequired,
    403 =>
      code == ApiErrorCodes.forbidden ||
          code == ApiErrorCodes.passwordChangeRequired ||
          code == ApiErrorCodes.userInactive ||
          code == ApiErrorCodes.institutionInactive,
    404 => code == ApiErrorCodes.resourceNotFound,
    409 => conflictCodes.contains(code),
    422 => code == ApiErrorCodes.validationFailed,
    429 => code == ApiErrorCodes.rateLimited,
    _ => false,
  };

  return recognized && (status == 422 || envelope.errors.isEmpty);
}

_ExactErrorEnvelope? _readExactErrorEnvelope(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      return null;
    }
    map[entry.key as String] = entry.value;
  }

  const required = {'message', 'code', 'errors'};
  const allowed = {...required, 'request_id'};
  if (map.length < required.length ||
      !map.keys.toSet().containsAll(required) ||
      map.keys.any((key) => !allowed.contains(key))) {
    return null;
  }

  final message = map['message'];
  final code = map['code'];
  final requestId = map['request_id'];
  final rawErrors = map['errors'];
  if (message is! String ||
      message.trim().isEmpty ||
      code is! String ||
      code.isEmpty ||
      rawErrors is! Map ||
      (map.containsKey('request_id') &&
          (requestId is! String || requestId.isEmpty))) {
    return null;
  }

  final errors = <String, List<String>>{};
  for (final entry in rawErrors.entries) {
    if (entry.key is! String || entry.value is! List) {
      return null;
    }
    final messages = <String>[];
    for (final item in entry.value as List) {
      if (item is! String || item.isEmpty) {
        return null;
      }
      messages.add(item);
    }
    if (messages.isEmpty) {
      return null;
    }
    errors[entry.key as String] = messages;
  }

  return _ExactErrorEnvelope(code: code, errors: errors);
}

class _ExactErrorEnvelope {
  const _ExactErrorEnvelope({required this.code, required this.errors});

  final String code;
  final Map<String, List<String>> errors;
}

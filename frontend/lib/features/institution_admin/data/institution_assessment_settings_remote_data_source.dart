import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_error_response.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_assessment_settings.dart';
import '../domain/institution_assessment_settings_repository.dart';
import 'dto/institution_assessment_settings_dto.dart';

const institutionAssessmentSettingsPath = '/institution/settings/assessment';

final institutionAssessmentSettingsRemoteDataSourceProvider =
    Provider<InstitutionAssessmentSettingsRemoteDataSource>((ref) {
      return InstitutionAssessmentSettingsRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionAssessmentSettingsRemoteDataSource {
  const InstitutionAssessmentSettingsRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionAssessmentSettingsDto> fetchSettings() async {
    try {
      final response = await dio.get<String>(
        institutionAssessmentSettingsPath,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
        ),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException('Unexpected assessment settings response.');
      }
      return InstitutionAssessmentSettingsDto.fromRawJson(response.data!);
    } on DioException catch (exception) {
      throw ApiRequestException(_mapReadFailure(exception));
    } on FormatException catch (exception) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: exception.message,
        ),
      );
    }
  }

  Future<InstitutionAssessmentSettingsDto> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) async {
    final body = request.toJson();
    _proveExactRequestNumber(body, request.acceptableScoreDifference);

    try {
      final response = await dio.put<String>(
        institutionAssessmentSettingsPath,
        data: body,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
        ),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException();
      }

      try {
        final parsed = InstitutionAssessmentSettingsDto.fromRawJson(
          response.data!,
        );
        if (!parsed.settings.educationalPolicyConfigured ||
            !request.matches(parsed.settings)) {
          throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException();
        }
        return parsed;
      } on FormatException {
        throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException();
      }
    } on InstitutionAssessmentSettingsUpdateOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      final definiteFailure = _mapExactDefiniteMutationFailure(exception);
      if (definiteFailure != null) {
        throw ApiRequestException(definiteFailure);
      }
      throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException();
    } catch (exception) {
      if (exception is ArgumentError || exception is StateError) {
        rethrow;
      }
      throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException();
    }
  }

  ApiFailure _mapReadFailure(DioException exception) {
    final decoded = _decodeExactError(exception.response);
    if (decoded == null) {
      return failureMapper.map(exception);
    }
    return failureMapper.map(_withDecodedResponse(exception, decoded));
  }

  ApiFailure? _mapExactDefiniteMutationFailure(DioException exception) {
    if (exception.type != DioExceptionType.badResponse) {
      return null;
    }
    final decoded = _decodeExactError(exception.response);
    if (decoded == null) {
      return null;
    }
    final mapped = failureMapper.map(_withDecodedResponse(exception, decoded));
    final status = mapped.statusCode;
    final code = mapped.serverCode;
    final definite = switch (status) {
      401 => code == ApiErrorCodes.authenticationRequired,
      403 =>
        code == ApiErrorCodes.forbidden ||
            code == ApiErrorCodes.userInactive ||
            code == ApiErrorCodes.institutionInactive ||
            code == ApiErrorCodes.passwordChangeRequired,
      422 => code == ApiErrorCodes.validationFailed,
      429 => code == ApiErrorCodes.rateLimited,
      _ => false,
    };
    return definite ? mapped : null;
  }
}

void _proveExactRequestNumber(
  Map<String, Object> body,
  ExactAssessmentDecimal expected,
) {
  final encoded = jsonEncode(body);
  final matches = _requestScoreToken
      .allMatches(encoded)
      .toList(growable: false);
  if (matches.length != 1 ||
      ExactAssessmentDecimal.parseJsonLexeme(matches.single.group(1)!) !=
          expected) {
    throw StateError('Assessment score JSON token is not exact.');
  }
}

final RegExp _requestScoreToken = RegExp(
  r'"acceptable_score_difference"\s*:\s*(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)\s*(?=[,}])',
);

Object? _decodeExactError(Response<Object?>? response) {
  final raw = response?.data;
  if (raw is! String) {
    return null;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  final error = ApiErrorResponse.tryParse(decoded);
  if (error == null || decoded is! Map) {
    return null;
  }
  final keys = decoded.keys.toSet();
  const required = {'message', 'code', 'errors'};
  const allowed = {...required, 'request_id'};
  if (!keys.containsAll(required) ||
      keys.any((key) => !allowed.contains(key))) {
    return null;
  }
  return decoded;
}

DioException _withDecodedResponse(DioException source, Object decoded) {
  final response = source.response!;
  return DioException(
    requestOptions: source.requestOptions,
    response: Response<Object?>(
      requestOptions: response.requestOptions,
      data: decoded,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      headers: response.headers,
      redirects: response.redirects,
      extra: response.extra,
    ),
    type: source.type,
    error: source.error,
    stackTrace: source.stackTrace,
    message: source.message,
  );
}

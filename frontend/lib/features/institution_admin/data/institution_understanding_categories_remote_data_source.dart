import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_error_response.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_understanding_categories.dart';
import '../domain/institution_understanding_categories_repository.dart';
import 'dto/institution_understanding_categories_dto.dart';

const institutionUnderstandingCategoriesPath =
    '/institution/understanding-categories';

final institutionUnderstandingCategoriesRemoteDataSourceProvider =
    Provider<InstitutionUnderstandingCategoriesRemoteDataSource>((ref) {
      return InstitutionUnderstandingCategoriesRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionUnderstandingCategoriesRemoteDataSource {
  const InstitutionUnderstandingCategoriesRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionUnderstandingCategoriesDto> fetchCategories() async {
    try {
      final response = await dio.get<String>(
        institutionUnderstandingCategoriesPath,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
        ),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException(
          'Unexpected understanding categories response.',
        );
      }
      return InstitutionUnderstandingCategoriesDto.fromRawJson(response.data!);
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

  Future<InstitutionUnderstandingCategoriesDto> replaceCategories(
    InstitutionUnderstandingCategoryUpdateRequest request,
  ) async {
    try {
      final response = await dio.put<String>(
        institutionUnderstandingCategoriesPath,
        data: request.toJson(),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
          followRedirects: false,
        ),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException();
      }
      try {
        final parsed = InstitutionUnderstandingCategoriesDto.fromRawJson(
          response.data!,
        );
        if (!request.matches(parsed.configuration)) {
          throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException();
        }
        return parsed;
      } on FormatException {
        throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException();
      }
    } on InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      final definiteFailure = _mapExactDefiniteMutationFailure(exception);
      if (definiteFailure != null) {
        throw ApiRequestException(definiteFailure);
      }
      throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException();
    } catch (exception) {
      if (exception is ArgumentError || exception is StateError) rethrow;
      throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException();
    }
  }

  ApiFailure _mapReadFailure(DioException exception) {
    final decoded = _decodeExactError(exception.response);
    if (decoded == null) return failureMapper.map(exception);
    return failureMapper.map(_withDecodedResponse(exception, decoded));
  }

  ApiFailure? _mapExactDefiniteMutationFailure(DioException exception) {
    if (exception.type != DioExceptionType.badResponse) return null;
    final decoded = _decodeExactError(exception.response);
    if (decoded == null) return null;
    final mapped = failureMapper.map(_withDecodedResponse(exception, decoded));
    final definite = switch (mapped.statusCode) {
      401 => mapped.serverCode == ApiErrorCodes.authenticationRequired,
      403 =>
        mapped.serverCode == ApiErrorCodes.forbidden ||
            mapped.serverCode == ApiErrorCodes.userInactive ||
            mapped.serverCode == ApiErrorCodes.institutionInactive ||
            mapped.serverCode == ApiErrorCodes.passwordChangeRequired,
      422 => mapped.serverCode == ApiErrorCodes.validationFailed,
      429 => mapped.serverCode == ApiErrorCodes.rateLimited,
      _ => false,
    };
    return definite ? mapped : null;
  }
}

Object? _decodeExactError(Response<Object?>? response) {
  final raw = response?.data;
  if (raw is! String) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  final error = ApiErrorResponse.tryParse(decoded);
  if (error == null || decoded is! Map) return null;
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

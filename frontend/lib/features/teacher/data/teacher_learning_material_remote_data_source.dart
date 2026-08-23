import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_error_response.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_learning_material_mutation.dart';
import '../domain/teacher_topic.dart';
import 'dto/teacher_learning_material_dto.dart';

final teacherLearningMaterialRemoteDataSourceProvider =
    Provider<TeacherLearningMaterialRemoteDataSource>((ref) {
      return TeacherLearningMaterialRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class TeacherLearningMaterialRemoteDataSource {
  const TeacherLearningMaterialRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  static const transferSendTimeout = Duration(minutes: 5);
  static const replaceSuccessMessage =
      'Learning material replaced successfully.';
  static const updateSuccessMessage = 'Learning material updated successfully.';

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherLearningMaterialListDto> fetchMaterials(String topicId) {
    _requireTopicId(topicId);
    return _mapReadFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}/materials',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Learning Material list status must be 200.',
        );
      }
      return TeacherLearningMaterialListDto.fromJson(
        response.data,
        expectedTopicId: topicId,
      );
    });
  }

  Future<TeacherLearningMaterialMutationDto> uploadMaterial({
    required String topicId,
    required TeacherMaterialUploadFile file,
    required String? title,
    TeacherMaterialUploadProgress? onProgress,
  }) {
    _requireTopicId(topicId);
    return _sendMutation(
      () => dio.post<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}/materials',
        data: _uploadFormData(file, title),
        options: Options(
          sendTimeout: transferSendTimeout,
          followRedirects: false,
        ),
        onSendProgress: onProgress,
      ),
      expectedStatus: 201,
      expectedTopicId: topicId,
      operation: _MaterialMutationOperation.upload,
    );
  }

  Future<TeacherLearningMaterialMutationDto> replaceMaterialFile({
    required String topicId,
    required String materialId,
    required TeacherMaterialUploadFile file,
    TeacherMaterialUploadProgress? onProgress,
  }) {
    _requireTopicId(topicId);
    _requireMaterialId(materialId);
    return _sendMutation(
      () => dio.post<Object?>(
        '/teacher/materials/${Uri.encodeComponent(materialId)}/replace',
        data: FormData.fromMap({
          'file': MultipartFile.fromStream(
            file.openRead,
            file.length,
            filename: file.name,
          ),
        }),
        options: Options(
          sendTimeout: transferSendTimeout,
          followRedirects: false,
        ),
        onSendProgress: onProgress,
      ),
      expectedStatus: 200,
      expectedTopicId: topicId,
      expectedMessage: replaceSuccessMessage,
      operation: _MaterialMutationOperation.replace,
    );
  }

  Future<TeacherLearningMaterialMutationDto> updateMaterialTitle({
    required String topicId,
    required String materialId,
    required String? title,
  }) {
    _requireTopicId(topicId);
    _requireMaterialId(materialId);
    return _sendMutation(
      () => dio.patch<Object?>(
        '/teacher/materials/${Uri.encodeComponent(materialId)}',
        data: <String, Object?>{'title': title},
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedTopicId: topicId,
      expectedMessage: updateSuccessMessage,
      operation: _MaterialMutationOperation.updateTitle,
    );
  }

  Future<void> removeMaterial({
    required String topicId,
    required String materialId,
  }) async {
    _requireTopicId(topicId);
    _requireMaterialId(materialId);
    try {
      final response = await dio.delete<Object?>(
        '/teacher/materials/${Uri.encodeComponent(materialId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 204) {
        throw const TeacherMaterialMutationOutcomeUnknownException();
      }
    } on TeacherMaterialMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isDefiniteMutationFailure(
        exception.response,
        _MaterialMutationOperation.remove,
      )) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const TeacherMaterialMutationOutcomeUnknownException();
    } catch (_) {
      throw const TeacherMaterialMutationOutcomeUnknownException();
    }
  }

  Future<TeacherLearningMaterialMutationDto> _sendMutation(
    Future<Response<Object?>> Function() send, {
    required int expectedStatus,
    required String expectedTopicId,
    required _MaterialMutationOperation operation,
    String? expectedMessage,
  }) async {
    try {
      final response = await send();
      if (response.statusCode != expectedStatus) {
        throw const TeacherMaterialMutationOutcomeUnknownException();
      }
      try {
        return TeacherLearningMaterialMutationDto.fromJson(
          response.data,
          expectedTopicId: expectedTopicId,
          expectedMessage: expectedMessage,
        );
      } on FormatException {
        throw const TeacherMaterialMutationOutcomeUnknownException();
      }
    } on TeacherMaterialMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isDefiniteMutationFailure(exception.response, operation)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const TeacherMaterialMutationOutcomeUnknownException();
    } catch (_) {
      throw const TeacherMaterialMutationOutcomeUnknownException();
    }
  }

  Future<T> _mapReadFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw ApiRequestException(failureMapper.map(exception));
    } on FormatException catch (exception) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: exception.message,
        ),
      );
    }
  }
}

enum _MaterialMutationOperation { upload, replace, updateTitle, remove }

bool _isDefiniteMutationFailure(
  Response<Object?>? response,
  _MaterialMutationOperation operation,
) {
  final status = response?.statusCode;
  final error = ApiErrorResponse.tryParse(response?.data);
  final code = error?.code;
  if (status == null || error == null || code == null) {
    return false;
  }
  return switch (status) {
    401 => code == ApiErrorCodes.authenticationRequired,
    403 =>
      code == ApiErrorCodes.forbidden ||
          code == ApiErrorCodes.passwordChangeRequired ||
          code == ApiErrorCodes.userInactive ||
          code == ApiErrorCodes.institutionInactive,
    404 => code == ApiErrorCodes.resourceNotFound,
    409 => code == ApiErrorCodes.topicNotEditable,
    422 =>
      code == ApiErrorCodes.validationFailed ||
          ((operation == _MaterialMutationOperation.upload ||
                  operation == _MaterialMutationOperation.replace) &&
              (code == ApiErrorCodes.unsupportedFileType ||
                  code == ApiErrorCodes.fileTooLarge)),
    429 => code == ApiErrorCodes.rateLimited,
    500 =>
      code == ApiErrorCodes.serverError ||
          ((operation == _MaterialMutationOperation.upload ||
                  operation == _MaterialMutationOperation.replace) &&
              code == ApiErrorCodes.fileUploadFailed),
    _ => false,
  };
}

void _requireTopicId(String topicId) {
  if (!isCanonicalTeacherTopicId(topicId)) {
    throw ArgumentError.value(topicId, 'topicId', 'Must be a canonical UUID.');
  }
}

void _requireMaterialId(String materialId) {
  if (!isCanonicalTeacherTopicId(materialId)) {
    throw ArgumentError.value(
      materialId,
      'materialId',
      'Must be a canonical UUID.',
    );
  }
}

FormData _uploadFormData(TeacherMaterialUploadFile file, String? title) {
  final fields = <String, Object?>{
    'file': MultipartFile.fromStream(
      file.openRead,
      file.length,
      filename: file.name,
    ),
  };
  if (title != null) {
    fields['title'] = title;
  }
  return FormData.fromMap(fields);
}

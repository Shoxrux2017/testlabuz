import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_failure.dart';
import '../network/api_request_exception.dart';
import '../network/dio_client_provider.dart';
import '../network/dio_failure_mapper.dart';
import 'protected_download_metadata.dart';

typedef ProtectedDownloadProgress = void Function(int received, int total);

final protectedLearningMaterialTransferProvider =
    Provider<ProtectedLearningMaterialTransfer>((ref) {
      return ProtectedLearningMaterialTransfer(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class ProtectedLearningMaterialTransfer {
  const ProtectedLearningMaterialTransfer({
    required this.dio,
    required this.failureMapper,
  });

  static const receiveTimeout = Duration(minutes: 5);

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TrustedDownloadedFile> download(
    String fileId, {
    ProtectedDownloadProgress? onReceiveProgress,
  }) async {
    if (!_uuidPattern.hasMatch(fileId)) {
      throw ArgumentError.value(fileId, 'fileId', 'Must be a canonical UUID.');
    }
    try {
      final response = await dio.get<List<int>>(
        '/files/${Uri.encodeComponent(fileId)}/download',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout,
          followRedirects: false,
        ),
        onReceiveProgress: onReceiveProgress,
      );
      try {
        return parseTrustedProtectedDownload(
          statusCode: response.statusCode,
          headers: response.headers.map,
          data: response.data,
        );
      } on FormatException catch (exception) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: exception.message,
          ),
        );
      }
    } on ApiRequestException {
      rethrow;
    } on DioException catch (exception) {
      throw ApiRequestException(failureMapper.map(exception));
    }
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

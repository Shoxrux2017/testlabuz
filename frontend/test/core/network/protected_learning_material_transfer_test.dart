import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file/open_file.dart';
import 'package:testlabuz_client/core/files/local_file_actions.dart';
import 'package:testlabuz_client/core/files/protected_download_metadata.dart';
import 'package:testlabuz_client/core/files/protected_learning_material_transfer.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';

const _fileId = '30000000-0000-0000-0000-000000000001';

void main() {
  group('ProtectedLearningMaterialTransfer', () {
    test(
      'uses exact authenticated GET transfer options and progress',
      () async {
        final adapter = _RecordingAdapter((_) => _downloadResponse());
        final dio = _dio(adapter)
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                options.headers['Authorization'] = 'Bearer configured-token';
                handler.next(options);
              },
            ),
          );
        final progress = <(int, int)>[];
        final transfer = ProtectedLearningMaterialTransfer(
          dio: dio,
          failureMapper: const DioFailureMapper(),
        );

        final file = await transfer.download(
          _fileId,
          onReceiveProgress: (received, total) =>
              progress.add((received, total)),
        );

        final request = adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.path, '/files/$_fileId/download');
        expect(request.data, isNull);
        expect(request.queryParameters, isEmpty);
        expect(request.responseType, ResponseType.bytes);
        expect(request.receiveTimeout, const Duration(minutes: 5));
        expect(request.sendTimeout, isNot(const Duration(minutes: 5)));
        expect(request.followRedirects, isFalse);
        expect(request.headers['Authorization'], 'Bearer configured-token');
        expect(file.bytes, [1, 2, 3, 4]);
        expect(file.filename, 'Dars 1.pdf');
        expect(file.mimeType, 'application/pdf');
        expect(file.extension, 'pdf');
        expect(progress, isNotEmpty);
      },
    );

    test('strict trusted headers and filename sanitization are enforced', () {
      final file = parseTrustedProtectedDownload(
        statusCode: 200,
        headers: _headers(
          disposition:
              "attachment; filename=\"fallback.pdf\"; filename*=UTF-8''..%2Funsafe.pdf",
        ),
        data: [1],
      );
      expect(file.filename, '.._unsafe.pdf');

      final fallback = parseTrustedProtectedDownload(
        statusCode: 200,
        headers: _headers(disposition: 'attachment; filename="unsafe.exe"'),
        data: [1],
      );
      expect(fallback.filename, 'download.pdf');

      for (final headers in [
        _headers(contentType: 'text/plain'),
        _headers(cacheControl: 'public'),
        _headers(nosniff: 'sniff'),
        _headers(disposition: 'inline; filename="lesson.pdf"'),
      ]) {
        expect(
          () => parseTrustedProtectedDownload(
            statusCode: 200,
            headers: headers,
            data: [1],
          ),
          throwsFormatException,
        );
      }
    });

    test(
      'Cache-Control accepts the exact private and no-store directive set',
      () {
        for (final cacheControl in [
          'private, no-store',
          'no-store, private',
          ' Private , NO-STORE ',
        ]) {
          expect(
            () => parseTrustedProtectedDownload(
              statusCode: 200,
              headers: _headers(cacheControl: cacheControl),
              data: [1],
            ),
            returnsNormally,
            reason: cacheControl,
          );
        }
      },
    );

    test(
      'Cache-Control rejects incomplete, additional, and duplicate sets',
      () {
        for (final cacheControl in [
          'private',
          'no-store',
          'public, no-store',
          'private, no-store, public',
          'private, private, no-store',
          'private="field", no-store',
        ]) {
          expect(
            () => parseTrustedProtectedDownload(
              statusCode: 200,
              headers: _headers(cacheControl: cacheControl),
              data: [1],
            ),
            throwsFormatException,
            reason: cacheControl,
          );
        }
      },
    );

    test('empty and oversized successful binary bodies are rejected', () {
      expect(
        () => parseTrustedProtectedDownload(
          statusCode: 200,
          headers: _headers(),
          data: <int>[],
        ),
        throwsFormatException,
      );
      expect(
        () => parseTrustedProtectedDownload(
          statusCode: 200,
          headers: _headers(),
          data: Uint8List(maximumProtectedMaterialBytes + 1),
        ),
        throwsFormatException,
      );
    });

    test('byte API errors remain in the shared failure mapper', () async {
      final transfer = ProtectedLearningMaterialTransfer(
        dio: _dio(
          _RecordingAdapter(
            (_) => ResponseBody.fromBytes(
              Uint8List.fromList(
                '{"message":"Missing","code":"resource_not_found","errors":{}}'
                    .codeUnits,
              ),
              404,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );

      await expectLater(
        transfer.download(_fileId),
        throwsA(
          isA<ApiRequestException>()
              .having((error) => error.failure.statusCode, 'status', 404)
              .having(
                (error) => error.failure.serverCode,
                'code',
                'resource_not_found',
              ),
        ),
      );
    });

    test('malformed successful response maps to invalidResponse', () async {
      final transfer = ProtectedLearningMaterialTransfer(
        dio: _dio(
          _RecordingAdapter(
            (_) => _downloadResponse(contentType: 'application/octet-stream'),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );

      await expectLater(
        transfer.download(_fileId),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('LocalFileActions', () {
    test('Save As cancel is neutral and success is reported', () async {
      final adapter = _FakeLocalAdapter();
      final actions = LocalFileActions(platform: adapter);
      final file = _trustedFile();

      expect(await actions.saveAs(file), isFalse);
      adapter.saveResult = Uri.file('chosen.pdf');
      expect(await actions.saveAs(file), isTrue);
      expect(adapter.savedName, 'lesson.pdf');
      expect(adapter.savedMime, 'application/pdf');
      expect(adapter.savedBytes, [1, 2, 3]);
    });

    test(
      'Open writes UUID plus canonical extension under TestLabUz temp',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'testlabuz-core-test-',
        );
        addTearDown(() async {
          if (root.path.startsWith(Directory.systemTemp.path) &&
              await root.exists()) {
            await root.delete(recursive: true);
          }
        });
        String? openedPath;
        String? openedMime;
        final adapter = NativeLocalFilePlatformAdapter(
          temporaryRoot: root,
          openFile: (path, mimeType) async {
            openedPath = path;
            openedMime = mimeType;
            return OpenResult();
          },
        );

        final result = await LocalFileActions(
          platform: adapter,
        ).open(_fileId, _trustedFile(filename: '../../unsafe.pdf'));

        expect(result, LocalFileOpenOutcome.opened);
        expect(
          openedPath,
          '${root.path}${Platform.pathSeparator}TestLabUz${Platform.pathSeparator}$_fileId.pdf',
        );
        expect(openedPath, isNot(contains('unsafe')));
        expect(openedMime, 'application/pdf');
        expect(await File(openedPath!).readAsBytes(), [1, 2, 3]);
      },
    );

    test('native Open result failure maps to noApplication', () async {
      final root = await Directory.systemTemp.createTemp(
        'testlabuz-core-test-',
      );
      addTearDown(() async {
        if (root.path.startsWith(Directory.systemTemp.path) &&
            await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final adapter = NativeLocalFilePlatformAdapter(
        temporaryRoot: root,
        openFile: (_, _) async => OpenResult(type: ResultType.error),
      );

      expect(
        await LocalFileActions(platform: adapter).open(_fileId, _trustedFile()),
        LocalFileOpenOutcome.noApplication,
      );
    });
  });
}

TrustedDownloadedFile _trustedFile({String filename = 'lesson.pdf'}) {
  return TrustedDownloadedFile(
    bytes: [1, 2, 3],
    filename: filename,
    mimeType: 'application/pdf',
    extension: 'pdf',
  );
}

Map<String, List<String>> _headers({
  String contentType = 'application/pdf',
  String disposition = "attachment; filename*=UTF-8''Dars%201.pdf",
  String cacheControl = 'private, no-store',
  String nosniff = 'nosniff',
}) {
  return {
    Headers.contentTypeHeader: [contentType],
    'content-disposition': [disposition],
    'cache-control': [cacheControl],
    'x-content-type-options': [nosniff],
  };
}

ResponseBody _downloadResponse({String contentType = 'application/pdf'}) {
  return ResponseBody.fromBytes(
    Uint8List.fromList([1, 2, 3, 4]),
    200,
    headers: {
      ..._headers(contentType: contentType),
      Headers.contentLengthHeader: ['4'],
    },
  );
}

Dio _dio(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeLocalAdapter implements LocalFilePlatformAdapter {
  Uri? saveResult;
  String? savedName;
  String? savedMime;
  Uint8List? savedBytes;

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    return LocalFileOpenOutcome.opened;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    savedName = fileName;
    savedMime = mimeType;
    savedBytes = bytes;
    return saveResult;
  }
}

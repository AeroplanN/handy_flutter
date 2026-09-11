import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/asr_model.dart';
import 'app_paths.dart';

enum ModelStatus { notDownloaded, downloading, ready, failed }

/// Состояние загрузки одной модели.
class ModelDownload {
  const ModelDownload({
    required this.modelId,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.currentFile = '',
    this.fileIndex = 0,
    this.fileCount = 0,
    this.error,
  });

  final String modelId;
  final ModelStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String currentFile;
  final int fileIndex;
  final int fileCount;
  final String? error;

  double get progress =>
      totalBytes == 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);
}

/// Скачивает, проверяет и удаляет модели — аналог `ModelManager` из Handy.
///
/// Каждый файл тянется отдельно во временный `.part` и переименовывается
/// только целиком, так что оборванная загрузка никогда не выглядит готовой.
/// При повторном запуске уже скачанная часть докачивается через Range.
class ModelManager extends ChangeNotifier {
  ModelManager({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Map<String, ModelDownload> _downloads = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _ready = {};

  bool _vadReady = false;

  bool get vadReady => _vadReady;

  /// Проверяет на диске, какие модели уже полностью скачаны.
  Future<void> refresh() async {
    _ready.clear();
    for (final model in kModelCatalog) {
      if (await _isComplete(model)) _ready.add(model.id);
    }
    _vadReady = await _isFileComplete(
      (await AppPaths.instance()).vadModelPath,
      sileroVadFile.sizeBytes,
    );
    notifyListeners();
  }

  bool isReady(String modelId) => _ready.contains(modelId);

  ModelDownload? downloadOf(String modelId) => _downloads[modelId];

  ModelStatus statusOf(String modelId) {
    final download = _downloads[modelId];
    if (download != null && download.status == ModelStatus.downloading) {
      return ModelStatus.downloading;
    }
    if (_ready.contains(modelId)) return ModelStatus.ready;
    return download?.status ?? ModelStatus.notDownloaded;
  }

  /// Суммарный размер скачанных моделей — показываем в настройках.
  Future<int> usedBytes() async {
    final paths = await AppPaths.instance();
    if (!await paths.models.exists()) return 0;

    var total = 0;
    await for (final entity in paths.models.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> download(AsrModel model) async {
    if (_cancelTokens.containsKey(model.id)) return;

    final paths = await AppPaths.instance();
    await paths.modelDir(model.id).create(recursive: true);

    final cancelToken = CancelToken();
    _cancelTokens[model.id] = cancelToken;

    final total = model.sizeBytes + (_vadReady ? 0 : sileroVadFile.sizeBytes);
    var doneBytes = 0;

    void publish(ModelDownload value) {
      _downloads[model.id] = value;
      notifyListeners();
    }

    publish(ModelDownload(
      modelId: model.id,
      status: ModelStatus.downloading,
      totalBytes: total,
      fileCount: model.files.length,
    ));

    try {
      // VAD нужен любой модели, поэтому тянем его вместе с первой.
      if (!_vadReady) {
        await _downloadFile(
          url: sileroVadFile.url,
          target: paths.vadModelPath,
          expectedSize: sileroVadFile.sizeBytes,
          cancelToken: cancelToken,
          onChunk: (received) => publish(ModelDownload(
            modelId: model.id,
            status: ModelStatus.downloading,
            receivedBytes: doneBytes + received,
            totalBytes: total,
            currentFile: sileroVadFile.name,
            fileCount: model.files.length,
          )),
        );
        doneBytes += sileroVadFile.sizeBytes;
        _vadReady = true;
      }

      for (var i = 0; i < model.files.length; i++) {
        final file = model.files[i];
        final target = paths.modelFilePath(model.id, file.name);

        if (await _isFileComplete(target, file.sizeBytes)) {
          doneBytes += file.sizeBytes;
          continue;
        }

        await _downloadFile(
          url: file.url,
          target: target,
          expectedSize: file.sizeBytes,
          cancelToken: cancelToken,
          onChunk: (received) => publish(ModelDownload(
            modelId: model.id,
            status: ModelStatus.downloading,
            receivedBytes: doneBytes + received,
            totalBytes: total,
            currentFile: file.name,
            fileIndex: i + 1,
            fileCount: model.files.length,
          )),
        );
        doneBytes += file.sizeBytes;
      }

      _ready.add(model.id);
      publish(ModelDownload(
        modelId: model.id,
        status: ModelStatus.ready,
        receivedBytes: total,
        totalBytes: total,
        fileCount: model.files.length,
      ));
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _downloads.remove(model.id);
        notifyListeners();
      } else {
        publish(ModelDownload(
          modelId: model.id,
          status: ModelStatus.failed,
          receivedBytes: doneBytes,
          totalBytes: total,
          error: _humanError(e),
          fileCount: model.files.length,
        ));
      }
    } catch (e) {
      publish(ModelDownload(
        modelId: model.id,
        status: ModelStatus.failed,
        receivedBytes: doneBytes,
        totalBytes: total,
        error: e.toString(),
        fileCount: model.files.length,
      ));
    } finally {
      _cancelTokens.remove(model.id);
    }
  }

  void cancel(String modelId) {
    _cancelTokens[modelId]?.cancel('Отменено пользователем');
    _cancelTokens.remove(modelId);
    _downloads.remove(modelId);
    notifyListeners();
  }

  Future<void> remove(AsrModel model) async {
    cancel(model.id);
    final paths = await AppPaths.instance();
    final dir = paths.modelDir(model.id);
    if (await dir.exists()) await dir.delete(recursive: true);
    _ready.remove(model.id);
    _downloads.remove(model.id);
    notifyListeners();
  }

  /// Скачивает один файл с докачкой: байты копятся в `<target>.part`.
  Future<void> _downloadFile({
    required String url,
    required String target,
    required int expectedSize,
    required CancelToken cancelToken,
    required void Function(int received) onChunk,
  }) async {
    final partFile = File('$target.part');
    var alreadyHave = 0;
    if (await partFile.exists()) {
      alreadyHave = await partFile.length();
      // Битый .part больше ожидаемого — начинаем заново.
      if (expectedSize > 0 && alreadyHave >= expectedSize) {
        await partFile.delete();
        alreadyHave = 0;
      }
    }

    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: alreadyHave > 0 ? {'Range': 'bytes=$alreadyHave-'} : null,
        // 416 значит «файл уже целиком скачан» — обрабатываем сами.
        validateStatus: (status) =>
            status != null && (status < 400 || status == 416),
      ),
    );

    if (response.statusCode == 416) {
      await partFile.rename(target);
      onChunk(expectedSize);
      return;
    }

    // Сервер проигнорировал Range и отдал файл целиком — пишем с нуля.
    final resumed = response.statusCode == 206;
    if (alreadyHave > 0 && !resumed) {
      await partFile.delete();
      alreadyHave = 0;
    }

    final sink = partFile.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    var received = alreadyHave;

    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onChunk(received);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    final size = await partFile.length();
    if (expectedSize > 0 && size != expectedSize) {
      await partFile.delete();
      throw Exception(
        'Файл скачан не полностью: ожидалось $expectedSize Б, получено $size Б',
      );
    }

    final targetFile = File(target);
    if (await targetFile.exists()) await targetFile.delete();
    await partFile.rename(target);
  }

  Future<bool> _isComplete(AsrModel model) async {
    final paths = await AppPaths.instance();
    for (final file in model.files) {
      final ok = await _isFileComplete(
        paths.modelFilePath(model.id, file.name),
        file.sizeBytes,
      );
      if (!ok) return false;
    }
    return true;
  }

  Future<bool> _isFileComplete(String path, int expectedSize) async {
    final file = File(path);
    if (!await file.exists()) return false;
    if (expectedSize <= 0) return true;
    return await file.length() == expectedSize;
  }

  String _humanError(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Таймаут соединения. Проверьте интернет.',
        DioExceptionType.connectionError =>
          'Нет соединения с сервером моделей.',
        _ => e.message ?? 'Не удалось скачать модель',
      };
}

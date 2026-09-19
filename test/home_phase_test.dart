import 'package:flutter_test/flutter_test.dart';
import 'package:handy/state/home_phase.dart';

void main() {
  HomePhase phase({
    bool recording = false,
    bool transcribing = false,
    bool modelDownloading = false,
    bool canRecord = true,
  }) =>
      computeHomePhase(
        recording: recording,
        transcribing: transcribing,
        modelDownloading: modelDownloading,
        canRecord: canRecord,
      );

  test('без модели предлагаем её скачать', () {
    expect(phase(canRecord: false), HomePhase.noModel);
  });

  test('идущая загрузка важнее отсутствия модели', () {
    expect(
      phase(canRecord: false, modelDownloading: true),
      HomePhase.modelDownloading,
    );
  });

  test('запись и распознавание перекрывают всё остальное', () {
    expect(
      phase(recording: true, canRecord: false, modelDownloading: true),
      HomePhase.recording,
    );
    expect(
      phase(transcribing: true, modelDownloading: true),
      HomePhase.transcribing,
    );
  });

  test('когда всё готово и ничего не происходит — покой', () {
    expect(phase(), HomePhase.idle);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:handy/models/settings.dart';

void main() {
  test('settings survive a JSON round trip', () {
    const original = Settings(
      modelId: 'whisper-small',
      language: 'ru',
      translateToEnglish: true,
      recordMode: RecordMode.toggle,
      afterTranscribe: AfterTranscribe.copyAndShare,
      vadThreshold: 0.42,
      customWords: {'flatter': 'Flutter'},
      recordingRetention: RecordingRetention.weeks2,
      theme: AppTheme.dark,
      onboardingDone: true,
    );

    final restored = Settings.fromJson(original.toJson());

    expect(restored.modelId, original.modelId);
    expect(restored.language, original.language);
    expect(restored.translateToEnglish, isTrue);
    expect(restored.recordMode, RecordMode.toggle);
    expect(restored.afterTranscribe, AfterTranscribe.copyAndShare);
    expect(restored.vadThreshold, closeTo(0.42, 1e-9));
    expect(restored.customWords, {'flatter': 'Flutter'});
    expect(restored.recordingRetention, RecordingRetention.weeks2);
    expect(restored.theme, AppTheme.dark);
    expect(restored.onboardingDone, isTrue);
  });

  test('unknown enum names fall back to defaults', () {
    final restored = Settings.fromJson({
      'recordMode': 'telepathy',
      'theme': 'neon',
    });

    expect(restored.recordMode, RecordMode.hold);
    expect(restored.theme, AppTheme.system);
  });
}

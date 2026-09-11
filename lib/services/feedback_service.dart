import 'package:flutter/services.dart';

import '../models/settings.dart';

/// Звук и вибрация на старте и финише записи — чтобы не смотреть на экран,
/// как и в десктопном Handy с его `audio_feedback`.
///
/// Используются системные звуки и хаптика: никаких ассетов, ничего не грузится
/// и поведение совпадает с привычным для платформы.
class FeedbackService {
  Settings settings = const Settings();

  Future<void> recordingStarted() async {
    if (settings.hapticFeedback) await HapticFeedback.mediumImpact();
    if (settings.soundFeedback) await SystemSound.play(SystemSoundType.click);
  }

  Future<void> recordingStopped() async {
    if (settings.hapticFeedback) await HapticFeedback.lightImpact();
    if (settings.soundFeedback) await SystemSound.play(SystemSoundType.click);
  }

  Future<void> transcriptionReady() async {
    if (settings.hapticFeedback) await HapticFeedback.selectionClick();
  }

  Future<void> failed() async {
    if (settings.hapticFeedback) await HapticFeedback.heavyImpact();
    if (settings.soundFeedback) await SystemSound.play(SystemSoundType.alert);
  }
}

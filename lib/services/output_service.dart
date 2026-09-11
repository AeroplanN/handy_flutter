import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Куда уходит распознанный текст.
///
/// На десктопе Handy вставляет текст прямо в активное поле; на телефоне так
/// нельзя, поэтому ближайшие аналоги — буфер обмена и системное «Поделиться».
class OutputService {
  Future<void> copy(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> share(String text, {String? subject}) async {
    if (text.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }
}

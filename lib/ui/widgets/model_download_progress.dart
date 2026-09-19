import 'package:flutter/material.dart';

import '../../services/model_manager.dart';
import '../tokens.dart';

/// Ход загрузки модели: полоса, мегабайты, скорость, остаток и файл,
/// который тянется прямо сейчас.
///
/// Раньше показывались только мегабайты и «файл 2/4», из-за чего 700-мегабайтная
/// загрузка выглядела зависшей.
class ModelDownloadProgress extends StatelessWidget {
  const ModelDownloadProgress({
    super.key,
    required this.download,
    required this.speed,
    required this.eta,
    this.onCancel,
  });

  final ModelDownload download;

  /// Байт в секунду; null — пока не измерено.
  final double? speed;
  final Duration? eta;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final progress = download.progress;
    final meta = <String>[
      '${formatSize(download.receivedBytes)} из '
          '${formatSize(download.totalBytes)}',
      if (speed != null) '${formatSize(speed!.round())}/с',
      if (eta != null && eta!.inSeconds > 0) 'осталось ${formatEta(eta!)}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kGapS),
                child: LinearProgressIndicator(
                  value: progress == 0 ? null : progress,
                ),
              ),
            ),
            const SizedBox(width: kGapM),
            Text(
              '${(progress * 100).round()} %',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: kGapS),
        Row(
          children: [
            Expanded(
              child: Text(
                meta.join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
            if (onCancel != null)
              TextButton(onPressed: onCancel, child: const Text('Отменить')),
          ],
        ),
        if (download.currentFile.isNotEmpty)
          Text(
            download.fileCount > 0
                ? '${download.currentFile}  ·  файл '
                    '${download.fileIndex} из ${download.fileCount}'
                : download.currentFile,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}

/// Размер в мегабайтах или гигабайтах — как привык человек, а не байты.
String formatSize(int bytes) {
  const mb = 1024 * 1024;
  if (bytes >= 1024 * mb) {
    return '${(bytes / (1024 * mb)).toStringAsFixed(1)} ГБ';
  }
  return '${(bytes / mb).round()} МБ';
}

String formatEta(Duration eta) {
  if (eta.inMinutes >= 60) return '~${(eta.inMinutes / 60).ceil()} ч';
  if (eta.inSeconds >= 60) return '~${eta.inMinutes + 1} мин';
  return '~${eta.inSeconds} с';
}

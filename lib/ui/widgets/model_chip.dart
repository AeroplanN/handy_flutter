import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/model_manager.dart';
import '../../state/app_controller.dart';
import '../navigation.dart';
import '../tokens.dart';

/// Состояние модели прямо в шапке: имя, точка готовности или кольцо
/// прогресса загрузки. Раньше о том, что происходит с моделью, можно было
/// узнать только зайдя в отдельный экран.
class ModelChip extends StatelessWidget {
  const ModelChip({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    // Прогресс живёт в отдельном ChangeNotifier — без этой подписки
    // кольцо стояло бы на месте.
    context.watch<ModelManager>();

    final scheme = Theme.of(context).colorScheme;
    final model = controller.selectedModel;

    final downloading = model != null &&
        controller.models.statusOf(model.id) == ModelStatus.downloading;
    final progress =
        downloading ? controller.models.downloadOf(model.id)?.progress ?? 0 : 0.0;

    final String label;
    final Color dotColor;
    if (model == null) {
      label = 'Нет модели';
      dotColor = kWarn;
    } else if (downloading) {
      label = '${(progress * 100).round()} %';
      dotColor = scheme.primary;
    } else {
      label = model.name;
      dotColor = controller.canRecord ? kOk : kWarn;
    }

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: InkWell(
        onTap: () => openModels(context),
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kGapM, kGapS, kGapS, kGapS),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (downloading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    value: progress == 0 ? null : progress,
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: kGapS),
              // Flexible, а не фиксированная ширина: имя модели бывает
              // длинным, и на узком экране оно должно ужиматься, а не
              // выталкивать строку за край.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

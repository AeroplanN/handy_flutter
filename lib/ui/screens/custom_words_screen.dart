import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';

/// Словарь замен: «как распозналось» → «как должно быть».
/// Мобильный аналог `CustomWords` из десктопного Handy — спасает имена,
/// термины и названия, которые модель стабильно слышит не так.
class CustomWordsScreen extends StatelessWidget {
  const CustomWordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final words = controller.settings.customWords;
    final entries = words.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Словарь замен')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Правило'),
      ),
      body: entries.isEmpty
          ? const _Empty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  title: Row(
                    children: [
                      Flexible(child: Text(entry.key)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 16),
                      ),
                      Flexible(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final next = Map<String, String>.from(words)
                        ..remove(entry.key);
                      controller.updateSettings(
                        controller.settings.copyWith(customWords: next),
                      );
                    },
                  ),
                  onTap: () => _edit(
                    context,
                    controller,
                    from: entry.key,
                    to: entry.value,
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    AppController controller, {
    String? from,
    String? to,
  }) async {
    final fromController = TextEditingController(text: from ?? '');
    final toController = TextEditingController(text: to ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(from == null ? 'Новое правило' : 'Изменить правило'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Как распозналось',
                hintText: 'флаттер',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: 'Чем заменить',
                hintText: 'Flutter',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final key = fromController.text.trim();
    final value = toController.text.trim();
    if (key.isEmpty) return;

    final next = Map<String, String>.from(controller.settings.customWords);
    // Ключ мог измениться — старое правило больше не нужно.
    if (from != null && from != key) next.remove(from);
    next[key] = value;

    await controller.updateSettings(
      controller.settings.copyWith(customWords: next),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spellcheck_rounded, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'Правил пока нет',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте замену, если модель стабильно ошибается в имени, '
              'термине или названии. Замена ищет слово целиком и не зависит '
              'от регистра.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_controller.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/theme.dart';

class HandyApp extends StatelessWidget {
  const HandyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return MaterialApp(
      title: 'Handy',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeModeOf(controller.settings.theme),
      home: !controller.ready
          ? const _Splash()
          : controller.settings.onboardingDone
              ? const RootShell()
              : const OnboardingScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

/// Три вкладки: запись, история, настройки.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Запись',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'История',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}

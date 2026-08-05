import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../l10n/l10n.dart';
import '../prototype/prototype_scenario_controller.dart';
import 'family_compass_shell.dart';

class FamilyCompassApp extends StatefulWidget {
  const FamilyCompassApp({
    super.key,
    required this.controller,
    this.initialLocale = const Locale('en'),
    this.initialThemeMode = ThemeMode.light,
    this.startInOnboarding = false,
  });

  final PrototypeScenarioController controller;
  final Locale initialLocale;
  final ThemeMode initialThemeMode;
  final bool startInOnboarding;

  @override
  State<FamilyCompassApp> createState() => _FamilyCompassAppState();
}

class _FamilyCompassAppState extends State<FamilyCompassApp> {
  late Locale _locale;
  late ThemeMode _themeMode;
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _themeMode = widget.initialThemeMode;
    _showOnboarding = widget.startInOnboarding;
  }

  void _toggleLanguage() {
    setState(() {
      _locale = Locale(_locale.languageCode == 'ar' ? 'en' : 'ar');
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Family Compass',
      theme: FamilyCompassTheme.light,
      darkTheme: FamilyCompassTheme.dark,
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _showOnboarding
          ? OnboardingScreen(
              onComplete: () => setState(() => _showOnboarding = false),
            )
          : FamilyCompassShell(
              controller: widget.controller,
              onToggleLanguage: _toggleLanguage,
              onToggleTheme: _toggleTheme,
              onPreviewOnboarding: () {
                setState(() => _showOnboarding = true);
              },
            ),
    );
  }
}

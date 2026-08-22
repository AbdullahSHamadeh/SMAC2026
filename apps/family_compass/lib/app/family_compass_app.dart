import 'dart:async';

import 'package:flutter/material.dart';

import '../features/family/family_invitation_controller.dart';
import '../design_system/design_system.dart';
import '../data/family_compass_repositories.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../firebase/firebase_notifications.dart';
import '../firebase/firebase_family_bootstrap.dart';
import '../firebase/firebase_phone_session.dart';
import '../l10n/l10n.dart';
import '../prototype/prototype_scenario_controller.dart';
import '../data/family_realtime_client.dart';
import 'app_preferences.dart';
import 'family_compass_shell.dart';

// THESIS: family opportunities and the people involved lead; product phases,
// dashboard chrome, and decorative AI stay quiet.
// OWN-WORLD: warm-milk canvases, pomegranate actions, apricot gathering
// fields, eucalyptus reassurance, truthful initials, and flat family rows.
// STORY: answer one pending request, understand the next family moment, see
// recent family updates, then consider one grounded Compass observation.
// FIRST VIEWPORT: one destination title, an optional Needs you strip, one
// split gathering sheet, and family content before Compass.
// FORM: Sunday Table, a native family organizer built around one shared moment.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
const familyCompassDesignContract = 'sunday-table:native-20260813';

class FamilyCompassApp extends StatefulWidget {
  const FamilyCompassApp({
    super.key,
    required this.controller,
    this.initialLocale,
    this.initialThemeMode,
    this.startInOnboarding = false,
    this.compassRepository,
    this.preferencesStore,
    this.invitationController,
    this.repositories,
    this.familyId,
    this.incomingLinks,
    this.foregroundNotifications,
    this.phoneSession,
    this.familyBootstrap,
    this.notificationPreferences,
    this.authenticatedPilotUserId,
    this.onAuthenticatedOnboardingComplete,
    this.onSignedOut,
    this.onFamilyScopeChanged,
    this.internalFirebaseTestAuth = false,
  });

  final PrototypeScenarioController controller;
  final Locale? initialLocale;
  final ThemeMode? initialThemeMode;
  final bool startInOnboarding;
  final CompassRepository? compassRepository;
  final AppPreferencesStore? preferencesStore;
  final FamilyInvitationController? invitationController;
  final FamilyCompassRepositories? repositories;
  final String? familyId;
  final Stream<Uri>? incomingLinks;
  final Stream<NotificationEnvelope>? foregroundNotifications;
  final PhoneOnboardingController? phoneSession;
  final FirebaseFamilyBootstrapService? familyBootstrap;
  final NotificationPreferenceController? notificationPreferences;
  final String? authenticatedPilotUserId;
  final Future<void> Function(OnboardingResult result, AppSession session)?
      onAuthenticatedOnboardingComplete;
  final Future<void> Function()? onSignedOut;
  final Future<void> Function()? onFamilyScopeChanged;
  final bool internalFirebaseTestAuth;

  @override
  State<FamilyCompassApp> createState() => _FamilyCompassAppState();
}

class _FamilyCompassAppState extends State<FamilyCompassApp> {
  late Locale _locale;
  late ThemeMode _themeMode;
  late bool _showOnboarding;
  late final FamilyInvitationController _invitationController;
  late final bool _ownsInvitationController;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _appLinkSubscription;
  StreamSubscription<NotificationEnvelope>? _foregroundNotificationSubscription;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale ??
        widget.preferencesStore?.value.locale ??
        const Locale('en');
    _themeMode = widget.initialThemeMode ??
        widget.preferencesStore?.value.themeMode ??
        ThemeMode.light;
    _showOnboarding = widget.startInOnboarding;
    _ownsInvitationController = widget.invitationController == null;
    _invitationController = widget.invitationController ??
        (widget.repositories != null && widget.familyId != null
            ? FamilyInvitationController(
                repository: widget.repositories!.family,
                familyId: widget.familyId,
              )
            : FamilyInvitationController.withDemoInvitation());
    _listenForAppLinks();
    _listenForForegroundNotifications();
  }

  @override
  void didUpdateWidget(covariant FamilyCompassApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incomingLinks != widget.incomingLinks) {
      unawaited(_appLinkSubscription?.cancel());
      _appLinkSubscription = null;
      _listenForAppLinks();
    }
    if (oldWidget.foregroundNotifications != widget.foregroundNotifications) {
      unawaited(_foregroundNotificationSubscription?.cancel());
      _foregroundNotificationSubscription = null;
      _listenForForegroundNotifications();
    }
  }

  @override
  void dispose() {
    unawaited(_appLinkSubscription?.cancel());
    unawaited(_foregroundNotificationSubscription?.cancel());
    if (_ownsInvitationController) _invitationController.dispose();
    super.dispose();
  }

  void _listenForForegroundNotifications() {
    final foregroundNotifications = widget.foregroundNotifications;
    if (foregroundNotifications == null) return;
    _foregroundNotificationSubscription = foregroundNotifications.listen(
      _showForegroundNotification,
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Family Compass notifications',
            context: ErrorDescription('while showing a family notification'),
          ),
        );
      },
    );
  }

  void _showForegroundNotification(NotificationEnvelope envelope) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = _scaffoldMessengerKey.currentState;
      final localizationContext = _scaffoldMessengerKey.currentContext;
      if (messenger == null || localizationContext == null) return;
      final l10n = localizationContext.l10n;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: Key(
              'notification.foreground.${envelope.deepLink.kind.name}',
            ),
            content: Text(
              _foregroundNotificationLabel(
                envelope.deepLink.kind,
                l10n,
              ),
            ),
            action: SnackBarAction(
              key: const Key('notification.foreground.open'),
              label: l10n.notificationOpen,
              onPressed: () => unawaited(_openDeepLink(envelope.deepLink)),
            ),
          ),
        );
    });
  }

  void _listenForAppLinks() {
    final incomingLinks = widget.incomingLinks;
    if (incomingLinks == null) return;
    _appLinkSubscription = incomingLinks.listen(
      (uri) => unawaited(_openIncomingLink(uri)),
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Family Compass deep links',
            context: ErrorDescription('while opening a family notification'),
          ),
        );
      },
    );
  }

  Future<void> _openIncomingLink(Uri uri) async {
    final link = FamilyCompassDeepLink.tryParse(uri.toString());
    if (link == null) return;
    await _openDeepLink(link);
  }

  Future<void> _openDeepLink(FamilyCompassDeepLink link) async {
    try {
      await widget.controller.openExactDeepLink(link);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Family Compass deep links',
          context: ErrorDescription('while resolving a family notification'),
        ),
      );
    }
  }

  void _setLocale(Locale locale) {
    if (_locale.languageCode == locale.languageCode) return;
    setState(() {
      _locale = Locale(locale.languageCode == 'ar' ? 'ar' : 'en');
    });
    final store = widget.preferencesStore;
    if (store != null) {
      unawaited(_persist(store.saveLocale(_locale), 'save language'));
    }
  }

  void _setDarkMode(bool enabled) {
    final nextThemeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextThemeMode) return;
    setState(() {
      _themeMode = nextThemeMode;
    });
    final store = widget.preferencesStore;
    if (store != null) {
      unawaited(_persist(store.saveThemeMode(_themeMode), 'save appearance'));
    }
  }

  Future<void> _persist(Future<void> operation, String action) async {
    try {
      await operation;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Family Compass preferences',
          context: ErrorDescription('while trying to $action'),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final phoneSession = widget.phoneSession;
    if (phoneSession == null) return;
    try {
      await phoneSession.signOut(
        beforeFirebaseSignOut: widget.notificationPreferences?.disable,
      );
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Family Compass session',
          context: ErrorDescription('while signing out'),
        ),
      );
    } finally {
      await widget.onSignedOut?.call();
      if (mounted) setState(() => _showOnboarding = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      restorationScopeId: 'family_compass',
      scaffoldMessengerKey: _scaffoldMessengerKey,
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
              phoneSession: widget.phoneSession,
              familyBootstrap: widget.familyBootstrap,
              onAuthenticatedComplete: widget.onAuthenticatedOnboardingComplete,
              canEnterAuthenticatedScope:
                  widget.onAuthenticatedOnboardingComplete != null
                      ? null
                      : (session) {
                          final familyId = widget.familyId;
                          final userId = widget.authenticatedPilotUserId;
                          return familyId != null &&
                              userId != null &&
                              session.userId == userId &&
                              session.familyIds.contains(familyId);
                        },
              internalFirebaseTestAuth: widget.internalFirebaseTestAuth,
            )
          : FamilyCompassShell(
              controller: widget.controller,
              compassRepository: widget.compassRepository,
              familyRoomCompassRepository:
                  widget.repositories?.familyRoomCompass,
              familyId: widget.familyId,
              invitationController: _invitationController,
              onLocaleChanged: _setLocale,
              onDarkModeChanged: _setDarkMode,
              onPreviewOnboarding: () {
                setState(() => _showOnboarding = true);
              },
              notificationPreferences: widget.notificationPreferences,
              onSignOut: widget.phoneSession == null ? null : _signOut,
              onFamilyScopeChanged: widget.onFamilyScopeChanged,
            ),
    );
  }
}

String _foregroundNotificationLabel(
  FamilyResourceKind kind,
  AppLocalizations l10n,
) =>
    switch (kind) {
      FamilyResourceKind.messages => l10n.notificationForegroundMessage,
      FamilyResourceKind.plans => l10n.notificationForegroundPlan,
      FamilyResourceKind.reminders => l10n.notificationForegroundReminder,
      FamilyResourceKind.checkIns => l10n.notificationForegroundCheckIn,
      FamilyResourceKind.unknown => l10n.notificationForegroundUpdate,
    };

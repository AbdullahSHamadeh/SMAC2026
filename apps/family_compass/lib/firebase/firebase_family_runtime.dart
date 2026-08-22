import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_preferences.dart';
import '../app/family_compass_app.dart';
import '../data/family_compass_api_client.dart';
import '../data/family_compass_repositories.dart';
import '../data/family_realtime_client.dart';
import '../data/http_family_compass_repositories.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../prototype/prototype_scenario_controller.dart';
import 'firebase_family_bootstrap.dart';
import 'firebase_notifications.dart';
import 'firebase_phone_auth.dart';
import 'firebase_phone_session.dart';

/// Owns the Firebase user's family-scoped runtime. No family repository,
/// realtime client, or notification repository exists until the backend has
/// returned both the authenticated user ID and an authorized family ID.
class FirebaseFamilyCompassRuntime extends StatefulWidget {
  const FirebaseFamilyCompassRuntime({
    super.key,
    required this.apiBaseUrl,
    required this.credentials,
    required this.phoneAuth,
    required this.preferencesStore,
    required this.incomingLinks,
    this.notifications,
    this.sharedPreferences,
    this.internalFirebaseTestAuth = false,
  });

  final String apiBaseUrl;
  final FirebaseApiCredentialProvider credentials;
  final FirebasePhoneAuthGateway phoneAuth;
  final AppPreferencesStore preferencesStore;
  final Stream<Uri> incomingLinks;
  final FirebaseNotificationCoordinator? notifications;
  final SharedPreferences? sharedPreferences;
  final bool internalFirebaseTestAuth;

  @override
  State<FirebaseFamilyCompassRuntime> createState() =>
      _FirebaseFamilyCompassRuntimeState();
}

class _FirebaseFamilyCompassRuntimeState
    extends State<FirebaseFamilyCompassRuntime> {
  late final FamilyCompassApiClient _bootstrapApi;
  late final FirebaseFamilyBootstrapService _bootstrap;
  late final FirebasePhoneSessionController _phoneSession;
  late final PrototypeScenarioController _unboundController;
  late final DeviceRegistrationStore _deviceRegistrationStore;

  HttpFamilyCompassRepositoryBundle? _bundle;
  PrototypeScenarioController? _boundController;
  FirebaseNotificationPreferenceController? _notificationPreferences;
  FirebaseFamilyBinding? _binding;
  StreamSubscription<Uri>? _incomingLinkSubscription;
  FamilyCompassDeepLink? _pendingDeepLink;
  bool _restoring = true;
  bool _routingDeepLink = false;
  bool _recoveringFamilyAccess = false;

  @override
  void initState() {
    super.initState();
    _bootstrapApi = FamilyCompassApiClient(
      baseUrl: widget.apiBaseUrl,
      credentials: widget.credentials,
    );
    _bootstrap = FirebaseFamilyBootstrapService(api: _bootstrapApi);
    _phoneSession = FirebasePhoneSessionController(
      auth: widget.phoneAuth,
      credentials: widget.credentials,
      api: _bootstrapApi,
    );
    _unboundController = PrototypeScenarioController();
    _deviceRegistrationStore = widget.sharedPreferences == null
        ? MemoryDeviceRegistrationStore()
        : SharedPreferencesDeviceRegistrationStore(widget.sharedPreferences!);
    _incomingLinkSubscription = widget.incomingLinks.listen(
      _receiveIncomingLink,
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Family Compass links',
            context: ErrorDescription('while receiving a notification link'),
          ),
        );
      },
    );
    unawaited(_restore());
  }

  void _receiveIncomingLink(Uri uri) {
    final link = FamilyCompassDeepLink.tryParse(uri.toString());
    if (link == null) return;
    _pendingDeepLink = link;
    unawaited(_openPendingDeepLink());
  }

  Future<void> _openPendingDeepLink() async {
    if (_routingDeepLink || _restoring || _pendingDeepLink == null) return;
    if (widget.phoneAuth.currentIdentity == null) return;
    _routingDeepLink = true;
    try {
      final link = _pendingDeepLink!;
      if (_binding?.familyId != link.familyId) {
        final authorized =
            await _bootstrap.restoreBindingForFamily(link.familyId);
        if (authorized == null) {
          _pendingDeepLink = null;
          return;
        }
        await _activate(authorized);
      }
      final controller = _boundController;
      if (controller != null && _binding?.familyId == link.familyId) {
        for (var attempt = 0;
            attempt < 40 && !controller.hasLoadedFamily;
            attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        if (!controller.hasLoadedFamily) return;
        await controller.openExactDeepLink(link);
        _pendingDeepLink = null;
      }
    } on Object {
      // Keep a valid deferred link for a later authenticated retry after a
      // temporary network failure. No family scope is guessed locally.
    } finally {
      _routingDeepLink = false;
    }
  }

  Future<void> _restore() async {
    try {
      if (widget.phoneAuth.currentIdentity != null) {
        await widget.credentials.refresh(force: false);
        final binding = await _bootstrap.restoreExistingBinding();
        if (binding != null) await _activate(binding);
      }
    } on Object {
      // An unregistered, revoked, offline, or family-less account remains in
      // authenticated onboarding. It never receives a guessed family scope.
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
        unawaited(_openPendingDeepLink());
      }
    }
  }

  Future<void> _completeAuthenticatedOnboarding(
    OnboardingResult result,
    AppSession session,
  ) async {
    final binding = await _bootstrap.bootstrap(
      displayName: result.name,
      createFamily: result.createsFamily,
      incomingInvitationId: result.incomingInvitationId,
      outgoingInvitationPhone:
          result.createsFamily ? result.preparedInvitationPhone : null,
    );
    if (binding.userId != session.userId) {
      throw StateError('The authenticated account changed during setup.');
    }
    await _activate(binding);
    unawaited(_openPendingDeepLink());
  }

  Future<void> _activate(FirebaseFamilyBinding binding) async {
    if (_binding?.userId == binding.userId &&
        _binding?.familyId == binding.familyId &&
        _bundle != null) {
      return;
    }
    final previousBundle = _bundle;
    final previousController = _boundController;
    final previousNotificationPreferences = _notificationPreferences;
    final previousBinding = _binding;
    final bundle = await HttpFamilyCompassRepositoryBundle.create(
      apiBaseUrl: widget.apiBaseUrl,
      familyId: binding.familyId,
      currentUserId: binding.userId,
      credentials: widget.credentials,
      preferences: widget.sharedPreferences,
    );
    final controller = PrototypeScenarioController(
      repositories: bundle.repositories,
      familyId: binding.familyId,
      currentUserId: binding.userId,
      familyEvents: bundle.events.watch(),
      onFamilyAccessLost: _familyAccessLost,
    );
    FirebaseNotificationPreferenceController? notificationPreferences;
    final notifications = widget.notifications;
    final devices = bundle.repositories.devices;
    if (notifications != null && devices != null) {
      notificationPreferences = FirebaseNotificationPreferenceController(
        registration: FirebaseDeviceRegistrationCoordinator(
          notifications: notifications,
          devices: devices,
          store: _deviceRegistrationStore,
        ),
      );
    }
    if (!mounted) {
      await notificationPreferences?.disposeAsync();
      controller.dispose();
      await bundle.dispose();
      return;
    }
    setState(() {
      _bundle = bundle;
      _boundController = controller;
      _notificationPreferences = notificationPreferences;
      _binding = binding;
      _restoring = false;
    });
    if (previousBundle != null || previousController != null) {
      await WidgetsBinding.instance.endOfFrame;
      await previousNotificationPreferences?.disposeAsync();
      if (previousBinding?.userId != binding.userId) {
        await previousBundle?.discardPendingWrites();
      }
      previousController?.dispose();
      await previousBundle?.dispose();
    }
  }

  Future<void> _clearBinding() async {
    final bundle = _bundle;
    final controller = _boundController;
    final notificationPreferences = _notificationPreferences;
    if (mounted) {
      setState(() {
        _bundle = null;
        _boundController = null;
        _notificationPreferences = null;
        _binding = null;
      });
      await WidgetsBinding.instance.endOfFrame;
    }
    await notificationPreferences?.disposeAsync();
    await bundle?.discardPendingWrites();
    controller?.dispose();
    await bundle?.dispose();
  }

  Future<void> _familyScopeChanged() async {
    await _clearBinding();
    if (mounted) setState(() => _restoring = true);
    try {
      final next = await _bootstrap.restoreExistingBinding();
      if (next != null) await _activate(next);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _familyAccessLost() async {
    if (_recoveringFamilyAccess) return;
    _recoveringFamilyAccess = true;
    _pendingDeepLink = null;
    try {
      await _familyScopeChanged();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Family Compass family runtime',
          context: ErrorDescription('while recovering from lost family access'),
        ),
      );
    } finally {
      _recoveringFamilyAccess = false;
    }
  }

  Future<void> _signedOut() async {
    _pendingDeepLink = null;
    await _clearBinding();
  }

  @override
  void dispose() {
    final bundle = _bundle;
    final controller = _boundController;
    final notificationPreferences = _notificationPreferences;
    _bundle = null;
    _boundController = null;
    _notificationPreferences = null;
    _phoneSession.dispose();
    unawaited(_incomingLinkSubscription?.cancel());
    _unboundController.dispose();
    _bootstrapApi.close();
    unawaited(notificationPreferences?.disposeAsync());
    controller?.dispose();
    unawaited(bundle?.dispose());
    unawaited(widget.credentials.dispose());
    unawaited(widget.notifications?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final binding = _binding;
    final bundle = _bundle;
    final controller = _boundController;
    if (binding != null && bundle != null && controller != null) {
      return FamilyCompassApp(
        key: ValueKey('firebase-${binding.userId}-${binding.familyId}'),
        controller: controller,
        preferencesStore: widget.preferencesStore,
        compassRepository: bundle.repositories.compass,
        repositories: bundle.repositories,
        familyId: binding.familyId,
        foregroundNotifications: widget.notifications?.foregroundMessages,
        phoneSession: _phoneSession,
        familyBootstrap: _bootstrap,
        notificationPreferences: _notificationPreferences,
        authenticatedPilotUserId: binding.userId,
        onAuthenticatedOnboardingComplete: _completeAuthenticatedOnboarding,
        onSignedOut: _signedOut,
        onFamilyScopeChanged: _familyScopeChanged,
        internalFirebaseTestAuth: widget.internalFirebaseTestAuth,
      );
    }
    return FamilyCompassApp(
      key: const ValueKey('firebase-unbound'),
      controller: _unboundController,
      preferencesStore: widget.preferencesStore,
      startInOnboarding: true,
      phoneSession: _phoneSession,
      familyBootstrap: _bootstrap,
      onAuthenticatedOnboardingComplete: _completeAuthenticatedOnboarding,
      onSignedOut: _signedOut,
      internalFirebaseTestAuth: widget.internalFirebaseTestAuth,
    );
  }
}

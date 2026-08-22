import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/design_system.dart';
import '../../data/family_compass_repositories.dart';
import '../../firebase/firebase_phone_session.dart';
import '../../firebase/firebase_phone_auth.dart';
import '../../firebase/firebase_family_bootstrap.dart';
import '../../widgets/prototype_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.onCompleted,
    this.phoneSession,
    this.familyBootstrap,
    this.canEnterAuthenticatedScope,
    this.onAuthenticatedComplete,
    this.internalFirebaseTestAuth = false,
  });

  final VoidCallback onComplete;
  final ValueChanged<OnboardingResult>? onCompleted;
  final PhoneOnboardingController? phoneSession;
  final FirebaseFamilyBootstrapService? familyBootstrap;
  final bool Function(AppSession session)? canEnterAuthenticatedScope;
  final Future<void> Function(OnboardingResult result, AppSession session)?
      onAuthenticatedComplete;
  final bool internalFirebaseTestAuth;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class OnboardingResult {
  const OnboardingResult({
    required this.phoneNumber,
    required this.name,
    required this.createsFamily,
    this.preparedInvitationPhone,
    this.incomingInvitationId,
  });

  final String phoneNumber;
  final String name;
  final bool createsFamily;
  final String? preparedInvitationPhone;
  final String? incomingInvitationId;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _codeController;
  final _nameController = TextEditingController(text: 'Abdullah');
  final _inviteController = TextEditingController(text: '+971 50 987 6543');
  int _step = 0;
  String? _preparedInvitePhone;
  bool _createFamily = true;
  String? _validationMessage;
  bool _busy = false;
  AppSession? _registeredSession;
  List<FirebaseIncomingInvitation> _incomingInvitations = const [];
  String? _processingInvitationId;
  DateTime? _verificationRetryAt;
  Timer? _verificationCooldownTimer;

  bool get _usesFirebase => widget.phoneSession != null;
  bool get _choosingInvitation => _usesFirebase && !_createFamily;
  int get _totalSteps => _choosingInvitation ? 5 : 4;
  bool get _verificationCoolingDown =>
      _verificationRetryAt?.isAfter(DateTime.now()) ?? false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: _usesFirebase ? '' : '+971 50 123 4567',
    );
    _codeController = TextEditingController(text: _usesFirebase ? '' : '2468');
    widget.phoneSession?.addListener(_phoneSessionChanged);
    for (final controller in [
      _phoneController,
      _codeController,
      _nameController,
      _inviteController,
    ]) {
      controller.addListener(_clearValidationMessage);
    }
    _inviteController.addListener(_invalidatePreparedInvitation);
  }

  @override
  void didUpdateWidget(covariant OnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phoneSession == widget.phoneSession) return;
    oldWidget.phoneSession?.removeListener(_phoneSessionChanged);
    widget.phoneSession?.addListener(_phoneSessionChanged);
  }

  @override
  void dispose() {
    _verificationCooldownTimer?.cancel();
    widget.phoneSession?.removeListener(_phoneSessionChanged);
    for (final controller in [
      _phoneController,
      _codeController,
      _nameController,
      _inviteController,
    ]) {
      controller.removeListener(_clearValidationMessage);
    }
    _inviteController.removeListener(_invalidatePreparedInvitation);
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0) {
      setState(() {
        _step = _usesFirebase && widget.phoneSession!.state.identity != null
            ? 2
            : 1;
        _validationMessage = null;
      });
      return;
    }
    final validationMessage = _validationForCurrentStep();
    if (validationMessage != null) {
      setState(() => _validationMessage = validationMessage);
      return;
    }
    if (_usesFirebase && _step == 1) {
      await _advanceFirebaseVerification();
      return;
    }
    if (_step == 3) {
      final result = _onboardingResult();
      if (_usesFirebase) {
        if (!_createFamily) {
          await _loadIncomingInvitations(enterChooser: true);
          return;
        }
        final completed = await _completeFirebaseAccount(result);
        if (!completed) return;
      }
      _finishOnboarding(result);
    } else {
      setState(() {
        _validationMessage = null;
        _step += 1;
      });
    }
  }

  OnboardingResult _onboardingResult({String? incomingInvitationId}) =>
      OnboardingResult(
        phoneNumber: widget.phoneSession?.state.identity?.phoneNumber ??
            _phoneController.text.trim(),
        name: _nameController.text.trim(),
        createsFamily: _createFamily,
        preparedInvitationPhone: _createFamily ? _preparedInvitePhone : null,
        incomingInvitationId: incomingInvitationId,
      );

  void _finishOnboarding(OnboardingResult result) {
    if (!mounted) return;
    widget.onCompleted?.call(result);
    widget.onComplete();
  }

  Future<void> _advanceFirebaseVerification() async {
    if (_verificationCoolingDown) return;
    final session = widget.phoneSession!;
    final hasChallenge = session.state.challenge != null;
    setState(() {
      _busy = true;
      _validationMessage = null;
    });
    try {
      if (!hasChallenge) {
        await session.sendCode(_normalizedPhone(_phoneController.text));
        if (session.state.identity != null && mounted) {
          setState(() => _step = 2);
        }
      } else {
        await session.verifyCode(_codeController.text.trim());
        if (mounted) setState(() => _step = 2);
      }
    } on Object catch (error) {
      if (!mounted) return;
      if (error is PhoneAuthFailure &&
          error.kind == PhoneAuthFailureKind.quotaExceeded) {
        _startVerificationCooldown();
      } else {
        setState(() => _validationMessage = error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendFirebaseCode() async {
    if (_busy || _verificationCoolingDown) return;
    setState(() {
      _busy = true;
      _validationMessage = null;
    });
    try {
      await widget.phoneSession!.resendCode();
    } on Object catch (error) {
      if (!mounted) return;
      if (error is PhoneAuthFailure &&
          error.kind == PhoneAuthFailureKind.quotaExceeded) {
        _startVerificationCooldown();
      } else {
        setState(() => _validationMessage = error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<AppSession> _backendSession() async {
    final existing = _registeredSession;
    if (existing != null) return existing;
    final session = await widget.phoneSession!.registerBackendAccount(
      _nameController.text,
    );
    _registeredSession = session;
    return session;
  }

  Future<bool> _completeFirebaseAccount(OnboardingResult result) async {
    setState(() {
      _busy = true;
      _validationMessage = null;
    });
    try {
      final session = await _backendSession();
      await widget.onAuthenticatedComplete?.call(result, session);
      final canEnter = widget.canEnterAuthenticatedScope?.call(session) ?? true;
      if (!canEnter) {
        if (mounted) {
          setState(() {
            _validationMessage = _message(
              'Your phone is verified and your account is ready. Live family creation and invitation selection must be connected before this account can enter the pilot family.',
              'تم التحقق من هاتفك وأصبح حسابك جاهزًا. يجب ربط إنشاء العائلة واختيار الدعوة فعليًا قبل دخول هذا الحساب إلى عائلة التجربة.',
            );
          });
        }
        return false;
      }
      return true;
    } on Object catch (error) {
      _showError(error);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadIncomingInvitations({bool enterChooser = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _validationMessage = null;
    });
    try {
      await _backendSession();
      final bootstrap = widget.familyBootstrap;
      if (bootstrap == null) {
        throw const FirebaseFamilyBootstrapFailure(
          english:
              'Invitation selection is not connected. Try again from the live Firebase app.',
          arabic:
              'اختيار الدعوة غير متصل. حاول مرة أخرى من تطبيق Firebase المباشر.',
        );
      }
      final invitations = await bootstrap.loadIncomingInvitations();
      if (!mounted) return;
      setState(() {
        _incomingInvitations = invitations;
        if (enterChooser) _step = 4;
      });
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptIncomingInvitation(
    FirebaseIncomingInvitation invitation,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _processingInvitationId = invitation.id;
      _validationMessage = null;
    });
    final result = _onboardingResult(incomingInvitationId: invitation.id);
    try {
      final session = await _backendSession();
      final complete = widget.onAuthenticatedComplete;
      if (complete == null) {
        throw const FirebaseFamilyBootstrapFailure(
          english:
              'Invitation acceptance is not connected. Try again from the live Firebase app.',
          arabic:
              'قبول الدعوة غير متصل. حاول مرة أخرى من تطبيق Firebase المباشر.',
        );
      }
      await complete(result, session);
      final canEnter = widget.canEnterAuthenticatedScope?.call(session) ?? true;
      if (!canEnter) {
        throw const FirebaseFamilyBootstrapFailure(
          english:
              'The invitation was accepted, but the family could not be opened. Check your connection and try again.',
          arabic:
              'تم قبول الدعوة، لكن تعذر فتح العائلة. تحقق من الاتصال وحاول مرة أخرى.',
        );
      }
      _finishOnboarding(result);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _processingInvitationId = null;
        });
      }
    }
  }

  Future<void> _declineIncomingInvitation(
    FirebaseIncomingInvitation invitation,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _processingInvitationId = invitation.id;
      _validationMessage = null;
    });
    try {
      final bootstrap = widget.familyBootstrap;
      if (bootstrap == null) {
        throw const FirebaseFamilyBootstrapFailure(
          english:
              'Invitation selection is not connected. Try again from the live Firebase app.',
          arabic:
              'اختيار الدعوة غير متصل. حاول مرة أخرى من تطبيق Firebase المباشر.',
        );
      }
      await bootstrap.declineIncomingInvitation(invitation.id);
      if (!mounted) return;
      setState(() {
        _incomingInvitations = _incomingInvitations
            .where((candidate) => candidate.id != invitation.id)
            .toList();
      });
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _processingInvitationId = null;
        });
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() {
      _validationMessage = error is FirebaseFamilyBootstrapFailure
          ? error.localized(
              isArabic: Localizations.localeOf(context).languageCode == 'ar',
            )
          : error.toString();
    });
  }

  void _back() {
    if (_step == 0 || _busy) return;
    setState(() {
      _validationMessage = null;
      _step -= 1;
    });
  }

  String? _validationForCurrentStep() {
    if (_step == 1) {
      if (_usesFirebase &&
          widget.phoneSession!.state.challenge == null &&
          !RegExp(r'^\+[1-9]\d{6,14}$')
              .hasMatch(_normalizedPhone(_phoneController.text))) {
        return _message(
          'Enter the full phone number with country code, such as +971501234567.',
          'أدخل رقم الهاتف الكامل مع رمز الدولة، مثل ‎+971501234567.',
        );
      }
      if (!_usesFirebase && !_isValidPhone(_phoneController.text)) {
        return _message(
          'Enter a valid phone number with at least 7 digits.',
          'أدخل رقم هاتف صحيحًا يحتوي على ٧ أرقام على الأقل.',
        );
      }
      if (_usesFirebase &&
          widget.phoneSession!.state.challenge != null &&
          !RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim())) {
        return _message(
          'Enter the 6-digit verification code.',
          'أدخل رمز التحقق المكوّن من ٦ أرقام.',
        );
      }
      if (!_usesFirebase &&
          !RegExp(r'^\d{4}$').hasMatch(_codeController.text.trim())) {
        return _message(
          'Enter the 4-digit verification code.',
          'أدخل رمز التحقق المكوّن من ٤ أرقام.',
        );
      }
    }
    if (_step == 3 && _nameController.text.trim().isEmpty) {
      return _message('Enter your name to continue.', 'أدخل اسمك للمتابعة.');
    }
    return null;
  }

  void _phoneSessionChanged() {
    if (!mounted) return;
    setState(() {
      if (_step == 1 && widget.phoneSession?.state.identity != null) {
        _step = 2;
        _validationMessage = null;
      }
    });
  }

  void _prepareInvitation() {
    final value = _inviteController.text.trim();
    if (!_isValidPhone(value)) {
      setState(() {
        _preparedInvitePhone = null;
        _validationMessage = _message(
          'Enter a valid invitation phone number.',
          'أدخل رقم هاتف صحيحًا للدعوة.',
        );
      });
      return;
    }
    setState(() {
      _preparedInvitePhone = value;
      _validationMessage = null;
    });
  }

  void _clearValidationMessage() {
    if (_validationMessage == null || !mounted) return;
    setState(() => _validationMessage = null);
  }

  void _invalidatePreparedInvitation() {
    if (_preparedInvitePhone == null ||
        _inviteController.text.trim() == _preparedInvitePhone) {
      return;
    }
    setState(() => _preparedInvitePhone = null);
  }

  String _message(String english, String arabic) =>
      Localizations.localeOf(context).languageCode == 'ar' ? arabic : english;

  void _startVerificationCooldown() {
    _verificationCooldownTimer?.cancel();
    _verificationRetryAt = DateTime.now().add(const Duration(minutes: 15));
    _validationMessage = _message(
      'Firebase paused verification after repeated requests. Stop retrying. The app will allow one new attempt in 15 minutes, although Firebase may require longer.',
      'أوقفت Firebase التحقق مؤقتًا بعد تكرار الطلبات. لا تحاول مجددًا الآن. سيسمح التطبيق بمحاولة واحدة جديدة بعد ١٥ دقيقة، وقد تتطلب Firebase وقتًا أطول.',
    );
    _verificationCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_verificationCoolingDown) {
        timer.cancel();
        setState(() => _verificationRetryAt = null);
        return;
      }
      setState(() {});
    });
    setState(() {});
  }

  String _verificationCooldownLabel(bool isArabic) {
    final retryAt = _verificationRetryAt;
    if (retryAt == null) return isArabic ? 'حاول لاحقًا' : 'Try later';
    final remaining = retryAt.difference(DateTime.now());
    final seconds = remaining.inSeconds.clamp(0, 15 * 60);
    final minutesPart = seconds ~/ 60;
    final secondsPart = (seconds % 60).toString().padLeft(2, '0');
    return isArabic
        ? 'حاول بعد $minutesPart:$secondsPart'
        : 'Try again in $minutesPart:$secondsPart';
  }

  static bool _isValidPhone(String value) =>
      value.replaceAll(RegExp(r'\D'), '').length >= 7;

  static String _normalizedPhone(String value) {
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return PopScope<void>(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 760 && constraints.maxHeight >= 680;
              if (wide) {
                return Row(
                  children: [
                    SizedBox(
                      width: constraints.maxWidth.clamp(280, 360) * 0.9,
                      child: _OnboardingSidePanel(
                        isArabic: isArabic,
                        usesFirebase: _usesFirebase,
                      ),
                    ),
                    Expanded(
                      child: _OnboardingForm(
                        step: _step,
                        totalSteps: _totalSteps,
                        isArabic: isArabic,
                        onBack: _back,
                        onNext: _next,
                        busy: _busy,
                        nextEnabled: !_verificationCoolingDown,
                        nextLabel: _nextLabel(isArabic),
                        showNext: _step != 4,
                        content: _stepContent(context),
                        validationMessage: _validationMessage,
                      ),
                    ),
                  ],
                );
              }
              return _OnboardingForm(
                step: _step,
                totalSteps: _totalSteps,
                isArabic: isArabic,
                onBack: _back,
                onNext: _next,
                busy: _busy,
                nextEnabled: !_verificationCoolingDown,
                nextLabel: _nextLabel(isArabic),
                showNext: _step != 4,
                content: _stepContent(context),
                validationMessage: _validationMessage,
                showProductName: true,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stepContent(BuildContext context) => switch (_step) {
        0 => const _WelcomeStep(),
        1 => _VerificationStep(
            phoneController: _phoneController,
            codeController: _codeController,
            usesFirebase: _usesFirebase,
            challengeSent: widget.phoneSession?.state.challenge != null,
            busy: _busy || _verificationCoolingDown,
            onResend: _resendFirebaseCode,
            internalFirebaseTestAuth: widget.internalFirebaseTestAuth,
          ),
        2 => _FamilyChoiceStep(
            createFamily: _createFamily,
            onChanged: (value) => setState(() {
              _createFamily = value;
              _incomingInvitations = const [];
              _validationMessage = null;
            }),
          ),
        3 => _ProfileStep(
            createsFamily: _createFamily,
            nameController: _nameController,
            inviteController: _inviteController,
            preparedInvitePhone: _preparedInvitePhone,
            onInvite: _prepareInvitation,
          ),
        _ => _IncomingInvitationStep(
            invitations: _incomingInvitations,
            processingInvitationId: _processingInvitationId,
            busy: _busy,
            onAccept: _acceptIncomingInvitation,
            onDecline: _declineIncomingInvitation,
            onReload: _loadIncomingInvitations,
          ),
      };

  String? _nextLabel(bool isArabic) {
    if (_usesFirebase && _step == 1) {
      if (_verificationCoolingDown) {
        return _verificationCooldownLabel(isArabic);
      }
      if (widget.phoneSession!.state.challenge == null) {
        if (widget.internalFirebaseTestAuth) {
          return isArabic ? 'استخدام حساب الاختبار' : 'Use test account';
        }
        return isArabic ? 'إرسال الرمز' : 'Send code';
      }
      return isArabic ? 'تحقق ومتابعة' : 'Verify and continue';
    }
    if (_choosingInvitation && _step == 3) {
      return isArabic ? 'مراجعة الدعوات' : 'Review invitations';
    }
    return null;
  }
}

class _OnboardingSidePanel extends StatelessWidget {
  const _OnboardingSidePanel({
    required this.isArabic,
    required this.usesFirebase,
  });

  final bool isArabic;
  final bool usesFirebase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(FamilyCompassSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Family Compass',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: scheme.onPrimary),
            ),
            const Spacer(),
            Text(
              isArabic ? 'وقت أكثر معًا.' : 'More time together.',
              style: FamilyCompassTypography.of(
                context,
              ).headlineLarge?.copyWith(color: scheme.onPrimary),
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            Text(
              isArabic
                  ? 'خططوا لوقت العائلة وابقوا مطمئنين من دون خريطة دائمة.'
                  : 'Make family plans and stay reassured without a permanent map.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.82),
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.xl),
            _SidePromise(
              icon: FamilyCompassIcons.eventAvailableOutlined,
              text: isArabic ? 'التجمع أولاً' : 'Gathering comes first',
            ),
            _SidePromise(
              icon: FamilyCompassIcons.visibilityOffOutlined,
              text: isArabic ? 'لا تتبع دائم' : 'No permanent tracking',
            ),
            _SidePromise(
              icon: FamilyCompassIcons.tuneOutlined,
              text: isArabic ? 'المشاركة بقرارك' : 'Sharing stays your choice',
            ),
            const Spacer(),
            Text(
              usesFirebase
                  ? isArabic
                      ? 'يُستخدم رقمك لتسجيل الدخول. لا يطلب التطبيق موقعك.'
                      : 'Your number is used for sign-in. Location is not requested.'
                  : isArabic
                      ? 'هذه نسخة تجريبية محلية. لا تُرسل رسائل نصية ولا تستخدم الموقع.'
                      : 'This local build sends no SMS and uses no location.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.78),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidePromise extends StatelessWidget {
  const _SidePromise({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: onPrimary, size: 22),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingForm extends StatelessWidget {
  const _OnboardingForm({
    required this.step,
    required this.totalSteps,
    required this.isArabic,
    required this.onBack,
    required this.onNext,
    required this.content,
    required this.busy,
    this.nextEnabled = true,
    this.validationMessage,
    this.showProductName = false,
    this.nextLabel,
    this.showNext = true,
  });

  final int step;
  final int totalSteps;
  final bool isArabic;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final Widget content;
  final bool busy;
  final bool nextEnabled;
  final String? validationMessage;
  final bool showProductName;
  final String? nextLabel;
  final bool showNext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(FamilyCompassSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showProductName) ...[
                Text(
                  'Family Compass',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: FamilyCompassSpacing.lg),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'الخطوة ${step + 1} من $totalSteps'
                          : 'Step ${step + 1} of $totalSteps',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  _StepMarks(step: step, totalSteps: totalSteps),
                ],
              ),
              const SizedBox(height: FamilyCompassSpacing.xl),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey('onboarding.step.$step'),
                  child: content,
                ),
              ),
              if (validationMessage != null) ...[
                const SizedBox(height: FamilyCompassSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: InlineNotice(
                    key: const Key('onboarding.validation'),
                    icon: FamilyCompassIcons.errorOutlineRounded,
                    title:
                        isArabic ? 'تحقق من المعلومات' : 'Check your details',
                    body: validationMessage!,
                  ),
                ),
              ],
              const SizedBox(height: FamilyCompassSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final back = OutlinedButton(
                    key: const Key('onboarding.back'),
                    onPressed: busy ? null : onBack,
                    child: Text(isArabic ? 'رجوع' : 'Back'),
                  );
                  if (!showNext) {
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: back,
                    );
                  }
                  final next = FilledButton(
                    key: const Key('onboarding.continue'),
                    onPressed: busy || !nextEnabled ? null : onNext,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            nextLabel ??
                                (step == 3
                                    ? isArabic
                                        ? 'الدخول إلى بوصلة العائلة'
                                        : 'Enter Family Compass'
                                    : isArabic
                                        ? 'متابعة'
                                        : 'Continue'),
                          ),
                  );
                  final stackActions = constraints.maxWidth < 440 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3;
                  if (stackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        back,
                        const SizedBox(height: FamilyCompassSpacing.sm),
                        next,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (step > 0) ...[
                        back,
                        const SizedBox(width: FamilyCompassSpacing.sm),
                      ],
                      next,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepMarks extends StatelessWidget {
  const _StepMarks({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var index = 0; index < totalSteps; index++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: index == step ? 28 : 10,
            height: 6,
            decoration: BoxDecoration(
              color: index <= step ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (index != totalSteps - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final ar = _isArabic(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ar
              ? 'وقت أكثر معًا. حيرة أقل.'
              : 'More time together. Less wondering.',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        Text(
          ar
              ? 'خططوا للقاءات العائلة، وابقوا على اطلاع، واحصلوا على طمأنينة من المعلومات التي يختار كل شخص مشاركتها.'
              : 'Make plans, keep everyone in the loop, and get reassurance from information each person chooses to share.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.xl),
        _PromiseRow(
          icon: FamilyCompassIcons.eventAvailableOutlined,
          title: ar ? 'التجمع أولاً' : 'Gathering comes first',
          body: ar
              ? 'حوّلوا محادثات العائلة إلى خطط وتذكيرات بسيطة.'
              : 'Turn family conversations into simple plans and reminders.',
        ),
        _PromiseRow(
          icon: FamilyCompassIcons.visibilityOffOutlined,
          title: ar ? 'لا خريطة عائلية دائمة' : 'No permanent family map',
          body: ar
              ? 'لا توجد نقطة مباشرة أو سجل مسار أو شاشة تتبع مخفية.'
              : 'There is no live dot, route history, or hidden tracking screen.',
        ),
        _PromiseRow(
          icon: FamilyCompassIcons.tuneOutlined,
          title: ar ? 'أنت تتحكم في مشاركتك' : 'You control your sharing',
          body: ar
              ? 'يختار كل بالغ ما يشاركه ومع من وإلى متى.'
              : 'Every adult chooses what to share, with whom, and for how long.',
        ),
      ],
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return FlatActionRow(
      topDivider: false,
      bottomDivider: true,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: title,
      body: body,
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep({
    required this.phoneController,
    required this.codeController,
    required this.usesFirebase,
    required this.challengeSent,
    required this.busy,
    required this.onResend,
    required this.internalFirebaseTestAuth,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool usesFirebase;
  final bool challengeSent;
  final bool busy;
  final VoidCallback onResend;
  final bool internalFirebaseTestAuth;

  @override
  Widget build(BuildContext context) {
    final ar = _isArabic(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (internalFirebaseTestAuth) ...[
          Text(
            ar ? 'اختبار داخلي · بلا SMS' : 'INTERNAL TEST · NO SMS',
            key: const Key('onboarding.internalFirebaseTestLabel'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: ar ? 0 : 0.8,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
        ],
        Text(
          ar ? 'تحقق من رقم هاتفك' : 'Verify your phone',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Text(
          usesFirebase
              ? challengeSent
                  ? ar
                      ? !internalFirebaseTestAuth
                          ? 'أدخل الرمز المكوّن من ٦ أرقام الذي أُرسل إلى هاتفك.'
                          : 'أدخل رمز الاختبار المكوّن من ٦ أرقام. لن تُرسل رسالة SMS.'
                      : !internalFirebaseTestAuth
                          ? 'Enter the 6-digit code sent to your phone.'
                          : 'Enter the 6-digit test code. No SMS was sent.'
                  : ar
                      ? !internalFirebaseTestAuth
                          ? 'استخدم رقمك الكامل مع رمز الدولة. لن نطلب الوصول إلى جهات الاتصال.'
                          : 'هذا إصدار اختبار داخلي يستخدم حساب Firebase وهميًا ومهيأ مسبقًا.'
                      : !internalFirebaseTestAuth
                          ? 'Use your full number with country code. Contacts access is not requested.'
                          : 'This internal test build uses one preconfigured fictional Firebase account.'
              : ar
                  ? 'تقبل هذه النسخة المحلية الرقم والرمز المحضرين أدناه.'
                  : 'This local build accepts the prepared number and code below.',
        ),
        if (usesFirebase && !challengeSent && !internalFirebaseTestAuth) ...[
          const SizedBox(height: FamilyCompassSpacing.md),
          Text(
            ar
                ? 'تتلقى Firebase وGoogle رقم هاتفك وتخزنانه للمصادقة ومنع الرسائل غير المرغوب فيها وإساءة الاستخدام. بالمتابعة، توافق على هذه المعالجة وإرسال رسالة SMS.'
                : 'Firebase and Google receive and store your phone number for authentication and spam and abuse prevention. Continuing agrees to this processing and sends an SMS.',
            key: const Key('onboarding.firebasePhoneDisclosure'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (usesFirebase && !challengeSent && internalFirebaseTestAuth) ...[
          const SizedBox(height: FamilyCompassSpacing.md),
          Text(
            ar
                ? 'لن تُرسل رسالة SMS، ولن يعمل أي رقم حقيقي في هذا الإصدار.'
                : 'No SMS will be sent, and no real phone number will work in this build.',
            key: const Key('onboarding.internalFirebaseTestDisclosure'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: FamilyCompassSpacing.lg),
        TextField(
          key: const Key('onboarding.phone'),
          controller: phoneController,
          enabled: !usesFirebase || !challengeSent,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(
            labelText: ar ? 'رقم الهاتف' : 'Mobile number',
            prefixIcon: const Icon(FamilyCompassIcons.phoneOutlined),
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        if (!usesFirebase || challengeSent) ...[
          TextField(
            key: const Key('onboarding.code'),
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: usesFirebase ? 6 : 4,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(
              labelText: usesFirebase
                  ? ar
                      ? 'رمز التحقق المكوّن من ٦ أرقام'
                      : '6-digit verification code'
                  : ar
                      ? 'رمز التحقق التجريبي'
                      : 'Demo verification code',
              prefixIcon: const Icon(FamilyCompassIcons.passwordRounded),
              counterText: '',
            ),
          ),
        ],
        const SizedBox(height: FamilyCompassSpacing.md),
        if (usesFirebase && challengeSent && !internalFirebaseTestAuth)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('onboarding.resendCode'),
              onPressed: busy ? null : onResend,
              child: Text(ar ? 'إعادة إرسال الرمز' : 'Resend code'),
            ),
          )
        else if (!usesFirebase)
          Text(
            ar
                ? 'لا تُرسل رسالة نصية ولا يُنشأ حساب في هذه النسخة المحلية.'
                : 'No SMS is sent, and no account is created in this local build.',
          ),
      ],
    );
  }
}

class _FamilyChoiceStep extends StatelessWidget {
  const _FamilyChoiceStep({
    required this.createFamily,
    required this.onChanged,
  });

  final bool createFamily;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ar = _isArabic(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ar ? 'مساحة عائلتك' : 'Your family space',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Text(
          ar
              ? 'أنشئ عائلة جديدة أو راجع الدعوة قبل الانضمام.'
              : 'Create a new family or preview an invitation before joining.',
        ),
        const SizedBox(height: FamilyCompassSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackChoices = constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            return SegmentedButton<bool>(
              key: const Key('onboarding.familyChoice'),
              direction: stackChoices ? Axis.vertical : Axis.horizontal,
              expandedInsets: stackChoices ? null : EdgeInsets.zero,
              showSelectedIcon: !stackChoices,
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(ar ? 'إنشاء عائلة' : 'Create a family'),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(ar ? 'الانضمام بدعوة' : 'Join by invitation'),
                ),
              ],
              selected: {createFamily},
              onSelectionChanged: (selection) {
                onChanged(selection.first);
              },
            );
          },
        ),
        const SizedBox(height: FamilyCompassSpacing.lg),
        FolioSurface(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          child: createFamily
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ar ? 'عائلة حمادة' : 'Hamadeh Family',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: FamilyCompassSpacing.xs),
                    Text(
                      ar
                          ? 'ستكون أول عضو ومنسق خطط العائلة.'
                          : 'You will be the first member and plan coordinator.',
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ar ? 'طابق رقمك الموثق' : 'Match your verified number',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: FamilyCompassSpacing.xs),
                    Text(
                      ar
                          ? 'سنبحث عن دعوة معلقة مرسلة إلى رقم هاتفك الموثق.'
                          : 'We will look for a pending invitation sent to your verified phone number.',
                    ),
                    const SizedBox(height: FamilyCompassSpacing.sm),
                    Row(
                      children: [
                        const Icon(FamilyCompassIcons.verifiedUserOutlined,
                            size: 18),
                        const SizedBox(width: FamilyCompassSpacing.xs),
                        Expanded(
                          child: Text(
                            ar
                                ? 'تظهر تفاصيل الدعوة قبل القبول'
                                : 'Invitation details appear before acceptance',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _IncomingInvitationStep extends StatelessWidget {
  const _IncomingInvitationStep({
    required this.invitations,
    required this.processingInvitationId,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onReload,
  });

  final List<FirebaseIncomingInvitation> invitations;
  final String? processingInvitationId;
  final bool busy;
  final ValueChanged<FirebaseIncomingInvitation> onAccept;
  final ValueChanged<FirebaseIncomingInvitation> onDecline;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final ar = _isArabic(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ar ? 'دعواتك' : 'Your invitations',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Text(
          ar
              ? 'راجع كل عائلة بعناية. لن تنضم إلى أي عائلة حتى تضغط على قبول.'
              : 'Review each family carefully. You will not join one until you tap Accept.',
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        InlineNotice(
          icon: FamilyCompassIcons.lockOutlineRounded,
          title: ar ? 'تطابق خاص' : 'Private phone match',
          body: ar
              ? 'تظهر فقط الدعوات المرسلة إلى رقمك الموثق، ويبقى الرقم الكامل مخفيًا.'
              : 'Only invitations sent to your verified phone are shown. The full number stays hidden.',
        ),
        const SizedBox(height: FamilyCompassSpacing.lg),
        if (invitations.isEmpty)
          FolioSurface(
            key: const Key('onboarding.invitations.empty'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ar ? 'لا توجد دعوات معلقة' : 'No pending invitations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: FamilyCompassSpacing.xs),
                Text(
                  ar
                      ? 'اطلب من منسق العائلة دعوة رقمك الموثق، ثم حاول مرة أخرى.'
                      : 'Ask a family organizer to invite your verified number, then check again.',
                ),
                const SizedBox(height: FamilyCompassSpacing.md),
                OutlinedButton.icon(
                  key: const Key('onboarding.invitations.reload'),
                  onPressed: busy ? null : onReload,
                  icon: const Icon(FamilyCompassIcons.refreshRounded),
                  label: Text(ar ? 'تحقق مرة أخرى' : 'Check again'),
                ),
              ],
            ),
          )
        else
          for (final invitation in invitations) ...[
            _IncomingInvitationCard(
              invitation: invitation,
              busy: busy,
              processing: processingInvitationId == invitation.id,
              onAccept: () => onAccept(invitation),
              onDecline: () => onDecline(invitation),
            ),
            if (invitation != invitations.last)
              const SizedBox(height: FamilyCompassSpacing.md),
          ],
      ],
    );
  }
}

class _IncomingInvitationCard extends StatelessWidget {
  const _IncomingInvitationCard({
    required this.invitation,
    required this.busy,
    required this.processing,
    required this.onAccept,
    required this.onDecline,
  });

  final FirebaseIncomingInvitation invitation;
  final bool busy;
  final bool processing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final ar = _isArabic(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final expiry = DateFormat.yMMMd(locale).add_jm().format(
          invitation.expiresAt.toLocal(),
        );
    final inviter = invitation.inviterName;
    final role = switch (invitation.role) {
      'organizer' => ar ? 'منسق' : 'Organizer',
      _ => ar ? 'بالغ' : 'Adult',
    };
    final scheme = Theme.of(context).colorScheme;
    return FolioSurface(
      key: Key('onboarding.invitation.${invitation.id}'),
      borderColor: scheme.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                FamilyCompassIcons.peopleOutlineRounded,
                color: scheme.primary,
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.familyName,
                      key: Key(
                        'onboarding.invitation.${invitation.id}.familyName',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (inviter != null) ...[
                      const SizedBox(height: FamilyCompassSpacing.xxs),
                      Text(
                        ar ? 'دعاك $inviter' : 'Invited by $inviter',
                        key: Key(
                          'onboarding.invitation.${invitation.id}.inviterName',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.md),
          _InvitationFact(
            icon: FamilyCompassIcons.phoneOutlined,
            label: ar
                ? 'أُرسلت إلى ${invitation.maskedPhoneNumber}'
                : 'Sent to ${invitation.maskedPhoneNumber}',
            key: Key('onboarding.invitation.${invitation.id}.maskedPhone'),
          ),
          _InvitationFact(
            icon: FamilyCompassIcons.verifiedUserOutlined,
            label: ar ? 'الدور: $role' : 'Role: $role',
            key: Key('onboarding.invitation.${invitation.id}.role'),
          ),
          _InvitationFact(
            icon: FamilyCompassIcons.scheduleOutlined,
            label: ar ? 'تنتهي في $expiry' : 'Expires $expiry',
            key: Key('onboarding.invitation.${invitation.id}.expiry'),
          ),
          if (processing) ...[
            const SizedBox(height: FamilyCompassSpacing.sm),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: FamilyCompassSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final accept = FilledButton(
                key: Key(
                  'onboarding.invitation.${invitation.id}.accept',
                ),
                onPressed: busy ? null : onAccept,
                child: Text(ar ? 'قبول' : 'Accept'),
              );
              final decline = OutlinedButton(
                key: Key(
                  'onboarding.invitation.${invitation.id}.decline',
                ),
                onPressed: busy ? null : onDecline,
                child: Text(ar ? 'رفض' : 'Decline'),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    accept,
                    const SizedBox(height: FamilyCompassSpacing.sm),
                    decline,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  decline,
                  const SizedBox(width: FamilyCompassSpacing.sm),
                  accept,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InvitationFact extends StatelessWidget {
  const _InvitationFact({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: FamilyCompassSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.createsFamily,
    required this.nameController,
    required this.inviteController,
    required this.preparedInvitePhone,
    required this.onInvite,
  });

  final bool createsFamily;
  final TextEditingController nameController;
  final TextEditingController inviteController;
  final String? preparedInvitePhone;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final ar = _isArabic(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ar ? 'أكمل مساحة عائلتك' : 'Finish your family space',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Text(
          ar
              ? createsFamily
                  ? 'اختر اسمك، ثم ادعُ شخصًا برقم هاتفه إذا رغبت.'
                  : 'اختر اسمك، ثم راجع كل دعوة تطابق رقم هاتفك الموثق.'
              : createsFamily
                  ? 'Choose your name, then invite someone by phone if you wish.'
                  : 'Choose your name, then review every invitation that matches your verified phone.',
        ),
        const SizedBox(height: FamilyCompassSpacing.lg),
        TextField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: ar ? 'اسمك' : 'Your name',
            prefixIcon: const Icon(FamilyCompassIcons.personOutlineRounded),
          ),
        ),
        if (createsFamily) ...[
          const SizedBox(height: FamilyCompassSpacing.md),
          TextField(
            controller: inviteController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: ar ? 'دعوة برقم الهاتف' : 'Invite by phone number',
              prefixIcon: const Icon(FamilyCompassIcons.personAddAlt1Outlined),
            ),
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('onboarding.prepareInvite'),
              onPressed: onInvite,
              icon: Icon(
                preparedInvitePhone == null
                    ? FamilyCompassIcons.sendOutlined
                    : FamilyCompassIcons.checkRounded,
              ),
              label: Text(
                preparedInvitePhone != null
                    ? ar
                        ? 'تم إعداد الدعوة'
                        : 'Invitation prepared'
                    : ar
                        ? 'إعداد الدعوة'
                        : 'Prepare invitation',
              ),
            ),
          ),
          if (preparedInvitePhone != null) ...[
            const SizedBox(height: FamilyCompassSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                ar
                    ? 'تم إعداد الدعوة إلى ${_maskPhone(preparedInvitePhone!)}'
                    : 'Invitation prepared for ${_maskPhone(preparedInvitePhone!)}',
                key: const Key('onboarding.preparedInvite'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          const SizedBox(height: FamilyCompassSpacing.md),
          Text(
            ar
                ? 'لا يلزم الوصول إلى جهات الاتصال لإرسال دعوة يدوية.'
                : 'Contacts access is never required for a manual invitation.',
          ),
        ] else ...[
          const SizedBox(height: FamilyCompassSpacing.md),
          FolioSurface(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Text(
              ar
                  ? 'لا تحتاج إلى إدخال رقم أو رمز دعوة. سترى تفاصيل كل تطابق، ويبقى القبول أو الرفض بقرارك.'
                  : 'No invitation number or code is needed. You will see each matching invitation and choose Accept or Decline.',
              key: const Key('onboarding.joinPhoneMatch'),
            ),
          ),
        ],
      ],
    );
  }
}

String _maskPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 4) return digits;
  return '••• ${digits.substring(digits.length - 4)}';
}

bool _isArabic(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ar';
}

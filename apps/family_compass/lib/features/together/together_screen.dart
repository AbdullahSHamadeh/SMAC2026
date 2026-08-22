import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../data/family_realtime_client.dart';
import '../../domain/family_models.dart';
import '../../domain/plan_models.dart';
import '../../l10n/l10n.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../prototype/prototype_scenario_state.dart';
import '../../widgets/prototype_widgets.dart';
import 'confirmed/confirmed_plan_screen.dart';
import 'plan_builder/plan_builder_screen.dart';
import 'poll/poll_detail_screen.dart';
import 'widgets/together_widgets.dart';

enum TogetherInitialView { automatic, overview, builder, poll, confirmed }

enum _TogetherView { overview, builder, poll, confirmed }

/// The planning home for proposals, decisions, and confirmed gatherings.
///
/// Prototype navigation remains local to this feature because the shared
/// prototype state currently has no nested-route field. Plan data and every
/// family-visible action still flow through [PrototypeScenarioController].
class TogetherScreen extends StatefulWidget {
  const TogetherScreen({
    required this.controller,
    this.initialView = TogetherInitialView.automatic,
    super.key,
  });

  final PrototypeScenarioController controller;
  final TogetherInitialView initialView;

  @override
  State<TogetherScreen> createState() => _TogetherScreenState();
}

class _TogetherScreenState extends State<TogetherScreen> {
  late _TogetherView _view;
  PlanPhase? _lastObservedPhase;
  int _lastHandledDeepLinkRevision = 0;
  bool _handlingSystemBack = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.controller.state.plan;
    _lastHandledDeepLinkRevision = widget.controller.deepLinkRevision;
    _view = _viewForDeepLink(widget.controller.lastDeepLink, plan) ??
        _resolveInitialView(widget.initialView, plan);
    _lastObservedPhase = plan?.phase;
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant TogetherScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _lastObservedPhase = widget.controller.state.plan?.phase;
    }
    if (oldWidget.initialView != widget.initialView &&
        widget.initialView != TogetherInitialView.automatic) {
      _view =
          _resolveInitialView(widget.initialView, widget.controller.state.plan);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final plan = state.plan;
        final view = _validView(_view, plan);
        final togetherIsActive = state.ui.selectedTab == 3;
        final linkedReminder = _linkedReminder(plan);
        final content = switch (view) {
          _TogetherView.builder when plan != null => PlanBuilderScreen(
              key: const ValueKey('plan-builder'),
              controller: widget.controller,
              plan: plan,
              onClose: _showOverview,
              onPollSent: () => _show(_TogetherView.poll),
            ),
          _TogetherView.poll when plan != null => PollDetailScreen(
              key: const ValueKey('poll-detail'),
              controller: widget.controller,
              plan: plan,
              onBack: _showOverview,
              onConfirmed: () => _show(_TogetherView.confirmed),
            ),
          _TogetherView.confirmed when plan != null => ConfirmedPlanScreen(
              key: const ValueKey('confirmed-plan'),
              controller: widget.controller,
              plan: plan,
              notificationPermission: state.notificationPermission,
              onBack: _showOverview,
              onPlanAgain: () => _show(_TogetherView.builder),
            ),
          _ => _TogetherOverview(
              state: state,
              currentUserId: widget.controller.currentUserId,
              members: widget.controller.familyMembersForDisplay,
              onStartPlan: () {
                widget.controller.draftFridayDinner();
                if (widget.controller.state.plan?.phase == PlanPhase.draft) {
                  _show(_TogetherView.builder);
                }
              },
              onOpenPoll: () => _show(_TogetherView.poll),
              onOpenConfirmed: () => _show(_TogetherView.confirmed),
              onPlanAgain: () {
                widget.controller.planAgain();
                if (widget.controller.state.plan?.phase == PlanPhase.draft) {
                  _show(_TogetherView.builder);
                }
              },
            ),
        };

        return PopScope<void>(
          canPop: !togetherIsActive || view == _TogetherView.overview,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && togetherIsActive) {
              _handleSystemBack(context, view);
            }
          },
          child: Column(
            children: <Widget>[
              if (linkedReminder != null)
                _LinkedReminderNotice(reminder: linkedReminder),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  PlanReminder? _linkedReminder(FamilyPlan? plan) {
    final link = widget.controller.lastDeepLink;
    if (plan == null || link?.kind != FamilyResourceKind.reminders) return null;
    for (final reminder in plan.reminders) {
      if (reminder.id == link?.resourceId) return reminder;
    }
    return null;
  }

  _TogetherView _validView(_TogetherView requested, FamilyPlan? plan) {
    if (plan == null) return _TogetherView.overview;
    return switch (requested) {
      _TogetherView.builder when plan.phase != PlanPhase.draft =>
        _TogetherView.overview,
      _TogetherView.poll
          when plan.phase != PlanPhase.pollOpen &&
              plan.phase != PlanPhase.readyToConfirm =>
        _TogetherView.overview,
      _TogetherView.confirmed
          when plan.phase != PlanPhase.confirmed &&
              plan.phase != PlanPhase.completed =>
        _TogetherView.overview,
      _ => requested,
    };
  }

  _TogetherView _resolveInitialView(
    TogetherInitialView requested,
    FamilyPlan? plan,
  ) {
    return switch (requested) {
      TogetherInitialView.overview => _TogetherView.overview,
      TogetherInitialView.builder => _TogetherView.builder,
      TogetherInitialView.poll => _TogetherView.poll,
      TogetherInitialView.confirmed => _TogetherView.confirmed,
      TogetherInitialView.automatic when plan?.phase == PlanPhase.draft =>
        _TogetherView.builder,
      TogetherInitialView.automatic => _TogetherView.overview,
    };
  }

  void _showOverview() => _show(_TogetherView.overview);

  void _show(_TogetherView view) {
    if (!mounted) return;
    setState(() => _view = view);
  }

  Future<void> _handleSystemBack(
    BuildContext context,
    _TogetherView view,
  ) async {
    if (_handlingSystemBack || view == _TogetherView.overview) return;
    _handlingSystemBack = true;
    try {
      if (view == _TogetherView.builder &&
          widget.controller.state.ui.hasUnsavedPlanChanges) {
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              togetherCopy(
                dialogContext,
                'Leave this draft?',
                'مغادرة هذه المسودة؟',
              ),
            ),
            content: Text(
              togetherCopy(
                dialogContext,
                'Your latest changes have not been sent to the family.',
                'لم تُرسل أحدث تغييراتك إلى العائلة.',
              ),
            ),
            actions: [
              TextButton(
                key: const ValueKey('keep-editing-plan-draft'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  togetherCopy(
                    dialogContext,
                    'Keep editing',
                    'متابعة التعديل',
                  ),
                ),
              ),
              FilledButton(
                key: const ValueKey('discard-plan-draft'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  togetherCopy(
                    dialogContext,
                    'Leave draft',
                    'مغادرة المسودة',
                  ),
                ),
              ),
            ],
          ),
        );
        if (leave == true) _showOverview();
        return;
      }
      _showOverview();
    } finally {
      _handlingSystemBack = false;
    }
  }

  void _handleControllerChange() {
    final phase = widget.controller.state.plan?.phase;
    final previous = _lastObservedPhase;
    _lastObservedPhase = phase;
    if (!mounted) return;

    if (widget.controller.deepLinkRevision != _lastHandledDeepLinkRevision) {
      final linkedView = _viewForDeepLink(
        widget.controller.lastDeepLink,
        widget.controller.state.plan,
      );
      if (linkedView != null) {
        _lastHandledDeepLinkRevision = widget.controller.deepLinkRevision;
        if (_view != linkedView) setState(() => _view = linkedView);
        return;
      }
    }

    if (phase == previous) return;

    if (previous == PlanPhase.draft &&
        phase == PlanPhase.pollOpen &&
        _view == _TogetherView.builder) {
      setState(() => _view = _TogetherView.poll);
      return;
    }

    // Today and Chat can create the draft while this tab remains alive in an
    // IndexedStack. A manual Back stays on the overview because it does not
    // change the shared plan phase.
    if (widget.initialView == TogetherInitialView.automatic &&
        phase == PlanPhase.draft &&
        _view == _TogetherView.overview) {
      setState(() => _view = _TogetherView.builder);
    }
  }

  _TogetherView? _viewForDeepLink(
    FamilyCompassDeepLink? link,
    FamilyPlan? plan,
  ) {
    if (link == null || plan == null) return null;
    final targetsPlan = switch (link.kind) {
      FamilyResourceKind.plans => link.resourceId == plan.id,
      FamilyResourceKind.reminders =>
        plan.reminders.any((reminder) => reminder.id == link.resourceId),
      _ => false,
    };
    if (!targetsPlan) return null;
    return switch (plan.phase) {
      PlanPhase.draft => _TogetherView.builder,
      PlanPhase.pollOpen || PlanPhase.readyToConfirm => _TogetherView.poll,
      PlanPhase.confirmed || PlanPhase.completed => _TogetherView.confirmed,
      PlanPhase.opportunity => _TogetherView.overview,
    };
  }
}

class _LinkedReminderNotice extends StatelessWidget {
  const _LinkedReminderNotice({required this.reminder});

  final PlanReminder reminder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heading = togetherCopy(
      context,
      'Opened reminder',
      'التذكير المفتوح',
    );
    return Semantics(
      liveRegion: true,
      selected: true,
      excludeSemantics: true,
      label: togetherCopy(
        context,
        'Opened reminder: ${reminder.label}',
        'التذكير المفتوح: ${reminder.label}',
      ),
      child: Container(
        key: ValueKey('together.linkedReminder.${reminder.id}'),
        width: double.infinity,
        margin: const EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.md,
          FamilyCompassSpacing.sm,
          FamilyCompassSpacing.md,
          0,
        ),
        padding: const EdgeInsets.all(FamilyCompassSpacing.sm),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          border: Border.all(color: colors.primary),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              FamilyCompassIcons.notificationsActiveOutlined,
              color: colors.primary,
            ),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    heading,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                        ),
                  ),
                  Text(
                    reminder.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TogetherGroup {
  needsYou,
  waitingForFamily,
  comingUp,
  ideasToRevisit,
  pastMoments,
}

class _TogetherOverview extends StatelessWidget {
  const _TogetherOverview({
    required this.state,
    required this.currentUserId,
    required this.members,
    required this.onStartPlan,
    required this.onOpenPoll,
    required this.onOpenConfirmed,
    required this.onPlanAgain,
  });

  final PrototypeScenarioState state;
  final String currentUserId;
  final List<FamilyMember> members;
  final VoidCallback onStartPlan;
  final VoidCallback onOpenPoll;
  final VoidCallback onOpenConfirmed;
  final VoidCallback onPlanAgain;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    return TogetherPageCanvas(
      scrollKey: const PageStorageKey<String>('together-scroll'),
      builder: (context, constraints, compactHeight) {
        final compactLandscape = compactHeight && constraints.maxWidth >= 680;
        final content = plan == null
            ? _EmptyTogetherOverview(onStartPlan: onStartPlan)
            : _TogetherGroupSection(
                group: _groupFor(plan),
                plan: plan,
                currentUserId: currentUserId,
                onStartPlan: onStartPlan,
                onOpenPoll: onOpenPoll,
                onOpenConfirmed: onOpenConfirmed,
                onPlanAgain: onPlanAgain,
              );

        return Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compactLandscape) ...[
                  _TogetherFamilyIntro(members: members),
                  const SizedBox(height: FamilyCompassSpacing.xl),
                ],
                content,
              ],
            ),
          ),
        );
      },
    );
  }

  _TogetherGroup _groupFor(FamilyPlan plan) {
    return switch (plan.phase) {
      PlanPhase.opportunity => _TogetherGroup.ideasToRevisit,
      PlanPhase.draft => _TogetherGroup.needsYou,
      PlanPhase.pollOpen when plan.responses.containsKey(currentUserId) =>
        _TogetherGroup.waitingForFamily,
      PlanPhase.pollOpen => _TogetherGroup.needsYou,
      PlanPhase.readyToConfirm when plan.coordinatorId == currentUserId =>
        _TogetherGroup.needsYou,
      PlanPhase.readyToConfirm => _TogetherGroup.waitingForFamily,
      PlanPhase.confirmed => _TogetherGroup.comingUp,
      PlanPhase.completed => _TogetherGroup.pastMoments,
    };
  }
}

class _TogetherFamilyIntro extends StatelessWidget {
  const _TogetherFamilyIntro({required this.members});

  final List<FamilyMember> members;

  @override
  Widget build(BuildContext context) {
    final copy = togetherCopy(
      context,
      'Find the next time everyone can be together.',
      'ابحثوا عن الوقت القادم الذي يجمعكم.',
    );
    final identities = FamilyIdentityStack(
      initials:
          members.map((member) => member.initials).toList(growable: false),
      maximumVisible: 4,
      markSize: 34,
      semanticLabel: context.l10n.familyMembersCount(members.length),
    );
    final text = Text(
      copy,
      key: const ValueKey('together-family-intro'),
      style: FamilyCompassTypography.of(context).titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.5) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          identities,
          const SizedBox(height: FamilyCompassSpacing.sm),
          text,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        identities,
        const SizedBox(width: FamilyCompassSpacing.md),
        Expanded(child: text),
      ],
    );
  }
}

class _EmptyTogetherOverview extends StatelessWidget {
  const _EmptyTogetherOverview({required this.onStartPlan});

  final VoidCallback onStartPlan;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TogetherSectionHeading(
            key: const ValueKey('together-empty-section'),
            title: togetherCopy(
                context, 'Plans will live here', 'ستظهر الخطط هنا'),
            subtitle: togetherCopy(
              context,
              'Start with one simple idea for time together.',
              'ابدأ بفكرة بسيطة لقضاء وقت معًا.',
            ),
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          TogetherEmptyRow(
            key: const ValueKey('together-empty-plan'),
            message: togetherCopy(
              context,
              'There is no family plan yet.',
              'لا توجد خطة عائلية بعد.',
            ),
            actionLabel: togetherCopy(
              context,
              'Start a family plan',
              'بدء خطة عائلية',
            ),
            onPressed: onStartPlan,
          ),
        ],
      );
}

class _TogetherGroupSection extends StatelessWidget {
  const _TogetherGroupSection({
    required this.group,
    required this.plan,
    required this.currentUserId,
    required this.onStartPlan,
    required this.onOpenPoll,
    required this.onOpenConfirmed,
    required this.onPlanAgain,
  });

  final _TogetherGroup group;
  final FamilyPlan plan;
  final String currentUserId;
  final VoidCallback onStartPlan;
  final VoidCallback onOpenPoll;
  final VoidCallback onOpenConfirmed;
  final VoidCallback onPlanAgain;

  @override
  Widget build(BuildContext context) {
    final title = switch (group) {
      _TogetherGroup.needsYou =>
        togetherCopy(context, 'Needs you', 'يحتاج إليك'),
      _TogetherGroup.waitingForFamily =>
        togetherCopy(context, 'Waiting for family', 'بانتظار العائلة'),
      _TogetherGroup.comingUp => togetherCopy(context, 'Coming up', 'قريبًا'),
      _TogetherGroup.ideasToRevisit =>
        togetherCopy(context, 'Ideas to revisit', 'أفكار للعودة إليها'),
      _TogetherGroup.pastMoments =>
        togetherCopy(context, 'Past moments', 'لحظات سابقة'),
    };
    final subtitle = switch (group) {
      _TogetherGroup.needsYou => togetherCopy(
          context,
          'One plan is ready for your next step.',
          'خطة واحدة جاهزة لخطوتك التالية.',
        ),
      _TogetherGroup.waitingForFamily => togetherCopy(
          context,
          'Your reply is in. The family can catch up when they are ready.',
          'تم تسجيل ردك. يمكن للعائلة إكمال الرد عندما يناسبها.',
        ),
      _TogetherGroup.comingUp => togetherCopy(
          context,
          'A family moment to look forward to.',
          'لحظة عائلية جميلة تنتظرونها.',
        ),
      _TogetherGroup.ideasToRevisit => togetherCopy(
          context,
          'Saved possibilities that have not been sent yet.',
          'اقتراحات محفوظة لم تُرسل بعد.',
        ),
      _TogetherGroup.pastMoments => togetherCopy(
          context,
          'Bring back a plan when the time feels right.',
          'أعد استخدام خطة عندما يحين الوقت المناسب.',
        ),
    };
    final headingKey = switch (group) {
      _TogetherGroup.needsYou => const ValueKey('together-needs-you-section'),
      _TogetherGroup.waitingForFamily =>
        const ValueKey('together-waiting-section'),
      _TogetherGroup.comingUp => const ValueKey('together-coming-up-section'),
      _TogetherGroup.ideasToRevisit => const ValueKey('together-ideas-section'),
      _TogetherGroup.pastMoments =>
        const ValueKey('together-past-moments-section'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TogetherSectionHeading(
          key: headingKey,
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        _buildPlan(context),
      ],
    );
  }

  Widget _buildPlan(BuildContext context) {
    final responseCount = plan.responses.length;
    final participantCount = plan.participantIds.length;
    final hasResponded = plan.responses.containsKey(currentUserId);
    final key = switch (plan.phase) {
      PlanPhase.opportunity => const ValueKey('together-dinner-idea'),
      PlanPhase.draft => const ValueKey('together-plan-draft'),
      PlanPhase.pollOpen ||
      PlanPhase.readyToConfirm =>
        const ValueKey('together-open-poll'),
      PlanPhase.confirmed => const ValueKey('together-next-plan'),
      PlanPhase.completed => const ValueKey('together-completed-plan'),
    };
    final phaseLabel = switch (plan.phase) {
      PlanPhase.opportunity =>
        togetherCopy(context, 'Idea from Chat', 'فكرة من الدردشة'),
      PlanPhase.draft => togetherCopy(context, 'Private draft', 'مسودة خاصة'),
      PlanPhase.pollOpen when hasResponded =>
        togetherCopy(context, 'Your reply is in', 'تم تسجيل ردك'),
      PlanPhase.pollOpen =>
        togetherCopy(context, 'Your reply is needed', 'ردك مطلوب'),
      PlanPhase.readyToConfirm =>
        togetherCopy(context, 'Ready to confirm', 'جاهز للتأكيد'),
      PlanPhase.confirmed => togetherCopy(context, 'Confirmed', 'تم التأكيد'),
      PlanPhase.completed => togetherCopy(context, 'Completed', 'اكتمل'),
    };
    final detail = switch (plan.phase) {
      PlanPhase.opportunity => togetherCopy(
          context,
          '${plan.candidateTimes.length} possible times are ready to review.',
          '${plan.candidateTimes.length} من الأوقات المقترحة جاهزة للمراجعة.',
        ),
      PlanPhase.draft => togetherCopy(
          context,
          'Review the people and times before sending.',
          'راجع الأشخاص والأوقات قبل الإرسال.',
        ),
      PlanPhase.pollOpen => togetherCopy(
          context,
          '$responseCount of $participantCount replied.',
          'رد $responseCount من أصل $participantCount.',
        ),
      PlanPhase.readyToConfirm => togetherCopy(
          context,
          '$responseCount of $participantCount replied. Choose the final time.',
          'رد $responseCount من أصل $participantCount. اختر الوقت النهائي.',
        ),
      PlanPhase.confirmed => confirmedPlanLabel(context, plan),
      PlanPhase.completed => togetherCopy(
          context,
          'A family moment you can plan again.',
          'لحظة عائلية يمكنكم التخطيط لها مجددًا.',
        ),
    };
    final actionLabel = switch (plan.phase) {
      PlanPhase.opportunity =>
        togetherCopy(context, 'Start a family plan', 'بدء خطة عائلية'),
      PlanPhase.draft => togetherCopy(context, 'Continue plan', 'متابعة الخطة'),
      PlanPhase.pollOpen when hasResponded =>
        togetherCopy(context, 'Review poll', 'مراجعة الاستطلاع'),
      PlanPhase.pollOpen => togetherCopy(context, 'Respond', 'الرد'),
      PlanPhase.readyToConfirm =>
        togetherCopy(context, 'Choose final time', 'اختيار الوقت النهائي'),
      PlanPhase.confirmed => togetherCopy(context, 'View plan', 'عرض الخطة'),
      PlanPhase.completed =>
        togetherCopy(context, 'Plan this again', 'التخطيط مجددًا'),
    };
    final onPressed = switch (plan.phase) {
      PlanPhase.opportunity || PlanPhase.draft => onStartPlan,
      PlanPhase.pollOpen || PlanPhase.readyToConfirm => onOpenPoll,
      PlanPhase.confirmed => onOpenConfirmed,
      PlanPhase.completed => onPlanAgain,
    };
    final supportingLabel = switch (plan.phase) {
      PlanPhase.confirmed => togetherCopy(
          context,
          '${plan.participantIds.length} family members are included.',
          '${plan.participantIds.length} من أفراد العائلة مشمولون.',
        ),
      PlanPhase.completed => togetherCopy(
          context,
          'The details are saved for next time.',
          'التفاصيل محفوظة للمرة القادمة.',
        ),
      _ => null,
    };

    return TogetherPlanFolio(
      key: key,
      plan: plan,
      phaseLabel: phaseLabel,
      detail: detail,
      supportingLabel: supportingLabel,
      actionLabel: actionLabel,
      onPressed: onPressed,
      emphasized: plan.phase == PlanPhase.opportunity ||
          plan.phase == PlanPhase.confirmed,
    );
  }
}

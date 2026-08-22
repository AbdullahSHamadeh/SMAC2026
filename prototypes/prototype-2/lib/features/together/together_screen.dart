import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../domain/plan_models.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../prototype/prototype_scenario_state.dart';
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

  @override
  void initState() {
    super.initState();
    final plan = widget.controller.state.plan;
    _view = _resolveInitialView(widget.initialView, plan);
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

        return switch (view) {
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
              controller: widget.controller,
              state: state,
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
      },
    );
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

  void _handleControllerChange() {
    final phase = widget.controller.state.plan?.phase;
    final previous = _lastObservedPhase;
    _lastObservedPhase = phase;
    if (!mounted || phase == previous) return;

    // Today and Chat can create the draft while this tab remains alive in an
    // IndexedStack. A manual Back stays on the overview because it does not
    // change the shared plan phase.
    if (widget.initialView == TogetherInitialView.automatic &&
        phase == PlanPhase.draft &&
        _view == _TogetherView.overview) {
      setState(() => _view = _TogetherView.builder);
    }
  }
}

class _TogetherOverview extends StatelessWidget {
  const _TogetherOverview({
    required this.controller,
    required this.state,
    required this.onStartPlan,
    required this.onOpenPoll,
    required this.onOpenConfirmed,
    required this.onPlanAgain,
  });

  final PrototypeScenarioController controller;
  final PrototypeScenarioState state;
  final VoidCallback onStartPlan;
  final VoidCallback onOpenPoll;
  final VoidCallback onOpenConfirmed;
  final VoidCallback onPlanAgain;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    final textTheme = FamilyCompassTypography.of(context);

    return PageAtmosphere(
      child: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey<String>('together-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                FamilyCompassSpacing.md,
                FamilyCompassSpacing.lg,
                FamilyCompassSpacing.md,
                FamilyCompassSpacing.xxl,
              ),
              sliver: SliverList.list(
                children: [
                  Text('Together', style: textTheme.headlineLarge),
                  const SizedBox(height: FamilyCompassSpacing.xs),
                  Text(
                    'Make the next family moment easy to decide and remember.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.xl),
                  const TogetherSectionHeading(
                    key: ValueKey('together-next-section'),
                    title: 'Next',
                    subtitle: 'Your next confirmed gathering',
                  ),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  if (plan?.phase == PlanPhase.confirmed)
                    TogetherPlanCard(
                      key: const ValueKey('together-next-plan'),
                      icon: Icons.restaurant_rounded,
                      title: plan!.title,
                      detail: confirmedPlanLabel(context, plan),
                      actionLabel: 'View plan',
                      onPressed: onOpenConfirmed,
                      emphasized: true,
                    )
                  else
                    const TogetherEmptyCard(
                      message: 'No gathering is confirmed yet.',
                    ),
                  const SizedBox(height: FamilyCompassSpacing.xl),
                  const TogetherSectionHeading(
                    key: ValueKey('together-decide-section'),
                    title: 'Decide',
                    subtitle: 'Polls waiting for a family decision',
                  ),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  if (plan?.phase == PlanPhase.pollOpen ||
                      plan?.phase == PlanPhase.readyToConfirm)
                    TogetherPlanCard(
                      key: const ValueKey('together-open-poll'),
                      icon: Icons.how_to_vote_outlined,
                      title: plan!.title,
                      detail: plan.phase == PlanPhase.readyToConfirm
                          ? 'Everyone replied. Ready to confirm.'
                          : '${plan.responses.length} of ${plan.participantIds.length} replied',
                      actionLabel: plan.responses.containsKey('abdullah')
                          ? 'Review poll'
                          : 'Respond',
                      onPressed: onOpenPoll,
                    )
                  else
                    const TogetherEmptyCard(message: 'No open polls.'),
                  const SizedBox(height: FamilyCompassSpacing.xl),
                  const TogetherSectionHeading(
                    key: ValueKey('together-later-section'),
                    title: 'Later',
                    subtitle: 'Ideas and gatherings you can use again',
                  ),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  if (plan?.phase == PlanPhase.completed)
                    TogetherPlanCard(
                      key: const ValueKey('together-completed-plan'),
                      icon: Icons.check_circle_outline_rounded,
                      title: plan!.title,
                      detail: 'Completed · Keep the idea for another Friday',
                      actionLabel: 'Plan this again',
                      onPressed: onPlanAgain,
                    )
                  else if (plan?.phase == PlanPhase.draft)
                    TogetherPlanCard(
                      key: const ValueKey('together-plan-draft'),
                      icon: Icons.edit_calendar_outlined,
                      title: plan!.title,
                      detail: 'Not sent · Continue reviewing the family poll.',
                      actionLabel: 'Continue plan',
                      onPressed: onStartPlan,
                    )
                  else if (plan?.phase == PlanPhase.opportunity)
                    TogetherPlanCard(
                      key: const ValueKey('together-dinner-idea'),
                      icon: Icons.auto_awesome_rounded,
                      title: 'Friday family dinner',
                      detail: 'Two possible times are ready to review.',
                      actionLabel: 'Start a family plan',
                      onPressed: onStartPlan,
                      emphasized: true,
                    )
                  else if (plan == null)
                    TogetherEmptyCard(
                      message: 'Save an idea when the family is ready.',
                      actionLabel: 'Start a family plan',
                      onPressed: onStartPlan,
                    )
                  else
                    const TogetherEmptyCard(
                      message: 'Future plans and saved ideas will appear here.',
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

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../domain/plan_models.dart';
import '../../l10n/l10n.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../prototype/prototype_scenario_state.dart';
import '../../widgets/prototype_widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.controller,
    required this.onOpenChat,
    required this.onOpenCompass,
    required this.onOpenTogether,
  });

  final PrototypeScenarioController controller;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenCompass;
  final VoidCallback onOpenTogether;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final plan = state.plan;
    final locale = Localizations.localeOf(context).languageCode;
    final friday = locale == 'ar' ? 'الجمعة' : 'Friday';

    if (state.surfaceState == SurfaceState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return PrototypePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.todayGreeting('Abdullah'),
            style: FamilyCompassTypography.of(context).headlineMedium,
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(
            locale == 'ar'
                ? 'ما تحتاجه العائلة اليوم، دون ضوضاء.'
                : 'What your family needs today, without the noise.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.lg),
          if (state.surfaceState == SurfaceState.offlineCached) ...[
            _OfflineBanner(controller: controller),
            const SizedBox(height: FamilyCompassSpacing.lg),
          ],
          if (!state.aiAvailable) ...[
            const StatusBanner(
              icon: Icons.auto_awesome_outlined,
              title: 'Compass is taking a break',
              body: 'Chat and family plans still work normally.',
              tone: StatusBannerTone.privacy,
            ),
            const SizedBox(height: FamilyCompassSpacing.lg),
          ],
          if (state.surfaceState == SurfaceState.empty || plan == null)
            EmptyStateCard(
              icon: Icons.diversity_3_rounded,
              title: context.l10n.todayNoUrgentUpdates,
              body: locale == 'ar'
                  ? 'يمكنك بدء خطة بسيطة عندما تكون العائلة مستعدة.'
                  : 'Start a simple plan whenever the family is ready.',
              action: FilledButton.icon(
                key: const Key('today.startPlan'),
                onPressed: () {
                  controller.reset(PrototypeScenario.dinnerOpportunity);
                  controller.draftFridayDinner();
                  onOpenTogether();
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  locale == 'ar' ? 'ابدأ خطة عائلية' : 'Start a family plan',
                ),
              ),
            )
          else ...[
            if (plan.phase == PlanPhase.confirmed) ...[
              SectionHeading(title: context.l10n.todayNextGathering),
              _NextGatheringCard(
                key: const Key('today.next'),
                details: context.l10n.todayDinnerDetails(friday, '7:30 PM'),
                onView: onOpenTogether,
              ),
              const SizedBox(height: FamilyCompassSpacing.lg),
            ],
            if (_needsReply(plan)) ...[
              SectionHeading(title: context.l10n.todayNeedsYourReply),
              _NeedsReplyCard(
                key: const Key('today.needsReply'),
                responseCount: plan.responses.length,
                onReply: onOpenTogether,
              ),
              const SizedBox(height: FamilyCompassSpacing.lg),
            ],
            if (state.statuses['dad']?.isUsableAt(state.scenarioNow) ??
                false) ...[
              SectionHeading(title: context.l10n.todaySharedUpdates),
              _SharedUpdateCard(
                key: const Key('today.relevantUpdate'),
                onAskCompass: onOpenCompass,
                title: locale == 'ar'
                    ? 'شارك الأب أنه يتوقع الوصول قرابة 7:20 مساءً'
                    : 'Dad expects to arrive around 7:20 PM',
                source: locale == 'ar' ? 'مشاركة من الأب' : 'Shared by Dad',
                freshness: locale == 'ar' ? 'قبل 3 دقائق' : '3 minutes ago',
                action: locale == 'ar'
                    ? 'اسأل البوصلة عن هذا'
                    : 'Ask Compass about this',
              ),
              const SizedBox(height: FamilyCompassSpacing.lg),
            ],
            if (state.hasActiveSuggestion) ...[
              SectionHeading(title: context.l10n.todayCompassSuggestion),
              _SuggestionCard(
                key: const Key('today.suggestion.dinner'),
                onOpenChat: onOpenChat,
                source: locale == 'ar'
                    ? 'بناءً على محادثة العائلة'
                    : 'Based on the family conversation',
                action: locale == 'ar' ? 'تابع في الدردشة' : 'Continue in Chat',
              ),
            ],
            if (plan.phase == PlanPhase.completed) ...[
              EmptyStateCard(
                icon: Icons.celebration_outlined,
                title: 'A good evening, completed',
                body:
                    'Keep the plan nearby or make another one when it suits you.',
                action: FilledButton(
                  onPressed: onOpenTogether,
                  child: const Text('Plan this again'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static bool _needsReply(FamilyPlan plan) {
    if (plan.phase == PlanPhase.readyToConfirm) return true;
    return plan.phase == PlanPhase.pollOpen &&
        !plan.responses.containsKey('abdullah');
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.controller});

  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    return StatusBanner(
      icon: Icons.cloud_off_outlined,
      title: 'Showing saved family information',
      body: 'Last updated 12 minutes ago',
      tone: StatusBannerTone.warning,
      action: TextButton(
        key: const Key('offline.retry'),
        onPressed: controller.state.isRetrying ? null : controller.retryOffline,
        child: controller.state.isRetrying
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Retry'),
      ),
    );
  }
}

class _NextGatheringCard extends StatelessWidget {
  const _NextGatheringCard(
      {super.key, required this.details, required this.onView});

  final String details;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final colors = FamilyCompassSemanticColors.of(context);
    return SoftCard(
      color: colors.gatheringContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconWell(
                icon: Icons.dinner_dining_rounded,
                background: colors.gathering,
                foreground: colors.onGathering,
                size: 52,
              ),
              const SizedBox(width: FamilyCompassSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.todayFamilyDinner,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colors.onGatheringContainer,
                          ),
                    ),
                    const SizedBox(height: FamilyCompassSpacing.xs),
                    Text(
                      details,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.onGatheringContainer,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.md),
          const FamilyAvatarStack(),
          const SizedBox(height: FamilyCompassSpacing.md),
          Wrap(
            spacing: FamilyCompassSpacing.xs,
            runSpacing: FamilyCompassSpacing.xs,
            children: [
              Chip(
                avatar: Icon(Icons.groups_rounded, color: colors.gathering),
                label: const Text('4 attending'),
              ),
              Chip(
                avatar: Icon(Icons.home_outlined, color: colors.gathering),
                label: const Text('At home'),
              ),
              Chip(
                avatar: Icon(Icons.notifications_active_outlined,
                    color: colors.gathering),
                label: const Text('Reminder on'),
              ),
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.md),
          FilledButton.tonalIcon(
            onPressed: onView,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(context.l10n.actionViewPlan),
          ),
        ],
      ),
    );
  }
}

class _NeedsReplyCard extends StatelessWidget {
  const _NeedsReplyCard({
    super.key,
    required this.responseCount,
    required this.onReply,
  });

  final int responseCount;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final colors = FamilyCompassSemanticColors.of(context);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(
                icon: Icons.how_to_vote_outlined,
                background: colors.gatheringContainer,
                foreground: colors.gathering,
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.todayFamilyDinner,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          Text(context.l10n.todayRsvpPrompt),
          const SizedBox(height: FamilyCompassSpacing.sm),
          Text(
            context.l10n.pollResponsesCount(responseCount),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: FamilyCompassSpacing.md),
          FilledButton(
            onPressed: onReply,
            child: Text(context.l10n.actionReply),
          ),
        ],
      ),
    );
  }
}

class _SharedUpdateCard extends StatelessWidget {
  const _SharedUpdateCard({
    super.key,
    required this.onAskCompass,
    required this.title,
    required this.source,
    required this.freshness,
    required this.action,
  });

  final VoidCallback onAskCompass;
  final String title;
  final String source;
  final String freshness;
  final String action;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MemberAvatar(
                initials: 'D',
                memberId: 'dad',
                radius: 22,
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          SourceLine(source: source, freshness: freshness),
          const SizedBox(height: FamilyCompassSpacing.md),
          TextButton.icon(
            onPressed: onAskCompass,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.onOpenChat,
    required this.source,
    required this.action,
  });

  final VoidCallback onOpenChat;
  final String source;
  final String action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      color: scheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconWell(
                icon: Icons.auto_awesome_rounded,
                background: scheme.primary,
                foreground: scheme.onPrimary,
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.compassGatheringSuggestion,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          SourceLine(
            icon: Icons.forum_outlined,
            source: source,
          ),
          const SizedBox(height: FamilyCompassSpacing.md),
          FilledButton.icon(
            onPressed: onOpenChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

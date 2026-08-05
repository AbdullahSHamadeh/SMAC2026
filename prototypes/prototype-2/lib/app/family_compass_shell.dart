import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import '../features/chat/chat_screen.dart';
import '../features/compass/compass_screen.dart';
import '../features/family/family_menu_screen.dart';
import '../features/today/today_screen.dart';
import '../features/together/together_screen.dart';
import '../l10n/l10n.dart';
import '../prototype/prototype_scenario_controller.dart';
import '../prototype/prototype_scenario_state.dart';

class FamilyCompassShell extends StatelessWidget {
  const FamilyCompassShell({
    super.key,
    required this.controller,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.onPreviewOnboarding,
  });

  final PrototypeScenarioController controller;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final VoidCallback onPreviewOnboarding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.state.ui.selectedTab.clamp(0, 3);
        return LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight =
                constraints.maxHeight < FamilyCompassBreakpoints.compactHeight;
            final useBottomNavigation = compactHeight ||
                constraints.maxWidth < FamilyCompassBreakpoints.compactWidth;
            final destinations = _destinations(context);
            final content = IndexedStack(
              index: selected,
              children: [
                TodayScreen(
                  key: const PageStorageKey('screen.today'),
                  controller: controller,
                  onOpenChat: () => controller.selectTab(1),
                  onOpenCompass: () => controller.selectTab(2),
                  onOpenTogether: () => controller.selectTab(3),
                ),
                ChatScreen(
                  key: const PageStorageKey('screen.chat'),
                  controller: controller,
                ),
                CompassScreen(
                  key: const PageStorageKey('screen.compass'),
                  controller: controller,
                ),
                TogetherScreen(
                  key: const PageStorageKey('screen.together'),
                  controller: controller,
                ),
              ],
            );

            return Scaffold(
              appBar: AppBar(
                toolbarHeight: compactHeight ? 56 : 68,
                titleSpacing: FamilyCompassSpacing.md,
                title: Semantics(
                  button: true,
                  hint: 'Long press to choose a prototype scenario',
                  child: GestureDetector(
                    onLongPress: () => _showScenarioPicker(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.explore_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: FamilyCompassSpacing.sm),
                        Flexible(
                          child: Text(
                            context.l10n.appName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    key: const Key('family.menu'),
                    tooltip: 'Family and profile',
                    onPressed: () => _openFamilyMenu(context),
                    icon: const CircleAvatar(
                      radius: 18,
                      child: Text('AH'),
                    ),
                  ),
                  const SizedBox(width: FamilyCompassSpacing.xs),
                ],
              ),
              body: useBottomNavigation
                  ? content
                  : Row(
                      children: [
                        NavigationRail(
                          selectedIndex: selected,
                          onDestinationSelected: controller.selectTab,
                          labelType: NavigationRailLabelType.all,
                          destinations: [
                            for (final destination in destinations)
                              NavigationRailDestination(
                                icon: KeyedSubtree(
                                  key: destination.key,
                                  child: Icon(destination.icon),
                                ),
                                selectedIcon: Icon(destination.selectedIcon),
                                label: Text(destination.label),
                              ),
                          ],
                        ),
                        VerticalDivider(
                          width: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Expanded(child: content),
                      ],
                    ),
              bottomNavigationBar: useBottomNavigation
                  ? NavigationBar(
                      selectedIndex: selected,
                      onDestinationSelected: controller.selectTab,
                      destinations: [
                        for (final destination in destinations)
                          NavigationDestination(
                            key: destination.key,
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: destination.label,
                          ),
                      ],
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  List<_ShellDestination> _destinations(BuildContext context) => [
        _ShellDestination(
          key: const Key('nav.today'),
          label: context.l10n.tabToday,
          icon: Icons.today_outlined,
          selectedIcon: Icons.today_rounded,
        ),
        _ShellDestination(
          key: const Key('nav.chat'),
          label: context.l10n.tabChat,
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
        ),
        _ShellDestination(
          key: const Key('nav.compass'),
          label: context.l10n.tabCompass,
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome_rounded,
        ),
        _ShellDestination(
          key: const Key('nav.together'),
          label: context.l10n.tabTogether,
          icon: Icons.diversity_3_outlined,
          selectedIcon: Icons.diversity_3_rounded,
        ),
      ];

  Future<void> _openFamilyMenu(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyMenuScreen(
          controller: controller,
          onToggleLanguage: onToggleLanguage,
          onToggleTheme: onToggleTheme,
          onPreviewOnboarding: onPreviewOnboarding,
        ),
      ),
    );
  }

  Future<void> _showScenarioPicker(BuildContext context) async {
    final selection = await showModalBottomSheet<PrototypeScenario>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            FamilyCompassSpacing.md,
            0,
            FamilyCompassSpacing.md,
            FamilyCompassSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Prototype scenarios',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FamilyCompassSpacing.sm),
              for (final scenario in PrototypeScenario.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_scenarioIcon(scenario)),
                  title: Text(_scenarioLabel(scenario)),
                  trailing: scenario == controller.state.scenario
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, scenario),
                ),
            ],
          ),
        ),
      ),
    );
    if (selection != null) controller.reset(selection);
  }

  static String _scenarioLabel(PrototypeScenario scenario) =>
      switch (scenario) {
        PrototypeScenario.dinnerOpportunity => 'Dinner opportunity',
        PrototypeScenario.dinnerPollOpen => 'Dinner poll open',
        PrototypeScenario.reassuranceAtSeven => 'Reassurance with shared ETA',
        PrototypeScenario.reassuranceUnknown => 'Reassurance with no update',
        PrototypeScenario.todayEmpty => 'Empty Today',
        PrototypeScenario.offlineCached => 'Offline with cached content',
        PrototypeScenario.aiUnavailable => 'Compass unavailable',
        PrototypeScenario.sharingPaused => 'Sharing paused',
        PrototypeScenario.notificationDenied => 'Notifications denied',
      };

  static IconData _scenarioIcon(PrototypeScenario scenario) =>
      switch (scenario) {
        PrototypeScenario.dinnerOpportunity => Icons.lightbulb_outline_rounded,
        PrototypeScenario.dinnerPollOpen => Icons.how_to_vote_outlined,
        PrototypeScenario.reassuranceAtSeven => Icons.schedule_rounded,
        PrototypeScenario.reassuranceUnknown => Icons.help_outline_rounded,
        PrototypeScenario.todayEmpty => Icons.inbox_outlined,
        PrototypeScenario.offlineCached => Icons.cloud_off_outlined,
        PrototypeScenario.aiUnavailable => Icons.auto_awesome_outlined,
        PrototypeScenario.sharingPaused => Icons.pause_circle_outline_rounded,
        PrototypeScenario.notificationDenied =>
          Icons.notifications_off_outlined,
      };
}

class _ShellDestination {
  const _ShellDestination({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final Key key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

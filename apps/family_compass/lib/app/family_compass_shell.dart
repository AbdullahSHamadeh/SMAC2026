import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import '../data/family_compass_repositories.dart';
import '../features/chat/chat_screen.dart';
import '../features/compass/compass_screen.dart';
import '../features/family/family_invitation_controller.dart';
import '../features/family/family_menu_screen.dart';
import '../features/today/today_screen.dart';
import '../features/together/together_screen.dart';
import '../firebase/firebase_notifications.dart';
import '../l10n/l10n.dart';
import '../prototype/prototype_scenario_controller.dart';
import '../prototype/prototype_scenario_state.dart';
import '../widgets/prototype_widgets.dart';

class FamilyCompassShell extends StatelessWidget {
  const FamilyCompassShell({
    super.key,
    required this.controller,
    required this.invitationController,
    required this.onLocaleChanged,
    required this.onDarkModeChanged,
    required this.onPreviewOnboarding,
    this.compassRepository,
    this.familyRoomCompassRepository,
    this.familyId,
    this.notificationPreferences,
    this.onSignOut,
    this.onFamilyScopeChanged,
  });

  final PrototypeScenarioController controller;
  final FamilyInvitationController invitationController;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onPreviewOnboarding;
  final CompassRepository? compassRepository;
  final FamilyRoomCompassRepository? familyRoomCompassRepository;
  final String? familyId;
  final NotificationPreferenceController? notificationPreferences;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onFamilyScopeChanged;

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
            final usesCupertinoTabs =
                Theme.of(context).platform == TargetPlatform.iOS;
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
                  familyRoomCompassRepository: familyRoomCompassRepository,
                  familyId: familyId,
                ),
                CompassScreen(
                  key: const PageStorageKey('screen.compass'),
                  controller: controller,
                  repository: compassRepository,
                ),
                TogetherScreen(
                  key: const PageStorageKey('screen.together'),
                  controller: controller,
                ),
              ],
            );

            return Scaffold(
              appBar: AppBar(
                toolbarHeight: compactHeight ? 52 : 58,
                titleSpacing: FamilyCompassSpacing.md,
                title: _DestinationTitle(
                  label: destinations[selected].label,
                  debugHint: context.l10n.shellScenarioPickerHint,
                  onOpenDebugPicker: () => _showScenarioPicker(context),
                ),
                actions: [
                  IconButton(
                    key: const Key('family.menu'),
                    tooltip: context.l10n.shellFamilyAndProfile,
                    onPressed: () => _openFamilyMenu(context),
                    icon: MemberMark(
                      initial: controller.currentMemberForDisplay.initials,
                      size: 34,
                      semanticLabel: context.l10n.shellFamilyAndProfile,
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
                  ? usesCupertinoTabs
                      ? MediaQuery.withNoTextScaling(
                          // Native UITabBar labels stay at their compact control
                          // size even when content text uses an accessibility
                          // size. The complete localized labels and selected
                          // state remain available through tab semantics.
                          child: CupertinoTabBar(
                            key: const Key('shell.cupertinoTabBar'),
                            currentIndex: selected,
                            onTap: controller.selectTab,
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.96),
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                                width: 0.5,
                              ),
                            ),
                            height: 58,
                            iconSize: 23,
                            items: [
                              for (final destination in destinations)
                                BottomNavigationBarItem(
                                  icon: KeyedSubtree(
                                    key: destination.key,
                                    child: Icon(destination.icon),
                                  ),
                                  activeIcon: KeyedSubtree(
                                    key: destination.key,
                                    child: Icon(destination.selectedIcon),
                                  ),
                                  label: destination.label,
                                ),
                            ],
                          ),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: NavigationBar(
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
                          ),
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
          icon: FamilyCompassIcons.todayOutline,
          selectedIcon: FamilyCompassIcons.todayFilled,
        ),
        _ShellDestination(
          key: const Key('nav.chat'),
          label: context.l10n.tabChat,
          icon: FamilyCompassIcons.chatOutline,
          selectedIcon: FamilyCompassIcons.chatFilled,
        ),
        _ShellDestination(
          key: const Key('nav.compass'),
          label: context.l10n.tabCompass,
          icon: FamilyCompassIcons.compassOutline,
          selectedIcon: FamilyCompassIcons.compassFilled,
        ),
        _ShellDestination(
          key: const Key('nav.together'),
          label: context.l10n.tabTogether,
          icon: FamilyCompassIcons.togetherOutline,
          selectedIcon: FamilyCompassIcons.togetherFilled,
        ),
      ];

  Future<void> _openFamilyMenu(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyMenuScreen(
          controller: controller,
          invitationController: invitationController,
          onLocaleChanged: onLocaleChanged,
          onDarkModeChanged: onDarkModeChanged,
          onPreviewOnboarding: onPreviewOnboarding,
          notificationPreferences: notificationPreferences,
          onSignOut: onSignOut,
          onFamilyScopeChanged: onFamilyScopeChanged,
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
                context.l10n.shellDemoStatesTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FamilyCompassSpacing.sm),
              for (final scenario in PrototypeScenario.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_scenarioIcon(scenario)),
                  title: Text(_scenarioLabel(context, scenario)),
                  trailing: scenario == controller.state.scenario
                      ? const Icon(FamilyCompassIcons.checkRounded)
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

  static String _scenarioLabel(
    BuildContext context,
    PrototypeScenario scenario,
  ) =>
      switch (scenario) {
        PrototypeScenario.dinnerOpportunity =>
          context.l10n.shellScenarioDinnerOpportunity,
        PrototypeScenario.dinnerPollOpen =>
          context.l10n.shellScenarioDinnerPollOpen,
        PrototypeScenario.reassuranceAtSeven =>
          context.l10n.shellScenarioReassuranceSharedEta,
        PrototypeScenario.reassuranceUnknown =>
          context.l10n.shellScenarioReassuranceNoUpdate,
        PrototypeScenario.todayEmpty => context.l10n.shellScenarioTodayEmpty,
        PrototypeScenario.offlineCached =>
          context.l10n.shellScenarioOfflineCached,
        PrototypeScenario.aiUnavailable =>
          context.l10n.shellScenarioCompassUnavailable,
        PrototypeScenario.sharingPaused =>
          context.l10n.shellScenarioSharingPaused,
        PrototypeScenario.notificationDenied =>
          context.l10n.shellScenarioNotificationsDenied,
      };

  static IconData _scenarioIcon(PrototypeScenario scenario) =>
      switch (scenario) {
        PrototypeScenario.dinnerOpportunity =>
          FamilyCompassIcons.eventNoteOutlined,
        PrototypeScenario.dinnerPollOpen =>
          FamilyCompassIcons.howToVoteOutlined,
        PrototypeScenario.reassuranceAtSeven =>
          FamilyCompassIcons.scheduleRounded,
        PrototypeScenario.reassuranceUnknown =>
          FamilyCompassIcons.helpOutlineRounded,
        PrototypeScenario.todayEmpty => FamilyCompassIcons.inboxOutlined,
        PrototypeScenario.offlineCached => FamilyCompassIcons.cloudOffOutlined,
        PrototypeScenario.aiUnavailable =>
          FamilyCompassIcons.contactSupportOutlined,
        PrototypeScenario.sharingPaused =>
          FamilyCompassIcons.pauseCircleOutlineRounded,
        PrototypeScenario.notificationDenied =>
          FamilyCompassIcons.notificationsOffOutlined,
      };
}

class _DestinationTitle extends StatelessWidget {
  const _DestinationTitle({
    required this.label,
    required this.debugHint,
    required this.onOpenDebugPicker,
  });

  final String label;
  final String debugHint;
  final VoidCallback onOpenDebugPicker;

  @override
  Widget build(BuildContext context) {
    final title = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: FamilyCompassSizes.minimumTouchTarget,
        minHeight: FamilyCompassSizes.minimumTouchTarget,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
      ),
    );

    if (!kDebugMode) {
      return Semantics(header: true, child: title);
    }

    return Semantics(
      button: true,
      hint: debugHint,
      child: GestureDetector(
        key: const Key('shell.debugScenarioPicker'),
        behavior: HitTestBehavior.opaque,
        onLongPress: onOpenDebugPicker,
        child: title,
      ),
    );
  }
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

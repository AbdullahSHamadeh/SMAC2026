import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../domain/family_models.dart';
import '../../l10n/l10n.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../widgets/prototype_widgets.dart';

class MySharingScreen extends StatelessWidget {
  const MySharingScreen({super.key, required this.controller});

  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final status = controller.state.statuses['abdullah'];
        final isActive = status?.state == SharingState.active;
        final isPaused = status?.state == SharingState.paused;
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.mySharingTitle)),
          body: PrototypePage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.mySharingDescription,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: FamilyCompassSpacing.lg),
                SoftCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconWell(
                              icon: isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.pause_circle_rounded,
                              background: isActive
                                  ? FamilyCompassSemanticColors.of(context)
                                      .successContainer
                                  : FamilyCompassSemanticColors.of(context)
                                      .warningContainer,
                              foreground: isActive
                                  ? FamilyCompassSemanticColors.of(context)
                                      .success
                                  : FamilyCompassSemanticColors.of(context)
                                      .warning,
                            ),
                            const SizedBox(width: FamilyCompassSpacing.sm),
                            Expanded(
                              child: Text(
                                isActive
                                    ? context.l10n.mySharingManualCheckIn
                                    : isPaused
                                        ? 'Paused'
                                        : context.l10n.mySharingNotSharing,
                                key: const Key('sharing.state'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: FamilyCompassSpacing.md),
                        if (status != null) ...[
                          Text(
                            status.text,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: FamilyCompassSpacing.md),
                          _SharingFact(
                            icon: Icons.people_outline_rounded,
                            label: context.l10n.mySharingAudience,
                            value:
                                status.audience == SharingAudience.wholeFamily
                                    ? context.l10n.mySharingEveryone
                                    : context.l10n.mySharingSelectedPeople,
                          ),
                          _SharingFact(
                            icon: Icons.timer_outlined,
                            label: context.l10n.mySharingExpires,
                            value: _expiryText(status.expiresAt),
                          ),
                          const _SharingFact(
                            icon: Icons.auto_awesome_outlined,
                            label: 'What Compass may use',
                            value:
                                'Only this update while it is active and permitted',
                          ),
                        ],
                      ],
                  ),
                ),
                const SizedBox(height: FamilyCompassSpacing.lg),
                if (status != null) ...[
                  OutlinedButton.icon(
                    onPressed: isActive
                        ? () => _correctUpdate(context, status.text)
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Correct my update'),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: isActive
                        ? () => _changeAudience(context, status.audience)
                        : null,
                    icon: const Icon(Icons.group_outlined),
                    label: const Text('Change audience'),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: isActive ? controller.shortenOwnStatus : null,
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('End in 30 minutes'),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  FilledButton.tonalIcon(
                    key: const Key('sharing.pause'),
                    onPressed: isActive ? controller.pauseOwnSharing : null,
                    icon: const Icon(Icons.pause_rounded),
                    label: Text(
                      isPaused ? 'Sharing paused' : context.l10n.mySharingPause,
                    ),
                  ),
                ],
                const SizedBox(height: FamilyCompassSpacing.lg),
                SoftCard(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  padding: const EdgeInsets.all(FamilyCompassSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.mySharingPrivateControl,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: FamilyCompassSpacing.xs),
                      Text(context.l10n.mySharingNeutralForOthers),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _expiryText(DateTime expiresAt) {
    final remaining = expiresAt.difference(controller.state.scenarioNow);
    if (remaining.isNegative) return 'Expired';
    if (remaining.inMinutes < 60) return '${remaining.inMinutes} minutes';
    return '${remaining.inHours} hours';
  }

  Future<void> _correctUpdate(BuildContext context, String initial) async {
    final field = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Correct my update'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Shared update'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value != null && value.isNotEmpty) controller.correctOwnStatus(value);
  }

  Future<void> _changeAudience(
    BuildContext context,
    SharingAudience current,
  ) async {
    final selected = await showModalBottomSheet<SharingAudience>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FamilyCompassSpacing.md,
            0,
            FamilyCompassSpacing.md,
            FamilyCompassSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.mySharingAudience,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ListTile(
                leading: Icon(
                  current == SharingAudience.wholeFamily
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(context.l10n.mySharingEveryone),
                onTap: () => Navigator.pop(
                  context,
                  SharingAudience.wholeFamily,
                ),
              ),
              ListTile(
                leading: Icon(
                  current == SharingAudience.selectedPeople
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(context.l10n.mySharingSelectedPeople),
                subtitle: const Text('Dad and Mom'),
                onTap: () => Navigator.pop(
                  context,
                  SharingAudience.selectedPeople,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) controller.setOwnAudience(selected);
  }
}

class _SharingFact extends StatelessWidget {
  const _SharingFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
        final ownStatuses = controller.state.statuses.values
            .where(
              (status) => !controller.availableSharingRecipients
                  .any((member) => member.id == status.memberId),
            )
            .toList();
        final status = ownStatuses.firstOrNull ??
            controller.state.statuses[controller.currentUserId];
        final active = status?.state == SharingState.active;
        final paused = status?.state == SharingState.paused;
        final ar = Localizations.localeOf(context).languageCode == 'ar';
        final availableRecipients = controller.availableSharingRecipients;
        final current = _CurrentSharing(
          status: status,
          active: active,
          paused: paused,
          isArabic: ar,
          availableRecipients: availableRecipients,
          expiryText: status == null ? '' : _expiryText(status.expiresAt, ar),
        );
        final controls = _SharingControls(
          controller: controller,
          status: status,
          active: active,
          paused: paused,
          isArabic: ar,
        );

        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.mySharingTitle)),
          body: PrototypePage(
            maxWidth: 980,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.mySharingDescription,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: FamilyCompassSpacing.xl),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          current,
                          const SizedBox(height: FamilyCompassSpacing.lg),
                          controls,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: current),
                        const SizedBox(width: FamilyCompassSpacing.xl),
                        Expanded(flex: 4, child: controls),
                      ],
                    );
                  },
                ),
                const SizedBox(height: FamilyCompassSpacing.lg),
                InlineNotice(
                  icon: FamilyCompassIcons.visibilityOffOutlined,
                  title: context.l10n.mySharingPrivateControl,
                  body: context.l10n.mySharingNeutralForOthers,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _expiryText(DateTime expiresAt, bool ar) {
    final remaining = expiresAt.difference(controller.state.scenarioNow);
    if (remaining.isNegative) return ar ? 'انتهت' : 'Expired';
    if (remaining.inMinutes < 60) {
      return ar
          ? '${remaining.inMinutes} دقيقة'
          : '${remaining.inMinutes} minutes';
    }
    return ar ? '${remaining.inHours} ساعات' : '${remaining.inHours} hours';
  }
}

class _CurrentSharing extends StatelessWidget {
  const _CurrentSharing({
    required this.status,
    required this.active,
    required this.paused,
    required this.isArabic,
    required this.availableRecipients,
    required this.expiryText,
  });

  final SharedStatus? status;
  final bool active;
  final bool paused;
  final bool isArabic;
  final List<FamilyMember> availableRecipients;
  final String expiryText;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final stateText = active
        ? context.l10n.mySharingManualCheckIn
        : paused
            ? isArabic
                ? 'متوقفة مؤقتًا'
                : 'Paused'
            : context.l10n.mySharingNotSharing;
    final stateColor = active ? semantic.success : semantic.warning;

    return FolioSurface(
      backgroundColor: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active
                    ? FamilyCompassIcons.checkCircleRounded
                    : FamilyCompassIcons.pauseCircleRounded,
                color: stateColor,
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Text(
                  stateText,
                  key: const Key('sharing.state'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: FamilyCompassSpacing.md),
            Text(status!.text, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: FamilyCompassSpacing.lg),
            Divider(color: scheme.outlineVariant),
            _SharingFact(
              icon: FamilyCompassIcons.peopleOutlineRounded,
              label: context.l10n.mySharingAudience,
              value: _audienceSummary(
                context,
                status!,
                availableRecipients,
                isArabic,
              ),
              valueKey: const Key('sharing.audience.summary'),
            ),
            _SharingFact(
              icon: FamilyCompassIcons.timerOutlined,
              label: context.l10n.mySharingExpires,
              value: expiryText,
            ),
            _SharingFact(
              icon: FamilyCompassIcons.contactSupportOutlined,
              label: isArabic
                  ? 'ما يمكن للبوصلة استخدامه'
                  : 'What Compass may use',
              value: isArabic
                  ? 'هذا التحديث فقط أثناء نشاطه والسماح به'
                  : 'Only this update while it is active and permitted',
            ),
          ],
        ],
      ),
    );
  }
}

class _SharingControls extends StatelessWidget {
  const _SharingControls({
    required this.controller,
    required this.status,
    required this.active,
    required this.paused,
    required this.isArabic,
  });

  final PrototypeScenarioController controller;
  final SharedStatus? status;
  final bool active;
  final bool paused;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          compact: true,
          title: isArabic ? 'تحكمك' : 'Your controls',
        ),
        FlatActionRow(
          topDivider: true,
          title: isArabic ? 'صحح تحديثي' : 'Correct my update',
          leading: const Icon(FamilyCompassIcons.editOutlined),
          trailing: const Icon(FamilyCompassIcons.chevronRightRounded),
          onTap: active ? () => _correctUpdate(context, status!.text) : null,
        ),
        FlatActionRow(
          key: const Key('sharing.changeAudience'),
          title: isArabic ? 'غيّر الجمهور' : 'Change audience',
          leading: const Icon(FamilyCompassIcons.groupOutlined),
          trailing: const Icon(FamilyCompassIcons.chevronRightRounded),
          onTap: active ? () => _changeAudience(context, status!) : null,
        ),
        FlatActionRow(
          title: isArabic ? 'إنهاء خلال ٣٠ دقيقة' : 'End in 30 minutes',
          leading: const Icon(FamilyCompassIcons.timerOutlined),
          trailing: const Icon(FamilyCompassIcons.chevronRightRounded),
          onTap: active ? controller.shortenOwnStatus : null,
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        FilledButton.tonalIcon(
          key: const Key('sharing.pause'),
          onPressed: active ? controller.pauseOwnSharing : null,
          icon: const Icon(FamilyCompassIcons.pauseRounded),
          label: Text(
            paused
                ? isArabic
                    ? 'المشاركة متوقفة'
                    : 'Sharing paused'
                : context.l10n.mySharingPause,
          ),
        ),
      ],
    );
  }

  Future<void> _correctUpdate(BuildContext context, String initial) async {
    final field = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'صحح تحديثي' : 'Correct my update'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: isArabic ? 'التحديث المشارك' : 'Shared update',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value != null && value.isNotEmpty) controller.correctOwnStatus(value);
  }

  Future<void> _changeAudience(
    BuildContext context,
    SharedStatus status,
  ) async {
    final selected = await showModalBottomSheet<_SharingAudienceSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SharingAudienceSheet(
        currentAudience: status.audience,
        currentRecipientIds: status.recipientIds,
        availableRecipients: controller.availableSharingRecipients,
        isArabic: isArabic,
      ),
    );
    if (selected == null) return;
    controller.setOwnAudience(
      audience: selected.audience,
      recipientIds: selected.recipientIds,
    );
  }
}

class _SharingAudienceSelection {
  const _SharingAudienceSelection({
    required this.audience,
    required this.recipientIds,
  });

  final SharingAudience audience;
  final Set<String> recipientIds;
}

class _SharingAudienceSheet extends StatefulWidget {
  const _SharingAudienceSheet({
    required this.currentAudience,
    required this.currentRecipientIds,
    required this.availableRecipients,
    required this.isArabic,
  });

  final SharingAudience currentAudience;
  final Set<String> currentRecipientIds;
  final List<FamilyMember> availableRecipients;
  final bool isArabic;

  @override
  State<_SharingAudienceSheet> createState() => _SharingAudienceSheetState();
}

class _SharingAudienceSheetState extends State<_SharingAudienceSheet> {
  late SharingAudience _audience;
  late Set<String> _selectedRecipientIds;

  bool get _canSave =>
      _audience != SharingAudience.selectedPeople ||
      _selectedRecipientIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _audience = widget.currentAudience;
    _selectedRecipientIds = {...widget.currentRecipientIds};
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      key: const Key('sharing.audience.sheet'),
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.only(
          start: FamilyCompassSpacing.md,
          top: FamilyCompassSpacing.md,
          end: FamilyCompassSpacing.md,
          bottom:
              FamilyCompassSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.mySharingAudience,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            _audienceTile(
              context,
              key: const Key('sharing.audience.wholeFamily'),
              audience: SharingAudience.wholeFamily,
              label: context.l10n.mySharingEveryone,
            ),
            _audienceTile(
              context,
              key: const Key('sharing.audience.selectedPeople'),
              audience: SharingAudience.selectedPeople,
              label: context.l10n.mySharingSelectedPeople,
            ),
            if (_audience == SharingAudience.selectedPeople) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: FamilyCompassSpacing.xl,
                  top: FamilyCompassSpacing.xxs,
                ),
                child: Text(
                  widget.isArabic
                      ? 'اختر شخصًا واحدًا على الأقل'
                      : 'Choose at least one person',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              for (final member in widget.availableRecipients)
                CheckboxListTile(
                  key: Key('sharing.recipient.${member.id}'),
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: FamilyCompassSpacing.xl,
                  ),
                  value: _selectedRecipientIds.contains(member.id),
                  secondary: MemberMark(
                    initial: member.initials,
                    semanticLabel: _localizedMemberName(
                      member,
                      widget.isArabic,
                    ),
                  ),
                  title: Text(
                    _localizedMemberName(member, widget.isArabic),
                  ),
                  onChanged: (selected) {
                    setState(() {
                      if (selected ?? false) {
                        _selectedRecipientIds.add(member.id);
                      } else {
                        _selectedRecipientIds.remove(member.id);
                      }
                    });
                  },
                ),
            ],
            _audienceTile(
              context,
              key: const Key('sharing.audience.onlyMe'),
              audience: SharingAudience.onlyMe,
              label: widget.isArabic ? 'أنا فقط' : 'Only me',
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            FilledButton(
              key: const Key('sharing.audience.save'),
              onPressed: _canSave
                  ? () {
                      Navigator.pop(
                        context,
                        _SharingAudienceSelection(
                          audience: _audience,
                          recipientIds:
                              _audience == SharingAudience.selectedPeople
                                  ? Set.unmodifiable(_selectedRecipientIds)
                                  : const {},
                        ),
                      );
                    }
                  : null,
              child: Text(widget.isArabic ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audienceTile(
    BuildContext context, {
    required Key key,
    required SharingAudience audience,
    required String label,
  }) {
    final selected = _audience == audience;
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? FamilyCompassIcons.radioButtonCheckedRounded
            : FamilyCompassIcons.radioButtonUncheckedRounded,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label),
      selected: selected,
      onTap: () => setState(() => _audience = audience),
    );
  }
}

String _audienceSummary(
  BuildContext context,
  SharedStatus status,
  List<FamilyMember> availableRecipients,
  bool isArabic,
) {
  switch (status.audience) {
    case SharingAudience.wholeFamily:
      return context.l10n.mySharingEveryone;
    case SharingAudience.onlyMe:
      return isArabic ? 'أنا فقط' : 'Only me';
    case SharingAudience.selectedPeople:
      final recipientsById = {
        for (final member in availableRecipients) member.id: member,
      };
      final names = status.recipientIds
          .map(
            (id) => recipientsById[id] == null
                ? id
                : _localizedMemberName(recipientsById[id]!, isArabic),
          )
          .toList(growable: false);
      return _formatMemberNames(names, isArabic);
  }
}

String _localizedMemberName(FamilyMember member, bool isArabic) {
  if (!isArabic) return member.name;
  return switch (member.id) {
    'abdullah' => 'عبدالله',
    'dad' => 'الأب',
    'mom' => 'الأم',
    'sara' => 'سارة',
    _ => member.name,
  };
}

String _formatMemberNames(List<String> names, bool isArabic) {
  if (names.length <= 1) return names.single;
  if (names.length == 2) {
    return isArabic
        ? '${names.first} و${names.last}'
        : '${names.first} and ${names.last}';
  }
  final separator = isArabic ? '، ' : ', ';
  final leadingNames = names.take(names.length - 1).join(separator);
  return isArabic
      ? '$leadingNames و${names.last}'
      : '$leadingNames, and ${names.last}';
}

class _SharingFact extends StatelessWidget {
  const _SharingFact({
    required this.icon,
    required this.label,
    required this.value,
    this.valueKey,
  });

  final IconData icon;
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: FamilyCompassSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: FamilyCompassSpacing.xxs),
                Text(value, key: valueKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../prototype/fixtures.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../widgets/prototype_widgets.dart';
import 'my_sharing_screen.dart';

class FamilyMenuScreen extends StatefulWidget {
  const FamilyMenuScreen({
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
  State<FamilyMenuScreen> createState() => _FamilyMenuScreenState();
}

class _FamilyMenuScreenState extends State<FamilyMenuScreen> {
  bool _invitePending = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family and profile')),
      body: PrototypePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftCard(
              child: Row(
                  children: [
                    const MemberAvatar(
                      initials: 'AH',
                      memberId: 'abdullah',
                      radius: 30,
                    ),
                    const SizedBox(width: FamilyCompassSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Abdullah',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text('Hamadeh Family · Adult account'),
                        ],
                      ),
                    ),
                  ],
              ),
            ),
            const SizedBox(height: FamilyCompassSpacing.lg),
            const SectionHeading(title: 'Family members'),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0;
                      index < familyMembers.length;
                      index++) ...[
                    ListTile(
                      leading: MemberAvatar(
                        initials: familyMembers[index].initials,
                        memberId: familyMembers[index].id,
                      ),
                      title: Text(familyMembers[index].name),
                      subtitle: Text(familyMembers[index].relationship),
                      trailing: familyMembers[index].id == 'abdullah'
                          ? const Chip(label: Text('Coordinator'))
                          : null,
                    ),
                    if (index != familyMembers.length - 1)
                      const Divider(indent: 72),
                  ],
                ],
              ),
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            OutlinedButton.icon(
              key: const Key('family.invite'),
              onPressed: () => _showInviteSheet(context),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Invite by phone number'),
            ),
            if (_invitePending) ...[
              const SizedBox(height: FamilyCompassSpacing.sm),
              SoftCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.schedule_send_outlined),
                  title: const Text('Invitation pending'),
                  subtitle: const Text('+971 50 ••• •543 · expires in 3 days'),
                  trailing: TextButton(
                    onPressed: () => setState(() => _invitePending = false),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: FamilyCompassSpacing.xl),
            const SectionHeading(title: 'Privacy and preferences'),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    key: const Key('family.mySharing'),
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('My sharing'),
                    subtitle:
                        const Text('What you share, with whom, and until when'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => MySharingScreen(
                          controller: widget.controller,
                        ),
                      ),
                    ),
                  ),
                  const Divider(indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark appearance'),
                    subtitle:
                        const Text('Preview the representative dark theme'),
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (_) => widget.onToggleTheme(),
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: const Text('Language'),
                    subtitle: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? 'العربية'
                          : 'English',
                    ),
                    trailing: const Icon(Icons.swap_horiz_rounded),
                    onTap: widget.onToggleLanguage,
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded),
                    title: const Text('Preview onboarding'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onPreviewOnboarding();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: FamilyCompassSpacing.lg),
            SoftCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Privacy promise'),
                subtitle: const Text(
                  'Family Compass has no permanent family map. Every adult controls their own sharing.',
                ),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Family Compass',
                  applicationVersion: 'Prototype 2',
                  children: const [
                    Text(
                      'This local prototype uses scripted information only. It does not access GPS, contacts, SMS, or a live AI service.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInviteSheet(BuildContext context) async {
    final phone = TextEditingController(text: '+971 50 987 6543');
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.sm,
          FamilyCompassSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + FamilyCompassSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Invite to Hamadeh Family',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FamilyCompassSpacing.xs),
              const Text(
                'Enter a phone number manually. Contacts access is not needed.',
              ),
              const SizedBox(height: FamilyCompassSpacing.lg),
              TextField(
                controller: phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: FamilyCompassSpacing.lg),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Prepare invitation'),
              ),
            ],
          ),
        ),
      ),
    );
    phone.dispose();
    if (sent ?? false) setState(() => _invitePending = true);
  }
}

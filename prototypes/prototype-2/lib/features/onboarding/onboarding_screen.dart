import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _phoneController = TextEditingController(text: '+971 50 123 4567');
  final _codeController = TextEditingController(text: '2468');
  final _nameController = TextEditingController(text: 'Abdullah');
  final _inviteController = TextEditingController(text: '+971 50 987 6543');
  int _step = 0;
  bool _inviteSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 3) {
      widget.onComplete();
    } else {
      setState(() => _step += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageAtmosphere(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 560;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    compactHeight
                        ? FamilyCompassSpacing.md
                        : FamilyCompassSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const BrandMark(size: 44),
                          const SizedBox(width: FamilyCompassSpacing.sm),
                          Text(
                            'Family Compass',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          Text('${_step + 1} of 4'),
                        ],
                      ),
                      const SizedBox(height: FamilyCompassSpacing.md),
                      LinearProgressIndicator(value: (_step + 1) / 4),
                      SizedBox(
                        height: compactHeight
                            ? FamilyCompassSpacing.lg
                            : FamilyCompassSpacing.xxl,
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _stepContent(context),
                        ),
                      ),
                      const SizedBox(height: FamilyCompassSpacing.xl),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: FamilyCompassSpacing.sm,
                        runSpacing: FamilyCompassSpacing.sm,
                        children: [
                          if (_step > 0)
                            OutlinedButton(
                              onPressed: () => setState(() => _step -= 1),
                              child: const Text('Back'),
                            ),
                          FilledButton.icon(
                            key: const Key('onboarding.continue'),
                            onPressed: _next,
                            icon: Icon(
                              _step == 3
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                            label: Text(
                              _step == 3 ? 'Enter Family Compass' : 'Continue',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _stepContent(BuildContext context) => switch (_step) {
        0 => _WelcomeStep(),
        1 => _VerificationStep(
            phoneController: _phoneController,
            codeController: _codeController,
          ),
        2 => const _FamilyChoiceStep(),
        _ => _ProfileStep(
            nameController: _nameController,
            inviteController: _inviteController,
            inviteSent: _inviteSent,
            onInvite: () => setState(() => _inviteSent = true),
          ),
      };
}

class _WelcomeStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'More time together. Less wondering.',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        Text(
          'Make plans, keep everyone in the loop, and get reassurance from information each person chooses to share.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.lg),
        const SizedBox(height: FamilyCompassSpacing.sm),
        const _PromiseTile(
          icon: Icons.diversity_3_rounded,
          title: 'Gathering comes first',
          body: 'Turn family conversations into simple plans and reminders.',
        ),
        const _PromiseTile(
          icon: Icons.visibility_off_outlined,
          title: 'No permanent family map',
          body:
              'There is no live dot, route history, or hidden tracking screen.',
        ),
        const _PromiseTile(
          icon: Icons.tune_rounded,
          title: 'You control your sharing',
          body:
              'Every adult chooses what to share, with whom, and for how long.',
        ),
      ],
    );
  }
}

class _PromiseTile extends StatelessWidget {
  const _PromiseTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.md),
      child: SoftCard(
        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconWell(icon: icon),
            const SizedBox(width: FamilyCompassSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: FamilyCompassSpacing.xxs),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep({
    required this.phoneController,
    required this.codeController,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify your phone',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        const Text(
            'This prototype accepts the prepared number and code below.'),
        const SizedBox(height: FamilyCompassSpacing.lg),
        TextField(
          key: const Key('onboarding.phone'),
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile number',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        TextField(
          key: const Key('onboarding.code'),
          controller: codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Mock verification code',
            prefixIcon: Icon(Icons.password_rounded),
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        const Text(
          'No SMS is sent, and no account is created in this local prototype.',
        ),
      ],
    );
  }
}

class _FamilyChoiceStep extends StatefulWidget {
  const _FamilyChoiceStep();

  @override
  State<_FamilyChoiceStep> createState() => _FamilyChoiceStepState();
}

class _FamilyChoiceStepState extends State<_FamilyChoiceStep> {
  bool _create = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your family space',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        const Text(
            'Create a new family or preview an invitation before joining.'),
        const SizedBox(height: FamilyCompassSpacing.lg),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Create a family')),
            ButtonSegment(value: false, label: Text('Join by invitation')),
          ],
          selected: {_create},
          onSelectionChanged: (selection) {
            setState(() => _create = selection.first);
          },
        ),
        const SizedBox(height: FamilyCompassSpacing.lg),
        SoftCard(
          child: _create
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hamadeh Family'),
                      SizedBox(height: FamilyCompassSpacing.xs),
                      Text(
                          'You will be the first member and plan coordinator.'),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invitation from Dad'),
                      SizedBox(height: FamilyCompassSpacing.xs),
                      Text('Join “Hamadeh Family” with Dad, Mom, and Sara.'),
                      SizedBox(height: FamilyCompassSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.verified_user_outlined, size: 18),
                          SizedBox(width: FamilyCompassSpacing.xs),
                          Expanded(
                              child: Text(
                                  'Invitation details shown before acceptance')),
                        ],
                      ),
                    ],
                  ),
        ),
      ],
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.nameController,
    required this.inviteController,
    required this.inviteSent,
    required this.onInvite,
  });

  final TextEditingController nameController;
  final TextEditingController inviteController;
  final bool inviteSent;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Finish your family space',
          style: FamilyCompassTypography.of(context).headlineLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        const Text(
            'Choose your name, then invite someone by phone if you wish.'),
        const SizedBox(height: FamilyCompassSpacing.lg),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Your name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        TextField(
          controller: inviteController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Invite by phone number',
            prefixIcon: Icon(Icons.person_add_alt_1_outlined),
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: inviteSent ? null : onInvite,
            icon: Icon(inviteSent ? Icons.check_rounded : Icons.send_outlined),
            label:
                Text(inviteSent ? 'Invitation prepared' : 'Prepare invitation'),
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        const Text(
            'Contacts access is never required for a manual invitation.'),
      ],
    );
  }
}

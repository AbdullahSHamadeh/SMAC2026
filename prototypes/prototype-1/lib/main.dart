import 'package:flutter/material.dart';

import 'family_store.dart';
import 'models.dart';

const compassBlue = Color(0xFF0B63F6);
const softBlue = Color(0xFFEAF3FF);
const coral = Color(0xFFF36552);
const green = Color(0xFF159447);
const ink = Color(0xFF0A0B12);
const muted = Color(0xFF6D7482);
const appBackground = Color(0xFFF9FAFC);

void main() => runApp(const FamilyCompassApp());

class FamilyCompassApp extends StatefulWidget {
  const FamilyCompassApp({super.key});

  @override
  State<FamilyCompassApp> createState() => _FamilyCompassAppState();
}

class _FamilyCompassAppState extends State<FamilyCompassApp> {
  final store = FamilyStore();
  bool onboarded = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Family Compass',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: appBackground,
        colorScheme: ColorScheme.fromSeed(
            seedColor: compassBlue, brightness: Brightness.light),
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: -1.2),
          headlineMedium: TextStyle(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: -.7),
          titleLarge:
              TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink),
          titleMedium:
              TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
          bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: muted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E5EA))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E5EA))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: compassBlue, width: 1.5)),
        ),
      ),
      home: onboarded
          ? FamilyShell(
              store: store,
              openOnboarding: () => setState(() => onboarded = false))
          : OnboardingScreen(
              onComplete: () => setState(() => onboarded = true)),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      (
        Icons.explore_rounded,
        'Your family, in one calm place',
        'Share plans, journeys, reminders, and everyday updates without repeatedly asking where everyone is.'
      ),
      (
        Icons.lock_outline_rounded,
        'Sharing is always a choice',
        'Every adult controls their own location, journeys, and availability. Family Compass explains what is known without guessing.'
      ),
      (
        Icons.auto_awesome_rounded,
        'AI that helps the family act',
        'Get grounded summaries, plan time together, create shared reminders, and find who may be available to help.'
      ),
    ];
    final item = pages[page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandHeader(),
              const Spacer(),
              Center(
                  child: Container(
                      width: 170,
                      height: 170,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: softBlue),
                      child: Icon(item.$1, size: 76, color: compassBlue))),
              const Spacer(),
              Text(item.$2, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 14),
              Text(item.$3,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: muted)),
              const SizedBox(height: 30),
              Row(
                  children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: index == page ? 26 : 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 7),
                          decoration: BoxDecoration(
                              color: index == page
                                  ? compassBlue
                                  : const Color(0xFFD9DDE5),
                              borderRadius: BorderRadius.circular(99))))),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: page == pages.length - 1
                    ? widget.onComplete
                    : () => setState(() => page += 1),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: compassBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17))),
                child: Text(
                    page == pages.length - 1
                        ? 'Create my family circle'
                        : 'Continue',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              TextButton(
                  onPressed: widget.onComplete,
                  child: const Text('Use prototype account')),
            ],
          ),
        ),
      ),
    );
  }
}

class FamilyShell extends StatefulWidget {
  const FamilyShell(
      {required this.store, required this.openOnboarding, super.key});
  final FamilyStore store;
  final VoidCallback openOnboarding;

  @override
  State<FamilyShell> createState() => _FamilyShellState();
}

class _FamilyShellState extends State<FamilyShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
          store: widget.store,
          openFamily: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FamilyMembersScreen(store: widget.store))),
          openJourney: () => setState(() => index = 2)),
      ChatScreen(store: widget.store),
      JourneyScreen(store: widget.store),
      RemindersScreen(store: widget.store),
      AssistantScreen(store: widget.store),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: screens)),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: index,
        indicatorColor: softBlue,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat'),
          NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on_rounded),
              label: 'Journey'),
          NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Reminders'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'AI'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen(
      {required this.store,
      required this.openFamily,
      required this.openJourney,
      super.key});
  final FamilyStore store;
  final VoidCallback openFamily;
  final VoidCallback openJourney;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
            sliver: SliverList.list(children: [
              BrandHeader(
                  action: IconButton.filledTonal(
                      onPressed: openFamily,
                      icon: const Icon(Icons.group_outlined,
                          color: compassBlue))),
              const SizedBox(height: 34),
              Text('Good morning',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 7),
              Text('Everyone is following their shared plans.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: muted)),
              const SizedBox(height: 22),
              const DailyBriefCard(),
              const SizedBox(height: 16),
              ...store.members.take(3).map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MemberStatusCard(
                      member: member,
                      onTap: member.activity == MemberActivity.university
                          ? openJourney
                          : null))),
              const SizedBox(height: 4),
              const FamilyDinnerCard(),
              const SizedBox(height: 22),
              Text('Stay connected',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: QuickAction(
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Ask for help',
                        onTap: () => showCheckInSheet(context))),
                const SizedBox(width: 10),
                Expanded(
                    child: QuickAction(
                        icon: Icons.waving_hand_outlined,
                        label: 'Check in',
                        onTap: () => showCheckInSheet(context))),
                const SizedBox(width: 10),
                Expanded(
                    child: QuickAction(
                        icon: Icons.group_add_outlined,
                        label: 'Invite',
                        onTap: openFamily)),
              ]),
              const SizedBox(height: 18),
              const BondingCard(),
            ]),
          ),
        ],
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({this.action, super.key});
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Text('Family Compass',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: ink,
                letterSpacing: -.6)),
        const Spacer(),
        action ??
            Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: softBlue),
                child: const Icon(Icons.explore_rounded,
                    color: compassBlue, size: 29)),
      ]);
}

class DailyBriefCard extends StatelessWidget {
  const DailyBriefCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
            color: const Color(0xFF0F63E9),
            borderRadius: BorderRadius.circular(20)),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome_rounded, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('TODAY’S FAMILY BRIEF',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFBFD8FF),
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8)),
                SizedBox(height: 6),
                Text(
                    'All active journeys look normal. Dinner at 7:00 PM works for everyone.',
                    style: TextStyle(
                        color: Colors.white,
                        height: 1.4,
                        fontWeight: FontWeight.w700))
              ])),
        ]),
      );
}

class MemberStatusCard extends StatelessWidget {
  const MemberStatusCard({required this.member, this.onTap, super.key});
  final FamilyMember member;
  final VoidCallback? onTap;

  IconData get icon => switch (member.activity) {
        MemberActivity.driving => Icons.directions_car_rounded,
        MemberActivity.shopping => Icons.shopping_cart_outlined,
        MemberActivity.university => Icons.school_outlined,
        MemberActivity.home => Icons.home_outlined,
        MemberActivity.walking => Icons.directions_walk_rounded,
        MemberActivity.paused => Icons.location_off_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final positive = member.detail == 'Arrived';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EC)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0C0A0B12),
                    blurRadius: 18,
                    offset: Offset(0, 7))
              ]),
          child: Row(children: [
            CircleAvatar(
                radius: 28,
                backgroundColor: softBlue,
                child: Icon(icon, color: compassBlue, size: 29)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(member.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(member.status,
                      style: Theme.of(context).textTheme.bodyMedium)
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                    color: positive ? const Color(0xFFEAF8EE) : softBlue,
                    borderRadius: BorderRadius.circular(99)),
                child: Row(children: [
                  Icon(
                      positive
                          ? Icons.check_circle_outline
                          : Icons.schedule_rounded,
                      size: 17,
                      color: positive ? green : compassBlue),
                  const SizedBox(width: 5),
                  Text(member.detail,
                      style: TextStyle(
                          color: positive ? green : compassBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800))
                ])),
          ]),
        ),
      ),
    );
  }
}

class FamilyDinnerCard extends StatelessWidget {
  const FamilyDinnerCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFFFD9D2)),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFFFECE8),
              child: Icon(Icons.restaurant_rounded, color: coral)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Family dinner',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Row(children: [
                  Icon(Icons.schedule_rounded, size: 17, color: coral),
                  SizedBox(width: 5),
                  Text('7:00 PM',
                      style:
                          TextStyle(color: coral, fontWeight: FontWeight.w800))
                ])
              ])),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ]),
      );
}

class QuickAction extends StatelessWidget {
  const QuickAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      super.key});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            side: const BorderSide(color: Color(0xFFDDE2E9)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        child: Column(children: [
          Icon(icon, color: compassBlue),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: ink, fontWeight: FontWeight.w800))
        ]),
      );
}

class BondingCard extends StatelessWidget {
  const BondingCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0xFFF2EDFF),
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.favorite_rounded, color: Color(0xFF7255B5)),
            SizedBox(width: 8),
            Text('FAMILY BONDING',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7255B5),
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8)),
            Spacer(),
            Text('3 of 4',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: Color(0xFF7255B5)))
          ]),
          const SizedBox(height: 12),
          Text('One more shared meal completes this week’s family challenge.',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(
                  value: .75,
                  minHeight: 8,
                  color: Color(0xFF7255B5),
                  backgroundColor: Colors.white)),
        ]),
      );
}

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({required this.store, super.key});
  final FamilyStore store;

  @override
  Widget build(BuildContext context) => Column(children: [
        ScreenTopBar(
            title: 'Journey to University',
            trailing: IconButton(
                onPressed: () {},
                icon:
                    const Icon(Icons.more_horiz_rounded, color: compassBlue))),
        Expanded(
            child: Stack(children: [
          const Positioned.fill(child: FakeMap()),
          Positioned(
              left: 22,
              right: 22,
              top: 20,
              child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(19),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 18,
                            offset: Offset(0, 8))
                      ]),
                  child: const Row(children: [
                    CircleAvatar(
                        backgroundColor: softBlue,
                        child: Text('A',
                            style: TextStyle(
                                color: compassBlue,
                                fontWeight: FontWeight.w900))),
                    SizedBox(width: 12),
                    Text('Abdullah',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    Spacer(),
                    Icon(Icons.directions_car_rounded, color: compassBlue)
                  ]))),
          Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 25,
                            offset: Offset(0, -6))
                      ]),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 54,
                        height: 5,
                        decoration: BoxDecoration(
                            color: const Color(0xFFD8DADE),
                            borderRadius: BorderRadius.circular(99))),
                    const SizedBox(height: 18),
                    const Row(children: [
                      CircleAvatar(
                          backgroundColor: softBlue,
                          child:
                              Icon(Icons.schedule_rounded, color: compassBlue)),
                      SizedBox(width: 12),
                      Text('ETA',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(width: 8),
                      Text('9:05 AM',
                          style: TextStyle(
                              fontSize: 27, fontWeight: FontWeight.w900)),
                      Spacer(),
                      Chip(
                          label: Text('12 min delay'),
                          backgroundColor: Color(0xFFFFE4DE),
                          labelStyle: TextStyle(
                              color: coral, fontWeight: FontWeight.w800),
                          side: BorderSide.none)
                    ]),
                    const SizedBox(height: 16),
                    const JourneyFact(
                        icon: Icons.traffic_rounded,
                        text: 'Delayed by traffic',
                        color: coral),
                    const JourneyFact(
                        icon: Icons.timeline_rounded,
                        text: 'Route looks normal',
                        color: compassBlue),
                    const SizedBox(height: 9),
                    const Text('Updated just now · Shared with Dad and Mom',
                        style: TextStyle(fontSize: 11, color: muted)),
                    const SizedBox(height: 15),
                    OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                                content: Text('Journey sharing paused'))),
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Stop sharing'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            foregroundColor: compassBlue,
                            side: const BorderSide(color: compassBlue),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)))),
                  ]))),
        ])),
      ]);
}

class FakeMap extends StatelessWidget {
  const FakeMap({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: MapPainter(),
      child: const Center(
          child: Icon(Icons.navigation_rounded, color: compassBlue, size: 34)));
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF0F3F5), BlendMode.src);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (i + 1) / 8;
      canvas.drawPath(
          Path()
            ..moveTo(0, y)
            ..quadraticBezierTo(size.width * .45, y - 45, size.width, y + 20),
          road);
    }
    final river = Paint()
      ..color = const Color(0xFFCDEBFA)
      ..strokeWidth = 38
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()
          ..moveTo(size.width * .22, 0)
          ..cubicTo(size.width * .45, size.height * .3, size.width * .18,
              size.height * .65, size.width * .5, size.height),
        river);
    final route = Paint()
      ..color = compassBlue
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(size.width * .15, size.height * .72)
          ..cubicTo(size.width * .37, size.height * .58, size.width * .6,
              size.height * .52, size.width * .78, size.height * .32),
        route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class JourneyFact extends StatelessWidget {
  const JourneyFact(
      {required this.icon, required this.text, required this.color, super.key});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        CircleAvatar(
            radius: 21,
            backgroundColor: softBlue,
            child: Icon(icon, color: compassBlue, size: 21)),
        const SizedBox(width: 13),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
        Icon(
            text.contains('normal')
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: color)
      ]));
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.store, super.key});
  final FamilyStore store;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ScreenTopBar(
            title: 'Family Chat',
            trailing: IconButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FamilyMembersScreen(store: widget.store))),
                icon: const Icon(Icons.group_outlined, color: compassBlue))),
        Expanded(
            child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) => ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                        children: [
                          ...widget.store.messages
                              .map((message) => ChatBubble(message: message)),
                          const SizedBox(height: 10),
                          AiChatCard(onCreate: () {
                            widget.store.createReminder(
                                'Notify everyone when Mom is heading home',
                                when: 'Today · When Mom leaves',
                                assignee: 'Everyone');
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Family reminder created')));
                          }),
                        ]))),
        Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE4E7EC)))),
            child: Row(children: [
              IconButton.filled(
                  onPressed: () {},
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                      backgroundColor: compassBlue,
                      foregroundColor: Colors.white)),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                          hintText: 'Type a message…', isDense: true),
                      onSubmitted: (_) => send())),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: send,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                      backgroundColor: compassBlue,
                      foregroundColor: Colors.white))
            ])),
      ]);
  void send() {
    widget.store.sendMessage(controller.text);
    controller.clear();
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({required this.message, super.key});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) => Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310),
              child: Column(
                  crossAxisAlignment: message.isMine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(message.author,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                            color: message.isMine ? compassBlue : Colors.white,
                            border: Border.all(
                                color: message.isMine
                                    ? compassBlue
                                    : const Color(0xFFE0E3E8)),
                            borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft:
                                    Radius.circular(message.isMine ? 18 : 4),
                                bottomRight:
                                    Radius.circular(message.isMine ? 4 : 18))),
                        child: Text(message.body,
                            style: TextStyle(
                                color: message.isMine ? Colors.white : ink,
                                height: 1.4))),
                    const SizedBox(height: 3),
                    Text(message.time,
                        style: const TextStyle(fontSize: 10, color: muted))
                  ]))));
}

class AiChatCard extends StatelessWidget {
  const AiChatCard({required this.onCreate, super.key});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: softBlue,
          border: Border.all(color: const Color(0xFFC9DEFF)),
          borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          CircleAvatar(
              backgroundColor: Color(0xFFD7E8FF),
              child: Icon(Icons.smart_toy_outlined, color: compassBlue)),
          SizedBox(width: 10),
          Text('AI update',
              style: TextStyle(
                  color: compassBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 17))
        ]),
        const SizedBox(height: 15),
        Text(
            'Create a family reminder and notify everyone when Mom is heading home?',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
                backgroundColor: compassBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13))),
            child: const Text('Create reminder'))
      ]));
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({required this.store, super.key});
  final FamilyStore store;
  @override
  Widget build(BuildContext context) => Column(children: [
        ScreenTopBar(
            title: 'Reminders',
            trailing: IconButton.filled(
                onPressed: () => showReminderDialog(context, store),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                    backgroundColor: compassBlue,
                    foregroundColor: Colors.white))),
        Expanded(
            child: AnimatedBuilder(
                animation: store,
                builder: (context, _) =>
                    ListView(padding: const EdgeInsets.all(20), children: [
                      Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF2EDFF),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [
                                  Icon(Icons.auto_awesome_rounded,
                                      color: Color(0xFF7255B5)),
                                  SizedBox(width: 8),
                                  Text('AI GATHERING SUGGESTION',
                                      style: TextStyle(
                                          color: Color(0xFF7255B5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900))
                                ]),
                                const SizedBox(height: 10),
                                Text('Everyone is free Friday after 7:00 PM.',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 7),
                                const Text(
                                    'Family dinner, movie night, or an evening walk would fit everyone’s shared plans.'),
                                const SizedBox(height: 15),
                                FilledButton(
                                    onPressed: () => store.createReminder(
                                        'Family gathering',
                                        when: 'Friday · 7:00 PM',
                                        assignee: 'Everyone'),
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF7255B5)),
                                    child: const Text('Plan family time'))
                              ])),
                      const SizedBox(height: 24),
                      Text('Shared reminders',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      ...store.reminders.map((reminder) => ReminderTile(
                          reminder: reminder,
                          toggle: () => store.toggleReminder(reminder.id))),
                      const SizedBox(height: 20),
                      Text('Family challenge',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      const ChallengeCard(),
                    ]))),
      ]);
}

class ReminderTile extends StatelessWidget {
  const ReminderTile({required this.reminder, required this.toggle, super.key});
  final FamilyReminder reminder;
  final VoidCallback toggle;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E5EA)),
          borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        Checkbox(
            value: reminder.completed,
            onChanged: (_) => toggle(),
            activeColor: compassBlue),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reminder.title,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration:
                      reminder.completed ? TextDecoration.lineThrough : null)),
          const SizedBox(height: 4),
          Text('${reminder.when} · ${reminder.assignee}',
              style: const TextStyle(fontSize: 12, color: muted))
        ])),
        const Icon(Icons.more_horiz_rounded, color: muted)
      ]));
}

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E5EA)),
          borderRadius: BorderRadius.circular(18)),
      child: const Row(children: [
        CircleAvatar(
            backgroundColor: Color(0xFFFFECE8),
            child: Icon(Icons.restaurant_rounded, color: coral)),
        SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Three meals together',
              style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('2 of 3 completed this week',
              style: TextStyle(fontSize: 12, color: muted)),
          SizedBox(height: 9),
          LinearProgressIndicator(
              value: .67,
              minHeight: 7,
              borderRadius: BorderRadius.all(Radius.circular(99)),
              color: coral,
              backgroundColor: Color(0xFFFFEAE5))
        ])),
        SizedBox(width: 12),
        Text('67%', style: TextStyle(fontWeight: FontWeight.w900, color: coral))
      ]));
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({required this.store, super.key});
  final FamilyStore store;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const ScreenTopBar(
            title: 'Family Assistant',
            trailing: CircleAvatar(
                backgroundColor: softBlue,
                child: Icon(Icons.favorite_rounded, color: compassBlue))),
        Expanded(
            child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) =>
                    ListView(padding: const EdgeInsets.all(20), children: [
                      ...widget.store.assistantMessages.map((message) => Align(
                          alignment: message.fromUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(17),
                              constraints: const BoxConstraints(maxWidth: 345),
                              decoration: BoxDecoration(
                                  color: message.fromUser
                                      ? softBlue
                                      : Colors.white,
                                  border: Border.all(
                                      color: message.fromUser
                                          ? const Color(0xFFC8DEFF)
                                          : const Color(0xFFE0E4E9)),
                                  borderRadius: BorderRadius.circular(20)),
                              child: message.fromUser
                                  ? Text(message.text,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          const Row(children: [
                                            Icon(Icons.shield_outlined,
                                                color: compassBlue),
                                            SizedBox(width: 8),
                                            Text('Shared facts',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w900))
                                          ]),
                                          const SizedBox(height: 12),
                                          Text(message.text,
                                              style:
                                                  const TextStyle(height: 1.5))
                                        ])))),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            'Is everyone okay?',
                            'Plan a family dinner',
                            'Who can help Mom?',
                            'What should I know today?'
                          ]
                              .map((prompt) => ActionChip(
                                  label: Text(prompt),
                                  onPressed: () => ask(prompt),
                                  side: const BorderSide(
                                      color: Color(0xFFC9DEFF)),
                                  backgroundColor: softBlue,
                                  labelStyle: const TextStyle(
                                      color: compassBlue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)))
                              .toList()),
                    ]))),
        Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            color: Colors.white,
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                          hintText: 'Ask about shared family information…',
                          isDense: true),
                      onSubmitted: ask)),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: () => ask(controller.text),
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                      backgroundColor: compassBlue,
                      foregroundColor: Colors.white))
            ])),
      ]);
  void ask(String prompt) {
    widget.store.askAssistant(prompt);
    controller.clear();
  }
}

class FamilyMembersScreen extends StatelessWidget {
  const FamilyMembersScreen({required this.store, super.key});
  final FamilyStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Family members',
                style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: appBackground,
            actions: [
              IconButton.filled(
                  onPressed: () => showInviteDialog(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  style: IconButton.styleFrom(
                      backgroundColor: compassBlue,
                      foregroundColor: Colors.white))
            ]),
        body: AnimatedBuilder(
            animation: store,
            builder: (context, _) =>
                ListView(padding: const EdgeInsets.all(20), children: [
                  Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: softBlue,
                          borderRadius: BorderRadius.circular(18)),
                      child: const Row(children: [
                        Icon(Icons.lock_outline_rounded, color: compassBlue),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                'Every adult controls their own location and journey sharing. Admins manage invitations, not private consent.',
                                style: TextStyle(
                                    color: compassBlue,
                                    height: 1.4,
                                    fontWeight: FontWeight.w700)))
                      ])),
                  const SizedBox(height: 20),
                  ...store.members.map((member) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE1E4EA)),
                          borderRadius: BorderRadius.circular(18)),
                      child: Column(children: [
                        Row(children: [
                          CircleAvatar(
                              backgroundColor: softBlue,
                              child: Text(member.name.substring(0, 1),
                                  style: const TextStyle(
                                      color: compassBlue,
                                      fontWeight: FontWeight.w900))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(member.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16)),
                                Text(member.relation,
                                    style: const TextStyle(
                                        fontSize: 12, color: muted))
                              ])),
                          Chip(
                              label: Text(member.isAdmin ? 'Admin' : 'Member'),
                              side: BorderSide.none,
                              backgroundColor: member.isAdmin
                                  ? softBlue
                                  : const Color(0xFFF0F1F4),
                              labelStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800))
                        ]),
                        const Divider(height: 26),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Share location',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(member.sharesLocation
                                ? 'Visible to this family circle'
                                : 'Paused by this member'),
                            value: member.sharesLocation,
                            activeThumbColor: compassBlue,
                            onChanged: member.id == 'abdullah'
                                ? (value) => store.updatePermissions(member.id,
                                    sharesLocation: value)
                                : null),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Family admin',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: const Text(
                                'Can invite members and manage shared plans'),
                            value: member.isAdmin,
                            activeThumbColor: compassBlue,
                            onChanged: member.id == 'abdullah'
                                ? null
                                : (value) => store.updatePermissions(member.id,
                                    isAdmin: value))
                      ]))),
                  OutlinedButton.icon(
                      onPressed: () => widgetStoreOnboardingNotice(context),
                      icon: const Icon(Icons.info_outline_rounded),
                      label: const Text('View onboarding and consent flow'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50))),
                ])),
      );
}

class ScreenTopBar extends StatelessWidget {
  const ScreenTopBar({required this.title, required this.trailing, super.key});
  final String title;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EC)))),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5))),
        trailing
      ]));
}

void showInviteDialog(BuildContext context) {
  final controller = TextEditingController();
  showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
              22, 8, 22, MediaQuery.viewInsetsOf(context).bottom + 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite family member',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                    'Send a private invitation by phone number. They choose what to share after joining.'),
                const SizedBox(height: 20),
                TextField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+971 50 123 4567')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    initialValue: 'adult',
                    decoration:
                        const InputDecoration(labelText: 'Initial role'),
                    items: const [
                      DropdownMenuItem(
                          value: 'adult', child: Text('Adult member')),
                      DropdownMenuItem(
                          value: 'child', child: Text('Child account')),
                      DropdownMenuItem(
                          value: 'admin', child: Text('Family admin'))
                    ],
                    onChanged: (_) {}),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Invitation sent to ${controller.text.isEmpty ? 'the family member' : controller.text}')));
                    },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: compassBlue),
                    child: const Text('Send invitation'))
              ])));
}

void showReminderDialog(BuildContext context, FamilyStore store) {
  final controller = TextEditingController();
  showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('New family reminder'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                      hintText: 'What should the family remember?')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        store.createReminder(controller.text.trim());
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Create'))
              ]));
}

void showCheckInSheet(BuildContext context) {
  showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick check-in',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                    'Share only what you want the family to know right now.'),
                const SizedBox(height: 18),
                ...[
                  ('I’m okay', Icons.check_circle_outline_rounded),
                  ('I arrived', Icons.home_outlined),
                  ('I’ll be late', Icons.schedule_rounded),
                  ('I need help', Icons.volunteer_activism_outlined),
                  ('I can’t reply now', Icons.do_not_disturb_alt_outlined)
                ].map((item) => ListTile(
                    leading: CircleAvatar(
                        backgroundColor: softBlue,
                        child: Icon(item.$2, color: compassBlue)),
                    title: Text(item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Check-in shared: ${item.$1}')));
                    }))
              ])));
}

void widgetStoreOnboardingNotice(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Onboarding is available from the prototype start screen.')));

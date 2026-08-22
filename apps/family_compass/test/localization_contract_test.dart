import 'dart:convert';
import 'dart:io';

import 'package:family_compass/data/api_mappers.dart';
import 'package:family_compass/domain/family_models.dart';
import 'package:family_compass/l10n/l10n.dart';
import 'package:family_compass/domain/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('English and Arabic localization contract', () {
    final english = _readArb('lib/l10n/app_en.arb');
    final arabic = _readArb('lib/l10n/app_ar.arb');
    final englishMessages = _messages(english);
    final arabicMessages = _messages(arabic);

    test('both catalogs expose the same non-empty message keys', () {
      expect(english['@@locale'], 'en');
      expect(arabic['@@locale'], 'ar');
      expect(arabicMessages.keys.toSet(), englishMessages.keys.toSet());
      expect(englishMessages.values, everyElement(isNotEmpty));
      expect(arabicMessages.values, everyElement(isNotEmpty));
    });

    test('translated messages preserve every ICU placeholder', () {
      for (final key in englishMessages.keys) {
        expect(
          _placeholders(arabicMessages[key]!),
          _placeholders(englishMessages[key]!),
          reason: 'Placeholder mismatch for $key',
        );
      }
    });

    test('Arabic messages contain Arabic script and are not English copies',
        () {
      for (final key in englishMessages.keys) {
        final translated = arabicMessages[key]!;
        expect(translated, isNot(englishMessages[key]), reason: key);
        expect(
          translated,
          matches(RegExp(r'[\u0600-\u06FF]')),
          reason: 'Arabic script missing for $key',
        );
      }
    });

    test('generated localizations advertise only the supported pilot locales',
        () {
      expect(
        AppLocalizations.supportedLocales,
        const <Locale>[Locale('en'), Locale('ar')],
      );
    });

    test('shell and family settings copy stays in the typed catalogs', () {
      expect(
        englishMessages.keys,
        containsAll(<String>[
          'shellScenarioPickerHint',
          'shellFamilyAndProfile',
          'shellDemoStatesTitle',
          'familyMembersTitle',
          'familyRelationshipMember',
          'familyCoordinatorRole',
          'settingsTitle',
          'settingsPrivacyPromise',
        ]),
      );
    });

    testWidgets(
      'API relationship kinds localize without changing personal copy',
      (tester) async {
        final apiMember = memberFromApi(
          <String, Object>{
            'user': <String, Object>{'id': 'member-1', 'name': 'Rania'},
            'role': 'member',
          },
          currentUserId: 'current-user',
        );
        const customMember = FamilyMember(
          id: 'member-2',
          name: 'Teta أمينة',
          relationship: 'Teta',
          initials: 'TA',
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Text(
                '${apiMember.name}|'
                '${apiMember.localizedRelationship(context)}|'
                '${customMember.name}|'
                '${customMember.localizedRelationship(context)}',
              ),
            ),
          ),
        );

        expect(
          find.text('Rania|فرد من العائلة|Teta أمينة|Teta'),
          findsOneWidget,
        );
        expect(find.textContaining('Family member'), findsNothing);
      },
    );

    testWidgets(
      'known fixture labels localize without translating arbitrary content',
      (tester) async {
        final seededPlan = FamilyPlan(
          id: '55555555-5555-5555-5555-555555555555',
          title: 'Family dinner',
          description: 'Home',
          locationLabel: 'Home',
          coordinatorId: '22222222-2222-2222-2222-222222222222',
          participantIds: const <String>[],
          candidateTimes: const <CandidateTime>[],
          phase: PlanPhase.pollOpen,
          decisionDeadline: DateTime(2026),
        );
        final personalPlan = FamilyPlan(
          id: 'personal-plan',
          title: 'Family dinner',
          description: 'Grandma’s garden',
          locationLabel: 'Grandma’s garden',
          coordinatorId: 'person',
          participantIds: const <String>[],
          candidateTimes: const <CandidateTime>[],
          phase: PlanPhase.draft,
          decisionDeadline: DateTime(2026),
        );
        const seededDad = FamilyMember(
          id: '22222222-2222-2222-2222-222222222222',
          name: 'Dad',
          initials: 'D',
        );
        const personalDad = FamilyMember(
          id: 'person-dad',
          name: 'Dad',
          initials: 'D',
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Text(
                '${seededPlan.localizedDisplayTitle(context)}|'
                '${personalPlan.localizedDisplayTitle(context)}|'
                '${seededDad.localizedDisplayName(context)}|'
                '${personalDad.localizedDisplayName(context)}',
              ),
            ),
          ),
        );

        expect(find.text('عشاء عائلي|Family dinner|الأب|Dad'), findsOneWidget);
      },
    );
  });
}

Map<String, dynamic> _readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, String> _messages(Map<String, dynamic> arb) => <String, String>{
      for (final entry in arb.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value as String,
    };

Set<String> _placeholders(String message) => RegExp(r'\{([A-Za-z_]\w*)(?:\}|,)')
    .allMatches(message)
    .map((match) => match.group(1)!)
    .toSet();

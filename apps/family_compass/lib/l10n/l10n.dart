import 'package:flutter/widgets.dart';

import '../domain/family_models.dart';
import '../domain/plan_models.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension FamilyMemberLocalization on FamilyMember {
  /// Localizes only the deterministic prototype and backend-seed identities.
  /// Other names are person-authored content and remain unchanged.
  String localizedDisplayName(BuildContext context) {
    if (Localizations.localeOf(context).languageCode != 'ar') return name;

    return switch (id) {
      'dad' ||
      '22222222-2222-2222-2222-222222222222' =>
        context.l10n.familyRelationshipFather,
      'mom' ||
      '33333333-3333-3333-3333-333333333333' =>
        context.l10n.familyRelationshipMother,
      _ => name,
    };
  }

  String localizedRelationship(
    BuildContext context, {
    bool isCurrentUser = false,
  }) {
    final localizations = context.l10n;
    if (isCurrentUser) return localizations.familyRelationshipSelf;

    return switch (relationshipKind) {
      FamilyRelationshipKind.self => localizations.familyRelationshipSelf,
      FamilyRelationshipKind.familyMember =>
        localizations.familyRelationshipMember,
      FamilyRelationshipKind.father => localizations.familyRelationshipFather,
      FamilyRelationshipKind.mother => localizations.familyRelationshipMother,
      FamilyRelationshipKind.sister => localizations.familyRelationshipSister,
      FamilyRelationshipKind.custom => relationship.trim().isEmpty
          ? localizations.familyRelationshipMember
          : relationship,
    };
  }
}

extension FamilyPlanLocalization on FamilyPlan {
  /// Localizes known app-authored dinner fixtures without translating an
  /// arbitrary title supplied by a family member.
  String localizedDisplayTitle(BuildContext context) {
    final isBuiltInDinner = id == 'friday-dinner' ||
        id == '55555555-5555-5555-5555-555555555555' ||
        (title == 'Family dinner' &&
            locationLabel == 'Home' &&
            candidateTimes.any(
              (candidate) => candidate.id.startsWith('dinner-'),
            ));
    return isBuiltInDinner ? context.l10n.todayFamilyDinner : title;
  }
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Family Compass';

  @override
  String get tabToday => 'Today';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabCompass => 'Compass';

  @override
  String get tabTogether => 'Together';

  @override
  String get actionReply => 'Reply';

  @override
  String get actionViewPlan => 'View plan';

  @override
  String get actionDismiss => 'Dismiss';

  @override
  String get actionCreatePlan => 'Create plan';

  @override
  String get todayTitle => 'Today';

  @override
  String todayGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get todayNextGathering => 'Next gathering';

  @override
  String get todayNeedsYourReply => 'Needs your reply';

  @override
  String get todaySharedUpdates => 'Shared updates';

  @override
  String get todayCompassSuggestion => 'Compass suggestion';

  @override
  String get todayFamilyDinner => 'Family dinner';

  @override
  String familyMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count family members',
      one: '1 family member',
      zero: 'No family members',
    );
    return '$_temp0';
  }

  @override
  String todayDinnerDetails(String day, String time) {
    return '$day at $time';
  }

  @override
  String get todayRsvpPrompt => 'Can you make it?';

  @override
  String get todayNoUrgentUpdates => 'Nothing needs your attention right now.';

  @override
  String get pollTitle => 'Choose a time';

  @override
  String get pollDinnerQuestion => 'When should we have family dinner?';

  @override
  String pollOptionDayTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get pollGoing => 'Going';

  @override
  String get pollMaybe => 'Maybe';

  @override
  String get pollCannotGo => 'Cannot go';

  @override
  String get pollSuggestAnother => 'Suggest another time';

  @override
  String pollDecisionDeadline(String deadline) {
    return 'Decide by $deadline';
  }

  @override
  String pollResponsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count responses',
      one: '1 response',
      zero: 'No responses yet',
    );
    return '$_temp0';
  }

  @override
  String get compassTitle => 'Compass';

  @override
  String get compassPrivateLabel => 'Private to you';

  @override
  String get compassPrivateDescription =>
      'Your Compass conversation is private.';

  @override
  String get compassInputHint => 'Ask about Dad\'s shared update';

  @override
  String get compassExampleQuestion => 'Where is Dad?';

  @override
  String compassGroundedAnswer(String time) {
    return 'Dad shared that he is at work until $time.';
  }

  @override
  String get compassSourceMemberShared => 'Shared by Dad';

  @override
  String get compassFreshnessCurrent => 'Current';

  @override
  String get compassFreshnessStale => 'May be out of date';

  @override
  String get compassNoRecentUpdate => 'No recent update';

  @override
  String get compassCannotInfer =>
      'I do not have a recent update that this person shared with you.';

  @override
  String get compassGatheringSuggestion =>
      'Friday evening looks open for everyone. Plan a family dinner?';

  @override
  String get compassAnswerVisibility => 'Only you can see this answer.';

  @override
  String get compassGroupMentionHint =>
      'Use @Compass in family chat for a family-visible answer.';

  @override
  String get mySharingTitle => 'My sharing';

  @override
  String get mySharingDescription =>
      'You choose what your family can see and for how long.';

  @override
  String get mySharingStatus => 'Sharing status';

  @override
  String get mySharingNotSharing => 'Not sharing';

  @override
  String get mySharingManualCheckIn => 'Manual check-in';

  @override
  String get mySharingEta => 'Share an ETA';

  @override
  String get mySharingAudience => 'Who can see this';

  @override
  String get mySharingEveryone => 'Everyone in the family';

  @override
  String get mySharingSelectedPeople => 'Selected people';

  @override
  String get mySharingExpires => 'Expires automatically';

  @override
  String mySharingExpiresIn(String duration) {
    return 'Expires in $duration';
  }

  @override
  String get mySharingPause => 'Pause sharing';

  @override
  String get mySharingStop => 'Stop sharing';

  @override
  String get mySharingPrivateControl =>
      'Only you can change your sharing settings.';

  @override
  String get mySharingNeutralForOthers =>
      'Others will see “No recent update” when you are not sharing.';

  @override
  String get shellScenarioPickerHint =>
      'Long press to choose a demonstration state';

  @override
  String get shellFamilyAndProfile => 'Family';

  @override
  String get shellDemoStatesTitle => 'Demo states';

  @override
  String get shellScenarioDinnerOpportunity => 'Dinner opportunity';

  @override
  String get shellScenarioDinnerPollOpen => 'Dinner poll open';

  @override
  String get shellScenarioReassuranceSharedEta => 'Reassurance with shared ETA';

  @override
  String get shellScenarioReassuranceNoUpdate => 'Reassurance with no update';

  @override
  String get shellScenarioTodayEmpty => 'Empty Today';

  @override
  String get shellScenarioOfflineCached => 'Offline with cached content';

  @override
  String get shellScenarioCompassUnavailable => 'Compass unavailable';

  @override
  String get shellScenarioSharingPaused => 'Sharing paused';

  @override
  String get shellScenarioNotificationsDenied => 'Notifications denied';

  @override
  String get notificationForegroundMessage => 'A new family message arrived.';

  @override
  String get notificationForegroundPlan => 'A family plan was updated.';

  @override
  String get notificationForegroundReminder => 'A family reminder is ready.';

  @override
  String get notificationForegroundCheckIn =>
      'A family check-in needs your attention.';

  @override
  String get notificationForegroundUpdate => 'A family update arrived.';

  @override
  String get notificationOpen => 'Open';

  @override
  String get familyProfileAccountSummary => 'Hamadeh Family · Adult account';

  @override
  String get familyMembersTitle => 'People';

  @override
  String get familyRelationshipSelf => 'You';

  @override
  String get familyRelationshipMember => 'Family member';

  @override
  String get familyRelationshipFather => 'Father';

  @override
  String get familyRelationshipMother => 'Mother';

  @override
  String get familyRelationshipSister => 'Sister';

  @override
  String get familyCoordinatorRole => 'Coordinator';

  @override
  String familyRemoveMemberTooltip(String name) {
    return 'Remove $name';
  }

  @override
  String get familyInviteByPhone => 'Invite by phone number';

  @override
  String get familyInvitationPending => 'Invitation pending';

  @override
  String familyInvitationExpiry(String maskedPhone) {
    return '$maskedPhone · expires in 3 days';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get familyLeave => 'Leave family';

  @override
  String get familyDelete => 'Delete family';

  @override
  String get settingsTitle => 'Your settings';

  @override
  String get settingsMySharingDescription =>
      'What you share, with whom, and until when';

  @override
  String get settingsDarkAppearance => 'Dark appearance';

  @override
  String get settingsDarkAppearanceDescription => 'Preview the dark appearance';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageDescription => 'Choose the app language.';

  @override
  String get settingsPreviewOnboarding => 'Preview onboarding';

  @override
  String get settingsPrivacyPromise => 'Privacy promise';

  @override
  String get settingsPrivacyPromiseBody =>
      'There is no permanent family map. Every adult controls their own sharing.';

  @override
  String get settingsAboutBuild => 'About this build';

  @override
  String get settingsDemoBuildDescription =>
      'This build uses demonstration information only. It does not access GPS, contacts, SMS, or a live AI service.';

  @override
  String get familyInviteTitle => 'Invite to Hamadeh Family';

  @override
  String get familyInviteDescription =>
      'Enter a phone number manually. Contacts access is not needed.';

  @override
  String get familyPhoneNumberLabel => 'Phone number';

  @override
  String get familyPhoneNumberHelper =>
      'Include the country code, such as +971.';

  @override
  String get familyPhoneNumberInvalid =>
      'Enter a valid international number with 8 to 15 digits.';

  @override
  String get familySendInvitation => 'Send invitation';

  @override
  String familyInvitationSent(String maskedPhone) {
    return 'Invitation sent to $maskedPhone.';
  }

  @override
  String get familyInvitationCancelled => 'Invitation cancelled.';

  @override
  String get familyLeaveDialogTitle => 'Leave this family?';

  @override
  String get familyLeaveDialogBody =>
      'You will lose access to this family’s messages and plans. Other accounts will not be deleted.';

  @override
  String get familyLeaveAction => 'Leave family';

  @override
  String familyRemoveDialogTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get familyRemoveDialogBody =>
      'Their access to this family will stop immediately.';

  @override
  String get familyRemoveAction => 'Remove member';

  @override
  String get familyDeleteDialogTitle => 'Delete this family?';

  @override
  String get familyDeleteDialogBody =>
      'Family messages, plans, reminders, and shared statuses will be permanently deleted. Individual accounts will remain.';

  @override
  String get familyDeleteAction => 'Delete family';
}

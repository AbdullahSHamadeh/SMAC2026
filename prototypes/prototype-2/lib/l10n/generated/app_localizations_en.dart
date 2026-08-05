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
  String get compassInputHint =>
      'Ask Compass about a shared update or family plan';

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
}

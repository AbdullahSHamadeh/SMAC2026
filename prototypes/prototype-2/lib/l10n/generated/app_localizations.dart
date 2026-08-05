import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar')
  ];

  /// Application name.
  ///
  /// In en, this message translates to:
  /// **'Family Compass'**
  String get appName;

  /// Label for the Today navigation destination.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// Label for the family Chat navigation destination.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get tabChat;

  /// Label for the private AI Compass navigation destination.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get tabCompass;

  /// Label for the plans and gatherings navigation destination.
  ///
  /// In en, this message translates to:
  /// **'Together'**
  String get tabTogether;

  /// Action that opens an item needing a response.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get actionReply;

  /// Action that opens a family plan.
  ///
  /// In en, this message translates to:
  /// **'View plan'**
  String get actionViewPlan;

  /// Action that dismisses a suggestion.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get actionDismiss;

  /// Action that creates a family plan from a suggestion.
  ///
  /// In en, this message translates to:
  /// **'Create plan'**
  String get actionCreatePlan;

  /// Heading for the Today screen.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// Personal greeting on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String todayGreeting(String name);

  /// Heading for the next confirmed family gathering.
  ///
  /// In en, this message translates to:
  /// **'Next gathering'**
  String get todayNextGathering;

  /// Heading for family decisions that need this member's response.
  ///
  /// In en, this message translates to:
  /// **'Needs your reply'**
  String get todayNeedsYourReply;

  /// Heading for relevant updates family members chose to share.
  ///
  /// In en, this message translates to:
  /// **'Shared updates'**
  String get todaySharedUpdates;

  /// Heading for the single active AI suggestion.
  ///
  /// In en, this message translates to:
  /// **'Compass suggestion'**
  String get todayCompassSuggestion;

  /// Representative title for a family dinner plan.
  ///
  /// In en, this message translates to:
  /// **'Family dinner'**
  String get todayFamilyDinner;

  /// Day and time summary for the representative dinner plan.
  ///
  /// In en, this message translates to:
  /// **'{day} at {time}'**
  String todayDinnerDetails(String day, String time);

  /// Prompt asking a member to respond to a gathering.
  ///
  /// In en, this message translates to:
  /// **'Can you make it?'**
  String get todayRsvpPrompt;

  /// Calm empty state when the Today screen has no urgent items.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs your attention right now.'**
  String get todayNoUrgentUpdates;

  /// Heading for a gathering time poll.
  ///
  /// In en, this message translates to:
  /// **'Choose a time'**
  String get pollTitle;

  /// Representative family dinner poll question.
  ///
  /// In en, this message translates to:
  /// **'When should we have family dinner?'**
  String get pollDinnerQuestion;

  /// A selectable day and time in a poll.
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String pollOptionDayTime(String day, String time);

  /// RSVP response confirming attendance.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get pollGoing;

  /// RSVP response indicating uncertain attendance.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get pollMaybe;

  /// RSVP response declining attendance.
  ///
  /// In en, this message translates to:
  /// **'Cannot go'**
  String get pollCannotGo;

  /// Action to propose a different gathering time.
  ///
  /// In en, this message translates to:
  /// **'Suggest another time'**
  String get pollSuggestAnother;

  /// Deadline for answering a family poll.
  ///
  /// In en, this message translates to:
  /// **'Decide by {deadline}'**
  String pollDecisionDeadline(String deadline);

  /// Number of responses received for a poll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No responses yet} =1{1 response} other{{count} responses}}'**
  String pollResponsesCount(int count);

  /// Heading for the private AI assistant screen.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get compassTitle;

  /// Short privacy label for the private Compass conversation.
  ///
  /// In en, this message translates to:
  /// **'Private to you'**
  String get compassPrivateLabel;

  /// Explains that private Compass chat is not shown to family members.
  ///
  /// In en, this message translates to:
  /// **'Your Compass conversation is private.'**
  String get compassPrivateDescription;

  /// Input hint for the private AI assistant.
  ///
  /// In en, this message translates to:
  /// **'Ask Compass about a shared update or family plan'**
  String get compassInputHint;

  /// Representative question for the private AI assistant.
  ///
  /// In en, this message translates to:
  /// **'Where is Dad?'**
  String get compassExampleQuestion;

  /// Representative answer grounded in a member-shared status.
  ///
  /// In en, this message translates to:
  /// **'Dad shared that he is at work until {time}.'**
  String compassGroundedAnswer(String time);

  /// Source label for information directly shared by Dad.
  ///
  /// In en, this message translates to:
  /// **'Shared by Dad'**
  String get compassSourceMemberShared;

  /// Freshness label for a current shared update.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get compassFreshnessCurrent;

  /// Freshness label for a stale shared update.
  ///
  /// In en, this message translates to:
  /// **'May be out of date'**
  String get compassFreshnessStale;

  /// Neutral response when no usable family update exists.
  ///
  /// In en, this message translates to:
  /// **'No recent update'**
  String get compassNoRecentUpdate;

  /// Privacy-safe explanation when Compass cannot answer.
  ///
  /// In en, this message translates to:
  /// **'I do not have a recent update that this person shared with you.'**
  String get compassCannotInfer;

  /// Representative AI suggestion intended to help the family gather.
  ///
  /// In en, this message translates to:
  /// **'Friday evening looks open for everyone. Plan a family dinner?'**
  String get compassGatheringSuggestion;

  /// Visibility label for an answer in private Compass chat.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this answer.'**
  String get compassAnswerVisibility;

  /// Explains how to ask Compass a question visible to the family group.
  ///
  /// In en, this message translates to:
  /// **'Use @Compass in family chat for a family-visible answer.'**
  String get compassGroupMentionHint;

  /// Heading for a member's own sharing controls.
  ///
  /// In en, this message translates to:
  /// **'My sharing'**
  String get mySharingTitle;

  /// Privacy explanation for sharing controls.
  ///
  /// In en, this message translates to:
  /// **'You choose what your family can see and for how long.'**
  String get mySharingDescription;

  /// Label for the member's current sharing state.
  ///
  /// In en, this message translates to:
  /// **'Sharing status'**
  String get mySharingStatus;

  /// State in which the member is not sharing context.
  ///
  /// In en, this message translates to:
  /// **'Not sharing'**
  String get mySharingNotSharing;

  /// Option to share a status manually.
  ///
  /// In en, this message translates to:
  /// **'Manual check-in'**
  String get mySharingManualCheckIn;

  /// Option to share an estimated arrival time manually.
  ///
  /// In en, this message translates to:
  /// **'Share an ETA'**
  String get mySharingEta;

  /// Label for choosing the recipients of a shared update.
  ///
  /// In en, this message translates to:
  /// **'Who can see this'**
  String get mySharingAudience;

  /// Audience option that includes every family member.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the family'**
  String get mySharingEveryone;

  /// Audience option limited to selected family members.
  ///
  /// In en, this message translates to:
  /// **'Selected people'**
  String get mySharingSelectedPeople;

  /// Label explaining that a shared update has an expiry.
  ///
  /// In en, this message translates to:
  /// **'Expires automatically'**
  String get mySharingExpires;

  /// Remaining time before a shared update expires.
  ///
  /// In en, this message translates to:
  /// **'Expires in {duration}'**
  String mySharingExpiresIn(String duration);

  /// Action that temporarily pauses sharing.
  ///
  /// In en, this message translates to:
  /// **'Pause sharing'**
  String get mySharingPause;

  /// Action that ends the current sharing session.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get mySharingStop;

  /// Explains that other family members cannot override these controls.
  ///
  /// In en, this message translates to:
  /// **'Only you can change your sharing settings.'**
  String get mySharingPrivateControl;

  /// Explains the neutral state shown to other family members.
  ///
  /// In en, this message translates to:
  /// **'Others will see “No recent update” when you are not sharing.'**
  String get mySharingNeutralForOthers;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

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

  /// Accessible count of family members represented in an identity stack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No family members} =1{1 family member} other{{count} family members}}'**
  String familyMembersCount(int count);

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
  /// **'Ask about Dad\'\'s shared update'**
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

  /// No description provided for @shellScenarioPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Long press to choose a demonstration state'**
  String get shellScenarioPickerHint;

  /// No description provided for @shellFamilyAndProfile.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get shellFamilyAndProfile;

  /// No description provided for @shellDemoStatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Demo states'**
  String get shellDemoStatesTitle;

  /// No description provided for @shellScenarioDinnerOpportunity.
  ///
  /// In en, this message translates to:
  /// **'Dinner opportunity'**
  String get shellScenarioDinnerOpportunity;

  /// No description provided for @shellScenarioDinnerPollOpen.
  ///
  /// In en, this message translates to:
  /// **'Dinner poll open'**
  String get shellScenarioDinnerPollOpen;

  /// No description provided for @shellScenarioReassuranceSharedEta.
  ///
  /// In en, this message translates to:
  /// **'Reassurance with shared ETA'**
  String get shellScenarioReassuranceSharedEta;

  /// No description provided for @shellScenarioReassuranceNoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Reassurance with no update'**
  String get shellScenarioReassuranceNoUpdate;

  /// No description provided for @shellScenarioTodayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty Today'**
  String get shellScenarioTodayEmpty;

  /// No description provided for @shellScenarioOfflineCached.
  ///
  /// In en, this message translates to:
  /// **'Offline with cached content'**
  String get shellScenarioOfflineCached;

  /// No description provided for @shellScenarioCompassUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Compass unavailable'**
  String get shellScenarioCompassUnavailable;

  /// No description provided for @shellScenarioSharingPaused.
  ///
  /// In en, this message translates to:
  /// **'Sharing paused'**
  String get shellScenarioSharingPaused;

  /// No description provided for @shellScenarioNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications denied'**
  String get shellScenarioNotificationsDenied;

  /// No description provided for @notificationForegroundMessage.
  ///
  /// In en, this message translates to:
  /// **'A new family message arrived.'**
  String get notificationForegroundMessage;

  /// No description provided for @notificationForegroundPlan.
  ///
  /// In en, this message translates to:
  /// **'A family plan was updated.'**
  String get notificationForegroundPlan;

  /// No description provided for @notificationForegroundReminder.
  ///
  /// In en, this message translates to:
  /// **'A family reminder is ready.'**
  String get notificationForegroundReminder;

  /// No description provided for @notificationForegroundCheckIn.
  ///
  /// In en, this message translates to:
  /// **'A family check-in needs your attention.'**
  String get notificationForegroundCheckIn;

  /// No description provided for @notificationForegroundUpdate.
  ///
  /// In en, this message translates to:
  /// **'A family update arrived.'**
  String get notificationForegroundUpdate;

  /// No description provided for @notificationOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationOpen;

  /// No description provided for @familyProfileAccountSummary.
  ///
  /// In en, this message translates to:
  /// **'Hamadeh Family · Adult account'**
  String get familyProfileAccountSummary;

  /// No description provided for @familyMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get familyMembersTitle;

  /// No description provided for @familyRelationshipSelf.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get familyRelationshipSelf;

  /// No description provided for @familyRelationshipMember.
  ///
  /// In en, this message translates to:
  /// **'Family member'**
  String get familyRelationshipMember;

  /// No description provided for @familyRelationshipFather.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get familyRelationshipFather;

  /// No description provided for @familyRelationshipMother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get familyRelationshipMother;

  /// No description provided for @familyRelationshipSister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get familyRelationshipSister;

  /// No description provided for @familyCoordinatorRole.
  ///
  /// In en, this message translates to:
  /// **'Coordinator'**
  String get familyCoordinatorRole;

  /// No description provided for @familyRemoveMemberTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String familyRemoveMemberTooltip(String name);

  /// No description provided for @familyInviteByPhone.
  ///
  /// In en, this message translates to:
  /// **'Invite by phone number'**
  String get familyInviteByPhone;

  /// No description provided for @familyInvitationPending.
  ///
  /// In en, this message translates to:
  /// **'Invitation pending'**
  String get familyInvitationPending;

  /// No description provided for @familyInvitationExpiry.
  ///
  /// In en, this message translates to:
  /// **'{maskedPhone} · expires in 3 days'**
  String familyInvitationExpiry(String maskedPhone);

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @familyLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave family'**
  String get familyLeave;

  /// No description provided for @familyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete family'**
  String get familyDelete;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your settings'**
  String get settingsTitle;

  /// No description provided for @settingsMySharingDescription.
  ///
  /// In en, this message translates to:
  /// **'What you share, with whom, and until when'**
  String get settingsMySharingDescription;

  /// No description provided for @settingsDarkAppearance.
  ///
  /// In en, this message translates to:
  /// **'Dark appearance'**
  String get settingsDarkAppearance;

  /// No description provided for @settingsDarkAppearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Preview the dark appearance'**
  String get settingsDarkAppearanceDescription;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language.'**
  String get settingsLanguageDescription;

  /// No description provided for @settingsPreviewOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Preview onboarding'**
  String get settingsPreviewOnboarding;

  /// No description provided for @settingsPrivacyPromise.
  ///
  /// In en, this message translates to:
  /// **'Privacy promise'**
  String get settingsPrivacyPromise;

  /// No description provided for @settingsPrivacyPromiseBody.
  ///
  /// In en, this message translates to:
  /// **'There is no permanent family map. Every adult controls their own sharing.'**
  String get settingsPrivacyPromiseBody;

  /// No description provided for @settingsAboutBuild.
  ///
  /// In en, this message translates to:
  /// **'About this build'**
  String get settingsAboutBuild;

  /// No description provided for @settingsDemoBuildDescription.
  ///
  /// In en, this message translates to:
  /// **'This build uses demonstration information only. It does not access GPS, contacts, SMS, or a live AI service.'**
  String get settingsDemoBuildDescription;

  /// No description provided for @familyInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite to Hamadeh Family'**
  String get familyInviteTitle;

  /// No description provided for @familyInviteDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number manually. Contacts access is not needed.'**
  String get familyInviteDescription;

  /// No description provided for @familyPhoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get familyPhoneNumberLabel;

  /// No description provided for @familyPhoneNumberHelper.
  ///
  /// In en, this message translates to:
  /// **'Include the country code, such as +971.'**
  String get familyPhoneNumberHelper;

  /// No description provided for @familyPhoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid international number with 8 to 15 digits.'**
  String get familyPhoneNumberInvalid;

  /// No description provided for @familySendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get familySendInvitation;

  /// No description provided for @familyInvitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {maskedPhone}.'**
  String familyInvitationSent(String maskedPhone);

  /// No description provided for @familyInvitationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Invitation cancelled.'**
  String get familyInvitationCancelled;

  /// No description provided for @familyLeaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this family?'**
  String get familyLeaveDialogTitle;

  /// No description provided for @familyLeaveDialogBody.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to this family’s messages and plans. Other accounts will not be deleted.'**
  String get familyLeaveDialogBody;

  /// No description provided for @familyLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave family'**
  String get familyLeaveAction;

  /// No description provided for @familyRemoveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String familyRemoveDialogTitle(String name);

  /// No description provided for @familyRemoveDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Their access to this family will stop immediately.'**
  String get familyRemoveDialogBody;

  /// No description provided for @familyRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get familyRemoveAction;

  /// No description provided for @familyDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this family?'**
  String get familyDeleteDialogTitle;

  /// No description provided for @familyDeleteDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Family messages, plans, reminders, and shared statuses will be permanently deleted. Individual accounts will remain.'**
  String get familyDeleteDialogBody;

  /// No description provided for @familyDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete family'**
  String get familyDeleteAction;
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

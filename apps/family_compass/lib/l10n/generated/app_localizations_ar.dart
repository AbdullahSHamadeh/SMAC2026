// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'بوصلة العائلة';

  @override
  String get tabToday => 'اليوم';

  @override
  String get tabChat => 'الدردشة';

  @override
  String get tabCompass => 'البوصلة';

  @override
  String get tabTogether => 'معًا';

  @override
  String get actionReply => 'رد';

  @override
  String get actionViewPlan => 'عرض الخطة';

  @override
  String get actionDismiss => 'تجاهل';

  @override
  String get actionCreatePlan => 'إنشاء خطة';

  @override
  String get todayTitle => 'اليوم';

  @override
  String todayGreeting(String name) {
    return 'أهلًا، $name';
  }

  @override
  String get todayNextGathering => 'التجمع القادم';

  @override
  String get todayNeedsYourReply => 'ينتظر ردك';

  @override
  String get todaySharedUpdates => 'التحديثات المشتركة';

  @override
  String get todayCompassSuggestion => 'اقتراح البوصلة';

  @override
  String get todayFamilyDinner => 'عشاء عائلي';

  @override
  String familyMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فرد من العائلة',
      many: '$count فردًا من العائلة',
      few: '$count أفراد من العائلة',
      two: 'فردان من العائلة',
      one: 'فرد واحد من العائلة',
      zero: 'لا يوجد أفراد من العائلة',
    );
    return '$_temp0';
  }

  @override
  String todayDinnerDetails(String day, String time) {
    return '$day، الساعة $time';
  }

  @override
  String get todayRsvpPrompt => 'هل يمكنك الحضور؟';

  @override
  String get todayNoUrgentUpdates => 'لا يوجد ما يحتاج إلى انتباهك الآن.';

  @override
  String get pollTitle => 'اختيار الوقت';

  @override
  String get pollDinnerQuestion => 'متى يناسبنا العشاء العائلي؟';

  @override
  String pollOptionDayTime(String day, String time) {
    return '$day، $time';
  }

  @override
  String get pollGoing => 'سأحضر';

  @override
  String get pollMaybe => 'ربما';

  @override
  String get pollCannotGo => 'لا أستطيع الحضور';

  @override
  String get pollSuggestAnother => 'اقتراح وقت آخر';

  @override
  String pollDecisionDeadline(String deadline) {
    return 'يرجى الرد قبل $deadline';
  }

  @override
  String pollResponsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رد',
      many: '$count ردًا',
      few: '$count ردود',
      two: 'ردان',
      one: 'رد واحد',
      zero: 'لا توجد ردود بعد',
    );
    return '$_temp0';
  }

  @override
  String get compassTitle => 'البوصلة';

  @override
  String get compassPrivateLabel => 'خاص بك';

  @override
  String get compassPrivateDescription => 'محادثتك مع البوصلة خاصة بك.';

  @override
  String get compassInputHint => 'اسأل عن التحديث الذي شاركه الأب';

  @override
  String get compassExampleQuestion => 'أين أبي؟';

  @override
  String compassGroundedAnswer(String time) {
    return 'شارك الأب أنه في العمل حتى الساعة $time.';
  }

  @override
  String get compassSourceMemberShared => 'مشاركة من الأب';

  @override
  String get compassFreshnessCurrent => 'محدّث';

  @override
  String get compassFreshnessStale => 'قد لا يكون محدّثًا';

  @override
  String get compassNoRecentUpdate => 'لا يوجد تحديث حديث';

  @override
  String get compassCannotInfer =>
      'لا يوجد لدي تحديث حديث شاركه هذا الشخص معك.';

  @override
  String get compassGatheringSuggestion =>
      'مساء الجمعة يبدو مناسبًا للجميع. هل نخطط لعشاء عائلي؟';

  @override
  String get compassAnswerVisibility => 'هذه الإجابة ظاهرة لك وحدك.';

  @override
  String get compassGroupMentionHint =>
      'استخدم @Compass في دردشة العائلة للحصول على إجابة يراها الجميع.';

  @override
  String get mySharingTitle => 'مشاركتي';

  @override
  String get mySharingDescription =>
      'أنت تختار ما يمكن لعائلتك رؤيته والمدة التي يبقى فيها متاحًا.';

  @override
  String get mySharingStatus => 'حالة المشاركة';

  @override
  String get mySharingNotSharing => 'لا توجد مشاركة الآن';

  @override
  String get mySharingManualCheckIn => 'تحديث يدوي';

  @override
  String get mySharingEta => 'مشاركة وقت الوصول المتوقع';

  @override
  String get mySharingAudience => 'من يمكنه رؤية هذا';

  @override
  String get mySharingEveryone => 'جميع أفراد العائلة';

  @override
  String get mySharingSelectedPeople => 'أشخاص محددون';

  @override
  String get mySharingExpires => 'تنتهي المشاركة تلقائيًا';

  @override
  String mySharingExpiresIn(String duration) {
    return 'تنتهي بعد $duration';
  }

  @override
  String get mySharingPause => 'إيقاف المشاركة مؤقتًا';

  @override
  String get mySharingStop => 'إنهاء المشاركة';

  @override
  String get mySharingPrivateControl =>
      'أنت وحدك من يمكنه تغيير إعدادات المشاركة الخاصة بك.';

  @override
  String get mySharingNeutralForOthers =>
      'سيظهر للآخرين “لا يوجد تحديث حديث” عندما لا تكون مشاركًا.';

  @override
  String get shellScenarioPickerHint => 'اضغط مطولًا لاختيار حالة تجريبية';

  @override
  String get shellFamilyAndProfile => 'العائلة';

  @override
  String get shellDemoStatesTitle => 'الحالات التجريبية';

  @override
  String get shellScenarioDinnerOpportunity => 'فرصة لعشاء عائلي';

  @override
  String get shellScenarioDinnerPollOpen => 'تصويت مفتوح على موعد العشاء';

  @override
  String get shellScenarioReassuranceSharedEta => 'طمأنة مع وقت وصول مشترك';

  @override
  String get shellScenarioReassuranceNoUpdate => 'طمأنة من دون تحديث';

  @override
  String get shellScenarioTodayEmpty => 'صفحة اليوم فارغة';

  @override
  String get shellScenarioOfflineCached => 'دون اتصال مع محتوى محفوظ';

  @override
  String get shellScenarioCompassUnavailable => 'البوصلة غير متاحة';

  @override
  String get shellScenarioSharingPaused => 'المشاركة متوقفة مؤقتًا';

  @override
  String get shellScenarioNotificationsDenied => 'الإشعارات غير مسموح بها';

  @override
  String get notificationForegroundMessage => 'وصلت رسالة عائلية جديدة.';

  @override
  String get notificationForegroundPlan => 'تم تحديث إحدى خطط العائلة.';

  @override
  String get notificationForegroundReminder => 'هناك تذكير عائلي جاهز.';

  @override
  String get notificationForegroundCheckIn =>
      'هناك طلب اطمئنان عائلي يحتاج إلى انتباهك.';

  @override
  String get notificationForegroundUpdate => 'هناك تحديث عائلي جديد.';

  @override
  String get notificationOpen => 'فتح';

  @override
  String get familyProfileAccountSummary => 'عائلة حمادة · حساب بالغ';

  @override
  String get familyMembersTitle => 'الأفراد';

  @override
  String get familyRelationshipSelf => 'أنت';

  @override
  String get familyRelationshipMember => 'فرد من العائلة';

  @override
  String get familyRelationshipFather => 'الأب';

  @override
  String get familyRelationshipMother => 'الأم';

  @override
  String get familyRelationshipSister => 'الأخت';

  @override
  String get familyCoordinatorRole => 'المنسق';

  @override
  String familyRemoveMemberTooltip(String name) {
    return 'إزالة $name';
  }

  @override
  String get familyInviteByPhone => 'دعوة برقم الهاتف';

  @override
  String get familyInvitationPending => 'دعوة معلقة';

  @override
  String familyInvitationExpiry(String maskedPhone) {
    return '$maskedPhone · تنتهي خلال 3 أيام';
  }

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get familyLeave => 'مغادرة العائلة';

  @override
  String get familyDelete => 'حذف العائلة';

  @override
  String get settingsTitle => 'إعداداتك';

  @override
  String get settingsMySharingDescription => 'ما تشاركه ومع من وإلى متى';

  @override
  String get settingsDarkAppearance => 'المظهر الداكن';

  @override
  String get settingsDarkAppearanceDescription => 'معاينة المظهر الداكن';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageDescription => 'اختر لغة التطبيق.';

  @override
  String get settingsPreviewOnboarding => 'معاينة خطوات البدء';

  @override
  String get settingsPrivacyPromise => 'وعد الخصوصية';

  @override
  String get settingsPrivacyPromiseBody =>
      'لا توجد خريطة عائلية دائمة. يتحكم كل بالغ في مشاركته.';

  @override
  String get settingsAboutBuild => 'حول التطبيق';

  @override
  String get settingsDemoBuildDescription =>
      'تستخدم هذه النسخة معلومات تجريبية فقط. لا تصل إلى GPS أو جهات الاتصال أو الرسائل النصية أو خدمة ذكاء اصطناعي مباشرة.';

  @override
  String get familyInviteTitle => 'دعوة إلى عائلة حمادة';

  @override
  String get familyInviteDescription =>
      'أدخل رقم الهاتف يدويًا. لا يلزم الوصول إلى جهات الاتصال.';

  @override
  String get familyPhoneNumberLabel => 'رقم الهاتف';

  @override
  String get familyPhoneNumberHelper => 'أدخل رمز الدولة، مثل +971.';

  @override
  String get familyPhoneNumberInvalid =>
      'أدخل رقمًا دوليًا صحيحًا من 8 إلى 15 رقمًا.';

  @override
  String get familySendInvitation => 'إرسال الدعوة';

  @override
  String familyInvitationSent(String maskedPhone) {
    return 'تم إرسال الدعوة إلى $maskedPhone.';
  }

  @override
  String get familyInvitationCancelled => 'تم إلغاء الدعوة.';

  @override
  String get familyLeaveDialogTitle => 'مغادرة العائلة؟';

  @override
  String get familyLeaveDialogBody =>
      'ستفقد الوصول إلى رسائل وخطط هذه العائلة. لن تُحذف حسابات الآخرين.';

  @override
  String get familyLeaveAction => 'مغادرة';

  @override
  String familyRemoveDialogTitle(String name) {
    return 'إزالة $name؟';
  }

  @override
  String get familyRemoveDialogBody =>
      'سيتوقف وصول هذا الشخص إلى محتوى العائلة فورًا.';

  @override
  String get familyRemoveAction => 'إزالة';

  @override
  String get familyDeleteDialogTitle => 'حذف العائلة نهائيًا؟';

  @override
  String get familyDeleteDialogBody =>
      'سيتم حذف رسائل العائلة وخططها وتذكيراتها وحالاتها المشتركة. ستبقى حسابات الأشخاص منفصلة.';

  @override
  String get familyDeleteAction => 'حذف العائلة';
}

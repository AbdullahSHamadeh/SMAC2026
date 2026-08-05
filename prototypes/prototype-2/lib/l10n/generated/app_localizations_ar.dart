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
  String get compassInputHint => 'اسأل البوصلة عن تحديث مشترك أو خطة عائلية';

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
}

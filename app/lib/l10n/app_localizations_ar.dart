// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Taskwise';

  @override
  String get navTasks => 'المهام';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get quickAddHint => 'أضف مهمة واضغط Enter';

  @override
  String get searchHint => 'ابحث في المهام';

  @override
  String get filter => 'تصفية';

  @override
  String filterWithCount(int count) {
    return 'تصفية ($count مفعّلة)';
  }

  @override
  String get clearFilters => 'مسح عوامل التصفية';

  @override
  String get sortBy => 'ترتيب حسب';

  @override
  String get sortDueDate => 'تاريخ الاستحقاق';

  @override
  String get sortPriority => 'الأولوية';

  @override
  String get sortTitle => 'العنوان';

  @override
  String get sortCreated => 'المضافة حديثًا';

  @override
  String get groupOverdue => 'متأخرة';

  @override
  String get groupToday => 'اليوم';

  @override
  String get groupTomorrow => 'غدًا';

  @override
  String get groupThisWeek => 'هذا الأسبوع';

  @override
  String get groupLater => 'لاحقًا';

  @override
  String get groupNoDate => 'بلا تاريخ';

  @override
  String get groupCompleted => 'مكتملة';

  @override
  String groupHeaderSemantics(String group, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$group، $count مهمة. اضغط للتوسيع أو الطي.',
      few: '$group، $count مهام. اضغط للتوسيع أو الطي.',
      two: '$group، مهمتان. اضغط للتوسيع أو الطي.',
      one: '$group، مهمة واحدة. اضغط للتوسيع أو الطي.',
      zero: '$group، لا توجد مهام. اضغط للتوسيع أو الطي.',
    );
    return '$_temp0';
  }

  @override
  String get emptyTasks => 'لا توجد مهام بعد. أضف أول مهمة من الأعلى.';

  @override
  String get emptyFiltered => 'لا توجد مهام تطابق البحث أو عوامل التصفية.';

  @override
  String get loadError => 'حدث خطأ أثناء التحميل.';

  @override
  String get today => 'اليوم';

  @override
  String get tomorrow => 'غدًا';

  @override
  String get yesterday => 'أمس';

  @override
  String markDone(String title) {
    return 'تعليم \"$title\" كمكتملة';
  }

  @override
  String markNotDone(String title) {
    return 'تعليم \"$title\" كغير مكتملة';
  }

  @override
  String subtaskProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get taskDeleted => 'تم حذف المهمة';

  @override
  String get undo => 'تراجع';

  @override
  String get selectTaskHint => 'اختر مهمة لعرض تفاصيلها.';

  @override
  String get taskNotFound => 'هذه المهمة لم تعد موجودة.';

  @override
  String get close => 'إغلاق';

  @override
  String get titleLabel => 'العنوان';

  @override
  String get notesLabel => 'ملاحظات';

  @override
  String get dueDate => 'تاريخ الاستحقاق';

  @override
  String get noDueDate => 'بلا تاريخ استحقاق';

  @override
  String get dueTime => 'الوقت';

  @override
  String get allDay => 'طوال اليوم';

  @override
  String get addTime => 'إضافة وقت';

  @override
  String get clearDueDate => 'مسح تاريخ الاستحقاق';

  @override
  String get clearDueTime => 'مسح الوقت';

  @override
  String get priority => 'الأولوية';

  @override
  String get priorityNone => 'بلا';

  @override
  String get priorityLow => 'منخفضة';

  @override
  String get priorityMedium => 'متوسطة';

  @override
  String get priorityHigh => 'عالية';

  @override
  String get category => 'الفئة';

  @override
  String get noCategory => 'بلا فئة';

  @override
  String get tags => 'الوسوم';

  @override
  String get addTag => 'إضافة وسم';

  @override
  String get tagName => 'اسم الوسم';

  @override
  String removeTag(String name) {
    return 'إزالة الوسم $name';
  }

  @override
  String get subtasks => 'المهام الفرعية';

  @override
  String get addSubtaskHint => 'أضف مهمة فرعية';

  @override
  String get renameSubtask => 'إعادة تسمية المهمة الفرعية';

  @override
  String get deleteSubtask => 'حذف المهمة الفرعية';

  @override
  String get reorderSubtask => 'اسحب لإعادة الترتيب';

  @override
  String get deleteTask => 'حذف المهمة';

  @override
  String get markTaskDone => 'تعليم كمكتملة';

  @override
  String get markTaskNotDone => 'تعليم كغير مكتملة';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get theme => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get settingsDateTime => 'التاريخ والوقت';

  @override
  String get weekStartsOn => 'يبدأ الأسبوع يوم';

  @override
  String get sunday => 'الأحد';

  @override
  String get saturday => 'السبت';

  @override
  String get monday => 'الإثنين';

  @override
  String get timeFormat => 'تنسيق الوقت';

  @override
  String get timeFormat12 => '12 ساعة';

  @override
  String get timeFormat24 => '24 ساعة';

  @override
  String get settingsOrganize => 'التنظيم';

  @override
  String get categories => 'الفئات';

  @override
  String get manageCategoriesSubtitle =>
      'إضافة الفئات أو إعادة تسميتها أو تغيير لونها أو حذفها';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get editCategory => 'تعديل الفئة';

  @override
  String get categoryName => 'الاسم';

  @override
  String get color => 'اللون';

  @override
  String colorOption(int index) {
    return 'اللون $index';
  }

  @override
  String get noCategoriesYet => 'لا توجد فئات بعد.';

  @override
  String deleteCategoryTitle(String name) {
    return 'حذف \"$name\"؟';
  }

  @override
  String get deleteCategoryBody => 'ستصبح المهام في هذه الفئة بلا فئة.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get add => 'إضافة';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get repeat => 'التكرار';

  @override
  String get repeatNone => 'بدون تكرار';

  @override
  String get repeatDaily => 'يوميًا';

  @override
  String get repeatWeekdays => 'كل أيام العمل';

  @override
  String repeatWeeklyOn(String day) {
    return 'أسبوعيًا يوم $day';
  }

  @override
  String repeatMonthlyOnDay(int day) {
    return 'شهريًا في اليوم $day';
  }

  @override
  String repeatMonthlyOnNth(String nth, String weekday) {
    return 'شهريًا في $weekday $nth';
  }

  @override
  String repeatYearlyOn(String date) {
    return 'سنويًا في $date';
  }

  @override
  String get repeatCustom => 'مخصص…';

  @override
  String get repeatCustomTitle => 'تكرار مخصص';

  @override
  String everyNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count يومًا',
      few: 'كل $count أيام',
      two: 'كل يومين',
      one: 'كل يوم',
    );
    return '$_temp0';
  }

  @override
  String everyNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count أسبوعًا',
      few: 'كل $count أسابيع',
      two: 'كل أسبوعين',
      one: 'كل أسبوع',
    );
    return '$_temp0';
  }

  @override
  String everyNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count شهرًا',
      few: 'كل $count أشهر',
      two: 'كل شهرين',
      one: 'كل شهر',
    );
    return '$_temp0';
  }

  @override
  String everyNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count سنة',
      few: 'كل $count سنوات',
      two: 'كل سنتين',
      one: 'كل سنة',
    );
    return '$_temp0';
  }

  @override
  String repeatOnDays(String base, String days) {
    return '$base أيام $days';
  }

  @override
  String repeatOnMonthDay(String base, int day) {
    return '$base في اليوم $day';
  }

  @override
  String repeatOnNth(String base, String nth, String weekday) {
    return '$base في $weekday $nth';
  }

  @override
  String repeatOnDate(String base, String date) {
    return '$base في $date';
  }

  @override
  String repeatUntil(String summary, String date) {
    return '$summary، حتى $date';
  }

  @override
  String repeatTimes(String summary, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$summary، $count مرة',
      few: '$summary، $count مرات',
      two: '$summary، مرتين',
      one: '$summary، مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get ordinal1 => 'الأول';

  @override
  String get ordinal2 => 'الثاني';

  @override
  String get ordinal3 => 'الثالث';

  @override
  String get ordinal4 => 'الرابع';

  @override
  String get ordinalLast => 'الأخير';

  @override
  String get repeatEvery => 'كل';

  @override
  String unitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يومًا',
      few: 'أيام',
      two: 'يومين',
      one: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String unitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أسبوعًا',
      few: 'أسابيع',
      two: 'أسبوعين',
      one: 'أسبوع',
    );
    return '$_temp0';
  }

  @override
  String unitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'شهرًا',
      few: 'أشهر',
      two: 'شهرين',
      one: 'شهر',
    );
    return '$_temp0';
  }

  @override
  String unitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سنة',
      few: 'سنوات',
      two: 'سنتين',
      one: 'سنة',
    );
    return '$_temp0';
  }

  @override
  String get repeatOn => 'في';

  @override
  String monthlyByDay(int day) {
    return 'في اليوم $day';
  }

  @override
  String monthlyByNth(String nth, String weekday) {
    return 'في $weekday $nth';
  }

  @override
  String get repeatEnds => 'ينتهي';

  @override
  String get endsNever => 'أبدًا';

  @override
  String endsOnDate(String date) {
    return 'في $date';
  }

  @override
  String get endsAfter => 'بعد';

  @override
  String endsTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مرة',
      few: 'مرات',
      two: 'مرتين',
      one: 'مرة',
    );
    return '$_temp0';
  }

  @override
  String get repeatingTask => 'مهمة متكررة';

  @override
  String doneNextOn(String date) {
    return 'تمت. القادمة: $date';
  }

  @override
  String get doneSeriesEnded => 'تمت. كانت هذه الأخيرة.';

  @override
  String get navCalendar => 'التقويم';

  @override
  String get calendarWeek => 'أسبوع';

  @override
  String get calendarMonth => 'شهر';

  @override
  String get calendarThisMonth => 'هذا الشهر';

  @override
  String get previousWeek => 'الأسبوع السابق';

  @override
  String get nextWeek => 'الأسبوع التالي';

  @override
  String get previousMonth => 'الشهر السابق';

  @override
  String get nextMonth => 'الشهر التالي';

  @override
  String get addTask => 'إضافة مهمة';

  @override
  String addTaskOn(String date) {
    return 'إضافة مهمة في $date';
  }

  @override
  String get newTaskHint => 'عنوان المهمة';

  @override
  String moreTasks(int count) {
    return '+$count';
  }

  @override
  String get noTasksThisDay => 'لا توجد مهام في هذا اليوم.';

  @override
  String upcomingOccurrence(String title) {
    return 'تكرار قادم لـ \"$title\"';
  }

  @override
  String get reminders => 'التذكيرات';

  @override
  String get addReminder => 'إضافة تذكير';

  @override
  String get reminderAtDueTime => 'في موعد الاستحقاق';

  @override
  String reminderBefore(String duration) {
    return 'قبل $duration';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتين',
      one: 'ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يومًا',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get reminderCustom => 'تاريخ ووقت مخصصان…';

  @override
  String get reminderNeedsDueDate =>
      'حدّد تاريخ الاستحقاق لإضافة تذكيرات قبله.';

  @override
  String get removeReminder => 'إزالة التذكير';

  @override
  String get hasReminders => 'لها تذكيرات';

  @override
  String get notificationsDenied =>
      'الإشعارات متوقفة لتطبيق Taskwise. فعّلها من إعدادات الهاتف لتصلك التذكيرات.';

  @override
  String get notifDone => 'تمت';

  @override
  String notifSnooze(String duration) {
    return 'تأجيل $duration';
  }

  @override
  String get notifOpen => 'فتح';

  @override
  String get notifChannel => 'التذكيرات';

  @override
  String notifDue(String when) {
    return 'الموعد: $when';
  }

  @override
  String notifSnoozed(String when) {
    return 'مؤجلة · الموعد: $when';
  }

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get defaultReminder => 'التذكير الافتراضي (عند تحديد وقت للمهمة)';

  @override
  String get defaultReminderNone => 'بدون';

  @override
  String get defaultReminderAtDue => 'في الموعد';

  @override
  String get defaultReminderMin15 => 'قبل 15 دقيقة';

  @override
  String get snoozeOptions => 'مدد التأجيل (حتى 3)';

  @override
  String minutesShort(int count) {
    return '$count د';
  }

  @override
  String get allDayReminderTime => 'وقت تذكير المهام طوال اليوم';

  @override
  String get settingsBackground => 'التشغيل في الخلفية';

  @override
  String get keepRunning => 'الاستمرار في العمل عند إغلاق النافذة';

  @override
  String get keepRunningHint =>
      'لا تظهر التذكيرات إلا أثناء تشغيل Taskwise. إغلاق النافذة يبقيه في شريط النظام.';

  @override
  String get startOnLogin => 'التشغيل عند تسجيل الدخول';

  @override
  String get linuxTrayHint =>
      'في GNOME تحتاج أيقونة شريط النظام إلى إضافة AppIndicator. بدونها افتح Taskwise من قائمة التطبيقات لإظهار النافذة.';

  @override
  String get trayShow => 'إظهار Taskwise';

  @override
  String get trayQuit => 'إنهاء Taskwise';

  @override
  String get settingsSync => 'المزامنة';

  @override
  String get syncNotConnectedHint =>
      'اجعل مهامك متطابقة على كل أجهزتك عبر خادم Taskwise الخاص بك.';

  @override
  String get syncConnect => 'الاتصال بخادمك';

  @override
  String syncSignedInAs(String username) {
    return 'تم تسجيل الدخول باسم $username';
  }

  @override
  String syncStatusSynced(String when) {
    return 'تمت المزامنة $when';
  }

  @override
  String get syncStatusNever => 'لم تتم المزامنة بعد';

  @override
  String get syncStatusSyncing => 'جارٍ المزامنة…';

  @override
  String get syncStatusOffline =>
      'غير متصل. ستُزامَن التغييرات عند الوصول إلى الخادم.';

  @override
  String get syncStatusSignedOut =>
      'تم تسجيل الخروج. سجّل الدخول مجددًا لمتابعة المزامنة.';

  @override
  String syncStatusError(String message) {
    return 'مشكلة في المزامنة: $message';
  }

  @override
  String get syncNow => 'زامن الآن';

  @override
  String get syncSignOut => 'تسجيل الخروج';

  @override
  String syncSignOutConfirm(String server) {
    return 'تسجيل الخروج من $server؟ سيتوقف هذا الجهاز عن المزامنة، وتبقى مهامك عليه.';
  }

  @override
  String get syncSignInAgain => 'سجّل الدخول مجددًا';

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'أمس',
    );
    return '$_temp0';
  }

  @override
  String get signInTitle => 'الاتصال بخادمك';

  @override
  String get signInServer => 'عنوان الخادم';

  @override
  String get signInServerHint => 'مثال: your-app.vercel.app';

  @override
  String get signInUsername => 'اسم المستخدم';

  @override
  String get signInPassword => 'كلمة المرور';

  @override
  String get signInDeviceName => 'اسم هذا الجهاز';

  @override
  String get signInButton => 'تسجيل الدخول';

  @override
  String get signInCreateAccount => 'أول مرة؟ أنشئ الحساب';

  @override
  String get signInCreateAccountHelp =>
      'أدخل سر الإعداد الذي وضعته على الخادم (SETUP_SECRET). يُطلب مرة واحدة فقط. اختر كلمة مرور من 10 أحرف على الأقل.';

  @override
  String get signInSetupSecret => 'سر الإعداد';

  @override
  String get signInCreateButton => 'إنشاء الحساب وتسجيل الدخول';

  @override
  String get signInHaveAccount => 'لدي حساب بالفعل';

  @override
  String get fieldRequired => 'مطلوب';

  @override
  String get passwordTooShort => '10 أحرف على الأقل';

  @override
  String get signInErrorUnreachable =>
      'تعذّر الوصول إلى الخادم. تحقّق من العنوان ومن اتصالك.';

  @override
  String get signInErrorBadAddress => 'لا يبدو هذا عنوان خادم.';

  @override
  String get signInErrorNotTaskwise =>
      'أجاب هذا العنوان، لكنه ليس خادم Taskwise.';

  @override
  String get signInErrorWrongPassword =>
      'اسم المستخدم أو كلمة المرور غير صحيحة.';

  @override
  String signInErrorRateLimited(int minutes) {
    return 'محاولات فاشلة كثيرة. حاول مجددًا بعد $minutes د.';
  }

  @override
  String get signInErrorWrongSecret => 'سر الإعداد غير صحيح.';

  @override
  String get signInErrorAccountExists =>
      'الحساب موجود بالفعل. سجّل الدخول بدلًا من ذلك.';

  @override
  String get signInErrorSetupDisabled =>
      'إعداد الحساب معطّل على الخادم (لم يُضبط SETUP_SECRET).';

  @override
  String signInErrorOther(String message) {
    return 'حدث خطأ: $message';
  }

  @override
  String get syncBannerText => 'زامن أجهزتك: اتصل بخادم Taskwise الخاص بك.';

  @override
  String get syncBannerConnect => 'اتصال';

  @override
  String get syncBannerLater => 'ليس الآن';

  @override
  String get devicesTitle => 'الأجهزة';

  @override
  String get devicesSubtitle => 'أعد تسمية أجهزتك أو أزلها';

  @override
  String get deviceThis => 'هذا الجهاز';

  @override
  String deviceLastSeen(String when) {
    return 'آخر ظهور $when';
  }

  @override
  String get deviceRename => 'إعادة التسمية';

  @override
  String get deviceName => 'اسم الجهاز';

  @override
  String get deviceRemove => 'إزالة';

  @override
  String deviceRemoveConfirm(String name) {
    return 'إزالة $name؟ سيتوقف عن المزامنة حتى يسجّل الدخول مجددًا بكلمة مرورك.';
  }

  @override
  String get deviceActionFailed =>
      'تعذّر الوصول إلى الخادم. حاول مجددًا عند الاتصال.';

  @override
  String get notifyOn => 'التنبيه على';

  @override
  String get notifyAllDevices => 'كل الأجهزة';

  @override
  String get notifyNoDevice =>
      'لم يُختر أي جهاز: لن تذكّر هذه المهمة على أي جهاز.';

  @override
  String get notNotifiedHere => 'لا تذكّر على هذا الجهاز';

  @override
  String get notifTestButton => 'إرسال إشعار تجريبي';

  @override
  String get notifTestBody => 'الإشعارات تعمل على هذا الجهاز.';

  @override
  String get notifTestDenied =>
      'الإشعارات معطّلة لـ Taskwise. فعّلها من إعدادات النظام.';

  @override
  String get notifTestSent =>
      'تم الإرسال. إن لم يظهر شيء، فتحقّق من إعدادات الإشعارات في النظام (ووضع التركيز / عدم الإزعاج).';

  @override
  String get reminderPassed => 'فات وقته';

  @override
  String get deviceMain => 'الجهاز الرئيسي';

  @override
  String get devicesMainHint =>
      'الجهاز الرئيسي يدير بقية الأجهزة: هو وحده يستطيع إزالتها أو إعادة تسميتها.';

  @override
  String get deviceMakeMain => 'جعله الجهاز الرئيسي';

  @override
  String deviceMakeMainConfirm(String name) {
    return 'جعل $name الجهاز الرئيسي؟ لن يستطيع هذا الجهاز بعدها إزالة الأجهزة الأخرى أو إعادة تسميتها.';
  }

  @override
  String get deviceClaimMain => 'اجعل هذا الجهاز الرئيسي';

  @override
  String get deviceClaimMainHelp =>
      'إذا فُقد الجهاز الرئيسي، أدخل كلمة مرور حسابك لجعل هذا الجهاز هو الرئيسي.';

  @override
  String get deviceWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get notifSnoozedNoDate => 'مؤجَّل';

  @override
  String get reminderAtLocation => 'عند مكان…';

  @override
  String get locArrive => 'الوصول';

  @override
  String get locLeave => 'المغادرة';

  @override
  String locChipArrive(String place) {
    return 'عند الوصول إلى $place';
  }

  @override
  String locChipLeave(String place) {
    return 'عند مغادرة $place';
  }

  @override
  String get locDroppedPin => 'دبوس على الخريطة';

  @override
  String meters(int meters) {
    return '$meters م';
  }

  @override
  String get locOnlyPhones => 'يذكّر على الهواتف فقط (آيفون وأندرويد)';

  @override
  String get locPickerTitle => 'تذكير بالمكان';

  @override
  String get locPlacePickerTitle => 'اختر المكان';

  @override
  String get locSearchHint => 'ابحث عن عنوان أو مكان';

  @override
  String get locSearch => 'بحث';

  @override
  String get locSearchNoResults =>
      'لم يُعثر على شيء. جرّب كلمات أخرى، أو انقر على الخريطة.';

  @override
  String get locSearchFailed =>
      'لم ينجح البحث. تحقق من الاتصال، أو انقر على الخريطة.';

  @override
  String get locTapToDrop => 'انقر على الخريطة لوضع الدبوس حيث يقع المكان.';

  @override
  String get locRadius => 'نصف القطر';

  @override
  String get locRemindWhen => 'ذكّرني عند';

  @override
  String get locSaveAsPlace => 'حفظه كمكان';

  @override
  String get locPlaceName => 'اسم المكان';

  @override
  String get locUseMyLocation => 'استخدم موقعي';

  @override
  String get locNoFix => 'تعذّر الحصول على موقعك.';

  @override
  String get locNeedPin =>
      'اختر مكانًا أولًا: ابحث، أو انقر على الخريطة، أو اختر مكانًا محفوظًا.';

  @override
  String locNotifArrived(String place) {
    return 'أنت الآن في $place';
  }

  @override
  String get locNotifArrivedNoName => 'وصلت إلى مكان هذه المهمة';

  @override
  String locNotifLeft(String place) {
    return 'غادرت $place';
  }

  @override
  String get locNotifLeftNoName => 'غادرت مكان هذه المهمة';

  @override
  String get placesTitle => 'الأماكن المحفوظة';

  @override
  String get placesSubtitle => 'المنزل والعمل وأماكن أخرى للتذكير بالمكان';

  @override
  String get placesEmpty => 'لا توجد أماكن محفوظة بعد.';

  @override
  String get addPlace => 'إضافة مكان';

  @override
  String get editPlace => 'تعديل المكان';

  @override
  String get deletePlaceTitle => 'حذف المكان؟';

  @override
  String deletePlaceBody(String name) {
    return 'حذف \"$name\"؟ تبقى تذكيرات المكان التي تستخدمه تعمل.';
  }

  @override
  String get defaultLocationRadius => 'نصف القطر الافتراضي لتذكيرات المكان';

  @override
  String get settingsLocation => 'تذكيرات المكان';

  @override
  String get locPermissionStatus => 'الوصول إلى الموقع';

  @override
  String get locPermAlways => 'دائمًا';

  @override
  String get locPermWhenInUse => 'أثناء استخدام التطبيق';

  @override
  String get locPermDenied => 'متوقف';

  @override
  String get locPermNotDetermined => 'لم يُطلب بعد';

  @override
  String get locPermRestricted => 'مقيَّد';

  @override
  String get locPermDialogTitle => 'الموقع في الخلفية';

  @override
  String get locPermDialogBody =>
      'يذكّرك Taskwise عند وصولك إلى مكان أو مغادرته، حتى والتطبيق مغلق. لذلك يجب أن يسمح iOS بالوصول إلى الموقع \"دائمًا\".\n\nيسأل iOS مرتين: اختر أولًا \"السماح أثناء استخدام التطبيق\". لاحقًا يسأل iOS مرة أخرى؛ عندها اختر \"التغيير إلى السماح دائمًا\". إن لم يسأل، افتح الإعدادات ← Taskwise ← الموقع واختر \"دائمًا\".\n\nموقعك يبقى على هاتفك.';

  @override
  String get locPermDialogBodyAndroid =>
      'يذكّرك Taskwise عند وصولك إلى مكان أو مغادرته، حتى والتطبيق مغلق. لذلك يجب أن يسمح أندرويد بالوصول إلى الموقع \"طوال الوقت\".\n\nاختر أولًا \"أثناء استخدام التطبيق\" وأبقِ \"الموقع الدقيق\" مفعّلًا. بعدها يفتح أندرويد إعدادات الموقع لتطبيق Taskwise: اختر \"السماح طوال الوقت\" ثم ارجع.\n\nموقعك يبقى على هاتفك.';

  @override
  String get locPermAlwaysAndroid => 'طوال الوقت';

  @override
  String get locBannerNotAlwaysAndroid =>
      'تحتاج تذكيرات المواقع إلى ضبط الوصول إلى الموقع على \"السماح طوال الوقت\".';

  @override
  String get locBatteryHint =>
      'إذا تأخرت التذكيرات أو لم تصل، اضبط استهلاك البطارية لتطبيق Taskwise على \"غير مقيّد\": الإعدادات ← التطبيقات ← Taskwise ← البطارية.';

  @override
  String get locPermContinue => 'متابعة';

  @override
  String get locBannerNotAlways =>
      'تحتاج تذكيرات المكان إلى ضبط الوصول إلى الموقع على \"دائمًا\".';

  @override
  String get locBannerDenied =>
      'الوصول إلى الموقع متوقف لـ Taskwise، لذا لا تستطيع تذكيرات المكان تذكيرك.';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get locDebugTitle => 'تشخيص الموقع';

  @override
  String get locDebugSubtitle => 'ما يراقبه الهاتف وما حدث';

  @override
  String locDebugEntries(int count) {
    return 'تذكيرات المكان على هذا الهاتف: $count';
  }

  @override
  String get locDebugRegions => 'المناطق المراقَبة';

  @override
  String get locDebugEvents => 'آخر الأحداث';

  @override
  String get locDebugNoEvents => 'لا توجد أحداث بعد.';

  @override
  String get locDebugPrecise => 'التتبع الدقيق يعمل الآن';

  @override
  String locDebugLastFix(int accuracy) {
    return 'آخر موقع: ±$accuracy م';
  }

  @override
  String locDebugAway(int distance) {
    return 'على بعد $distance م';
  }

  @override
  String get refresh => 'تحديث';

  @override
  String get syncBackgroundHint =>
      'تزامن الهواتف أيضًا في الخلفية من حين لآخر (يقرر الهاتف متى).';

  @override
  String get lapisEmptyTasks => 'اكتب مهمة في الحقل أعلاه ثم اضغط Enter';

  @override
  String get lapisEmptyTasksTitle => 'لا توجد مهام بعد';

  @override
  String get shortcutNewTask => 'مهمة جديدة';

  @override
  String get shortcutSearch => 'بحث';

  @override
  String todayLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقيت $count مهمة اليوم',
      few: 'بقيت $count مهام اليوم',
      two: 'بقيت مهمتان اليوم',
      one: 'بقيت مهمة واحدة اليوم',
    );
    return '$_temp0';
  }

  @override
  String todayDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أنجزت $count ',
      two: 'أنجزت اثنتين',
      one: 'أنجزت واحدة',
      zero: 'لم تُنجز أي مهمة بعد',
    );
    return '$_temp0';
  }

  @override
  String get todayAllDone => 'أنجزت كل مهام اليوم';

  @override
  String todayProgressSemantics(int done, int total) {
    return 'أنجزت $done من $total من مهام اليوم';
  }

  @override
  String progressSummary(int done, int total) {
    return '$done من $total مكتملة';
  }

  @override
  String get progressAllDone => 'أنجزت جميع مهام اليوم!';

  @override
  String get quickAddSubmitTooltip => 'إضافة المهمة (Enter)';

  @override
  String get todayOverview => 'تركيز اليوم';

  @override
  String statOpen(int count) {
    return 'متبقية: $count';
  }

  @override
  String statOverdue(int count) {
    return 'متأخرة: $count';
  }

  @override
  String get brutalEmptyTasksTitle => 'قائمتك فارغة';

  @override
  String get shortcutsTitle => 'اختصارات لوحة المفاتيح';

  @override
  String get shortcutCloseTask => 'إغلاق المهمة';

  @override
  String get settingsDesign => 'التصميم';

  @override
  String get designClassic => 'كلاسيكي';

  @override
  String get designLapis => 'لازورد';

  @override
  String get designSlate => 'أردواز ونيلي';

  @override
  String get designBrutal => 'جريء';

  @override
  String get settingsBackup => 'النسخ الاحتياطي';

  @override
  String get backupExport => 'تصدير إلى ملف';

  @override
  String get backupExportSubtitle => 'احفظ كل مهامك في ملف JSON';

  @override
  String get backupImport => 'استيراد من ملف';

  @override
  String get backupImportSubtitle =>
      'يضيف مهام النسخة الاحتياطية، وتبقى التعديلات الأحدث على هذا الجهاز.';

  @override
  String backupSaved(String path) {
    return 'حُفظت النسخة الاحتياطية: $path';
  }

  @override
  String backupSavedIos(String name) {
    return 'حُفظت النسخة الاحتياطية. افتح تطبيق الملفات ← على iPhone ← Taskwise ← $name';
  }

  @override
  String fileSaved(String name) {
    return 'تم حفظ $name';
  }

  @override
  String backupImported(int changed, int kept, int skipped) {
    return 'اكتمل الاستيراد: $changed أُضيفت أو حُدّثت، $kept أحدث هنا، $skipped تُخطّيت';
  }

  @override
  String get backupNotABackup => 'هذا الملف ليس نسخة احتياطية من Taskwise.';

  @override
  String get backupTooNew =>
      'هذه النسخة من إصدار أحدث من Taskwise. حدّث Taskwise أولًا.';

  @override
  String get actionFailed =>
      'حدث خطأ. التفاصيل في الإعدادات ← حول ← عرض السجلات.';

  @override
  String get settingsAbout => 'حول';

  @override
  String aboutVersion(String version) {
    return 'Taskwise $version';
  }

  @override
  String get aboutViewLogs => 'عرض السجلات';

  @override
  String get aboutViewLogsSubtitle =>
      'للبحث عن المشكلات. لا تحتوي السجلات على مهامك أبدًا.';

  @override
  String get logsTitle => 'السجلات';

  @override
  String get logsEmpty => 'لا شيء في السجل بعد.';

  @override
  String get logsCopy => 'نسخ الكل';

  @override
  String get logsCopied => 'نُسخت السجلات';

  @override
  String get logsSave => 'حفظ في ملف';

  @override
  String get logsClear => 'مسح';

  @override
  String get logsFilterAll => 'الكل';

  @override
  String get logsFilterProblems => 'المشكلات فقط';

  @override
  String sharedTaskAdded(String title) {
    return 'تمت إضافة «$title»';
  }

  @override
  String updateAvailable(String version) {
    return 'يتوفر Taskwise $version';
  }

  @override
  String get updateLater => 'لاحقًا';

  @override
  String get updateSee => 'ما الجديد';

  @override
  String updateTitle(String version) {
    return 'Taskwise $version';
  }

  @override
  String updateCurrent(String version) {
    return 'لديك الإصدار $version.';
  }

  @override
  String get updateNow => 'حدّث الآن';

  @override
  String get updateNowRestart => 'حدّث وأعد التشغيل';

  @override
  String updateDownloading(int percent) {
    return 'جارٍ التنزيل… $percent٪';
  }

  @override
  String get updateDownloadingNoSize => 'جارٍ التنزيل…';

  @override
  String get updateInstalling => 'جارٍ التثبيت…';

  @override
  String get updateOpenPage => 'افتح صفحة التنزيل';

  @override
  String get updateIosHint =>
      'لا يمكن لتطبيقات iPhone تحديث نفسها. نزّل ملف ‎.ipa الجديد وثبّته باستخدام iloader (أو SideStore) كالمعتاد. مهامك تبقى كما هي.';

  @override
  String get updateManualHint =>
      'لا تستطيع هذه النسخة من Taskwise تحديث نفسها. نزّل الإصدار الجديد من صفحة الإصدار.';

  @override
  String get updateAndroidHint =>
      'سيطلب منك Android تأكيد التحديث. مهامك تبقى كما هي.';

  @override
  String get updateDesktopHint =>
      'ينزّل Taskwise التحديث ويتحقق من أنه صادر فعلًا عن إصدارات Taskwise، ثم يعيد التشغيل. مهامك تبقى كما هي.';

  @override
  String get updateCheck => 'التحقق من التحديثات';

  @override
  String get updateChecking => 'جارٍ التحقق…';

  @override
  String get updateUpToDate => 'Taskwise محدَّث';

  @override
  String get updateAuto => 'التحقق من التحديثات تلقائيًا';

  @override
  String get updateAutoSubtitle => 'مرة في اليوم تقريبًا، من GitHub';

  @override
  String get updateErrorCheck =>
      'تعذّر التحقق من التحديثات. هل أنت متصل بالإنترنت؟';

  @override
  String get updateErrorDownload => 'فشل التنزيل. حاول لاحقًا.';

  @override
  String get updateErrorVerification =>
      'لم يجتز التنزيل فحص الأمان، فلم يُثبَّت شيء.';

  @override
  String get updateErrorInstall => 'تعذّر تثبيت التحديث.';

  @override
  String get updateErrorPermission =>
      'اسمح لـ Taskwise بتثبيت التطبيقات (\"السماح من هذا المصدر\")، ثم اضغط تحديث مرة أخرى.';

  @override
  String get updateTryAgain => 'حاول مرة أخرى';
}

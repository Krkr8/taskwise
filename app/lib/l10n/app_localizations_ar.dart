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
}

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
/// import 'l10n/app_localizations.dart';
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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Taskwise'**
  String get appTitle;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @quickAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add a task and press Enter'**
  String get quickAddHint;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get searchHint;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @filterWithCount.
  ///
  /// In en, this message translates to:
  /// **'Filter ({count} active)'**
  String filterWithCount(int count);

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get sortDueDate;

  /// No description provided for @sortPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sortPriority;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// No description provided for @sortCreated.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get sortCreated;

  /// No description provided for @groupOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get groupOverdue;

  /// No description provided for @groupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get groupToday;

  /// No description provided for @groupTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get groupTomorrow;

  /// No description provided for @groupThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get groupThisWeek;

  /// No description provided for @groupLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get groupLater;

  /// No description provided for @groupNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get groupNoDate;

  /// No description provided for @groupCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get groupCompleted;

  /// No description provided for @groupHeaderSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{group}, 1 task. Tap to expand or collapse.} other{{group}, {count} tasks. Tap to expand or collapse.}}'**
  String groupHeaderSemantics(String group, int count);

  /// No description provided for @emptyTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Add your first one above.'**
  String get emptyTasks;

  /// No description provided for @emptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No tasks match your search or filters.'**
  String get emptyFiltered;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while loading.'**
  String get loadError;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" as done'**
  String markDone(String title);

  /// No description provided for @markNotDone.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" as not done'**
  String markNotDone(String title);

  /// No description provided for @subtaskProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total}'**
  String subtaskProgress(int done, int total);

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @selectTaskHint.
  ///
  /// In en, this message translates to:
  /// **'Select a task to see its details.'**
  String get selectTaskHint;

  /// No description provided for @taskNotFound.
  ///
  /// In en, this message translates to:
  /// **'This task no longer exists.'**
  String get taskNotFound;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDate;

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No description provided for @dueTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get dueTime;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get addTime;

  /// No description provided for @clearDueDate.
  ///
  /// In en, this message translates to:
  /// **'Clear due date'**
  String get clearDueDate;

  /// No description provided for @clearDueTime.
  ///
  /// In en, this message translates to:
  /// **'Clear time'**
  String get clearDueTime;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @priorityNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get priorityNone;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get addTag;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagName;

  /// No description provided for @removeTag.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {name}'**
  String removeTag(String name);

  /// No description provided for @subtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get subtasks;

  /// No description provided for @addSubtaskHint.
  ///
  /// In en, this message translates to:
  /// **'Add a subtask'**
  String get addSubtaskHint;

  /// No description provided for @renameSubtask.
  ///
  /// In en, this message translates to:
  /// **'Rename subtask'**
  String get renameSubtask;

  /// No description provided for @deleteSubtask.
  ///
  /// In en, this message translates to:
  /// **'Delete subtask'**
  String get deleteSubtask;

  /// No description provided for @reorderSubtask.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get reorderSubtask;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get deleteTask;

  /// No description provided for @markTaskDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markTaskDone;

  /// No description provided for @markTaskNotDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as not done'**
  String get markTaskNotDone;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @settingsDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get settingsDateTime;

  /// No description provided for @weekStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get weekStartsOn;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @timeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get timeFormat;

  /// No description provided for @timeFormat12.
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get timeFormat12;

  /// No description provided for @timeFormat24.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get timeFormat24;

  /// No description provided for @settingsOrganize.
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get settingsOrganize;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @manageCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, rename, recolor or delete categories'**
  String get manageCategoriesSubtitle;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoryName;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @colorOption.
  ///
  /// In en, this message translates to:
  /// **'Color {index}'**
  String colorOption(int index);

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get noCategoriesYet;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteCategoryTitle(String name);

  /// No description provided for @deleteCategoryBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks in this category will have no category.'**
  String get deleteCategoryBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Every weekday'**
  String get repeatWeekdays;

  /// No description provided for @repeatWeeklyOn.
  ///
  /// In en, this message translates to:
  /// **'Weekly on {day}'**
  String repeatWeeklyOn(String day);

  /// No description provided for @repeatMonthlyOnDay.
  ///
  /// In en, this message translates to:
  /// **'Monthly on day {day}'**
  String repeatMonthlyOnDay(int day);

  /// No description provided for @repeatMonthlyOnNth.
  ///
  /// In en, this message translates to:
  /// **'Monthly on the {nth} {weekday}'**
  String repeatMonthlyOnNth(String nth, String weekday);

  /// No description provided for @repeatYearlyOn.
  ///
  /// In en, this message translates to:
  /// **'Yearly on {date}'**
  String repeatYearlyOn(String date);

  /// No description provided for @repeatCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get repeatCustom;

  /// No description provided for @repeatCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom repeat'**
  String get repeatCustomTitle;

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String everyNDays(int count);

  /// No description provided for @everyNWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week} other{Every {count} weeks}}'**
  String everyNWeeks(int count);

  /// No description provided for @everyNMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month} other{Every {count} months}}'**
  String everyNMonths(int count);

  /// No description provided for @everyNYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every year} other{Every {count} years}}'**
  String everyNYears(int count);

  /// No description provided for @repeatOnDays.
  ///
  /// In en, this message translates to:
  /// **'{base} on {days}'**
  String repeatOnDays(String base, String days);

  /// No description provided for @repeatOnMonthDay.
  ///
  /// In en, this message translates to:
  /// **'{base} on day {day}'**
  String repeatOnMonthDay(String base, int day);

  /// No description provided for @repeatOnNth.
  ///
  /// In en, this message translates to:
  /// **'{base} on the {nth} {weekday}'**
  String repeatOnNth(String base, String nth, String weekday);

  /// No description provided for @repeatOnDate.
  ///
  /// In en, this message translates to:
  /// **'{base} on {date}'**
  String repeatOnDate(String base, String date);

  /// No description provided for @repeatUntil.
  ///
  /// In en, this message translates to:
  /// **'{summary}, until {date}'**
  String repeatUntil(String summary, String date);

  /// No description provided for @repeatTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{summary}, once} other{{summary}, {count} times}}'**
  String repeatTimes(String summary, int count);

  /// No description provided for @ordinal1.
  ///
  /// In en, this message translates to:
  /// **'first'**
  String get ordinal1;

  /// No description provided for @ordinal2.
  ///
  /// In en, this message translates to:
  /// **'second'**
  String get ordinal2;

  /// No description provided for @ordinal3.
  ///
  /// In en, this message translates to:
  /// **'third'**
  String get ordinal3;

  /// No description provided for @ordinal4.
  ///
  /// In en, this message translates to:
  /// **'fourth'**
  String get ordinal4;

  /// No description provided for @ordinalLast.
  ///
  /// In en, this message translates to:
  /// **'last'**
  String get ordinalLast;

  /// No description provided for @repeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get repeatEvery;

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day} other{days}}'**
  String unitDays(int count);

  /// No description provided for @unitWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{week} other{weeks}}'**
  String unitWeeks(int count);

  /// No description provided for @unitMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{month} other{months}}'**
  String unitMonths(int count);

  /// No description provided for @unitYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{year} other{years}}'**
  String unitYears(int count);

  /// No description provided for @repeatOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get repeatOn;

  /// No description provided for @monthlyByDay.
  ///
  /// In en, this message translates to:
  /// **'On day {day}'**
  String monthlyByDay(int day);

  /// No description provided for @monthlyByNth.
  ///
  /// In en, this message translates to:
  /// **'On the {nth} {weekday}'**
  String monthlyByNth(String nth, String weekday);

  /// No description provided for @repeatEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get repeatEnds;

  /// No description provided for @endsNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get endsNever;

  /// No description provided for @endsOnDate.
  ///
  /// In en, this message translates to:
  /// **'On {date}'**
  String endsOnDate(String date);

  /// No description provided for @endsAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get endsAfter;

  /// No description provided for @endsTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{time} other{times}}'**
  String endsTimes(int count);

  /// No description provided for @repeatingTask.
  ///
  /// In en, this message translates to:
  /// **'Repeating task'**
  String get repeatingTask;

  /// No description provided for @doneNextOn.
  ///
  /// In en, this message translates to:
  /// **'Done. Next: {date}'**
  String doneNextOn(String date);

  /// No description provided for @doneSeriesEnded.
  ///
  /// In en, this message translates to:
  /// **'Done. That was the last one.'**
  String get doneSeriesEnded;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @calendarWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarWeek;

  /// No description provided for @calendarMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarMonth;

  /// No description provided for @calendarThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get calendarThisMonth;

  /// No description provided for @previousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get previousWeek;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get nextWeek;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTask;

  /// No description provided for @addTaskOn.
  ///
  /// In en, this message translates to:
  /// **'Add a task on {date}'**
  String addTaskOn(String date);

  /// No description provided for @newTaskHint.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get newTaskHint;

  /// No description provided for @moreTasks.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String moreTasks(int count);

  /// No description provided for @noTasksThisDay.
  ///
  /// In en, this message translates to:
  /// **'No tasks on this day.'**
  String get noTasksThisDay;

  /// No description provided for @upcomingOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Upcoming repeat of \"{title}\"'**
  String upcomingOccurrence(String title);

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get addReminder;

  /// No description provided for @reminderAtDueTime.
  ///
  /// In en, this message translates to:
  /// **'At due time'**
  String get reminderAtDueTime;

  /// No description provided for @reminderBefore.
  ///
  /// In en, this message translates to:
  /// **'{duration} before'**
  String reminderBefore(String duration);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String durationMinutes(int count);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String durationHours(int count);

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String durationDays(int count);

  /// No description provided for @reminderCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom date & time…'**
  String get reminderCustom;

  /// No description provided for @reminderNeedsDueDate.
  ///
  /// In en, this message translates to:
  /// **'Set a due date to add reminders before it.'**
  String get reminderNeedsDueDate;

  /// No description provided for @removeReminder.
  ///
  /// In en, this message translates to:
  /// **'Remove reminder'**
  String get removeReminder;

  /// No description provided for @hasReminders.
  ///
  /// In en, this message translates to:
  /// **'Has reminders'**
  String get hasReminders;

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Taskwise. Turn them on in the phone\'s Settings to get reminders.'**
  String get notificationsDenied;

  /// No description provided for @notifDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get notifDone;

  /// No description provided for @notifSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze {duration}'**
  String notifSnooze(String duration);

  /// No description provided for @notifOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notifOpen;

  /// No description provided for @notifChannel.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notifChannel;

  /// No description provided for @notifDue.
  ///
  /// In en, this message translates to:
  /// **'Due: {when}'**
  String notifDue(String when);

  /// No description provided for @notifSnoozed.
  ///
  /// In en, this message translates to:
  /// **'Snoozed · Due: {when}'**
  String notifSnoozed(String when);

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @defaultReminder.
  ///
  /// In en, this message translates to:
  /// **'Default reminder (when a task gets a time)'**
  String get defaultReminder;

  /// No description provided for @defaultReminderNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get defaultReminderNone;

  /// No description provided for @defaultReminderAtDue.
  ///
  /// In en, this message translates to:
  /// **'At due time'**
  String get defaultReminderAtDue;

  /// No description provided for @defaultReminderMin15.
  ///
  /// In en, this message translates to:
  /// **'15 min before'**
  String get defaultReminderMin15;

  /// No description provided for @snoozeOptions.
  ///
  /// In en, this message translates to:
  /// **'Snooze options (up to 3)'**
  String get snoozeOptions;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesShort(int count);

  /// No description provided for @allDayReminderTime.
  ///
  /// In en, this message translates to:
  /// **'All-day tasks remind at'**
  String get allDayReminderTime;

  /// No description provided for @settingsBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get settingsBackground;

  /// No description provided for @keepRunning.
  ///
  /// In en, this message translates to:
  /// **'Keep running when the window is closed'**
  String get keepRunning;

  /// No description provided for @keepRunningHint.
  ///
  /// In en, this message translates to:
  /// **'Reminders only appear while Taskwise is running. Closing the window keeps it in the tray.'**
  String get keepRunningHint;

  /// No description provided for @startOnLogin.
  ///
  /// In en, this message translates to:
  /// **'Start when I log in'**
  String get startOnLogin;

  /// No description provided for @linuxTrayHint.
  ///
  /// In en, this message translates to:
  /// **'On GNOME the tray icon needs the AppIndicator extension. Without it, open Taskwise from the app menu to bring the window back.'**
  String get linuxTrayHint;

  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Show Taskwise'**
  String get trayShow;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit Taskwise'**
  String get trayQuit;

  /// No description provided for @settingsSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsSync;

  /// No description provided for @syncNotConnectedHint.
  ///
  /// In en, this message translates to:
  /// **'Keep your tasks the same on all your devices through your own Taskwise server.'**
  String get syncNotConnectedHint;

  /// No description provided for @syncConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to your server'**
  String get syncConnect;

  /// No description provided for @syncSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username}'**
  String syncSignedInAs(String username);

  /// No description provided for @syncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced {when}'**
  String syncStatusSynced(String when);

  /// No description provided for @syncStatusNever.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get syncStatusNever;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline. Changes will sync when the server can be reached.'**
  String get syncStatusOffline;

  /// No description provided for @syncStatusSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out. Sign in again to keep syncing.'**
  String get syncStatusSignedOut;

  /// No description provided for @syncStatusError.
  ///
  /// In en, this message translates to:
  /// **'Sync problem: {message}'**
  String syncStatusError(String message);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get syncSignOut;

  /// No description provided for @syncSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of {server}? This device stops syncing. Your tasks stay on it.'**
  String syncSignOutConfirm(String server);

  /// No description provided for @syncSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get syncSignInAgain;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} min ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{yesterday} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to your server'**
  String get signInTitle;

  /// No description provided for @signInServer.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get signInServer;

  /// No description provided for @signInServerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. your-app.vercel.app'**
  String get signInServerHint;

  /// No description provided for @signInUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get signInUsername;

  /// No description provided for @signInPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPassword;

  /// No description provided for @signInDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Name of this device'**
  String get signInDeviceName;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @signInCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'First time? Create the account'**
  String get signInCreateAccount;

  /// No description provided for @signInCreateAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the setup secret you set on the server (SETUP_SECRET). It\'s only needed this once. Choose a password of at least 10 characters.'**
  String get signInCreateAccountHelp;

  /// No description provided for @signInSetupSecret.
  ///
  /// In en, this message translates to:
  /// **'Setup secret'**
  String get signInSetupSecret;

  /// No description provided for @signInCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create account and sign in'**
  String get signInCreateButton;

  /// No description provided for @signInHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get signInHaveAccount;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters'**
  String get passwordTooShort;

  /// No description provided for @signInErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check the address and your connection.'**
  String get signInErrorUnreachable;

  /// No description provided for @signInErrorBadAddress.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a server address.'**
  String get signInErrorBadAddress;

  /// No description provided for @signInErrorNotTaskwise.
  ///
  /// In en, this message translates to:
  /// **'That address answered, but it isn\'t a Taskwise server.'**
  String get signInErrorNotTaskwise;

  /// No description provided for @signInErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password.'**
  String get signInErrorWrongPassword;

  /// No description provided for @signInErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many failed tries. Try again in {minutes} min.'**
  String signInErrorRateLimited(int minutes);

  /// No description provided for @signInErrorWrongSecret.
  ///
  /// In en, this message translates to:
  /// **'Wrong setup secret.'**
  String get signInErrorWrongSecret;

  /// No description provided for @signInErrorAccountExists.
  ///
  /// In en, this message translates to:
  /// **'The account already exists. Sign in instead.'**
  String get signInErrorAccountExists;

  /// No description provided for @signInErrorSetupDisabled.
  ///
  /// In en, this message translates to:
  /// **'Account setup is turned off on the server (SETUP_SECRET isn\'t set).'**
  String get signInErrorSetupDisabled;

  /// No description provided for @signInErrorOther.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {message}'**
  String signInErrorOther(String message);

  /// No description provided for @syncBannerText.
  ///
  /// In en, this message translates to:
  /// **'Sync your devices: connect to your Taskwise server.'**
  String get syncBannerText;

  /// No description provided for @syncBannerConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get syncBannerConnect;

  /// No description provided for @syncBannerLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get syncBannerLater;

  /// No description provided for @devicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTitle;

  /// No description provided for @devicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rename or remove your devices'**
  String get devicesSubtitle;

  /// No description provided for @deviceThis.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get deviceThis;

  /// No description provided for @deviceLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {when}'**
  String deviceLastSeen(String when);

  /// No description provided for @deviceRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get deviceRename;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceName;

  /// No description provided for @deviceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get deviceRemove;

  /// No description provided for @deviceRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}? It stops syncing until it signs in again with your password.'**
  String deviceRemoveConfirm(String name);

  /// No description provided for @deviceActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Try again when you\'re online.'**
  String get deviceActionFailed;

  /// No description provided for @notifyOn.
  ///
  /// In en, this message translates to:
  /// **'Notify on'**
  String get notifyOn;

  /// No description provided for @notifyAllDevices.
  ///
  /// In en, this message translates to:
  /// **'All devices'**
  String get notifyAllDevices;

  /// No description provided for @notifyNoDevice.
  ///
  /// In en, this message translates to:
  /// **'No device chosen: this task won\'t remind anywhere.'**
  String get notifyNoDevice;

  /// No description provided for @notNotifiedHere.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t remind on this device'**
  String get notNotifiedHere;

  /// No description provided for @notifTestButton.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get notifTestButton;

  /// No description provided for @notifTestBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications work on this device.'**
  String get notifTestBody;

  /// No description provided for @notifTestDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Taskwise. Turn them on in the system settings.'**
  String get notifTestDenied;

  /// No description provided for @notifTestSent.
  ///
  /// In en, this message translates to:
  /// **'Sent. If nothing appeared, check the system\'s notification settings (and Focus / Do Not Disturb).'**
  String get notifTestSent;

  /// No description provided for @reminderPassed.
  ///
  /// In en, this message translates to:
  /// **'time passed'**
  String get reminderPassed;

  /// No description provided for @deviceMain.
  ///
  /// In en, this message translates to:
  /// **'Main device'**
  String get deviceMain;

  /// No description provided for @devicesMainHint.
  ///
  /// In en, this message translates to:
  /// **'The main device manages the others: only it can remove or rename them.'**
  String get devicesMainHint;

  /// No description provided for @deviceMakeMain.
  ///
  /// In en, this message translates to:
  /// **'Make main device'**
  String get deviceMakeMain;

  /// No description provided for @deviceMakeMainConfirm.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the main device? This device then can\'t remove or rename other devices any more.'**
  String deviceMakeMainConfirm(String name);

  /// No description provided for @deviceClaimMain.
  ///
  /// In en, this message translates to:
  /// **'Make this the main device'**
  String get deviceClaimMain;

  /// No description provided for @deviceClaimMainHelp.
  ///
  /// In en, this message translates to:
  /// **'If the main device is lost, enter your account password to make this one the main device.'**
  String get deviceClaimMainHelp;

  /// No description provided for @deviceWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get deviceWrongPassword;

  /// No description provided for @notifSnoozedNoDate.
  ///
  /// In en, this message translates to:
  /// **'Snoozed'**
  String get notifSnoozedNoDate;

  /// No description provided for @reminderAtLocation.
  ///
  /// In en, this message translates to:
  /// **'At a location…'**
  String get reminderAtLocation;

  /// No description provided for @locArrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive'**
  String get locArrive;

  /// No description provided for @locLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get locLeave;

  /// No description provided for @locChipArrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive at {place}'**
  String locChipArrive(String place);

  /// No description provided for @locChipLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave {place}'**
  String locChipLeave(String place);

  /// No description provided for @locDroppedPin.
  ///
  /// In en, this message translates to:
  /// **'dropped pin'**
  String get locDroppedPin;

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String meters(int meters);

  /// No description provided for @locOnlyPhones.
  ///
  /// In en, this message translates to:
  /// **'Only reminds on phones (iPhone and Android)'**
  String get locOnlyPhones;

  /// No description provided for @locPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Location reminder'**
  String get locPickerTitle;

  /// No description provided for @locPlacePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the place'**
  String get locPlacePickerTitle;

  /// No description provided for @locSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for an address or place'**
  String get locSearchHint;

  /// No description provided for @locSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get locSearch;

  /// No description provided for @locSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found. Try other words, or tap the map.'**
  String get locSearchNoResults;

  /// No description provided for @locSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search didn\'t work. Check your connection, or tap the map.'**
  String get locSearchFailed;

  /// No description provided for @locTapToDrop.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to put the pin where the place is.'**
  String get locTapToDrop;

  /// No description provided for @locRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get locRadius;

  /// No description provided for @locRemindWhen.
  ///
  /// In en, this message translates to:
  /// **'Remind me when I'**
  String get locRemindWhen;

  /// No description provided for @locSaveAsPlace.
  ///
  /// In en, this message translates to:
  /// **'Save as a place'**
  String get locSaveAsPlace;

  /// No description provided for @locPlaceName.
  ///
  /// In en, this message translates to:
  /// **'Place name'**
  String get locPlaceName;

  /// No description provided for @locUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get locUseMyLocation;

  /// No description provided for @locNoFix.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location.'**
  String get locNoFix;

  /// No description provided for @locNeedPin.
  ///
  /// In en, this message translates to:
  /// **'Choose a place first: search, tap the map or pick a saved place.'**
  String get locNeedPin;

  /// No description provided for @locNotifArrived.
  ///
  /// In en, this message translates to:
  /// **'You\'re at {place}'**
  String locNotifArrived(String place);

  /// No description provided for @locNotifArrivedNoName.
  ///
  /// In en, this message translates to:
  /// **'You\'re at the place for this task'**
  String get locNotifArrivedNoName;

  /// No description provided for @locNotifLeft.
  ///
  /// In en, this message translates to:
  /// **'You left {place}'**
  String locNotifLeft(String place);

  /// No description provided for @locNotifLeftNoName.
  ///
  /// In en, this message translates to:
  /// **'You left the place for this task'**
  String get locNotifLeftNoName;

  /// No description provided for @placesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get placesTitle;

  /// No description provided for @placesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Home, work and other places for location reminders'**
  String get placesSubtitle;

  /// No description provided for @placesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet.'**
  String get placesEmpty;

  /// No description provided for @addPlace.
  ///
  /// In en, this message translates to:
  /// **'Add place'**
  String get addPlace;

  /// No description provided for @editPlace.
  ///
  /// In en, this message translates to:
  /// **'Edit place'**
  String get editPlace;

  /// No description provided for @deletePlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete place?'**
  String get deletePlaceTitle;

  /// No description provided for @deletePlaceBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Location reminders that use it keep working.'**
  String deletePlaceBody(String name);

  /// No description provided for @defaultLocationRadius.
  ///
  /// In en, this message translates to:
  /// **'Default radius for location reminders'**
  String get defaultLocationRadius;

  /// No description provided for @settingsLocation.
  ///
  /// In en, this message translates to:
  /// **'Location reminders'**
  String get settingsLocation;

  /// No description provided for @locPermissionStatus.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get locPermissionStatus;

  /// No description provided for @locPermAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get locPermAlways;

  /// No description provided for @locPermWhenInUse.
  ///
  /// In en, this message translates to:
  /// **'While using the app'**
  String get locPermWhenInUse;

  /// No description provided for @locPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get locPermDenied;

  /// No description provided for @locPermNotDetermined.
  ///
  /// In en, this message translates to:
  /// **'Not asked yet'**
  String get locPermNotDetermined;

  /// No description provided for @locPermRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get locPermRestricted;

  /// No description provided for @locPermDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Location in the background'**
  String get locPermDialogTitle;

  /// No description provided for @locPermDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Taskwise reminds you when you arrive at or leave a place, even when the app is closed. For that, iOS needs to allow location access \"Always\".\n\niOS asks twice: first choose \"Allow While Using App\". Later iOS asks again; then choose \"Change to Always Allow\". If it doesn\'t ask, open Settings → Taskwise → Location and choose \"Always\".\n\nYour location stays on your phone.'**
  String get locPermDialogBody;

  /// No description provided for @locPermDialogBodyAndroid.
  ///
  /// In en, this message translates to:
  /// **'Taskwise reminds you when you arrive at or leave a place, even when the app is closed. For that, Android needs to allow location access \"all the time\".\n\nFirst choose \"While using the app\" and keep \"Precise\" on. Then Android opens Taskwise\'s location settings: choose \"Allow all the time\" and go back.\n\nYour location stays on your phone.'**
  String get locPermDialogBodyAndroid;

  /// No description provided for @locPermAlwaysAndroid.
  ///
  /// In en, this message translates to:
  /// **'All the time'**
  String get locPermAlwaysAndroid;

  /// No description provided for @locBannerNotAlwaysAndroid.
  ///
  /// In en, this message translates to:
  /// **'Location reminders need location access set to \"Allow all the time\".'**
  String get locBannerNotAlwaysAndroid;

  /// No description provided for @locBatteryHint.
  ///
  /// In en, this message translates to:
  /// **'If reminders come late or not at all, set Taskwise\'s battery use to \"Unrestricted\": Settings → Apps → Taskwise → Battery.'**
  String get locBatteryHint;

  /// No description provided for @locPermContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get locPermContinue;

  /// No description provided for @locBannerNotAlways.
  ///
  /// In en, this message translates to:
  /// **'Location reminders need location access set to \"Always\".'**
  String get locBannerNotAlways;

  /// No description provided for @locBannerDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access is off for Taskwise, so location reminders can\'t remind you.'**
  String get locBannerDenied;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @locDebugTitle.
  ///
  /// In en, this message translates to:
  /// **'Location debug'**
  String get locDebugTitle;

  /// No description provided for @locDebugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What the phone watches and what happened'**
  String get locDebugSubtitle;

  /// No description provided for @locDebugEntries.
  ///
  /// In en, this message translates to:
  /// **'Location reminders on this phone: {count}'**
  String locDebugEntries(int count);

  /// No description provided for @locDebugRegions.
  ///
  /// In en, this message translates to:
  /// **'Watched areas'**
  String get locDebugRegions;

  /// No description provided for @locDebugEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent events'**
  String get locDebugEvents;

  /// No description provided for @locDebugNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events yet.'**
  String get locDebugNoEvents;

  /// No description provided for @locDebugPrecise.
  ///
  /// In en, this message translates to:
  /// **'Precise tracking is running'**
  String get locDebugPrecise;

  /// No description provided for @locDebugLastFix.
  ///
  /// In en, this message translates to:
  /// **'Last position: ±{accuracy} m'**
  String locDebugLastFix(int accuracy);

  /// No description provided for @locDebugAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} m away'**
  String locDebugAway(int distance);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @syncBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'Phones also sync in the background now and then (the phone decides when).'**
  String get syncBackgroundHint;

  /// No description provided for @lapisEmptyTasks.
  ///
  /// In en, this message translates to:
  /// **'Type one in the box above and press Enter.'**
  String get lapisEmptyTasks;

  /// No description provided for @lapisEmptyTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get lapisEmptyTasksTitle;

  /// No description provided for @shortcutNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get shortcutNewTask;

  /// No description provided for @shortcutSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get shortcutSearch;

  /// No description provided for @todayLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 left today} other{{count} left today} }'**
  String todayLeft(int count);

  /// No description provided for @todayDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None done yet} other{{count} done} }'**
  String todayDone(int count);

  /// No description provided for @todayAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done for today'**
  String get todayAllDone;

  /// No description provided for @todayProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} tasks for today done'**
  String todayProgressSemantics(int done, int total);

  /// No description provided for @progressSummary.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} completed'**
  String progressSummary(int done, int total);

  /// No description provided for @progressAllDone.
  ///
  /// In en, this message translates to:
  /// **'All tasks completed for today!'**
  String get progressAllDone;

  /// No description provided for @quickAddSubmitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add task (Enter)'**
  String get quickAddSubmitTooltip;

  /// No description provided for @todayOverview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Focus'**
  String get todayOverview;

  /// No description provided for @statOpen.
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String statOpen(int count);

  /// No description provided for @statOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue'**
  String statOverdue(int count);

  /// No description provided for @brutalEmptyTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Your list is empty'**
  String get brutalEmptyTasksTitle;

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @shortcutCloseTask.
  ///
  /// In en, this message translates to:
  /// **'Close the task'**
  String get shortcutCloseTask;

  /// No description provided for @settingsDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get settingsDesign;

  /// No description provided for @designClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get designClassic;

  /// No description provided for @designLapis.
  ///
  /// In en, this message translates to:
  /// **'Lapis'**
  String get designLapis;

  /// No description provided for @designSlate.
  ///
  /// In en, this message translates to:
  /// **'Slate & Indigo'**
  String get designSlate;

  /// No description provided for @designBrutal.
  ///
  /// In en, this message translates to:
  /// **'Brutal'**
  String get designBrutal;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export to a file'**
  String get backupExport;

  /// No description provided for @backupExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save all your tasks in a JSON file'**
  String get backupExportSubtitle;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Import from a file'**
  String get backupImport;

  /// No description provided for @backupImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adds the tasks from a backup. Newer changes on this device are kept.'**
  String get backupImportSubtitle;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved: {path}'**
  String backupSaved(String path);

  /// No description provided for @backupSavedIos.
  ///
  /// In en, this message translates to:
  /// **'Backup saved. Open the Files app → On My iPhone → Taskwise → {name}'**
  String backupSavedIos(String name);

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String fileSaved(String name);

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Import done: {changed} added or updated, {kept} already newer here, {skipped} skipped'**
  String backupImported(int changed, int kept, int skipped);

  /// No description provided for @backupNotABackup.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a Taskwise backup.'**
  String get backupNotABackup;

  /// No description provided for @backupTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup is from a newer Taskwise. Update Taskwise first.'**
  String get backupTooNew;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Details are in Settings → About → View logs.'**
  String get actionFailed;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Taskwise {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutViewLogs.
  ///
  /// In en, this message translates to:
  /// **'View logs'**
  String get aboutViewLogs;

  /// No description provided for @aboutViewLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For finding problems. Logs never contain your tasks.'**
  String get aboutViewLogsSubtitle;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get logsEmpty;

  /// No description provided for @logsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get logsCopy;

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied'**
  String get logsCopied;

  /// No description provided for @logsSave.
  ///
  /// In en, this message translates to:
  /// **'Save to file'**
  String get logsSave;

  /// No description provided for @logsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get logsClear;

  /// No description provided for @logsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logsFilterAll;

  /// No description provided for @logsFilterProblems.
  ///
  /// In en, this message translates to:
  /// **'Problems only'**
  String get logsFilterProblems;
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
    'that was used.',
  );
}

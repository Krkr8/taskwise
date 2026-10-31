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
  /// **'Notifications are off for Taskwise. Turn them on in the iPhone\'s Settings to get reminders.'**
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

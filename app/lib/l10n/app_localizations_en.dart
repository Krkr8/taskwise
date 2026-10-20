// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Taskwise';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navSettings => 'Settings';

  @override
  String get quickAddHint => 'Add a task and press Enter';

  @override
  String get searchHint => 'Search tasks';

  @override
  String get filter => 'Filter';

  @override
  String filterWithCount(int count) {
    return 'Filter ($count active)';
  }

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortDueDate => 'Due date';

  @override
  String get sortPriority => 'Priority';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortCreated => 'Recently added';

  @override
  String get groupOverdue => 'Overdue';

  @override
  String get groupToday => 'Today';

  @override
  String get groupTomorrow => 'Tomorrow';

  @override
  String get groupThisWeek => 'This week';

  @override
  String get groupLater => 'Later';

  @override
  String get groupNoDate => 'No date';

  @override
  String get groupCompleted => 'Completed';

  @override
  String groupHeaderSemantics(String group, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$group, $count tasks. Tap to expand or collapse.',
      one: '$group, 1 task. Tap to expand or collapse.',
    );
    return '$_temp0';
  }

  @override
  String get emptyTasks => 'No tasks yet. Add your first one above.';

  @override
  String get emptyFiltered => 'No tasks match your search or filters.';

  @override
  String get loadError => 'Something went wrong while loading.';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String markDone(String title) {
    return 'Mark \"$title\" as done';
  }

  @override
  String markNotDone(String title) {
    return 'Mark \"$title\" as not done';
  }

  @override
  String subtaskProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get taskDeleted => 'Task deleted';

  @override
  String get undo => 'Undo';

  @override
  String get selectTaskHint => 'Select a task to see its details.';

  @override
  String get taskNotFound => 'This task no longer exists.';

  @override
  String get close => 'Close';

  @override
  String get titleLabel => 'Title';

  @override
  String get notesLabel => 'Notes';

  @override
  String get dueDate => 'Due date';

  @override
  String get noDueDate => 'No due date';

  @override
  String get dueTime => 'Time';

  @override
  String get allDay => 'All day';

  @override
  String get addTime => 'Add time';

  @override
  String get clearDueDate => 'Clear due date';

  @override
  String get clearDueTime => 'Clear time';

  @override
  String get priority => 'Priority';

  @override
  String get priorityNone => 'None';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get category => 'Category';

  @override
  String get noCategory => 'No category';

  @override
  String get tags => 'Tags';

  @override
  String get addTag => 'Add tag';

  @override
  String get tagName => 'Tag name';

  @override
  String removeTag(String name) {
    return 'Remove tag $name';
  }

  @override
  String get subtasks => 'Subtasks';

  @override
  String get addSubtaskHint => 'Add a subtask';

  @override
  String get renameSubtask => 'Rename subtask';

  @override
  String get deleteSubtask => 'Delete subtask';

  @override
  String get reorderSubtask => 'Drag to reorder';

  @override
  String get deleteTask => 'Delete task';

  @override
  String get markTaskDone => 'Mark as done';

  @override
  String get markTaskNotDone => 'Mark as not done';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get settingsDateTime => 'Date & time';

  @override
  String get weekStartsOn => 'Week starts on';

  @override
  String get sunday => 'Sunday';

  @override
  String get saturday => 'Saturday';

  @override
  String get monday => 'Monday';

  @override
  String get timeFormat => 'Time format';

  @override
  String get timeFormat12 => '12-hour';

  @override
  String get timeFormat24 => '24-hour';

  @override
  String get settingsOrganize => 'Organize';

  @override
  String get categories => 'Categories';

  @override
  String get manageCategoriesSubtitle =>
      'Add, rename, recolor or delete categories';

  @override
  String get addCategory => 'Add category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get categoryName => 'Name';

  @override
  String get color => 'Color';

  @override
  String colorOption(int index) {
    return 'Color $index';
  }

  @override
  String get noCategoriesYet => 'No categories yet.';

  @override
  String deleteCategoryTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteCategoryBody =>
      'Tasks in this category will have no category.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';
}

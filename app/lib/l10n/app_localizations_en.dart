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

  @override
  String get repeat => 'Repeat';

  @override
  String get repeatNone => 'Does not repeat';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekdays => 'Every weekday';

  @override
  String repeatWeeklyOn(String day) {
    return 'Weekly on $day';
  }

  @override
  String repeatMonthlyOnDay(int day) {
    return 'Monthly on day $day';
  }

  @override
  String repeatMonthlyOnNth(String nth, String weekday) {
    return 'Monthly on the $nth $weekday';
  }

  @override
  String repeatYearlyOn(String date) {
    return 'Yearly on $date';
  }

  @override
  String get repeatCustom => 'Custom…';

  @override
  String get repeatCustomTitle => 'Custom repeat';

  @override
  String everyNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String everyNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String everyNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String everyNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String repeatOnDays(String base, String days) {
    return '$base on $days';
  }

  @override
  String repeatOnMonthDay(String base, int day) {
    return '$base on day $day';
  }

  @override
  String repeatOnNth(String base, String nth, String weekday) {
    return '$base on the $nth $weekday';
  }

  @override
  String repeatOnDate(String base, String date) {
    return '$base on $date';
  }

  @override
  String repeatUntil(String summary, String date) {
    return '$summary, until $date';
  }

  @override
  String repeatTimes(String summary, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$summary, $count times',
      one: '$summary, once',
    );
    return '$_temp0';
  }

  @override
  String get ordinal1 => 'first';

  @override
  String get ordinal2 => 'second';

  @override
  String get ordinal3 => 'third';

  @override
  String get ordinal4 => 'fourth';

  @override
  String get ordinalLast => 'last';

  @override
  String get repeatEvery => 'Every';

  @override
  String unitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String unitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$_temp0';
  }

  @override
  String unitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$_temp0';
  }

  @override
  String unitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'years',
      one: 'year',
    );
    return '$_temp0';
  }

  @override
  String get repeatOn => 'On';

  @override
  String monthlyByDay(int day) {
    return 'On day $day';
  }

  @override
  String monthlyByNth(String nth, String weekday) {
    return 'On the $nth $weekday';
  }

  @override
  String get repeatEnds => 'Ends';

  @override
  String get endsNever => 'Never';

  @override
  String endsOnDate(String date) {
    return 'On $date';
  }

  @override
  String get endsAfter => 'After';

  @override
  String endsTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'times',
      one: 'time',
    );
    return '$_temp0';
  }

  @override
  String get repeatingTask => 'Repeating task';

  @override
  String doneNextOn(String date) {
    return 'Done. Next: $date';
  }

  @override
  String get doneSeriesEnded => 'Done. That was the last one.';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get calendarWeek => 'Week';

  @override
  String get calendarMonth => 'Month';

  @override
  String get calendarThisMonth => 'This month';

  @override
  String get previousWeek => 'Previous week';

  @override
  String get nextWeek => 'Next week';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get addTask => 'Add task';

  @override
  String addTaskOn(String date) {
    return 'Add a task on $date';
  }

  @override
  String get newTaskHint => 'Task title';

  @override
  String moreTasks(int count) {
    return '+$count';
  }

  @override
  String get noTasksThisDay => 'No tasks on this day.';

  @override
  String upcomingOccurrence(String title) {
    return 'Upcoming repeat of \"$title\"';
  }

  @override
  String get reminders => 'Reminders';

  @override
  String get addReminder => 'Add reminder';

  @override
  String get reminderAtDueTime => 'At due time';

  @override
  String reminderBefore(String duration) {
    return '$duration before';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get reminderCustom => 'Custom date & time…';

  @override
  String get reminderNeedsDueDate =>
      'Set a due date to add reminders before it.';

  @override
  String get removeReminder => 'Remove reminder';

  @override
  String get hasReminders => 'Has reminders';

  @override
  String get notificationsDenied =>
      'Notifications are off for Taskwise. Turn them on in the phone\'s Settings to get reminders.';

  @override
  String get notifDone => 'Done';

  @override
  String notifSnooze(String duration) {
    return 'Snooze $duration';
  }

  @override
  String get notifOpen => 'Open';

  @override
  String get notifChannel => 'Reminders';

  @override
  String notifDue(String when) {
    return 'Due: $when';
  }

  @override
  String notifSnoozed(String when) {
    return 'Snoozed · Due: $when';
  }

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get defaultReminder => 'Default reminder (when a task gets a time)';

  @override
  String get defaultReminderNone => 'None';

  @override
  String get defaultReminderAtDue => 'At due time';

  @override
  String get defaultReminderMin15 => '15 min before';

  @override
  String get snoozeOptions => 'Snooze options (up to 3)';

  @override
  String minutesShort(int count) {
    return '$count min';
  }

  @override
  String get allDayReminderTime => 'All-day tasks remind at';

  @override
  String get settingsBackground => 'Background';

  @override
  String get keepRunning => 'Keep running when the window is closed';

  @override
  String get keepRunningHint =>
      'Reminders only appear while Taskwise is running. Closing the window keeps it in the tray.';

  @override
  String get startOnLogin => 'Start when I log in';

  @override
  String get linuxTrayHint =>
      'On GNOME the tray icon needs the AppIndicator extension. Without it, open Taskwise from the app menu to bring the window back.';

  @override
  String get trayShow => 'Show Taskwise';

  @override
  String get trayQuit => 'Quit Taskwise';

  @override
  String get settingsSync => 'Sync';

  @override
  String get syncNotConnectedHint =>
      'Keep your tasks the same on all your devices through your own Taskwise server.';

  @override
  String get syncConnect => 'Connect to your server';

  @override
  String syncSignedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String syncStatusSynced(String when) {
    return 'Synced $when';
  }

  @override
  String get syncStatusNever => 'Not synced yet';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusOffline =>
      'Offline. Changes will sync when the server can be reached.';

  @override
  String get syncStatusSignedOut =>
      'Signed out. Sign in again to keep syncing.';

  @override
  String syncStatusError(String message) {
    return 'Sync problem: $message';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncSignOut => 'Sign out';

  @override
  String syncSignOutConfirm(String server) {
    return 'Sign out of $server? This device stops syncing. Your tasks stay on it.';
  }

  @override
  String get syncSignInAgain => 'Sign in again';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String get signInTitle => 'Connect to your server';

  @override
  String get signInServer => 'Server address';

  @override
  String get signInServerHint => 'e.g. your-app.vercel.app';

  @override
  String get signInUsername => 'Username';

  @override
  String get signInPassword => 'Password';

  @override
  String get signInDeviceName => 'Name of this device';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signInCreateAccount => 'First time? Create the account';

  @override
  String get signInCreateAccountHelp =>
      'Enter the setup secret you set on the server (SETUP_SECRET). It\'s only needed this once. Choose a password of at least 10 characters.';

  @override
  String get signInSetupSecret => 'Setup secret';

  @override
  String get signInCreateButton => 'Create account and sign in';

  @override
  String get signInHaveAccount => 'I already have an account';

  @override
  String get fieldRequired => 'Required';

  @override
  String get passwordTooShort => 'At least 10 characters';

  @override
  String get signInErrorUnreachable =>
      'Can\'t reach the server. Check the address and your connection.';

  @override
  String get signInErrorBadAddress =>
      'That doesn\'t look like a server address.';

  @override
  String get signInErrorNotTaskwise =>
      'That address answered, but it isn\'t a Taskwise server.';

  @override
  String get signInErrorWrongPassword => 'Wrong username or password.';

  @override
  String signInErrorRateLimited(int minutes) {
    return 'Too many failed tries. Try again in $minutes min.';
  }

  @override
  String get signInErrorWrongSecret => 'Wrong setup secret.';

  @override
  String get signInErrorAccountExists =>
      'The account already exists. Sign in instead.';

  @override
  String get signInErrorSetupDisabled =>
      'Account setup is turned off on the server (SETUP_SECRET isn\'t set).';

  @override
  String signInErrorOther(String message) {
    return 'Something went wrong: $message';
  }

  @override
  String get syncBannerText =>
      'Sync your devices: connect to your Taskwise server.';

  @override
  String get syncBannerConnect => 'Connect';

  @override
  String get syncBannerLater => 'Not now';

  @override
  String get devicesTitle => 'Devices';

  @override
  String get devicesSubtitle => 'Rename or remove your devices';

  @override
  String get deviceThis => 'This device';

  @override
  String deviceLastSeen(String when) {
    return 'Last seen $when';
  }

  @override
  String get deviceRename => 'Rename';

  @override
  String get deviceName => 'Device name';

  @override
  String get deviceRemove => 'Remove';

  @override
  String deviceRemoveConfirm(String name) {
    return 'Remove $name? It stops syncing until it signs in again with your password.';
  }

  @override
  String get deviceActionFailed =>
      'Couldn\'t reach the server. Try again when you\'re online.';

  @override
  String get notifyOn => 'Notify on';

  @override
  String get notifyAllDevices => 'All devices';

  @override
  String get notifyNoDevice =>
      'No device chosen: this task won\'t remind anywhere.';

  @override
  String get notNotifiedHere => 'Doesn\'t remind on this device';

  @override
  String get notifTestButton => 'Send a test notification';

  @override
  String get notifTestBody => 'Notifications work on this device.';

  @override
  String get notifTestDenied =>
      'Notifications are turned off for Taskwise. Turn them on in the system settings.';

  @override
  String get notifTestSent =>
      'Sent. If nothing appeared, check the system\'s notification settings (and Focus / Do Not Disturb).';

  @override
  String get reminderPassed => 'time passed';

  @override
  String get deviceMain => 'Main device';

  @override
  String get devicesMainHint =>
      'The main device manages the others: only it can remove or rename them.';

  @override
  String get deviceMakeMain => 'Make main device';

  @override
  String deviceMakeMainConfirm(String name) {
    return 'Make $name the main device? This device then can\'t remove or rename other devices any more.';
  }

  @override
  String get deviceClaimMain => 'Make this the main device';

  @override
  String get deviceClaimMainHelp =>
      'If the main device is lost, enter your account password to make this one the main device.';

  @override
  String get deviceWrongPassword => 'Wrong password.';

  @override
  String get notifSnoozedNoDate => 'Snoozed';

  @override
  String get reminderAtLocation => 'At a location…';

  @override
  String get locArrive => 'Arrive';

  @override
  String get locLeave => 'Leave';

  @override
  String locChipArrive(String place) {
    return 'Arrive at $place';
  }

  @override
  String locChipLeave(String place) {
    return 'Leave $place';
  }

  @override
  String get locDroppedPin => 'dropped pin';

  @override
  String meters(int meters) {
    return '$meters m';
  }

  @override
  String get locOnlyPhones => 'Only reminds on phones (iPhone and Android)';

  @override
  String get locPickerTitle => 'Location reminder';

  @override
  String get locPlacePickerTitle => 'Choose the place';

  @override
  String get locSearchHint => 'Search for an address or place';

  @override
  String get locSearch => 'Search';

  @override
  String get locSearchNoResults =>
      'Nothing found. Try other words, or tap the map.';

  @override
  String get locSearchFailed =>
      'Search didn\'t work. Check your connection, or tap the map.';

  @override
  String get locTapToDrop => 'Tap the map to put the pin where the place is.';

  @override
  String get locRadius => 'Radius';

  @override
  String get locRemindWhen => 'Remind me when I';

  @override
  String get locSaveAsPlace => 'Save as a place';

  @override
  String get locPlaceName => 'Place name';

  @override
  String get locUseMyLocation => 'Use my location';

  @override
  String get locNoFix => 'Couldn\'t get your location.';

  @override
  String get locNeedPin =>
      'Choose a place first: search, tap the map or pick a saved place.';

  @override
  String locNotifArrived(String place) {
    return 'You\'re at $place';
  }

  @override
  String get locNotifArrivedNoName => 'You\'re at the place for this task';

  @override
  String locNotifLeft(String place) {
    return 'You left $place';
  }

  @override
  String get locNotifLeftNoName => 'You left the place for this task';

  @override
  String get placesTitle => 'Saved places';

  @override
  String get placesSubtitle =>
      'Home, work and other places for location reminders';

  @override
  String get placesEmpty => 'No saved places yet.';

  @override
  String get addPlace => 'Add place';

  @override
  String get editPlace => 'Edit place';

  @override
  String get deletePlaceTitle => 'Delete place?';

  @override
  String deletePlaceBody(String name) {
    return 'Delete \"$name\"? Location reminders that use it keep working.';
  }

  @override
  String get defaultLocationRadius => 'Default radius for location reminders';

  @override
  String get settingsLocation => 'Location reminders';

  @override
  String get locPermissionStatus => 'Location access';

  @override
  String get locPermAlways => 'Always';

  @override
  String get locPermWhenInUse => 'While using the app';

  @override
  String get locPermDenied => 'Off';

  @override
  String get locPermNotDetermined => 'Not asked yet';

  @override
  String get locPermRestricted => 'Restricted';

  @override
  String get locPermDialogTitle => 'Location in the background';

  @override
  String get locPermDialogBody =>
      'Taskwise reminds you when you arrive at or leave a place, even when the app is closed. For that, iOS needs to allow location access \"Always\".\n\niOS asks twice: first choose \"Allow While Using App\". Later iOS asks again; then choose \"Change to Always Allow\". If it doesn\'t ask, open Settings → Taskwise → Location and choose \"Always\".\n\nYour location stays on your phone.';

  @override
  String get locPermDialogBodyAndroid =>
      'Taskwise reminds you when you arrive at or leave a place, even when the app is closed. For that, Android needs to allow location access \"all the time\".\n\nFirst choose \"While using the app\" and keep \"Precise\" on. Then Android opens Taskwise\'s location settings: choose \"Allow all the time\" and go back.\n\nYour location stays on your phone.';

  @override
  String get locPermAlwaysAndroid => 'All the time';

  @override
  String get locBannerNotAlwaysAndroid =>
      'Location reminders need location access set to \"Allow all the time\".';

  @override
  String get locBatteryHint =>
      'If reminders come late or not at all, set Taskwise\'s battery use to \"Unrestricted\": Settings → Apps → Taskwise → Battery.';

  @override
  String get locPermContinue => 'Continue';

  @override
  String get locBannerNotAlways =>
      'Location reminders need location access set to \"Always\".';

  @override
  String get locBannerDenied =>
      'Location access is off for Taskwise, so location reminders can\'t remind you.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get locDebugTitle => 'Location debug';

  @override
  String get locDebugSubtitle => 'What the phone watches and what happened';

  @override
  String locDebugEntries(int count) {
    return 'Location reminders on this phone: $count';
  }

  @override
  String get locDebugRegions => 'Watched areas';

  @override
  String get locDebugEvents => 'Recent events';

  @override
  String get locDebugNoEvents => 'No events yet.';

  @override
  String get locDebugPrecise => 'Precise tracking is running';

  @override
  String locDebugLastFix(int accuracy) {
    return 'Last position: ±$accuracy m';
  }

  @override
  String locDebugAway(int distance) {
    return '$distance m away';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get syncBackgroundHint =>
      'Phones also sync in the background now and then (the phone decides when).';

  @override
  String get lapisEmptyTasks => 'Type one in the box above and press Enter.';

  @override
  String get lapisEmptyTasksTitle => 'No tasks yet';

  @override
  String get shortcutNewTask => 'New task';

  @override
  String get shortcutSearch => 'Search';

  @override
  String todayLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left today',
      one: '1 left today',
    );
    return '$_temp0';
  }

  @override
  String todayDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count done',
      zero: 'None done yet',
    );
    return '$_temp0';
  }

  @override
  String get todayAllDone => 'All done for today';

  @override
  String todayProgressSemantics(int done, int total) {
    return '$done of $total tasks for today done';
  }

  @override
  String progressSummary(int done, int total) {
    return '$done of $total completed';
  }

  @override
  String get progressAllDone => 'All tasks completed for today!';

  @override
  String get quickAddSubmitTooltip => 'Add task (Enter)';

  @override
  String get todayOverview => 'Today\'s Focus';

  @override
  String statOpen(int count) {
    return '$count open';
  }

  @override
  String statOverdue(int count) {
    return '$count overdue';
  }

  @override
  String get brutalEmptyTasksTitle => 'Your list is empty';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutCloseTask => 'Close the task';

  @override
  String get settingsDesign => 'Design';

  @override
  String get designClassic => 'Classic';

  @override
  String get designLapis => 'Lapis';

  @override
  String get designSlate => 'Slate & Indigo';

  @override
  String get designBrutal => 'Brutal';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get backupExport => 'Export to a file';

  @override
  String get backupExportSubtitle => 'Save all your tasks in a JSON file';

  @override
  String get backupImport => 'Import from a file';

  @override
  String get backupImportSubtitle =>
      'Adds the tasks from a backup. Newer changes on this device are kept.';

  @override
  String backupSaved(String path) {
    return 'Backup saved: $path';
  }

  @override
  String backupSavedIos(String name) {
    return 'Backup saved. Open the Files app → On My iPhone → Taskwise → $name';
  }

  @override
  String fileSaved(String name) {
    return 'Saved $name';
  }

  @override
  String backupImported(int changed, int kept, int skipped) {
    return 'Import done: $changed added or updated, $kept already newer here, $skipped skipped';
  }

  @override
  String get backupNotABackup => 'This file isn\'t a Taskwise backup.';

  @override
  String get backupTooNew =>
      'This backup is from a newer Taskwise. Update Taskwise first.';

  @override
  String get actionFailed =>
      'Something went wrong. Details are in Settings → About → View logs.';

  @override
  String get settingsAbout => 'About';

  @override
  String aboutVersion(String version) {
    return 'Taskwise $version';
  }

  @override
  String get aboutViewLogs => 'View logs';

  @override
  String get aboutViewLogsSubtitle =>
      'For finding problems. Logs never contain your tasks.';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsEmpty => 'Nothing logged yet.';

  @override
  String get logsCopy => 'Copy all';

  @override
  String get logsCopied => 'Logs copied';

  @override
  String get logsSave => 'Save to file';

  @override
  String get logsClear => 'Clear';

  @override
  String get logsFilterAll => 'All';

  @override
  String get logsFilterProblems => 'Problems only';
}

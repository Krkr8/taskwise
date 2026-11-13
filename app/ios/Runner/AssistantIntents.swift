import AppIntents
import Foundation

// Siri and Shortcuts commands (App Intents). They run in the background,
// without opening Taskwise (the default `supportedModes`): adding writes to Siri's inbox (AssistantStore.swift), which the
// app moves into its database the next time it runs or syncs in the
// background; "what's due" reads the app's snapshot.
//
// Apple requires the app's name in every phrase, and a free-text title can't
// be part of the phrase, so Siri asks for it ("What's the task?").
// Arabic phrases: ar.lproj/AppShortcuts.strings; Arabic dialogs:
// ar.lproj/Localizable.strings.

@available(iOS 17.0, *)
struct AddTaskIntent: AppIntent {
  static let title: LocalizedStringResource = "Add a task"
  static let description: IntentDescription? = IntentDescription("Adds a task to Taskwise.")

  @Parameter(title: "Task", requestValueDialog: IntentDialog("What's the task?"))
  var taskTitle: String

  static var parameterSummary: some ParameterSummary {
    Summary("Add \(\.$taskTitle) to Taskwise")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let entry = try AssistantIntentError.wrap {
      try AssistantStore.shared.add(title: taskTitle)
    }
    return .result(dialog: IntentDialog("Added \(entry.title) to Taskwise."))
  }
}

@available(iOS 17.0, *)
struct AddDatedTaskIntent: AppIntent {
  static let title: LocalizedStringResource = "Add a task with a due date"
  static let description: IntentDescription? = IntentDescription(
    "Adds a task with a due date (and a time, if you say one) to Taskwise.")

  @Parameter(title: "Task", requestValueDialog: IntentDialog("What's the task?"))
  var taskTitle: String

  @Parameter(
    title: "Due", kind: .dateTime, requestValueDialog: IntentDialog("When is it due?"))
  var due: DateComponents

  static var parameterSummary: some ParameterSummary {
    Summary("Add \(\.$taskTitle) due \(\.$due) to Taskwise")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    // A date without a time is all-day.
    let entry = try AssistantIntentError.wrap {
      try AssistantStore.shared.add(title: taskTitle, due: AssistantStore.due(from: due))
    }
    return .result(dialog: IntentDialog("Added \(entry.title) to Taskwise."))
  }
}

@available(iOS 17.0, *)
struct DueTodayIntent: AppIntent {
  static let title: LocalizedStringResource = "What's due today"
  static let description: IntentDescription? = IntentDescription(
    "Reads out the Taskwise tasks due today and the overdue ones.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let agenda = AssistantStore.shared.agenda(today: Date(), calendar: .current)
    return .result(dialog: IntentDialog(stringLiteral: Self.speech(agenda)))
  }

  /// Read at most this many titles of each list.
  private static let maxTitles = 5

  static func speech(_ agenda: AssistantAgenda) -> String {
    if agenda.today.isEmpty && agenda.overdue.isEmpty {
      return String(localized: "Nothing is due today.")
    }
    var parts: [String] = []
    if agenda.today.isEmpty {
      parts.append(String(localized: "Nothing is due today."))
    } else {
      parts.append(
        String(format: String(localized: "Today: %@."), list(agenda.today)))
    }
    if !agenda.overdue.isEmpty {
      parts.append(
        String(format: String(localized: "Overdue: %@."), list(agenda.overdue)))
    }
    return parts.joined(separator: " ")
  }

  /// "A, B and C", or "A, B, C, D, E and 3 more".
  private static func list(_ titles: [String]) -> String {
    var items = Array(titles.prefix(maxTitles))
    if titles.count > maxTitles {
      items.append(
        String(format: String(localized: "%lld more"), titles.count - maxTitles))
    }
    return ListFormatter.localizedString(byJoining: items)
  }
}

@available(iOS 17.0, *)
enum AssistantIntentError: Error, CustomLocalizedStringResourceConvertible {
  case emptyTitle
  case failed

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .emptyTitle: return "The task needs a name."
    case .failed: return "Taskwise couldn't save the task. Please try again."
    }
  }

  /// Runs [body] and turns store errors into messages Siri can say.
  static func wrap<T>(_ body: () throws -> T) throws -> T {
    do {
      return try body()
    } catch AssistantStoreError.emptyTitle {
      throw AssistantIntentError.emptyTitle
    } catch {
      throw AssistantIntentError.failed
    }
  }
}

/// The phrases Siri knows without any setup. Each must contain the app name.
@available(iOS 17.0, *)
struct TaskwiseShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddTaskIntent(),
      phrases: [
        "Add a task in \(.applicationName)",
        "Add a task to \(.applicationName)",
        "New task in \(.applicationName)",
        "New \(.applicationName) task",
      ],
      shortTitle: "Add a task",
      systemImageName: "plus.circle")
    AppShortcut(
      intent: AddDatedTaskIntent(),
      phrases: [
        "Add a task with a date in \(.applicationName)",
        "Add a task with a due date in \(.applicationName)",
        "Add a dated task to \(.applicationName)",
      ],
      shortTitle: "Add a task with a date",
      systemImageName: "calendar.badge.plus")
    AppShortcut(
      intent: DueTodayIntent(),
      phrases: [
        "What's on my list in \(.applicationName)",
        "What's due today in \(.applicationName)",
        "What do I have today in \(.applicationName)",
        "Read my \(.applicationName) tasks",
      ],
      shortTitle: "What's due today",
      systemImageName: "checklist")
  }
}

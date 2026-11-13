package io.github.krkr8.taskwise_android

/**
 * Turns the intents Taskwise is started with into actions for Dart's
 * `taskwise/assistant` channel (app/lib/assistant/assistant_platform.dart):
 * - the "New task" shortcut (long-press the app icon, res/xml/shortcuts.xml
 *   in the app) → `{type: newTask}`;
 * - text shared from another app (ACTION_SEND, text/plain) →
 *   `{type: share, text}`. A subject (e.g. a page title shared with its
 *   link) becomes the first line, so it is the task's title.
 *
 * Plain values in, so it is tested without Android (AssistantIntentsTest).
 */
object AssistantIntents {
  const val NEW_TASK = "io.github.krkr8.taskwise.NEW_TASK"
  const val ACTION_SEND = "android.intent.action.SEND"

  /** Set on an intent once handled, so a recreated activity doesn't repeat it. */
  const val HANDLED_EXTRA = "io.github.krkr8.taskwise.HANDLED"

  fun action(
    action: String?,
    mimeType: String?,
    text: CharSequence?,
    subject: CharSequence?,
  ): Map<String, Any>? = when {
    action == NEW_TASK -> mapOf("type" to "newTask")
    action == ACTION_SEND && mimeType?.startsWith("text/") == true -> {
      val body = text?.toString()?.trim().orEmpty()
      val title = subject?.toString()?.trim().orEmpty()
      val shared = when {
        title.isEmpty() -> body
        body.isEmpty() || body.startsWith(title) -> body.ifEmpty { title }
        else -> "$title\n$body"
      }
      if (shared.isBlank()) null else mapOf("type" to "share", "text" to shared)
    }
    else -> null
  }
}

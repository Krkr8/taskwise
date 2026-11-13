# Siri, shortcuts and sharing

Taskwise can take tasks from outside the app: Siri on the iPhone, and on Android the long-press shortcut and the share sheet.

## Siri (iPhone)

Say one of these. Every phrase has to contain "Taskwise"; Apple requires the app's name.

| Say | What happens |
|---|---|
| "Add a task in Taskwise" (or "New Taskwise task") | Siri asks "What's the task?", then adds it with no due date. |
| "Add a task with a date in Taskwise" | Siri asks for the task, then "When is it due?". Say a day ("tomorrow", "next Monday") for an all-day task, or a day and a time ("Friday at 5 pm") for a timed one. Timed tasks get your default reminder (Settings → Notifications). |
| "What's on my list in Taskwise" (or "What's due today in Taskwise") | Siri reads the tasks due today and the overdue ones, up to 5 of each. |

In Arabic (when Siri speaks Arabic): «أضف مهمة في Taskwise», «أضف مهمة بتاريخ في Taskwise» and «ما هي مهامي في Taskwise».

You can't say the task's name in the first sentence ("Add buy milk to Taskwise"). Apple doesn't allow free text inside these phrases, so Siri always asks for it.

### How it works

Siri runs these commands **without opening Taskwise**:
- A task Siri adds waits in a small inbox on the phone. Taskwise moves it into your list as soon as it runs: when you open it, or when iOS lets it sync in the background. If Taskwise is open at the time, the task appears right away. Until then, other devices don't have it yet.
- For "What's on my list", Taskwise keeps a short list of the open tasks due in the next week for Siri, refreshed whenever your tasks change. Siri checks it against today's date when you ask, and adds the tasks it took itself.

The code: `app/ios/Runner/AssistantIntents.swift` (the commands and phrases), `AssistantStore.swift` (inbox and list, tested on Linux with `tools/geofence_sim/run.sh test`), `AssistantPlugin.swift`, and on the Dart side `app/lib/assistant/`.

### If Siri doesn't know the commands

1. Open Taskwise once after installing or updating it. iOS reads the commands from the app.
2. Open the **Shortcuts** app → **Taskwise** (under "Shortcuts from your apps"). Tap **ⓘ** and check that **Siri** is on.
3. Try the command from Shortcuts first (tap it). If that works but Siri doesn't, Siri may not have learnt the phrase yet: wait a few minutes, or say it exactly as written above.
4. Settings → Apps → Taskwise → **Siri**: "Learn from this App" and "Use with Ask Siri" should be on.

## Android

- **New task:** long-press the Taskwise icon and tap **New task** (or drag it to the home screen). Taskwise opens on Tasks with the quick-add field ready.
- **Share to Taskwise:** in any app, tap Share and choose **Taskwise**. The shared text becomes a task: the first line, or the page title when a browser shares a link, is the title, and the rest goes into the notes. A message says "Added …", with **Open** to show it.

The code: `app/packages/taskwise_android/.../AssistantIntents.kt` and `TaskwiseAndroidPlugin.kt`, `app/android/app/src/main/res/xml/shortcuts.xml`, and `app/lib/ui/shared/assistant/`.

### Gemini

Gemini can't add tasks to Taskwise yet. Google lets assistants use other apps through **AppFunctions** (Android 16 and newer), but as of November 2026 Gemini only calls them for apps in a closed preview, and Google's new Connected Apps platform is opening slowly, by sign-up. When Google opens it, Taskwise can offer the same commands to Gemini.

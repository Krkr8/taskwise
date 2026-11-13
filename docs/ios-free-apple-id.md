# What works with a free Apple ID (sideloaded)

SideStore signs Taskwise with a **free** Apple ID. Free signing can grant **Info.plist features**: anything enabled by an Info.plist key needs no entitlement, so signing can't block it. It can't grant some **entitlement-based capabilities**.

Apple's table of capabilities by account type: [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios). Look at the **Apple Developer** column, which is the free tier: "No cost is associated with this agreement and developers can't distribute apps."

| Feature Taskwise uses | How it's enabled | Free Apple ID | Confirmed on the iPhone |
|---|---|---|---|
| App installs and runs | — | ✅ works (7-day signing; installed and refreshed with iloader while SideStore sign-in is broken) | ✅ M2 (2026-10-30) |
| **Local notifications** (reminders) | Runtime permission prompt, no entitlement | ✅ expected to work | M4 |
| **Background location / geofencing** (location reminders) | `UIBackgroundModes: location` + location usage texts in Info.plist; "Always" permission prompt | ✅ expected to work | M7 |
| **Background refresh** (sync while closed) | `UIBackgroundModes: fetch` in Info.plist | ✅ expected to work | M6 |
| **Siri and Shortcuts** (App Intents: "Add a task in Taskwise") | App Intents code in the app; no Siri entitlement (that one is only for the old SiriKit intents) | ✅ expected to work | M11 |
| Keychain (storing the sync token) | Default access-group entitlement, which every signed app gets | ✅ expected to work | M6 |
| **Push notifications (APNs)** | `aps-environment` entitlement | ❌ needs the paid program. **Taskwise doesn't use it**: every phone notification is a local notification the app schedules itself. | n/a |
| iCloud, App Groups, Associated Domains, Sign in with Apple | Entitlements | ❌ or limited. **Not used by Taskwise.** | n/a |

Taskwise's iOS project has **no entitlements file**. Everything it needs is an Info.plist key or a runtime permission, so free signing doesn't strip anything.

## Limits that come with free signing

- **7-day expiry:** apps must be refreshed weekly (with iloader over USB for now, or SideStore once its sign-in works; see [install-ios-sidestore.md](install-ios-sidestore.md)).
- **3 apps at once** (SideStore included) and **10 App IDs per week**.
- A paid Apple Developer Program membership ($99/year) removes these limits and gives 1-year signing. It's optional.
- **Sign-in can break without warning:** free sideloaders sign in to Apple with a device identity ("anisette") that Apple can reject at any time. In October 2026, Apple's changes broke SideStore sign-in with -80045 and -80046 until a workaround was found (see Troubleshooting in [install-ios-sidestore.md](install-ios-sidestore.md)). If this keeps happening, the reliable fallback is the paid program with **TestFlight**. TestFlight needs the paid account; a free Apple ID can't use it.

"Expected to work" means it follows from how the feature is enabled, but hasn't been tested on an iPhone yet. Each row is updated to ✅ confirmed in the milestone listed.

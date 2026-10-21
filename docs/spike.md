# Phase 0 spike: WKWebView feasibility

Goal: confirm that Messenger works in a native `WKWebView` wrapper before building the rest.

## Run

```bash
scripts/build.sh
open build/Messenger.app
```

Watch the app's logs in a second terminal:

```bash
/usr/bin/log stream --level debug --style compact --predicate 'subsystem == "pl.paksonite.messenger"'
```

The `js:` lines come from the page scripts in `Resources/Scripts/` (originally a single `notification-shim.js`) and show which notification APIs Messenger calls.

## Checklist

| # | Check | How | Result |
|---|-------|-----|--------|
| 1 | Page loads without an "unsupported browser" notice | Launch the app | ✅ No browser warning |
| 2 | Login works, including 2FA and checkpoints | Log in | ✅ Login incl. Facebook checkpoint |
| 3 | End-to-end encrypted chats open (PIN / restore) | Open a private chat | |
| 4 | Session survives a restart | ⌘Q, relaunch | ✅ |
| 5 | Notification API used by Messenger | Look for `Notification.requestPermission`, `permissions.query` or `ServiceWorkerRegistration.showNotification` in the log | ⚠️ None: no Web Push in WKWebView (`PushManager` missing), only `permissions.query`. See findings |
| 6 | Native notification shows while the window is hidden | ⌘W, send yourself a message from another device | ✅ ~0.5 s after the message, sender + text + avatar |
| 7 | Clicking the notification opens the right chat | Click the banner | ✅ Opens the conversation |
| 8 | Notifications keep arriving after 10+ minutes hidden | ⌘W, wait, send a message | |
| 9 | Dock badge shows the unread count | Leave messages unread | ✅ |
| 10 | Links open in the default browser | Click a link in a chat | ✅ |
| 11 | Audio/video call works (popup window, camera, mic) | Start a call | |
| 12 | File upload and download | Send and save an attachment | ✅ Sending works (after the SharedWorker fix in 0.3.3) |
| 13 | Memory vs. the old app and Safari | Activity Monitor: Messenger + its WebContent process | |

## Findings (2026-10-21)

- Messenger never calls the Notification API in WKWebView: there is no Web Push (`PushManager`), and messenger.com only shows desktop notifications through push. It only checks `navigator.permissions.query({name: "notifications"})`.
- It does play a sound (`.ogg` from fbcdn.net) for every incoming message. The shim uses that as the trigger and reads the newest row of the chat list for sender, text, avatar and thread id. Emoji in names are images, so the row is read from a clone with emoji images replaced by their alt text.
- Rows contain presence ("Aktywny teraz") and screen reader labels ("Nieprzeczytana wiadomość:"); `MessagePreview` strips them.
- Messenger alternates the title between the count ("(1) Messenger") or plain "Messenger" and "X napisał(a) do Ciebie" every ~1.5 s, and may mark a message read while its chat is open in the hidden window. The badge therefore stays at ≥1 while the title flashes.
- Several copies of the app with the same bundle ID (`build/`, DerivedData) ran at once and doubled every sound and notification; the app now allows only one instance.

## Notes

- Closing the window (⌘W) only hides it so the page stays connected; ⌘Q quits.
- The Web Inspector is enabled in Debug builds. For Release: `defaults write pl.paksonite.messenger WebInspectorEnabled -bool true`, then Safari → Develop → Messenger.
- The app is ad-hoc signed for now, so camera and microphone permissions may be asked again after each rebuild. Phase 4 switches to a stable self-signed certificate.

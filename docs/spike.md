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

The `js:` lines come from `Resources/Scripts/notification-shim.js` and show which notification APIs Messenger calls.

## Checklist

| # | Check | How | Result |
|---|-------|-----|--------|
| 1 | Page loads without an "unsupported browser" notice | Launch the app | |
| 2 | Login works, including 2FA and checkpoints | Log in | |
| 3 | End-to-end encrypted chats open (PIN / restore) | Open a private chat | |
| 4 | Session survives a restart | ⌘Q, relaunch | |
| 5 | Notification API used by Messenger | Look for `Notification.requestPermission`, `permissions.query` or `ServiceWorkerRegistration.showNotification` in the log | |
| 6 | Native notification shows while the window is hidden | ⌘W, send yourself a message from another device | |
| 7 | Clicking the notification opens the right chat | Click the banner | |
| 8 | Notifications keep arriving after 10+ minutes hidden | ⌘W, wait, send a message | |
| 9 | Dock badge shows the unread count | Leave messages unread | |
| 10 | Links open in the default browser | Click a link in a chat | |
| 11 | Audio/video call works (popup window, camera, mic) | Start a call | |
| 12 | File upload and download | Send and save an attachment | |
| 13 | Memory vs. the old app and Safari | Activity Monitor: Messenger + its WebContent process | |

## Notes

- Closing the window (⌘W) only hides it so the page stays connected; ⌘Q quits.
- The Web Inspector is enabled in Debug builds. For Release: `defaults write pl.paksonite.messenger WebInspectorEnabled -bool true`, then Safari → Develop → Messenger.
- The app is ad-hoc signed for now, so camera and microphone permissions may be asked again after each rebuild. Phase 4 switches to a stable self-signed certificate.

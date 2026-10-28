# Maintenance

The app depends on how messenger.com behaves and how its page is built. Meta changes both without notice, so most breakage will show up as one feature quietly stopping. This page lists where each feature hooks into the page and how to find out what changed.

## Seeing what the page does

```bash
defaults write pl.paksonite.messenger VerboseLogging -bool true    # then restart the app
/usr/bin/log stream --level info --style compact --predicate 'subsystem == "pl.paksonite.messenger"'
defaults delete pl.paksonite.messenger VerboseLogging              # when done: it logs message text
```

With verbose logging the page scripts log every sound Messenger plays, the chat row they read for a notification, visibility changes, worker creation and the labels of visible buttons when ⌘N finds none. Page titles are logged in clear text.

For the Web Inspector: `defaults write pl.paksonite.messenger WebInspectorEnabled -bool true`, restart, then Safari → Develop → *your Mac* → Messenger.

## Where each feature hooks into the page

| Feature | Depends on | Code | Symptom when it breaks |
|---|---|---|---|
| Notifications | Messenger playing an audio file from `fbcdn.net` for each incoming message | `incoming-messages.js` | No notifications; the fallback ("New message" from the title) may still appear |
| Notification sender/text | Chat list rows: links to `/t/<id>` with an avatar and 2+ text lines | `chat-list.js`, `text-rules.js` | Wrong sender or text, or "New message" only |
| Reading the row text | Polish/English labels such as "Aktywny teraz", "Nieprzeczytana wiadomość:", times like "2 min" | `text-rules.js` | Status or labels show up as sender/text |
| Dock badge | Page title `(n) Messenger` and the flashing "X napisał(a) do Ciebie" | `BadgeController.swift` | Badge missing or flickering |
| ⌘1–⌘9 | Same chat list rows | `shortcuts.js` | Opens nothing or the wrong chat |
| ⌘N | A visible element whose `aria-label` starts with "New message" / "Nowa wiadomość" | `shortcuts.js` | URL changes to `/new/` but the compose view doesn't open |
| ⌘F | A visible `input[type=search]` or `input[role=combobox]` | `shortcuts.js` | Nothing focused |
| Realtime connection | Messenger falling back from `SharedWorker` to dedicated workers | `workarounds.js` | Messages stuck at "Sending…" after a while |
| Idle audio | Messenger playing its sounds through `AudioContext` source nodes (`AudioBufferSourceNode.start`) | `workarounds.js` | Audio monitors show Messenger playing sound all the time again, or a sound is cut off/missing after a quiet period |
| No "Now Playing" entry | Message sounds as `<audio>` from `static.*.fbcdn.net`, downloadable with CORS from messenger.com | `sounds.js` | Now Playing widgets and menu bar audio indicators show Messenger permanently; the log says "sound through Web Audio failed" |
| Page doesn't scroll | Messenger's app scrolling only inside its panels; chat list rows present | `layout.js` | Top of the chat list cut off with an empty band at the bottom; the log says "page scrolled to …, resetting" with the focused element |
| Last chat at launch | Conversation URLs `/t/<id>` and `/e2ee/t/<id>` | `NavigationPolicy.swift` | Opens the start page |

When something breaks: turn on verbose logging, reproduce it, compare the logged rows, labels or titles with the patterns above, and add a test to `Tests/js/text-rules.test.mjs` (row text) or the Swift tests before changing the pattern.

## Known Messenger issues

- **A chat that ends with a reaction comes back unread** after reopening Messenger, while it shows as read on the phone. The same happens on messenger.com in Safari, so it is Messenger's web client, not the app. Workaround: "…" → "Mark as read".
- **No Web Push in WKWebView.** Messenger never calls the Notification API in the app; notifications come from the message sound and the chat list instead (see `docs/spike.md`).
- **The page uses 500–750 MB of memory** after a few hours, almost all of it Messenger's own code.

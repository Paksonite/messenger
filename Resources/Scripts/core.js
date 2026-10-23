// Shared helpers for the page scripts. WebViewConfigurationFactory joins core.js and the other
// scripts, in a fixed order, into one function injected at document start into every frame, so
// they share these names without exposing them to the page. Messages go to NotificationBridge.swift,
// which accepts them only from Messenger's main frame.

const handler = window.webkit?.messageHandlers?.messengerBridge;
const post = (message) => {
  try {
    handler?.postMessage(message);
  } catch (_) {}
};
const log = (message) => post({ type: "log", message: String(message) });

const diagnostics = window.__messengerDiagnostics === true;
const frame = window === window.top ? "main" : "subframe";
const caller = () => (new Error().stack ?? "").split("\n")[2]?.trim().slice(0, 160) ?? "?";

const timing = {
  // After Messenger's message sound, how long the chat list takes to show the change.
  rowUpdateDelay: 400,
  // A second look if no row had changed yet.
  rowRetryDelay: 800,
  // How often the chat list snapshot is refreshed while nothing arrives.
  snapshotInterval: 30000,
  // How long an AudioContext may stay running without any sound before it is suspended.
  audioIdleSuspend: 3000,
};

// Click targets for delivered notifications, by notification id.
const live = new Map();
let sequence = 0;
const nextId = () => `n-${Date.now()}-${++sequence}`;

const absolute = (url) => {
  try {
    return url ? new URL(url, location.href).href : "";
  } catch (_) {
    return "";
  }
};

const isVisible = (element) => {
  const rect = element.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0;
};

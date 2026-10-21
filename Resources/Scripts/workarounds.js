// Messenger keeps its realtime connection in a SharedWorker when one is available. WKWebView runs
// shared workers in a separate process that macOS may kill under memory pressure, and WebKit does not
// restart it: the page then silently stops sending and receiving ("Sending…" forever). Without
// SharedWorker, Messenger keeps the connection in the page, whose process the app reloads if it dies.
if ("SharedWorker" in window) {
  delete window.SharedWorker;
  if ("SharedWorker" in window) {
    Object.defineProperty(window, "SharedWorker", { value: undefined, configurable: true, writable: true });
  }
}

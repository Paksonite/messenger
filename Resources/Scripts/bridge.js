// What the native side calls with evaluateJavaScript: notification clicks and keyboard shortcuts.

Object.defineProperty(window, "__messengerBridge", {
  value: Object.freeze({
    click(id) {
      const target = live.get(id);
      if (!target) return false;
      target.__fire("click");
      return true;
    },
    ...shortcuts,
  }),
});

if (frame === "main" || diagnostics) log(`page scripts installed (${frame}) on ${location.host}${location.pathname}`);

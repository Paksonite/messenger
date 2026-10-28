// Messenger fills the window and scrolls only inside its panels (chat list, conversation). In the app
// the page itself sometimes ended up scrolled by ~120 px, cutting off the top of the chat list and
// leaving an empty band at the bottom. On messenger.com the page's own overscroll bounce is turned off,
// and while the chat list is on screen any scroll of the page itself is reset. Each reset is logged
// with the focused element, to find out what scrolled it.

if (frame === "main" && /(^|\.)messenger\.com$/.test(location.hostname)) {
  const noBounce = document.createElement("style");
  noBounce.textContent = "html, body { overscroll-behavior: none !important; }";
  (document.head || document.documentElement).append(noBounce);

  let loggedResets = 0;
  window.addEventListener(
    "scroll",
    () => {
      if (window.scrollX === 0 && window.scrollY === 0) return;
      if (conversationRows().length === 0) return;
      if (loggedResets < 5) {
        loggedResets += 1;
        const focused = document.activeElement;
        const focus = focused ? `${focused.tagName.toLowerCase()}${focused.getAttribute("role") ? `[role=${focused.getAttribute("role")}]` : ""}` : "none";
        log(`page scrolled to ${Math.round(window.scrollX)},${Math.round(window.scrollY)} (focus: ${focus}), resetting`);
      }
      window.scrollTo(0, 0);
    },
    { passive: true }
  );
}

// Keyboard shortcut actions called from the native menu; each returns a short result for the log.

const newMessageLabel = /^(new message|nowa wiadomość|compose|utwórz (nową )?wiadomość|napisz wiadomość)/i;

const shortcuts = {
  openChat(index) {
    const row = conversationRows()[index - 1];
    if (!row) return `no chat ${index}`;
    row.link.click();
    return `opened chat ${index}`;
  },

  newMessage() {
    const button = [...document.querySelectorAll("[aria-label]")].find(
      (element) => isVisible(element) && newMessageLabel.test(element.getAttribute("aria-label").trim())
    );
    if (button) {
      button.click();
      return `clicked "${button.getAttribute("aria-label")}"`;
    }
    const link = [...document.querySelectorAll('a[href*="/new"]')].find(isVisible);
    if (link) {
      link.click();
      return "clicked new message link";
    }
    if (diagnostics) {
      const labels = [...document.querySelectorAll('[role="button"][aria-label], a[aria-label]')]
        .filter(isVisible)
        .map((element) => element.getAttribute("aria-label"))
        .slice(0, 40);
      log(`newMessage candidates: ${labels.join(" | ")}`);
    }
    // In-page navigation instead of loading /new/, which reloads the whole app.
    history.pushState(null, "", "/new/");
    dispatchEvent(new PopStateEvent("popstate", { state: null }));
    return "pushState /new/";
  },

  focusSearch() {
    const input = [...document.querySelectorAll('input[type="search"], input[role="combobox"]')].find(isVisible);
    if (!input) return "no search field";
    input.focus();
    input.select?.();
    return "focused search";
  },
};

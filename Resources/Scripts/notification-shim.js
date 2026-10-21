// Bridges the web Notification API to native macOS notifications.
// Injected at document start into every frame; talks to NotificationBridge.swift.
(() => {
  "use strict";
  if (window.__messengerBridge) return;

  const handler = window.webkit?.messageHandlers?.messengerBridge;
  const post = (message) => {
    try {
      handler?.postMessage(message);
    } catch (_) {}
  };
  const log = (message) => post({ type: "log", message: String(message) });

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

  const deliver = (id, title, options, source) =>
    post({
      type: "notification",
      id,
      source,
      title: String(title ?? ""),
      body: String(options?.body ?? ""),
      tag: String(options?.tag ?? ""),
      icon: absolute(options?.icon || options?.image),
      silent: Boolean(options?.silent),
    });

  class BridgedNotification extends EventTarget {
    constructor(title, options = {}) {
      super();
      this.title = String(title ?? "");
      this.body = String(options.body ?? "");
      this.tag = String(options.tag ?? "");
      this.icon = absolute(options.icon);
      this.data = options.data ?? null;
      this.silent = Boolean(options.silent);
      this.onclick = null;
      this.onclose = null;
      this.onshow = null;
      this.onerror = null;
      this.__id = nextId();
      live.set(this.__id, this);
      deliver(this.__id, this.title, options, "window");
      setTimeout(() => this.__fire("show"), 0);
    }

    static get permission() {
      return "granted";
    }

    static requestPermission(callback) {
      log("Notification.requestPermission");
      if (typeof callback === "function") callback("granted");
      return Promise.resolve("granted");
    }

    static get maxActions() {
      return 0;
    }

    close() {
      if (!live.delete(this.__id)) return;
      post({ type: "notification-close", id: this.__id });
      this.__fire("close");
    }

    __fire(name) {
      const event = new Event(name, { cancelable: true });
      const listener = this[`on${name}`];
      if (typeof listener === "function") listener.call(this, event);
      this.dispatchEvent(event);
    }
  }

  const diagnostics = window.__messengerDiagnostics === true;
  const frame = window === window.top ? "main" : "subframe";
  const caller = () => (new Error().stack ?? "").split("\n")[2]?.trim().slice(0, 160) ?? "?";

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
  if (diagnostics && window.Worker) {
    const NativeWorker = window.Worker;
    window.Worker = new Proxy(NativeWorker, {
      construct(target, args) {
        log(`new Worker ${String(args[0]).slice(0, 120)}`);
        return Reflect.construct(target, args);
      },
    });
  }

  let notificationReads = 0;
  Object.defineProperty(window, "Notification", {
    configurable: true,
    get() {
      if (diagnostics && ++notificationReads <= 5) log(`window.Notification read #${notificationReads} at ${caller()}`);
      return BridgedNotification;
    },
    set() {
      log("page tried to replace window.Notification");
    },
  });

  // Incoming messages. Without Web Push, Messenger never calls the Notification API in WKWebView,
  // but it plays a sound for every incoming message: use that as the trigger and read the newest
  // row of the chat list (sender, text, avatar).
  const threadLinks = () =>
    [...document.querySelectorAll('a[href*="/t/"]')].filter((link) => {
      const rect = link.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0 && rect.left < window.innerWidth / 2;
    });

  // Text lines of a row with emoji images (e.g. in names) replaced by their alt text. Works on an
  // invisible clone so Messenger's own DOM is never touched; the clone keeps the row's CSS, so
  // innerText still splits lines the way they are displayed.
  const rowLines = (link) => {
    const clone = link.cloneNode(true);
    clone.querySelectorAll("img[alt]").forEach((img) => {
      if (img.alt && img.alt.length <= 8) img.replaceWith(img.alt);
    });
    const holder = document.createElement("div");
    holder.style.cssText =
      `position:fixed;left:-10000px;top:0;width:${link.getBoundingClientRect().width}px;opacity:0;pointer-events:none`;
    holder.append(clone);
    document.body.append(holder);
    const text = clone.innerText;
    holder.remove();
    return text.split("\n").map((line) => line.trim()).filter(Boolean).slice(0, 8);
  };

  // Conversation rows link to /t/<thread id> and show an avatar plus at least a name and a preview line;
  // this skips headers such as "Chats · 3 unread" that also link to /t/.
  const conversationRows = () =>
    threadLinks()
      .map((link) => ({
        link,
        top: link.getBoundingClientRect().top,
        threadId: link.getAttribute("href").match(/\/t\/([^/?#]+)/)?.[1] ?? "",
        lines: link.innerText.split("\n").map((line) => line.trim()).filter(Boolean).slice(0, 8),
        image: link.querySelector("img, image"),
      }))
      .filter((row) => row.threadId && row.lines.length >= 2 && row.image)
      .sort((a, b) => a.top - b.top);

  const isVisible = (element) => {
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };

  // Keyboard shortcut actions called from the native menu; each returns a short result for the log.
  const shortcuts = {
    openChat(index) {
      const row = conversationRows()[index - 1];
      if (!row) return `no chat ${index}`;
      row.link.click();
      return `opened chat ${index}`;
    },
    newMessage() {
      const label = /^(new message|nowa wiadomość|compose|utwórz (nową )?wiadomość|napisz wiadomość)/i;
      const button = [...document.querySelectorAll("[aria-label]")].find(
        (element) => isVisible(element) && label.test(element.getAttribute("aria-label").trim())
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

  const openThread = (href) => {
    const path = new URL(href, location.href).pathname;
    const link = [...document.querySelectorAll('a[href*="/t/"]')].find((a) => new URL(a.href).pathname === path);
    if (link) link.click();
    else location.assign(href);
  };

  // A new message moves its chat to the top, but a reaction only updates the row in place. So the
  // notification is built from the row whose text changed since the last snapshot, falling back to
  // the top row. Times ("2 min") and presence ("Aktywny teraz") are ignored when comparing.
  const comparableText = (row) =>
    row.lines
      .map((line) => line.replace(/\s+·\s+[^·]{1,12}$/, ""))
      .filter((line) => !/^(·|\d+\s?\p{L}{1,6}\.?|now|just now|teraz|active now|aktywn\S* teraz)$/iu.test(line))
      .join("\n");

  let snapshot = new Map();
  const takeSnapshot = () => {
    snapshot = new Map(conversationRows().map((row) => [row.threadId, comparableText(row)]));
  };
  const changedRow = () => conversationRows().find((row) => snapshot.get(row.threadId) !== comparableText(row));

  const describe = (row) => ({
    href: row.link.href,
    threadId: row.threadId,
    lines: rowLines(row.link),
    icon: absolute(row.image.currentSrc || row.image.src || row.image.getAttribute("xlink:href") || row.image.getAttribute("href")),
  });

  const notifyRow = (row, reason) => {
    const thread = describe(row);
    const id = nextId();
    live.set(id, {
      __fire(name) {
        if (name === "click") openThread(thread.href);
      },
    });
    if (diagnostics) log(`message row picked: ${reason}`);
    post({ type: "message", id, threadId: thread.threadId, lines: thread.lines, icon: thread.icon });
    takeSnapshot();
  };

  let messageTimer = null;
  const onMessageSound = () => {
    clearTimeout(messageTimer);
    // Give the chat list a moment to update; retry once if no row changed yet.
    messageTimer = setTimeout(() => {
      const changed = changedRow();
      if (changed) return notifyRow(changed, "changed");
      messageTimer = setTimeout(() => {
        const row = changedRow() ?? conversationRows()[0];
        if (!row) return log("message sound, but no chat list rows found");
        notifyRow(row, snapshot.get(row.threadId) !== comparableText(row) ? "changed (retry)" : "top row");
      }, 800);
    }, 400);
  };

  if (frame === "main") {
    // Keep the snapshot current while nothing arrives: the user's own reading and sending also change rows.
    document.addEventListener("visibilitychange", takeSnapshot);
    setInterval(takeSnapshot, 30000);
  }

  const play = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function (...args) {
    const source = this.currentSrc || this.src || "";
    if (diagnostics) log(`media.play ${source.slice(0, 160) || "(no src)"}`);
    if (frame === "main" && this instanceof HTMLAudioElement && source.includes("fbcdn.net")) onMessageSound();
    return play.apply(this, args);
  };

  if (diagnostics) {
    log(
      `diagnostics ${frame}: serviceWorker=${"serviceWorker" in navigator} PushManager=${"PushManager" in window} ` +
        `visibility=${document.visibilityState} focus=${document.hasFocus()}`
    );
    document.addEventListener("visibilitychange", () => log(`visibility ${document.visibilityState}`));
    window.addEventListener("focus", () => log("window focus"));
    window.addEventListener("blur", () => log("window blur"));

    const start = window.AudioBufferSourceNode?.prototype.start;
    if (start) {
      AudioBufferSourceNode.prototype.start = function (...args) {
        log(`AudioBufferSourceNode.start at ${caller()}`);
        return start.apply(this, args);
      };
    }
  }

  // Page-initiated service worker notifications. Push from inside the worker is not available in WKWebView.
  const registration = window.ServiceWorkerRegistration?.prototype;
  if (registration) {
    registration.showNotification = function (title, options = {}) {
      log("ServiceWorkerRegistration.showNotification");
      const id = nextId();
      live.set(id, {
        __fire(name) {
          const url = options?.data?.url;
          if (name === "click" && url) location.assign(absolute(url));
        },
      });
      deliver(id, title, options, "service-worker");
      return Promise.resolve();
    };
    registration.getNotifications = () => Promise.resolve([]);
  }

  const permissions = navigator.permissions;
  if (permissions?.query) {
    const query = permissions.query.bind(permissions);
    permissions.query = (descriptor) => {
      if (descriptor?.name !== "notifications") return query(descriptor);
      log("permissions.query(notifications)");
      return Promise.resolve({
        name: "notifications",
        state: "granted",
        onchange: null,
        addEventListener() {},
        removeEventListener() {},
        dispatchEvent() {
          return true;
        },
      });
    };
  }

  const serviceWorker = navigator.serviceWorker;
  if (serviceWorker?.register) {
    const register = serviceWorker.register.bind(serviceWorker);
    serviceWorker.register = (url, options) => {
      log(`serviceWorker.register ${url}`);
      return register(url, options);
    };
  }

  Object.defineProperty(window, "__messengerBridge", {
    value: Object.freeze({
      click(id) {
        const notification = live.get(id);
        if (!notification) return false;
        notification.__fire("click");
        return true;
      },
      ...shortcuts,
    }),
  });

  if (frame === "main" || diagnostics) log(`shim installed (${frame}) on ${location.host}${location.pathname}`);
})();

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
  const latestThread = () =>
    threadLinks()
      .map((link) => ({
        link,
        top: link.getBoundingClientRect().top,
        threadId: link.getAttribute("href").match(/\/t\/([^/?#]+)/)?.[1] ?? "",
        lines: link.innerText.split("\n").map((line) => line.trim()).filter(Boolean).slice(0, 8),
        image: link.querySelector("img, image"),
      }))
      .filter((row) => row.threadId && row.lines.length >= 2 && row.image)
      .sort((a, b) => a.top - b.top)
      .map((row) => ({
        href: row.link.href,
        threadId: row.threadId,
        lines: rowLines(row.link),
        icon: absolute(row.image.currentSrc || row.image.src || row.image.getAttribute("xlink:href") || row.image.getAttribute("href")),
      }))[0] ?? null;

  const openThread = (href) => {
    const path = new URL(href, location.href).pathname;
    const link = [...document.querySelectorAll('a[href*="/t/"]')].find((a) => new URL(a.href).pathname === path);
    if (link) link.click();
    else location.assign(href);
  };

  let messageTimer = null;
  const onMessageSound = () => {
    clearTimeout(messageTimer);
    // Give the chat list a moment to move the new message to the top.
    messageTimer = setTimeout(() => {
      const thread = latestThread();
      if (!thread) {
        log("message sound, but no chat list rows found");
        return;
      }
      const id = nextId();
      live.set(id, {
        __fire(name) {
          if (name === "click") openThread(thread.href);
        },
      });
      post({ type: "message", id, threadId: thread.threadId, lines: thread.lines, icon: thread.icon });
    }, 400);
  };

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
    }),
  });

  if (frame === "main" || diagnostics) log(`shim installed (${frame}) on ${location.host}${location.pathname}`);
})();

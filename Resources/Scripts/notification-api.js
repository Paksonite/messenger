// The web Notification API, bridged to native notifications. Messenger currently never calls it in
// WKWebView (it only shows desktop notifications through Web Push, which WKWebView lacks), so new
// messages are detected in incoming-messages.js instead. Kept so notifications keep working if
// Messenger starts using the API directly.

const deliverWebNotification = (id, title, options, source) =>
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
    deliverWebNotification(this.__id, this.title, options, "window");
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

// Page-initiated service worker notifications. Push from inside the worker is not available in WKWebView.
const workerRegistration = window.ServiceWorkerRegistration?.prototype;
if (workerRegistration) {
  workerRegistration.showNotification = function (title, options = {}) {
    log("ServiceWorkerRegistration.showNotification");
    const id = nextId();
    live.set(id, {
      __fire(name) {
        const url = options?.data?.url;
        if (name === "click" && url) location.assign(absolute(url));
      },
    });
    deliverWebNotification(id, title, options, "service-worker");
    return Promise.resolve();
  };
  workerRegistration.getNotifications = () => Promise.resolve([]);
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

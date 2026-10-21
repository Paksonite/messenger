// Extra logging, only with `defaults write pl.paksonite.messenger VerboseLogging -bool true`.

if (diagnostics) {
  log(
    `diagnostics ${frame}: serviceWorker=${"serviceWorker" in navigator} PushManager=${"PushManager" in window} ` +
      `visibility=${document.visibilityState} focus=${document.hasFocus()}`
  );
  document.addEventListener("visibilitychange", () => log(`visibility ${document.visibilityState}`));
  window.addEventListener("focus", () => log("window focus"));
  window.addEventListener("blur", () => log("window blur"));

  if (window.Worker) {
    window.Worker = new Proxy(window.Worker, {
      construct(target, args) {
        log(`new Worker ${String(args[0]).slice(0, 120)}`);
        return Reflect.construct(target, args);
      },
    });
  }

  const serviceWorker = navigator.serviceWorker;
  if (serviceWorker?.register) {
    const register = serviceWorker.register.bind(serviceWorker);
    serviceWorker.register = (url, options) => {
      log(`serviceWorker.register ${url}`);
      return register(url, options);
    };
  }
}

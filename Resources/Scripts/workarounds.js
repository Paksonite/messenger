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

// Messenger creates its Web Audio contexts once and never suspends them. A running AudioContext keeps
// the audio output busy even in silence, so macOS and audio monitors show Messenger as playing sound
// all day, and it costs power. Contexts are suspended after a few seconds without sound and resumed
// when the next sound starts. Contexts fed by media streams or elements (calls, voice messages) are
// left running.
const NativeAudioContext = window.AudioContext;
if (NativeAudioContext && window.AudioScheduledSourceNode) {
  const audioStates = new WeakMap();
  const audioState = (context) => {
    let state = audioStates.get(context);
    if (!state) {
      state = { playing: 0, timer: null, pinned: false };
      audioStates.set(context, state);
    }
    return state;
  };

  const suspendWhenIdle = (context) => {
    const state = audioState(context);
    clearTimeout(state.timer);
    if (state.pinned || state.playing > 0) return;
    state.timer = setTimeout(() => {
      if (state.pinned || state.playing > 0 || context.state !== "running") return;
      context.suspend().then(
        () => diagnostics && log("audio context suspended while idle"),
        () => {}
      );
    }, timing.audioIdleSuspend);
  };

  window.AudioContext = new Proxy(NativeAudioContext, {
    construct(target, args, newTarget) {
      const context = Reflect.construct(target, args, newTarget);
      suspendWhenIdle(context);
      return context;
    },
  });

  // Messenger may resume a context itself (e.g. after a click); let it go idle again afterwards.
  const resume = NativeAudioContext.prototype.resume;
  NativeAudioContext.prototype.resume = function (...args) {
    const result = resume.apply(this, args);
    suspendWhenIdle(this);
    return result;
  };

  for (const method of ["createMediaStreamSource", "createMediaElementSource", "createMediaStreamDestination"]) {
    const create = NativeAudioContext.prototype[method];
    if (!create) continue;
    NativeAudioContext.prototype[method] = function (...args) {
      const state = audioState(this);
      state.pinned = true;
      clearTimeout(state.timer);
      if (this.state === "suspended") resume.call(this).catch(() => {});
      return create.apply(this, args);
    };
  }

  // Covers AudioBufferSourceNode, OscillatorNode and ConstantSourceNode.
  const start = AudioScheduledSourceNode.prototype.start;
  AudioScheduledSourceNode.prototype.start = function (...args) {
    const context = this.context;
    if (context instanceof NativeAudioContext) {
      const state = audioState(context);
      state.playing += 1;
      clearTimeout(state.timer);
      this.addEventListener(
        "ended",
        () => {
          state.playing = Math.max(0, state.playing - 1);
          suspendWhenIdle(context);
        },
        { once: true }
      );
      if (context.state === "suspended") resume.call(context).catch(() => {});
    }
    return start.apply(this, args);
  };
}

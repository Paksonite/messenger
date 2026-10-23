// Run with: node --test Tests/js/*.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(new URL("../../Resources/Scripts/sounds.js", import.meta.url), "utf8");
const messageSound = "https://static.xx.fbcdn.net/rsrc.php/yy/r/XFhtdTsftOC.ogg";

// Runs sounds.js against fake media and Web Audio classes; returns what happened.
function install({ fetchFails = false } = {}) {
  const calls = { elementPlays: 0, fetches: 0, started: [], gains: [] };

  class FakeMediaElement {
    loop = false;
    muted = false;
    volume = 1;
    srcObject = null;
    events = [];
    constructor(src) {
      this.src = src;
      this.currentSrc = src;
    }
    dispatchEvent(event) {
      this.events.push(event.type);
    }
  }
  FakeMediaElement.prototype.play = function () {
    calls.elementPlays += 1;
    return Promise.resolve();
  };
  class FakeAudioElement extends FakeMediaElement {}

  class FakeAudioContext {
    destination = {};
    decodeAudioData() {
      return Promise.resolve({ duration: 1.67 });
    }
    createGain() {
      const gain = { gain: { value: 1 }, connect() {} };
      calls.gains.push(gain);
      return gain;
    }
    createBufferSource() {
      const node = {
        listeners: [],
        connect() {},
        addEventListener(type, listener) {
          if (type === "ended") this.listeners.push(listener);
        },
        start() {
          calls.started.push(this);
        },
        finish() {
          this.listeners.forEach((listener) => listener());
        },
      };
      return node;
    }
  }

  const fetch = () => {
    calls.fetches += 1;
    if (fetchFails) return Promise.reject(new Error("blocked"));
    return Promise.resolve({ ok: true, arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)) });
  };

  const window = { AudioContext: FakeAudioContext, HTMLMediaElement: FakeMediaElement };
  new Function("window", "HTMLMediaElement", "HTMLAudioElement", "fetch", "Event", "frame", "diagnostics", "log", source)(
    window,
    FakeMediaElement,
    FakeAudioElement,
    fetch,
    class {
      constructor(type) {
        this.type = type;
      }
    },
    "main",
    false,
    () => {}
  );
  return { calls, FakeAudioElement, FakeMediaElement };
}

test("Messenger's message sound plays through Web Audio, not the element", async () => {
  const { calls, FakeAudioElement } = install();
  const element = new FakeAudioElement(messageSound);
  await element.play();

  assert.equal(calls.elementPlays, 0);
  assert.equal(calls.started.length, 1);
  assert.deepEqual(element.events, ["play", "playing"]);

  calls.started[0].finish();
  assert.deepEqual(element.events, ["play", "playing", "ended"]);
});

test("the decoded sound is reused", async () => {
  const { calls, FakeAudioElement } = install();
  await new FakeAudioElement(messageSound).play();
  await new FakeAudioElement(messageSound).play();
  assert.equal(calls.fetches, 1);
  assert.equal(calls.started.length, 2);
});

test("volume and mute of the element are kept", async () => {
  const { calls, FakeAudioElement } = install();
  const quiet = new FakeAudioElement(messageSound);
  quiet.volume = 0.3;
  await quiet.play();
  const muted = new FakeAudioElement(messageSound);
  muted.muted = true;
  await muted.play();
  assert.deepEqual(calls.gains.map((gain) => gain.gain.value), [0.3, 0]);
});

test("other media still play through the element", async () => {
  const { calls, FakeAudioElement, FakeMediaElement } = install();
  await new FakeAudioElement("https://video.xx.fbcdn.net/voice-message.mp4").play();
  await new FakeMediaElement(messageSound).play();
  const looping = new FakeAudioElement(messageSound);
  looping.loop = true;
  await looping.play();
  assert.equal(calls.elementPlays, 3);
  assert.equal(calls.started.length, 0);
});

test("a sound that can't be loaded falls back to the element", async () => {
  const { calls, FakeAudioElement } = install({ fetchFails: true });
  await new FakeAudioElement(messageSound).play();
  assert.equal(calls.elementPlays, 1);
  assert.equal(calls.started.length, 0);
});

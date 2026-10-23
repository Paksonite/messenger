// Run with: node --test Tests/js/*.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { setTimeout as sleep } from "node:timers/promises";

const source = readFileSync(new URL("../../Resources/Scripts/workarounds.js", import.meta.url), "utf8");
const idleDelay = 20;

class FakeAudioContext {
  state = "running";
  suspend() {
    this.state = "suspended";
    return Promise.resolve();
  }
  resume() {
    this.state = "running";
    return Promise.resolve();
  }
  createMediaStreamSource() {
    return {};
  }
}

class FakeSourceNode {
  constructor(context) {
    this.context = context;
    this.listeners = [];
  }
  addEventListener(type, listener) {
    if (type === "ended") this.listeners.push(listener);
  }
  start() {}
  finish() {
    this.listeners.forEach((listener) => listener());
  }
}

// Runs workarounds.js against fake Web Audio classes and returns the patched AudioContext.
function install() {
  const window = { AudioContext: FakeAudioContext, AudioScheduledSourceNode: FakeSourceNode };
  const timing = { audioIdleSuspend: idleDelay };
  new Function("window", "AudioScheduledSourceNode", "timing", "diagnostics", "log", source)(
    window,
    FakeSourceNode,
    timing,
    false,
    () => {}
  );
  return window.AudioContext;
}

test("an unused context is suspended after the idle delay", async () => {
  const AudioContext = install();
  const context = new AudioContext();
  assert.equal(context.state, "running");
  await sleep(idleDelay * 2);
  assert.equal(context.state, "suspended");
});

test("starting a sound resumes the context and keeps it running until the sound ends", async () => {
  const AudioContext = install();
  const context = new AudioContext();
  await sleep(idleDelay * 2);

  const sound = new FakeSourceNode(context);
  sound.start();
  assert.equal(context.state, "running");
  await sleep(idleDelay * 2);
  assert.equal(context.state, "running", "suspended while the sound was playing");

  sound.finish();
  await sleep(idleDelay * 2);
  assert.equal(context.state, "suspended");
});

test("contexts fed by media streams are never suspended", async () => {
  const AudioContext = install();
  const context = new AudioContext();
  context.createMediaStreamSource();
  await sleep(idleDelay * 2);
  assert.equal(context.state, "running");
});

test("a context Messenger resumes itself goes idle again", async () => {
  const AudioContext = install();
  const context = new AudioContext();
  await sleep(idleDelay * 2);
  context.resume();
  assert.equal(context.state, "running");
  await sleep(idleDelay * 2);
  assert.equal(context.state, "suspended");
});

test("instanceof still works for the wrapped constructor", () => {
  const AudioContext = install();
  assert.ok(new AudioContext() instanceof FakeAudioContext);
});

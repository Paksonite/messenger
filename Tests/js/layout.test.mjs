// Run with: node --test Tests/js/*.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(new URL("../../Resources/Scripts/layout.js", import.meta.url), "utf8");

// Runs layout.js against a fake page; returns the page and what happened.
function install({ hostname = "www.messenger.com", rows = 3 } = {}) {
  const calls = { scrollTo: [], logs: [], styles: [] };
  const listeners = {};
  const window = {
    scrollX: 0,
    scrollY: 0,
    addEventListener(type, listener) {
      listeners[type] = listener;
    },
    scrollTo(x, y) {
      calls.scrollTo.push([x, y]);
      this.scrollX = x;
      this.scrollY = y;
    },
  };
  const document = {
    head: { append: (style) => calls.styles.push(style.textContent) },
    activeElement: { tagName: "DIV", getAttribute: (name) => (name === "role" ? "textbox" : null) },
    createElement: () => ({ textContent: "" }),
  };
  new Function("window", "document", "location", "frame", "conversationRows", "log", source)(
    window,
    document,
    { hostname },
    "main",
    () => Array.from({ length: rows }),
    (message) => calls.logs.push(message)
  );
  const scrollPage = (y) => {
    window.scrollY = y;
    listeners.scroll?.();
  };
  return { calls, scrollPage };
}

test("a scrolled app page is reset to the top and the cause is logged", () => {
  const { calls, scrollPage } = install();
  scrollPage(120);
  assert.deepEqual(calls.scrollTo, [[0, 0]]);
  assert.deepEqual(calls.logs, ["page scrolled to 0,120 (focus: div[role=textbox]), resetting"]);
});

test("overscroll bounce is turned off on messenger.com", () => {
  const { calls } = install();
  assert.equal(calls.styles.length, 1);
  assert.match(calls.styles[0], /overscroll-behavior: none/);
});

test("pages without the chat list (login, checkpoints) can scroll", () => {
  const { calls, scrollPage } = install({ rows: 0 });
  scrollPage(300);
  assert.deepEqual(calls.scrollTo, []);
});

test("facebook.com pages are left alone", () => {
  const { calls, scrollPage } = install({ hostname: "www.facebook.com" });
  scrollPage(300);
  assert.deepEqual(calls.scrollTo, []);
  assert.deepEqual(calls.styles, []);
});

test("logging stops after a few resets", () => {
  const { calls, scrollPage } = install();
  for (let i = 0; i < 10; i += 1) scrollPage(50);
  assert.equal(calls.scrollTo.length, 10);
  assert.equal(calls.logs.length, 5);
});

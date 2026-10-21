// Run with: node --test Tests/js/*.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(new URL("../../Resources/Scripts/text-rules.js", import.meta.url), "utf8");
const { parsePreview, comparableText } = new Function(`${source}\nreturn { parsePreview, comparableText };`)();

test("separate time line", () => {
  assert.deepEqual(parsePreview(["Jane Doe", "See you tomorrow", "·", "2 min"]), { sender: "Jane Doe", text: "See you tomorrow" });
});

test("inline time", () => {
  assert.deepEqual(parsePreview(["Myszka ❤️🐣🐭", "Hej, co tam? · 1 min"]), { sender: "Myszka ❤️🐣🐭", text: "Hej, co tam?" });
});

test("screen reader labels", () => {
  assert.deepEqual(parsePreview(["Jane", "Unread message:", "Ping", "·", "now"]), { sender: "Jane", text: "Ping" });
});

test("real row with presence and unread label", () => {
  assert.deepEqual(parsePreview(["Aktywny teraz", "Myszka ❤️🐣🐭 Nieprzeczytana wiadomość:", "To ide", "·", "1 min"]), {
    sender: "Myszka ❤️🐣🐭",
    text: "To ide",
  });
});

test("reaction row", () => {
  assert.deepEqual(parsePreview(["Katarzyna Szafrańska", "Nieprzeczytana wiadomość:", "Reakcja ❤️ na T…", "·", "1 dzień"]), {
    sender: "Katarzyna Szafrańska",
    text: "Reakcja ❤️ na T…",
  });
});

test("text that looks like a time is kept when it is the only line", () => {
  assert.equal(parsePreview(["Jane", "5 min"]).text, "5 min");
});

test("own messages are skipped", () => {
  assert.equal(parsePreview(["Jane", "You: ok", "·", "1 min"]), null);
  assert.equal(parsePreview(["Jane", "Ty: ok · 1 min"]), null);
});

test("empty row", () => {
  assert.equal(parsePreview(["", " "]), null);
});

test("comparison ignores time and presence changes", () => {
  assert.equal(
    comparableText(["Aktywny teraz", "Myszka ❤️🐣🐭", "To ide", "·", "1 min"]),
    comparableText(["Myszka ❤️🐣🐭", "To ide", "·", "2 min"])
  );
});

test("comparison sees a new reaction on an old row", () => {
  assert.notEqual(
    comparableText(["Katarzyna Szafrańska", "Nieprzeczytana wiadomość:", "Reakcja ❤️ na T…", "·", "1 dzień"]),
    comparableText(["Katarzyna Szafrańska", "Ty: ok · 1 dzień"])
  );
});

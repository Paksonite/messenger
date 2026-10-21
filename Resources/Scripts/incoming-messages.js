// Incoming messages. Messenger plays a sound for every incoming message; that is the trigger to read
// the chat list. A new message moves its chat to the top, but a reaction only updates the row in
// place, so the notification is built from the row whose text changed since the last snapshot,
// falling back to the top row.

let snapshot = new Map();
const takeSnapshot = () => {
  snapshot = new Map(conversationRows().map((row) => [row.threadId, comparableText(row.lines)]));
};
const hasChanged = (row) => snapshot.get(row.threadId) !== comparableText(row.lines);
const changedRow = () => conversationRows().find(hasChanged);

const notifyRow = (row, reason) => {
  const lines = rowLinesWithEmoji(row.link);
  const preview = parsePreview(lines);
  if (diagnostics) log(`message row picked (${reason}): ${JSON.stringify(lines)}`);
  takeSnapshot();
  if (!preview) return;

  const id = nextId();
  const href = row.link.href;
  live.set(id, {
    __fire(name) {
      if (name === "click") openThread(href);
    },
  });
  post({ type: "message", id, threadId: row.threadId, sender: preview.sender, text: preview.text, icon: avatarURL(row) });
};

let messageTimer = null;
const onMessageSound = () => {
  clearTimeout(messageTimer);
  messageTimer = setTimeout(() => {
    const changed = changedRow();
    if (changed) return notifyRow(changed, "changed");
    messageTimer = setTimeout(() => {
      const row = changedRow() ?? conversationRows()[0];
      if (!row) return log("message sound, but no chat list rows found");
      notifyRow(row, hasChanged(row) ? "changed on retry" : "top row");
    }, timing.rowRetryDelay);
  }, timing.rowUpdateDelay);
};

if (frame === "main") {
  // Keep the snapshot current while nothing arrives: the user's own reading and sending also change rows.
  document.addEventListener("visibilitychange", takeSnapshot);
  setInterval(takeSnapshot, timing.snapshotInterval);

  const play = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function (...args) {
    const source = this.currentSrc || this.src || "";
    if (diagnostics) log(`media.play ${source.slice(0, 160) || "(no src)"}`);
    if (this instanceof HTMLAudioElement && source.includes("fbcdn.net")) onMessageSound();
    return play.apply(this, args);
  };
}

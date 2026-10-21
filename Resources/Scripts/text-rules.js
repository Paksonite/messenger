// How chat list rows read, e.g. ["Aktywny teraz", "Jane Doe", "Nieprzeczytana wiadomość:", "See you", "·", "2 min"].
// Pure functions without page access, so Tests/js/text-rules.test.mjs runs them in node.
// Polish and English labels; extend the lists when Messenger changes its wording.

// Presence and screen reader labels inside rows.
const rowNoise = new Set(["·", "Unread message:", "Nieprzeczytana wiadomość:"]);
const presencePattern = /^(active now|aktywn\S* teraz)$/iu;
// Unread marker appended to the name line, e.g. "Jane Unread message:".
const unreadSuffixPattern = /\s*(Unread message|Nieprzeczytana wiadomość):\s*$/u;
// Relative times: "2 min", "1h", "1 dzień", "now", "teraz".
const timePattern = /^(\d+\s?\p{L}{1,6}\.?|now|just now|teraz)$/iu;
// A time appended to the text line: "See you · 2 min".
const inlineTimePattern = /\s+·\s+[^·]{1,12}$/u;
// The user's own messages, which should not notify.
const ownMessagePrefixes = ["You: ", "You sent", "Ty: ", "Wysłano"];

function cleanRowLines(lines) {
  return lines
    .map((line) => line.replace(unreadSuffixPattern, "").trim())
    .filter((line) => line && !rowNoise.has(line) && !presencePattern.test(line));
}

/** Sender and text of the newest message in a row, or null for the user's own messages and empty rows. */
function parsePreview(lines) {
  const [sender, ...rest] = cleanRowLines(lines);
  if (!sender) return null;
  if (rest.length > 1 && timePattern.test(rest[rest.length - 1])) rest.pop();
  const text = rest.join(" ").replace(inlineTimePattern, "").trim();
  if (ownMessagePrefixes.some((prefix) => text.startsWith(prefix))) return null;
  return { sender, text };
}

/** Row text without times and presence, which change on their own, to detect rows that really changed. */
function comparableText(lines) {
  return cleanRowLines(lines)
    .map((line) => line.replace(inlineTimePattern, ""))
    .filter((line) => !timePattern.test(line))
    .join("\n");
}

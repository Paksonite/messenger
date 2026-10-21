// Reading Messenger's chat list, shared by incoming-messages.js and shortcuts.js.

const threadLinks = () =>
  [...document.querySelectorAll('a[href*="/t/"]')].filter((link) => {
    const rect = link.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && rect.left < window.innerWidth / 2;
  });

const textLines = (text) =>
  text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 8);

// Conversation rows link to /t/<thread id> and show an avatar plus at least a name and a preview line;
// this skips headers such as "Chats · 3 unread" that also link to /t/.
const conversationRows = () =>
  threadLinks()
    .map((link) => ({
      link,
      top: link.getBoundingClientRect().top,
      threadId: link.getAttribute("href").match(/\/t\/([^/?#]+)/)?.[1] ?? "",
      lines: textLines(link.innerText),
      image: link.querySelector("img, image"),
    }))
    .filter((row) => row.threadId && row.lines.length >= 2 && row.image)
    .sort((a, b) => a.top - b.top);

// Text lines of a row with emoji images (e.g. in names) replaced by their alt text. Works on an
// invisible clone so Messenger's own DOM is never touched; the clone keeps the row's CSS, so
// innerText still splits lines the way they are displayed.
const rowLinesWithEmoji = (link) => {
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
  return textLines(text);
};

const avatarURL = (row) =>
  absolute(row.image.currentSrc || row.image.src || row.image.getAttribute("xlink:href") || row.image.getAttribute("href"));

const openThread = (href) => {
  const path = new URL(href, location.href).pathname;
  const link = [...document.querySelectorAll('a[href*="/t/"]')].find((a) => new URL(a.href).pathname === path);
  if (link) link.click();
  else location.assign(href);
};

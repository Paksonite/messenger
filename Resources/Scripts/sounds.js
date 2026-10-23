// Messenger plays its message sounds with <audio> elements. WebKit then lists Messenger in macOS
// "Now Playing" and doesn't clear it after the 1–2 s sound, so Now Playing widgets and menu bar audio
// indicators show Messenger as playing all the time. Short sounds from Messenger's static CDN are
// played through Web Audio instead, which has no Now Playing entry; the idle suspension in
// workarounds.js stops the audio output again afterwards. Anything else, and any sound that fails to
// load this way, still plays through the element. Must run before incoming-messages.js, which wraps
// HTMLMediaElement.play again to detect incoming messages.

const messengerSoundPattern = /^https:\/\/static\.[^/]*fbcdn\.net\//;

if (frame === "main" && window.AudioContext && window.HTMLMediaElement) {
  const elementPlay = HTMLMediaElement.prototype.play;
  const decodedSounds = new Map();
  let soundContext = null;

  const isMessengerSound = (element, source) =>
    element instanceof HTMLAudioElement && !element.loop && !element.srcObject && messengerSoundPattern.test(source);

  const decodedSound = (source) => {
    if (!decodedSounds.has(source)) {
      soundContext ??= new window.AudioContext();
      const sound = fetch(source, { mode: "cors", credentials: "omit" })
        .then((response) => {
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          return response.arrayBuffer();
        })
        .then((data) => soundContext.decodeAudioData(data));
      // Forget failures, so a later play tries again instead of always falling back.
      sound.catch(() => decodedSounds.delete(source));
      decodedSounds.set(source, sound);
    }
    return decodedSounds.get(source);
  };

  HTMLMediaElement.prototype.play = function (...args) {
    const source = this.currentSrc || this.src || "";
    if (!isMessengerSound(this, source)) return elementPlay.apply(this, args);

    const element = this;
    return decodedSound(source).then(
      (buffer) => {
        const node = soundContext.createBufferSource();
        node.buffer = buffer;
        const gain = soundContext.createGain();
        gain.gain.value = element.muted ? 0 : element.volume;
        node.connect(gain);
        gain.connect(soundContext.destination);
        node.addEventListener("ended", () => element.dispatchEvent(new Event("ended")), { once: true });
        node.start();
        element.dispatchEvent(new Event("play"));
        element.dispatchEvent(new Event("playing"));
      },
      (error) => {
        log(`sound through Web Audio failed (${error}), using the element`);
        return elementPlay.apply(element, args);
      }
    );
  };
}

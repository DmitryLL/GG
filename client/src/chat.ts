import type { Room } from "colyseus.js";
import type { ChatBroadcast, ChatSend } from "@gg/shared";

const LOG_KEEP = 8;

export type IncomingHandler = (msg: ChatBroadcast) => void;

export function mountChat(room: Room, onIncoming: IncomingHandler) {
  const container = document.getElementById("chat") as HTMLDivElement;
  const log = document.getElementById("chat-log") as HTMLDivElement;
  const input = document.getElementById("chat-input") as HTMLInputElement;
  container.style.display = "flex";

  const setActive = (active: boolean) => {
    input.classList.toggle("idle", !active);
  };
  setActive(false);

  window.addEventListener("keydown", (e) => {
    const typing = document.activeElement === input;
    if (e.key === "Enter") {
      if (!typing) {
        input.focus();
        setActive(true);
        e.preventDefault();
        return;
      }
      const text = input.value.trim();
      input.value = "";
      input.blur();
      setActive(false);
      if (text) {
        const payload: ChatSend = { text };
        room.send("chat", payload);
      }
      e.preventDefault();
    } else if (e.key === "Escape" && typing) {
      input.value = "";
      input.blur();
      setActive(false);
      e.preventDefault();
    }
  });

  input.addEventListener("blur", () => setActive(false));
  input.addEventListener("focus", () => setActive(true));

  room.onMessage<ChatBroadcast>("chat", (msg) => {
    appendLog(log, msg);
    onIncoming(msg);
  });
}

function appendLog(log: HTMLDivElement, msg: ChatBroadcast) {
  const line = document.createElement("div");
  line.className = "msg";
  const who = document.createElement("span");
  who.className = "who";
  who.textContent = msg.name + ":";
  const text = document.createElement("span");
  text.textContent = " " + msg.text;
  line.appendChild(who);
  line.appendChild(text);
  log.appendChild(line);
  while (log.childElementCount > LOG_KEEP) {
    log.firstElementChild?.remove();
  }
}

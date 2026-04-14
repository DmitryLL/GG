import type { Room } from "colyseus.js";
import { ITEMS, type BuyMessage, type SellMessage, type ItemId, type NpcDef } from "@gg/shared";

const BASE = (import.meta as any).env?.BASE_URL ?? "/";
const ITEMS_URL = `${BASE}sprites/items.png`;

function iconEl(iconIdx: number): HTMLDivElement {
  const el = document.createElement("div");
  el.className = "icon";
  el.style.background = `url(${ITEMS_URL}) -${iconIdx * 16}px 0 / auto 100% no-repeat`;
  return el;
}

export function mountShop(room: Room) {
  const overlay = document.getElementById("shop-overlay") as HTMLDivElement;
  const title = document.getElementById("shop-title") as HTMLHeadingElement;
  const buyList = document.getElementById("shop-buy") as HTMLDivElement;
  const sellList = document.getElementById("shop-sell") as HTMLDivElement;
  const closeBtn = document.getElementById("shop-close") as HTMLButtonElement;

  let currentNpc: NpcDef | null = null;

  const close = () => {
    overlay.classList.remove("open");
    currentNpc = null;
  };
  closeBtn.addEventListener("click", close);
  window.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && overlay.classList.contains("open")) close();
  });

  function renderBuy(npc: NpcDef, player: any) {
    buyList.innerHTML = "";
    for (const itemId of npc.stock) {
      const def = (ITEMS as Record<string, any>)[itemId];
      if (!def?.price) continue;
      const entry = document.createElement("div");
      entry.className = "entry";
      const affordable = (player?.gold ?? 0) >= def.price;
      if (!affordable) entry.classList.add("disabled");
      entry.appendChild(iconEl(def.icon));
      const name = document.createElement("span");
      name.className = "name";
      name.textContent = def.name;
      entry.appendChild(name);
      const price = document.createElement("span");
      price.className = "price";
      price.textContent = `${def.price}z`;
      entry.appendChild(price);
      if (affordable) {
        entry.addEventListener("click", () => {
          const payload: BuyMessage = { npcId: npc.id, itemId: itemId as ItemId };
          room.send("buy", payload);
        });
      }
      buyList.appendChild(entry);
    }
  }

  function renderSell(player: any) {
    sellList.innerHTML = "";
    const inv = player?.inventory ?? [];
    if (!inv.length) {
      const msg = document.createElement("div");
      msg.className = "empty-msg";
      msg.textContent = "Инвентарь пуст";
      sellList.appendChild(msg);
      return;
    }
    for (let i = 0; i < inv.length; i++) {
      const e = inv[i];
      const def = (ITEMS as Record<string, any>)[e.itemId];
      if (!def?.sellPrice) continue;
      const entry = document.createElement("div");
      entry.className = "entry";
      entry.appendChild(iconEl(def.icon));
      const name = document.createElement("span");
      name.className = "name";
      name.textContent = e.qty > 1 ? `${def.name} ×${e.qty}` : def.name;
      entry.appendChild(name);
      const price = document.createElement("span");
      price.className = "price";
      price.textContent = `${def.sellPrice}z`;
      entry.appendChild(price);
      entry.addEventListener("click", () => {
        const payload: SellMessage = { slot: i };
        room.send("sell", payload);
      });
      sellList.appendChild(entry);
    }
  }

  return {
    open(npc: NpcDef, player: any) {
      currentNpc = npc;
      title.textContent = npc.name;
      overlay.classList.add("open");
      renderBuy(npc, player);
      renderSell(player);
    },
    refresh(player: any) {
      if (!currentNpc) return;
      renderBuy(currentNpc, player);
      renderSell(player);
    },
    isOpen() {
      return overlay.classList.contains("open");
    },
  };
}

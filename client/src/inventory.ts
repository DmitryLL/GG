import { INVENTORY_SLOTS, ITEMS, isEquippable, type ItemId, type EquipMessage, type UnequipMessage, type UseItemMessage } from "@gg/shared";
import type { Room } from "colyseus.js";

export type InvSlotView = { itemId: ItemId; qty: number } | null;
export type HudView = {
  gold: number;
  weapon: string;
  armor: string;
  slots: InvSlotView[];
};

const BASE = (import.meta as any).env?.BASE_URL ?? "/";
const ITEMS_URL = `${BASE}sprites/items.png`;

function iconStyle(iconIdx: number): string {
  return `background: url(${ITEMS_URL}) -${iconIdx * 16}px 0 / auto 100% no-repeat; width: 28px; height: 28px; margin: 3px auto 0; display: block; image-rendering: pixelated;`;
}

function renderSlotContent(itemId: ItemId | "", qty: number): string {
  if (!itemId) return "";
  const def = (ITEMS as Record<string, any>)[itemId];
  if (!def) return "";
  const qtyHtml = qty > 1 ? `<span class="qty" style="position:absolute;right:2px;bottom:0;font-size:10px;color:#fff;text-shadow:1px 1px 0 #000,-1px 1px 0 #000,1px -1px 0 #000,-1px -1px 0 #000">${qty}</span>` : "";
  return `<div class="icon" style="${iconStyle(def.icon)}" title="${def.name}"></div>${qtyHtml}`;
}

export function mountHud(room: Room) {
  const hud = document.getElementById("hud") as HTMLDivElement;
  const goldEl = document.getElementById("gold") as HTMLDivElement;
  const invEl = document.getElementById("inv") as HTMLDivElement;
  const eqWeapon = document.getElementById("eq-weapon") as HTMLDivElement;
  const eqArmor = document.getElementById("eq-armor") as HTMLDivElement;
  hud.style.display = "flex";

  for (let i = 0; i < INVENTORY_SLOTS; i++) {
    const slot = document.createElement("div");
    slot.className = "inv-slot";
    slot.dataset.idx = String(i);
    slot.addEventListener("click", () => {
      const idx = Number(slot.dataset.idx);
      const itemId = slot.dataset.item as ItemId | undefined;
      if (!itemId) return;
      const def = (ITEMS as Record<string, any>)[itemId];
      if (!def) return;
      if (def.kind === "consumable") {
        const payload: UseItemMessage = { slot: idx };
        room.send("useItem", payload);
      } else if (isEquippable(itemId)) {
        const payload: EquipMessage = { slot: idx };
        room.send("equip", payload);
      }
    });
    invEl.appendChild(slot);
  }

  eqWeapon.addEventListener("click", () => {
    if (eqWeapon.classList.contains("empty")) return;
    const payload: UnequipMessage = { slot: "weapon" };
    room.send("unequip", payload);
  });
  eqArmor.addEventListener("click", () => {
    if (eqArmor.classList.contains("empty")) return;
    const payload: UnequipMessage = { slot: "armor" };
    room.send("unequip", payload);
  });

  return {
    update(view: HudView) {
      goldEl.textContent = `${view.gold} зол.`;
      for (let i = 0; i < INVENTORY_SLOTS; i++) {
        const slot = invEl.children[i] as HTMLDivElement;
        const data = view.slots[i] ?? null;
        slot.innerHTML = data ? renderSlotContent(data.itemId, data.qty) : "";
        slot.classList.toggle("equippable", !!data && isEquippable(data.itemId));
        if (data) slot.dataset.item = data.itemId;
        else delete slot.dataset.item;
      }
      eqWeapon.innerHTML = renderSlotContent((view.weapon || "") as ItemId | "", 1);
      eqWeapon.classList.toggle("empty", !view.weapon);
      eqArmor.innerHTML = renderSlotContent((view.armor || "") as ItemId | "", 1);
      eqArmor.classList.toggle("empty", !view.armor);
    },
  };
}

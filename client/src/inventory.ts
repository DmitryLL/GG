import { INVENTORY_SLOTS, ITEMS, type ItemId } from "@gg/shared";

export type InvSlotView = { itemId: ItemId; qty: number } | null;

const BASE = (import.meta as any).env?.BASE_URL ?? "/";
const ITEMS_URL = `${BASE}sprites/items.png`;

export function mountInventory() {
  const el = document.getElementById("inv") as HTMLDivElement;
  el.style.display = "grid";
  for (let i = 0; i < INVENTORY_SLOTS; i++) {
    const slot = document.createElement("div");
    slot.className = "inv-slot";
    slot.dataset.idx = String(i);
    el.appendChild(slot);
  }
  return {
    update(slots: InvSlotView[]) {
      for (let i = 0; i < INVENTORY_SLOTS; i++) {
        const slot = el.children[i] as HTMLDivElement;
        const data = slots[i] ?? null;
        slot.innerHTML = "";
        if (!data) continue;
        const def = ITEMS[data.itemId];
        if (!def) continue;
        const icon = document.createElement("div");
        icon.className = "icon";
        icon.style.background = `url(${ITEMS_URL}) -${def.icon * 16}px 0 / auto 100% no-repeat`;
        slot.appendChild(icon);
        const qty = document.createElement("span");
        qty.className = "qty";
        qty.textContent = String(data.qty);
        slot.appendChild(qty);
      }
    },
  };
}

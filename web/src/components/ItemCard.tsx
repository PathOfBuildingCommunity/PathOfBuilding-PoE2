import type { Item } from "../api/types";
import { rarityColor } from "./format";

const kindStyle: Record<string, string> = {
  enchant: "text-es",
  rune: "text-gold-soft",
  implicit: "text-ink-200",
  explicit: "text-magic",
};

export function ItemCard({ item }: { item: Item }) {
  const color = rarityColor[item.rarity] ?? "text-ink-200";
  return (
    <div className="text-center text-[13px]">
      <div className={`font-semibold ${color}`}>{item.title ?? item.name}</div>
      {item.title && <div className={color}>{item.baseName}</div>}
      <div className="mt-0.5 text-xs text-ink-400">
        {item.type}
        {item.itemLevel ? ` · ilvl ${item.itemLevel}` : ""}
        {item.quality ? ` · Q${item.quality}%` : ""}
      </div>
      {item.mods?.length ? (
        <ul className="mt-2 space-y-0.5 border-t border-ink-700 pt-2">
          {item.mods.map((m, i) => (
            <li key={i} className={m.supported ? kindStyle[m.kind] : "text-bad"} title={m.supported ? m.kind : "Not supported by PoB"}>
              {m.text}
            </li>
          ))}
        </ul>
      ) : null}
      {item.corrupted && <div className="mt-1 text-bad">Corrupted</div>}
    </div>
  );
}

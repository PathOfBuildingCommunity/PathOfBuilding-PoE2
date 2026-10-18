import { useMutation, useQuery } from "@tanstack/react-query";
import { Scale, Search, Trash2 } from "lucide-react";
import { useState } from "react";
import { api, qs } from "../../api/client";
import { useBuildMutation, useItems, useSlots } from "../../api/hooks";
import type { Comparison, Item, ItemCheck } from "../../api/types";
import { DeltaTable } from "../../components/DeltaTable";
import { ItemVerdict } from "../../components/ItemVerdict";
import { ErrorText } from "../../components/ErrorText";
import { ItemCard } from "../../components/ItemCard";

function UniqueSearch({ onPick }: { onPick: (text: string) => void }) {
  const [q, setQ] = useState("");
  const results = useQuery({
    queryKey: ["static", "uniques", q],
    queryFn: () => api.get<{ name: string; baseName: string; type: string }[]>(`/data/uniques${qs({ q, limit: 15 })}`),
    enabled: q.length >= 2,
  });
  const pick = async (name: string) => {
    const u = await api.get<{ text: string }>(`/data/uniques/${encodeURIComponent(name)}`);
    onPick(u.text);
    setQ("");
  };
  return (
    <div className="relative">
      <Search size={14} className="absolute left-2.5 top-2.5 text-ink-400" />
      <input className="input pl-8" placeholder="Search uniques…" value={q} onChange={(e) => setQ(e.target.value)} />
      {q.length >= 2 && results.data?.length ? (
        <ul className="panel absolute z-20 mt-1 max-h-72 w-full overflow-y-auto py-1 shadow-xl">
          {results.data.map((u) => (
            <li key={u.name}>
              <button className="w-full px-3 py-1.5 text-left text-sm hover:bg-ink-800" onClick={() => pick(u.name)}>
                <span className="text-unique">{u.name}</span>
                <span className="ml-2 text-xs text-ink-400">{u.baseName}</span>
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

function ItemWorkbench() {
  const slots = useSlots();
  const [text, setText] = useState("");
  const [slot, setSlot] = useState("");
  const parsed = useMutation({ mutationFn: (t: string) => api.post<Item & { primarySlot: string }>("/items/parse", { text: t }) });
  const compare = useMutation({ mutationFn: () => api.post<Comparison>("/items/compare", { text, slot: slot || null }) });
  // Full verdict: every damage skill (totems counted), Spirit/totems, requirements and skills the swap removes.
  const check = useMutation({ mutationFn: () => api.post<ItemCheck>("/items/check", { text, slot: slot || null }) });
  const equip = useBuildMutation(() => api.post("/items/equip", { text, slot: slot || null }));

  const run = () => {
    parsed.mutate(text);
    compare.mutate();
    check.mutate();
  };

  return (
    <div className="panel p-4">
      <h3 className="label mb-2">Item workbench</h3>
      <div className="grid gap-4 lg:grid-cols-2">
        <div className="space-y-2">
          <UniqueSearch onPick={(t) => { setText(t); parsed.reset(); compare.reset(); check.reset(); }} />
          <textarea
            className="input h-56 font-mono text-xs"
            placeholder="Paste an item copied from the game (Ctrl+C on the item) or from Path of Building…"
            value={text}
            onChange={(e) => setText(e.target.value)}
          />
          <div className="flex flex-wrap items-center gap-2">
            <select className="input w-auto" value={slot} onChange={(e) => setSlot(e.target.value)}>
              <option value="">Auto slot</option>
              {slots.data?.filter((s) => !/Socket/.test(s)).map((s) => <option key={s}>{s}</option>)}
            </select>
            <button className="btn" disabled={!text.trim() || compare.isPending} onClick={run}><Scale size={14} /> Check / compare</button>
            <button className="btn btn-primary" disabled={!text.trim() || equip.isPending}
              onClick={() => (!check.data?.warnings.length || confirm(`This item has warnings:\n\n${check.data.warnings.join("\n")}\n\nEquip anyway?`)) && equip.mutate(undefined, { onSuccess: () => { compare.reset(); check.reset(); } })}>
              Equip
            </button>
          </div>
          <ErrorText error={parsed.error ?? compare.error ?? check.error ?? equip.error} />
        </div>
        <div className="space-y-3">
          {check.isPending && <p className="text-sm text-ink-400">Checking every skill, Spirit and totems…</p>}
          {check.data && <ItemVerdict check={check.data} />}
          {parsed.data && <div className="rounded-md border border-ink-700 bg-ink-900 p-3"><ItemCard item={parsed.data} /></div>}
          {compare.data && (
            <div>
              <div className="label mb-1">Equipping in {compare.data.slot}</div>
              <DeltaTable comparison={compare.data} />
            </div>
          )}
          {!parsed.data && !compare.data && <p className="text-sm text-ink-400">Check before you buy: paste an item to see the verdict for every skill (totems counted), Spirit, defences and requirements.</p>}
        </div>
      </div>
    </div>
  );
}

export function ItemsTab() {
  const items = useItems();
  const unequip = useBuildMutation((slot: string) => api.del(`/items/${encodeURIComponent(slot)}`));
  // Show main gear slots even when empty; rune sockets, weapon swap and tree jewels only when filled.
  const equipped = items.data?.filter((s) => s.item || !(s.jewelNodeId || /Socket|Swap/.test(s.slot))) ?? [];
  return (
    <div className="mx-auto max-w-6xl space-y-4 p-4">
      <ItemWorkbench />
      <ErrorText error={items.error ?? unequip.error} />
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {equipped.map((s) => (
          <div key={s.slot} className="panel p-3">
            <div className="mb-2 flex items-center justify-between">
              <span className="label">{s.slot}</span>
              {s.item && (
                <button className="btn btn-ghost hover:text-bad" title="Unequip" onClick={() => unequip.mutate(s.slot)}><Trash2 size={14} /></button>
              )}
            </div>
            {s.item ? <ItemCard item={s.item} /> : <p className="text-center text-sm text-ink-400">Empty</p>}
          </div>
        ))}
      </div>
    </div>
  );
}

import { useQuery } from "@tanstack/react-query";
import { Search } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { api } from "../../api/client";
import { useBuildMutation, useConfig } from "../../api/hooks";
import type { ConfigOption } from "../../api/types";
import { ErrorText } from "../../components/ErrorText";

function OptionControl({ o, onChange }: { o: ConfigOption; onChange: (v: unknown) => void }) {
  const [draft, setDraft] = useState(o.value ?? "");
  useEffect(() => setDraft(o.value ?? ""), [o.value]);
  const changed = o.value !== undefined && o.value !== null && o.value !== o.default;
  const label = <span className={changed ? "text-gold-soft" : "text-ink-200"}>{o.label.replace(/:$/, "")}</span>;
  if (o.type === "check") {
    return (
      <label className="flex cursor-pointer items-start gap-2 py-1 text-sm">
        <input type="checkbox" className="mt-0.5 accent-[#c8a24a]" checked={o.value === true} onChange={(e) => onChange(e.target.checked)} />
        {label}
      </label>
    );
  }
  if (o.type === "list") {
    return (
      <label className="grid grid-cols-[1fr_12rem] items-center gap-2 py-1 text-sm">
        {label}
        <select className="input" value={String(o.value ?? o.default ?? "")} onChange={(e) => {
          const choice = o.choices?.find((c) => String(c.value) === e.target.value);
          onChange(choice ? choice.value : e.target.value);
        }}>
          {o.choices?.map((c) => <option key={String(c.value)} value={String(c.value)}>{c.label}</option>)}
        </select>
      </label>
    );
  }
  return (
    <label className="grid grid-cols-[1fr_7rem] items-center gap-2 py-1 text-sm">
      {label}
      <input
        className="input tabular-nums"
        inputMode="decimal"
        placeholder={o.default !== undefined && o.default !== null ? String(o.default) : ""}
        value={String(draft)}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={() => String(draft) !== String(o.value ?? "") && onChange(draft === "" ? null : Number(draft))}
        onKeyDown={(e) => e.key === "Enter" && (e.target as HTMLInputElement).blur()}
      />
    </label>
  );
}

function CustomMods() {
  const current = useQuery({ queryKey: ["custom-mods"], queryFn: () => api.get<{ text: string }>("/config/custom-mods") });
  const [text, setText] = useState("");
  useEffect(() => setText(current.data?.text ?? ""), [current.data]);
  const save = useBuildMutation(() => api.put("/config/custom-mods", { text }));
  return (
    <section className="panel p-4">
      <h3 className="label mb-2">Custom modifiers</h3>
      <textarea className="input h-28 font-mono text-xs" placeholder="One modifier per line, e.g. +20% to Fire Resistance" value={text} onChange={(e) => setText(e.target.value)} />
      <ErrorText error={save.error} />
      <div className="mt-2 flex justify-end">
        <button className="btn btn-primary" disabled={save.isPending || text === (current.data?.text ?? "")} onClick={() => save.mutate(undefined)}>Apply</button>
      </div>
    </section>
  );
}

export function ConfigTab() {
  const [all, setAll] = useState(false);
  const [filter, setFilter] = useState("");
  const config = useConfig(all);
  const set = useBuildMutation((values: Record<string, unknown>) => api.patch("/config", { values }));
  const sections = useMemo(() => {
    const f = filter.toLowerCase();
    const map = new Map<string, ConfigOption[]>();
    for (const o of config.data ?? []) {
      if (f && !o.label.toLowerCase().includes(f) && !o.var.toLowerCase().includes(f)) continue;
      const key = o.section ?? "Other";
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(o);
    }
    return [...map.entries()];
  }, [config.data, filter]);

  return (
    <div className="mx-auto max-w-6xl space-y-4 p-4">
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative w-72">
          <Search size={14} className="absolute left-2.5 top-2.5 text-ink-400" />
          <input className="input pl-8" placeholder="Filter options…" value={filter} onChange={(e) => setFilter(e.target.value)} />
        </div>
        <label className="flex items-center gap-2 text-sm text-ink-400">
          <input type="checkbox" checked={all} onChange={(e) => setAll(e.target.checked)} /> Show options not relevant to this build
        </label>
      </div>
      <ErrorText error={config.error ?? set.error} />
      <div className="columns-1 gap-4 lg:columns-2 2xl:columns-3">
        {sections.map(([name, opts]) => (
          <section key={name} className="panel mb-4 break-inside-avoid p-4">
            <h3 className="label mb-2">{name}</h3>
            {opts.map((o) => <OptionControl key={o.var} o={o} onChange={(v) => set.mutate({ [o.var]: v })} />)}
          </section>
        ))}
      </div>
      <CustomMods />
    </div>
  );
}

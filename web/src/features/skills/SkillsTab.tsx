import { useQuery } from "@tanstack/react-query";
import { Plus, Star, Trash2, X } from "lucide-react";
import { useState } from "react";
import { api, qs } from "../../api/client";
import { useBuildMutation, useSkills } from "../../api/hooks";
import type { SkillGroup } from "../../api/types";
import { ErrorText } from "../../components/ErrorText";

interface GemResult { id: string; name: string; support: boolean; tags?: string }

function GemPicker({ onPick }: { onPick: (name: string) => void }) {
  const [q, setQ] = useState("");
  const results = useQuery({
    queryKey: ["static", "gems", q],
    queryFn: () => api.get<GemResult[]>(`/data/gems${qs({ q, limit: 12 })}`),
    enabled: q.length >= 2,
  });
  return (
    <div className="relative">
      <input className="input" placeholder="Add gem…" value={q} onChange={(e) => setQ(e.target.value)} />
      {q.length >= 2 && results.data?.length ? (
        <ul className="panel absolute z-20 mt-1 max-h-72 w-full overflow-y-auto py-1 shadow-xl">
          {results.data.map((g) => (
            <li key={g.id}>
              <button className="w-full px-3 py-1.5 text-left text-sm hover:bg-ink-800" onClick={() => { onPick(g.name); setQ(""); }}>
                <span className={g.support ? "text-magic" : "text-gold-soft"}>{g.name}</span>
                <span className="ml-2 text-xs text-ink-400">{g.tags}</span>
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

function AddGroup() {
  const [gems, setGems] = useState<string[]>([]);
  const [label, setLabel] = useState("");
  const m = useBuildMutation(() => api.post<SkillGroup>("/skills", { gems, label: label || null, makeMain: true }));
  return (
    <div className="panel p-4">
      <h3 className="label mb-2">New skill group</h3>
      <div className="grid gap-2 sm:grid-cols-2">
        <GemPicker onPick={(g) => setGems((x) => [...x, g])} />
        <input className="input" placeholder="Label (optional)" value={label} onChange={(e) => setLabel(e.target.value)} />
      </div>
      {gems.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {gems.map((g, i) => (
            <span key={i} className="inline-flex items-center gap-1 rounded bg-ink-800 px-2 py-0.5 text-sm">
              {g}
              <button onClick={() => setGems((x) => x.filter((_, j) => j !== i))} aria-label={`Remove ${g}`}><X size={12} /></button>
            </span>
          ))}
        </div>
      )}
      <ErrorText error={m.error} />
      {m.data?.warnings?.map((w) => <p key={w} className="mt-2 text-sm text-rare">{w}</p>)}
      <div className="mt-3 flex justify-end">
        <button className="btn btn-primary" disabled={!gems.length || m.isPending} onClick={() => m.mutate(undefined, { onSuccess: () => { setGems([]); setLabel(""); } })}>
          <Plus size={14} /> Add group
        </button>
      </div>
    </div>
  );
}

function GroupCard({ g }: { g: SkillGroup }) {
  const setMain = useBuildMutation((skill?: number) => api.post(`/skills/${g.index}/main`, { skill }));
  const setEnabled = useBuildMutation((enabled: boolean) => api.patch(`/skills/${g.index}`, { enabled }));
  const remove = useBuildMutation(() => api.del(`/skills/${g.index}`));
  return (
    <div className={`panel p-4 ${g.isMain ? "border-gold/60" : ""} ${g.enabled ? "" : "opacity-60"}`}>
      <div className="flex items-start gap-2">
        <div className="min-w-0 flex-1">
          <div className="font-medium text-ink-200">{g.label ?? g.displayLabel ?? `Group ${g.index}`}</div>
          {g.slot && <div className="text-xs text-ink-400">{g.slot}</div>}
        </div>
        <button className={`btn btn-ghost ${g.isMain ? "text-gold" : ""}`} title="Set as main skill" onClick={() => setMain.mutate(undefined)}>
          <Star size={15} fill={g.isMain ? "currentColor" : "none"} />
        </button>
        <label className="flex items-center gap-1 text-xs text-ink-400">
          <input type="checkbox" checked={g.enabled} onChange={(e) => setEnabled.mutate(e.target.checked)} /> on
        </label>
        <button className="btn btn-ghost hover:text-bad" title="Remove group" onClick={() => confirm("Remove this skill group?") && remove.mutate(undefined)}>
          <Trash2 size={15} />
        </button>
      </div>
      <ul className="mt-2 space-y-0.5 text-sm">
        {g.gems.map((gem, i) => (
          <li key={i} className="flex justify-between gap-2">
            <span className={!gem.recognised ? "text-bad" : gem.support ? "text-magic" : "text-gold-soft"} title={gem.recognised ? undefined : "Not recognised by PoB"}>
              {gem.name}
            </span>
            <span className="tabular-nums text-ink-400">{gem.level}/{gem.quality}</span>
          </li>
        ))}
      </ul>
      {g.isMain && g.activeSkills.length > 1 && (
        <select className="input mt-2" value={g.activeSkills.find((s) => s.isMain)?.index} onChange={(e) => setMain.mutate(Number(e.target.value))}>
          {g.activeSkills.map((s) => <option key={s.index} value={s.index}>{s.name}</option>)}
        </select>
      )}
      <ErrorText error={setMain.error ?? setEnabled.error ?? remove.error} />
    </div>
  );
}

export function SkillsTab() {
  const skills = useSkills();
  return (
    <div className="mx-auto max-w-5xl space-y-4 p-4">
      <AddGroup />
      <ErrorText error={skills.error} />
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {skills.data?.map((g) => <GroupCard key={g.index} g={g} />)}
      </div>
      {skills.data && !skills.data.length && <p className="text-sm text-ink-400">No skills yet.</p>}
    </div>
  );
}

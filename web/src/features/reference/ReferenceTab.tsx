import { useQuery, useQueryClient } from "@tanstack/react-query";
import { BookOpen, ExternalLink, Plus, Trash2, Upload } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { api, qs } from "../../api/client";
import { useBuildMutation, useReference } from "../../api/hooks";
import type { ImpactStep, ReferenceCompare, ReferenceImpact, ReferenceSummary } from "../../api/types";
import { DeltaTable } from "../../components/DeltaTable";
import { ErrorText } from "../../components/ErrorText";

const pct = (v: number) => `${v > 0 ? "+" : ""}${v.toFixed(1)}%`;
const tone = (v: number) => (v > 0.05 ? "text-good" : v < -0.05 ? "text-bad" : "text-ink-400");

function Card({ title, children, actions }: { title: string; children: ReactNode; actions?: ReactNode }) {
  return (
    <section className="panel p-4">
      <div className="mb-3 flex items-center gap-2">
        <h3 className="label">{title}</h3>
        <div className="ml-auto flex gap-2">{actions}</div>
      </div>
      {children}
    </section>
  );
}

function Stat({ label, value, sub, good }: { label: string; value: ReactNode; sub?: ReactNode; good?: boolean }) {
  return (
    <div className="rounded border border-ink-700 bg-ink-850 px-3 py-2">
      <div className="text-xs text-ink-400">{label}</div>
      <div className={`text-lg font-semibold ${good === undefined ? "text-ink-200" : good ? "text-good" : "text-rare"}`}>{value}</div>
      {sub && <div className="text-xs text-ink-400">{sub}</div>}
    </div>
  );
}

function Upload_({ onDone, compact }: { onDone?: () => void; compact?: boolean }) {
  const input = useRef<HTMLInputElement>(null);
  const qc = useQueryClient();
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const [drag, setDrag] = useState(false);
  const upload = async (file: File) => {
    setBusy(true);
    setError(null);
    try {
      await api.put<ReferenceSummary>("/reference", { content: await file.text() });
      await qc.invalidateQueries({ predicate: (q) => String(q.queryKey[0]).startsWith("reference") });
      onDone?.();
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  };
  const pick = (
    <input ref={input} type="file" accept=".build,.json,application/json" className="hidden"
      onChange={(e) => { const f = e.target.files?.[0]; if (f) void upload(f); e.target.value = ""; }} />
  );
  if (compact) {
    return (
      <>
        {pick}
        <button className="btn" disabled={busy} onClick={() => input.current?.click()}><Upload size={14} /> Replace</button>
        <ErrorText error={error} />
      </>
    );
  }
  return (
    <div
      className={`panel grid place-items-center gap-3 border-2 border-dashed p-10 text-center ${drag ? "border-gold" : "border-ink-700"}`}
      onDragOver={(e) => { e.preventDefault(); setDrag(true); }}
      onDragLeave={() => setDrag(false)}
      onDrop={(e) => { e.preventDefault(); setDrag(false); const f = e.dataTransfer.files[0]; if (f) void upload(f); }}
    >
      {pick}
      <BookOpen className="text-gold" size={28} />
      <div>
        <div className="font-semibold text-ink-200">Compare your character with a build guide</div>
        <p className="mt-1 max-w-md text-sm text-ink-400">
          Import your character with <b>Import</b> (share code), then drop a guide's PoE2 BuildPlanner <code>.build</code> file here
          (Maxroll and the in-game planner export these). You'll get the passive, skill and gear gaps, and the best next steps ranked by gain per point.
        </p>
      </div>
      <button className="btn btn-primary" disabled={busy} onClick={() => input.current?.click()}>
        <Upload size={14} /> {busy ? "Loading…" : "Choose .build file"}
      </button>
      <ErrorText error={error} />
    </div>
  );
}

function StepTable({ rows, action, empty }: { rows: ImpactStep[]; action?: (r: ImpactStep) => ReactNode; empty: string }) {
  if (!rows.length) return <p className="text-sm text-ink-400">{empty}</p>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className="text-left text-xs text-ink-400">
          <tr><th className="py-1 pr-3 font-normal">Node</th><th className="pr-3 font-normal">Points</th><th className="pr-3 font-normal">DPS</th><th className="pr-3 font-normal">EHP</th><th className="pr-3 font-normal">Life / ES</th><th /></tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} className="border-t border-ink-800">
              <td className="py-1.5 pr-3">
                <span className={r.type === "Keystone" ? "text-rare" : "text-gold-soft"}>{r.name}</span>
                <span className="ml-2 text-xs text-ink-400">{r.ascendancy ?? r.type}</span>
              </td>
              <td className="pr-3 tabular-nums">{Math.abs(r.points)}</td>
              <td className={`pr-3 tabular-nums ${tone(r.dpsPercent)}`}>{pct(r.dpsPercent)}</td>
              <td className={`pr-3 tabular-nums ${tone(r.ehpPercent)}`}>{pct(r.ehpPercent)}</td>
              <td className="pr-3 tabular-nums text-ink-400">
                <span className={tone(r.lifeDelta)}>{r.lifeDelta ? `${r.lifeDelta > 0 ? "+" : ""}${Math.round(r.lifeDelta)}` : "0"}</span>
                {" / "}
                <span className={tone(r.esDelta)}>{r.esDelta ? `${r.esDelta > 0 ? "+" : ""}${Math.round(r.esDelta)}` : "0"}</span>
              </td>
              <td className="text-right">{action?.(r)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Note({ text }: { text?: string }) {
  const [open, setOpen] = useState(false);
  if (!text) return null;
  const short = text.length <= 160 && !text.includes("\n");
  return (
    <div className="mt-1 text-xs text-ink-400">
      {short || open ? <p className="whitespace-pre-wrap">{text}</p> : <p className="line-clamp-2 whitespace-pre-wrap">{text}</p>}
      {!short && <button className="mt-0.5 text-gold hover:underline" onClick={() => setOpen((o) => !o)}>{open ? "Less" : "Guide notes"}</button>}
    </div>
  );
}

function Loaded({ summary }: { summary: ReferenceSummary }) {
  const [level, setLevel] = useState<number | null>(null);
  const qc = useQueryClient();
  const compare = useQuery({
    queryKey: ["reference-compare", level],
    queryFn: () => api.get<ReferenceCompare>(`/reference/compare${qs({ level })}`),
  });
  const impact = useQuery({
    queryKey: ["reference-impact", level],
    queryFn: () => api.get<ReferenceImpact>(`/reference/impact${qs({ level, limit: 40 })}`),
  });
  const allocate = useBuildMutation((ids: number[]) => api.post("/tree/allocate", { ids }));
  const deallocate = useBuildMutation((ids: number[]) => api.post("/tree/deallocate", { ids }));
  const applyTree = useBuildMutation(() => api.post(`/reference/apply-tree${qs({ level })}`));
  const clear = async () => {
    await api.del("/reference");
    await qc.invalidateQueries({ predicate: (q) => String(q.queryKey[0]).startsWith("reference") });
  };
  const c = compare.data, i = impact.data;
  const ascMatch = c?.ascendancy ? c.ascendancy.name === c.current.ascendClassName : undefined;
  const supportsMissing = c?.skills.reduce((n, s) => n + s.missingSupports.length, 0) ?? 0;
  const uniques = c?.items.filter((it) => it.uniqueName) ?? [];

  return (
    <div className="space-y-4 p-4">
      <section className="panel flex flex-wrap items-start gap-3 p-4">
        <BookOpen className="mt-0.5 shrink-0 text-gold" size={20} />
        <div className="min-w-0 flex-1">
          <div className="font-semibold text-gold-soft">{summary.name ?? "Reference build"}</div>
          <div className="text-xs text-ink-400">
            {summary.author && <>by {summary.author} · </>}
            {c?.ascendancy ? `${c.ascendancy.name} (${c.ascendancy.className})` : summary.ascendancy}
            {summary.link && (
              <a className="ml-2 inline-flex items-center gap-0.5 text-gold hover:underline" href={summary.link} target="_blank" rel="noreferrer">
                guide <ExternalLink size={11} />
              </a>
            )}
          </div>
          <Note text={c?.description} />
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <label className="text-xs text-ink-400" htmlFor="ref-stage">Stage</label>
          <select id="ref-stage" className="input w-auto" value={level ?? ""} onChange={(e) => setLevel(e.target.value ? Number(e.target.value) : null)}>
            <option value="">Character level</option>
            {c?.stages.map((s) => <option key={`${s.from}-${s.to}`} value={s.to}>Level {s.from}–{s.to}</option>)}
          </select>
          <Upload_ compact />
          <button className="btn" onClick={() => void clear()} title="Remove reference"><Trash2 size={14} /></button>
        </div>
      </section>
      <ErrorText error={compare.error ?? impact.error ?? allocate.error ?? deallocate.error ?? applyTree.error} />

      {c && (
        <div className="grid grid-cols-2 gap-2 md:grid-cols-3 xl:grid-cols-6">
          <Stat label="Guide passives taken" value={`${c.passives.matched} / ${c.passives.referencePoints + c.passives.referenceAscendancyPoints}`} good={c.passives.missing.length === 0} />
          <Stat label="Missing passives" value={c.passives.missing.length} sub={`${c.passives.missing.filter((n) => n.type === "Notable" || n.type === "Keystone").length} notables/keystones`} good={c.passives.missing.length === 0} />
          <Stat label="Not in guide" value={c.passives.extra.length} sub={c.passives.weaponSetMismatch ? `${c.passives.weaponSetMismatch} on a different weapon set` : "refund candidates"} good={c.passives.extra.length === 0} />
          <Stat label="Ascendancy" value={c.ascendancy?.name ?? "?"} sub={ascMatch ? "matches" : `you: ${c.current.ascendClassName ?? "none"}`} good={ascMatch} />
          <Stat label="Skills" value={`${c.skills.filter((s) => s.found).length} / ${c.skills.length}`} sub={`${supportsMissing} supports missing`} good={supportsMissing === 0 && c.skills.every((s) => s.found)} />
          <Stat label="Guide uniques" value={`${uniques.filter((u) => u.match).length} / ${uniques.length}`} good={uniques.every((u) => u.match)} />
        </div>
      )}

      <Card
        title="Respec to the guide's tree"
        actions={
          <button className="btn" disabled={applyTree.isPending || !i}
            onClick={() => confirm("Replace your passive tree with the guide's tree? (Undo by re-importing your build.)") && applyTree.mutate(undefined)}>
            Apply guide tree
          </button>
        }
      >
        {impact.isLoading ? <p className="text-sm text-ink-400">Calculating…</p> : i && (
          <>
            <div className="mb-3 grid grid-cols-2 gap-2 md:grid-cols-4">
              <Stat label="DPS" value={<span className={tone(i.fullTree.dpsPercent)}>{pct(i.fullTree.dpsPercent)}</span>} />
              <Stat label="Effective HP" value={<span className={tone(i.fullTree.ehpPercent)}>{pct(i.fullTree.ehpPercent)}</span>} />
              <Stat label="Life / ES" value={`${Math.round(i.fullTree.lifeDelta)} / ${Math.round(i.fullTree.esDelta)}`} />
              <Stat label="Nodes" value={`+${i.fullTree.added} −${i.fullTree.removed}`} />
            </div>
            <details>
              <summary className="cursor-pointer text-sm text-ink-400">All stat changes</summary>
              <div className="mt-2"><DeltaTable comparison={{ changes: i.fullTree.changes }} /></div>
            </details>
          </>
        )}
      </Card>

      <Card title="Next steps (guide nodes ranked by gain per point)">
        <StepTable
          rows={i?.steps ?? []}
          empty={impact.isLoading ? "Calculating…" : "You have every guide notable reachable from your tree."}
          action={(r) => (
            <button className="btn" disabled={allocate.isPending} onClick={() => r.path && allocate.mutate(r.path)} title="Allocate this node and its path">
              <Plus size={13} /> Allocate
            </button>
          )}
        />
      </Card>

      <Card title="Your notables the guide doesn't take">
        <StepTable
          rows={i?.extras ?? []}
          empty={impact.isLoading ? "Calculating…" : "None."}
          action={(r) => (
            <button className="btn" disabled={deallocate.isPending} onClick={() => deallocate.mutate([r.id])} title="Refund (also removes nodes that depend on it)">
              Refund
            </button>
          )}
        />
        {c && c.passives.extra.length > (i?.extras.length ?? 0) && (
          <p className="mt-2 text-xs text-ink-400">
            Plus {c.passives.extra.length - (i?.extras.length ?? 0)} small nodes off the guide's path: {c.passives.extra.filter((n) => n.type !== "Notable" && n.type !== "Keystone").map((n) => n.name).join(", ")}
          </p>
        )}
      </Card>

      {c && (
        <Card title="Skills and supports">
          <div className="grid gap-2 lg:grid-cols-2">
            {c.skills.map((s, idx) => (
              <div key={`${s.name}-${idx}`} className="rounded border border-ink-700 bg-ink-850 p-3">
                <div className="flex items-center gap-2">
                  <span className={s.found ? "font-semibold text-gold-soft" : "font-semibold text-bad"}>{s.name}</span>
                  {!s.found && <span className="text-xs text-bad">not in your build</span>}
                  {s.found && s.enabled === false && <span className="text-xs text-rare">disabled</span>}
                </div>
                <div className="mt-1 flex flex-wrap gap-1 text-xs">
                  {s.supports.map((sup) => {
                    const missing = s.missingSupports.includes(sup);
                    const tier = s.tierDifferences.find((t) => t.reference === sup);
                    return (
                      <span key={sup} className={`rounded px-1.5 py-0.5 ${missing ? "bg-bad/15 text-bad" : "bg-ink-800 text-magic"}`}>
                        {sup}{tier && <span className="text-ink-400"> (you: {tier.current})</span>}
                      </span>
                    );
                  })}
                  {s.extraSupports.map((sup) => (
                    <span key={sup} className="rounded bg-ink-800 px-1.5 py-0.5 text-ink-400 line-through decoration-ink-600">{sup}</span>
                  ))}
                </div>
                <Note text={s.note} />
              </div>
            ))}
          </div>
          <p className="mt-2 text-xs text-ink-400">Red: support the guide uses that you don't. Struck through: support you use that the guide doesn't.</p>
          {c.unknownGems.length > 0 && <p className="mt-1 text-xs text-rare">Unrecognised gems: {c.unknownGems.join(", ")}</p>}
        </Card>
      )}

      {c && (
        <Card title="Gear">
          <div className="divide-y divide-ink-800">
            {c.items.map((it, idx) => (
              <div key={`${it.slot}-${idx}`} className="grid gap-1 py-2 md:grid-cols-[9rem_1fr]">
                <div className="text-sm text-ink-400">{it.slot}</div>
                <div className="min-w-0">
                  <div className="flex flex-wrap items-baseline gap-x-2 text-sm">
                    {it.uniqueName && (
                      <span className={it.match ? "text-good" : "text-unique"}>{it.match ? "✓ " : "Guide: "}{it.uniqueName}</span>
                    )}
                    <span className="text-ink-200">{it.equipped ? (it.match ? "" : `You: ${it.equipped.name}`) : <span className="text-ink-400">empty</span>}</span>
                  </div>
                  <Note text={it.note} />
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}
      {c?.passives.unknown.length ? <p className="text-xs text-rare">Unrecognised passives (different tree version?): {c.passives.unknown.join(", ")}</p> : null}
    </div>
  );
}

export function ReferenceTab() {
  const ref = useReference();
  if (ref.isLoading) return <p className="p-4 text-sm text-ink-400">Loading…</p>;
  return ref.data ? <Loaded summary={ref.data} /> : <div className="p-4"><Upload_ /><ErrorText error={ref.error} /></div>;
}

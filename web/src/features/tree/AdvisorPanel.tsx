import { ChevronDown, ChevronUp, Crosshair, Lightbulb } from "lucide-react";
import { useState } from "react";
import { api } from "../../api/client";
import { useBuildMutation } from "../../api/hooks";
import type { Advice } from "../../api/types";
import { ErrorText } from "../../components/ErrorText";

const SHORT: Record<string, string> = { Strength: "Str", Dexterity: "Dex", Intelligence: "Int" };
const pct = (v: number) => `${v > 0 ? "+" : ""}${v.toFixed(1)}%`;

function Dot({ color }: { color: string }) {
  return <span className="mt-1.5 inline-block h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: color }} />;
}

export function AdvisorPanel({
  advice, loading, error, metric, onMetric, onShow,
}: {
  advice?: Advice;
  loading: boolean;
  error: unknown;
  metric: Advice["metric"];
  onMetric: (m: Advice["metric"]) => void;
  onShow: (id: number) => void;
}) {
  const [open, setOpen] = useState(true);
  const [showAttrs, setShowAttrs] = useState(false);
  const allocate = useBuildMutation((ids: number[]) => api.post("/tree/allocate", { ids }));
  const refund = useBuildMutation((id: number) => api.post("/tree/deallocate", { ids: [id] }));
  const attrs = useBuildMutation((changes: { id: number; attribute: string }[]) => api.post("/tree/attributes", { changes }));
  const busy = allocate.isPending || refund.isPending || attrs.isPending;
  const next = advice?.next;
  const move = advice?.move;
  const switches = advice?.attributes.nodes.filter((n) => n.recommended !== n.current) ?? [];
  const totals = advice?.attributes.totals;

  return (
    <div className="panel absolute left-3 top-3 z-10 w-80 max-w-[calc(100%-1.5rem)] text-sm shadow-xl">
      <button className="flex w-full items-center gap-2 px-3 py-2" onClick={() => setOpen((o) => !o)}>
        <Lightbulb size={15} className="text-gold" />
        <span className="font-semibold text-gold-soft">Advisor</span>
        <span className="truncate text-xs text-ink-400">
          {advice ? (advice.mode === "guide" ? `following ${advice.guide?.name ?? "guide"}` : "best value nearby") : loading ? "thinking…" : ""}
        </span>
        <span className="ml-auto text-ink-400">{open ? <ChevronUp size={14} /> : <ChevronDown size={14} />}</span>
      </button>
      {open && (
        <div className="space-y-3 border-t border-ink-700 px-3 py-3">
          <div className="flex items-center gap-2 text-xs text-ink-400">
            Optimise for
            {(["balanced", "dps", "ehp"] as const).map((m) => (
              <button key={m} onClick={() => onMetric(m)}
                className={`rounded px-1.5 py-0.5 ${metric === m ? "bg-gold/20 text-gold-soft" : "hover:text-ink-200"}`}>
                {m === "balanced" ? "Balanced" : m === "dps" ? "Damage" : "Defence"}
              </button>
            ))}
          </div>
          <ErrorText error={error ?? allocate.error ?? refund.error ?? attrs.error} />
          {loading && !advice && <p className="text-xs text-ink-400">Measuring candidate nodes…</p>}

          {advice && (next ? (
            <div className="flex gap-2">
              <Dot color="#4ade80" />
              <div className="min-w-0 flex-1">
                <div className="text-xs uppercase tracking-wide text-[#4ade80]">Next point</div>
                <div className="text-ink-200">
                  {next.first.name ?? `Node ${next.first.id}`}
                  {next.first.id !== next.target.id && <span className="text-ink-400"> → {next.target.name}</span>}
                </div>
                <div className="text-xs text-ink-400">
                  {next.points} pt{next.points === 1 ? "" : "s"} · {pct(next.dpsPercent)} DPS · {pct(next.ehpPercent)} EHP
                </div>
                <div className="mt-1.5 flex flex-wrap gap-1.5">
                  <button className="btn btn-primary" disabled={busy} onClick={() => allocate.mutate([next.first.id])}>Allocate next point</button>
                  {next.points > 1 && <button className="btn" disabled={busy} onClick={() => allocate.mutate(next.path)}>All {next.points}</button>}
                  <button className="btn" onClick={() => onShow(next.first.id)} title="Show on tree"><Crosshair size={13} /></button>
                </div>
              </div>
            </div>
          ) : <p className="text-xs text-ink-400">No worthwhile node within reach{advice.mode === "guide" ? " (you have the guide's notables)" : ""}.</p>)}

          {move && (
            <div className="flex gap-2">
              <Dot color="#f87171" />
              <div className="min-w-0 flex-1">
                <div className="text-xs uppercase tracking-wide text-[#f87171]">Move a point</div>
                <div className="text-ink-200">Refund {move.refund.node.name ?? `node ${move.refund.node.id}`}</div>
                <p className="text-xs text-ink-400">{move.reason}</p>
                <div className="mt-1.5 flex gap-1.5">
                  <button className="btn" disabled={busy} onClick={() => refund.mutate(move.refund.node.id)}>Refund it</button>
                  <button className="btn" onClick={() => onShow(move.refund.node.id)} title="Show on tree"><Crosshair size={13} /></button>
                </div>
              </div>
            </div>
          )}

          {advice && (
            <div className="flex gap-2">
              <Dot color="#fbbf24" />
              <div className="min-w-0 flex-1">
                <div className="text-xs uppercase tracking-wide text-[#fbbf24]">Attribute nodes</div>
                {totals && (
                  <div className="text-xs text-ink-400">
                    {Object.entries(totals).map(([k, t]) => (
                      <span key={k} className={`mr-2 ${t.value < t.required ? "text-bad" : ""}`}>{SHORT[k]} {t.value}/{t.required}</span>
                    ))}
                  </div>
                )}
                {switches.length ? (
                  <>
                    <div className="text-ink-200">{switches.length} to switch</div>
                    <ul className="mt-1 space-y-1">
                      {(showAttrs ? switches : switches.slice(0, 2)).map((n) => (
                        <li key={n.id} className="text-xs">
                          <button className="text-left hover:underline" onClick={() => onShow(n.id)}>
                            <span className="text-ink-200">{n.current === "unset" ? "Unassigned" : `+5 ${SHORT[n.current]}`} → +5 {SHORT[n.recommended]}</span>
                          </button>
                          <div className="text-ink-400">{n.reason}</div>
                        </li>
                      ))}
                    </ul>
                    {switches.length > 2 && (
                      <button className="mt-1 text-xs text-gold hover:underline" onClick={() => setShowAttrs((s) => !s)}>
                        {showAttrs ? "Show less" : `Show all ${switches.length}`}
                      </button>
                    )}
                    <div className="mt-1.5">
                      <button className="btn" disabled={busy}
                        onClick={() => attrs.mutate(switches.map((n) => ({ id: n.id, attribute: n.recommended })))}>
                        Apply {switches.length === 1 ? "switch" : `all ${switches.length}`}
                      </button>
                    </div>
                  </>
                ) : (
                  <p className="text-xs text-ink-400">All {advice.attributes.nodes.length} set well. Hover one for details.</p>
                )}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

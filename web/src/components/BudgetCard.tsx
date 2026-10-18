import { AlertTriangle } from "lucide-react";
import { useBudget } from "../api/hooks";
import { fmtNum } from "./format";

/** Sidebar: Spirit in use, totems you can actually keep up, and main-skill DPS counting every totem. */
export function BudgetCard() {
  const { data: b } = useBudget();
  if (!b || (!b.spirit && b.totems === undefined)) return null;
  const used = b.spirit - b.free;
  const pct = b.spirit > 0 ? Math.min(100, (used / b.spirit) * 100) : 0;
  return (
    <section className="mx-4 mt-4 rounded border border-ink-700 bg-ink-850 p-3 text-[13px]">
      <div className="flex items-baseline justify-between">
        <span className="label">Spirit</span>
        <span className={`tabular-nums ${b.free < 0 ? "text-bad" : "text-ink-200"}`}>{fmtNum(used)} / {fmtNum(b.spirit)} <span className="text-ink-400">({fmtNum(b.free)} free)</span></span>
      </div>
      <div className="mt-1 h-1.5 overflow-hidden rounded bg-ink-700">
        <div className={`h-full ${b.free < 0 ? "bg-bad" : "bg-gold"}`} style={{ width: `${pct}%` }} />
      </div>
      {b.reservations.length > 0 && (
        <ul className="mt-1.5 space-y-0.5 text-xs text-ink-400">
          {b.reservations.map((r) => (
            <li key={r.name} className="flex justify-between gap-2"><span className="truncate">{r.name}{r.count ? ` ×${r.count}` : ""}</span><span className="tabular-nums">{fmtNum(r.spirit)}</span></li>
          ))}
        </ul>
      )}
      {b.totems !== undefined && (
        <>
          <div className="mt-2 flex items-baseline justify-between">
            <span className="label">Totems</span>
            <span className={`tabular-nums ${b.spiritLimited ? "text-rare" : "text-ink-200"}`}>{b.totems} / {b.totemCap}</span>
          </div>
          {b.spiritLimited && (
            <p className="mt-1 flex gap-1 text-xs text-rare">
              <AlertTriangle size={12} className="mt-0.5 shrink-0" />
              Spirit-limited: each totem reserves {fmtNum(b.totemCost ?? 0)}. {b.totemCost ? `${fmtNum(b.totemCost - Math.max(0, b.free))} more Spirit for the next one.` : ""}
            </p>
          )}
          <div className="mt-2 flex items-baseline justify-between" title="PoB shows totem skill DPS per totem; this counts every totem your Spirit can keep up">
            <span className="text-ink-400">DPS, all totems</span>
            <span className="tabular-nums text-gold-soft">{fmtNum(b.effectiveDps)}</span>
          </div>
          <div className="flex items-baseline justify-between text-xs text-ink-400">
            <span>per totem</span>
            <span className="tabular-nums">{fmtNum(b.perTotemDps ?? 0)}</span>
          </div>
        </>
      )}
    </section>
  );
}

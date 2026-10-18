import { AlertTriangle } from "lucide-react";
import type { Comparison } from "../api/types";
import { fmtNum } from "./format";

export function DeltaTable({ comparison, empty = "No stat changes." }: { comparison?: Comparison; empty?: string }) {
  if (!comparison) return null;
  const b = comparison.budget;
  const totemsChanged = b?.before.totems !== undefined && b.before.totems !== b.after.totems;
  const dpsChanged = !!b && b.before.totems !== undefined && Math.round(b.effectiveBefore) !== Math.round(b.effectiveAfter);
  const spiritChanged = !!b && b.before.spirit !== b.after.spirit;
  if (!comparison.changes.length && !b?.warnings.length && !totemsChanged && !spiritChanged) return <p className="text-sm text-ink-400">{empty}</p>;
  const sign = (v: number) => (v > 0 ? "+" : "");
  return (
    <>
    {b?.warnings.length ? (
      <ul className="mb-2 space-y-1 text-[13px]">
        {b.warnings.map((w) => <li key={w} className="flex gap-1.5 text-bad"><AlertTriangle size={13} className="mt-0.5 shrink-0" /> {w}</li>)}
      </ul>
    ) : null}
    <table className="w-full text-[13px]">
      <tbody>
        {dpsChanged && b && (
          <tr className="border-b border-ink-700/50" title="PoB shows totem DPS per totem; this counts every totem your Spirit can keep up">
            <td className="py-1 pr-2 font-semibold text-gold-soft">DPS, all totems</td>
            <td className="py-1 pr-2 text-right tabular-nums text-ink-400">{fmtNum(b.effectiveBefore)} → {fmtNum(b.effectiveAfter)}</td>
            <td className={`py-1 text-right tabular-nums ${b.effectiveAfter >= b.effectiveBefore ? "text-good" : "text-bad"}`}>
              {b.effectiveBefore ? `${sign(b.effectiveAfter - b.effectiveBefore)}${((b.effectiveAfter / b.effectiveBefore - 1) * 100).toFixed(1)}%` : ""}
            </td>
          </tr>
        )}
        {totemsChanged && b && (
          <tr className="border-b border-ink-700/50">
            <td className="py-1 pr-2 text-ink-200">Totems</td>
            <td className="py-1 pr-2 text-right tabular-nums text-ink-400">{b.before.totems} → {b.after.totems}</td>
            <td className={`py-1 text-right tabular-nums ${(b.after.totems ?? 0) >= (b.before.totems ?? 0) ? "text-good" : "text-bad"}`}>{sign((b.after.totems ?? 0) - (b.before.totems ?? 0))}{(b.after.totems ?? 0) - (b.before.totems ?? 0)}</td>
          </tr>
        )}
        {spiritChanged && b && (
          <tr className="border-b border-ink-700/50">
            <td className="py-1 pr-2 text-ink-200">Spirit</td>
            <td className="py-1 pr-2 text-right tabular-nums text-ink-400">{fmtNum(b.before.spirit)} → {fmtNum(b.after.spirit)}</td>
            <td className={`py-1 text-right tabular-nums ${b.after.spirit >= b.before.spirit ? "text-good" : "text-bad"}`}>{sign(b.after.spirit - b.before.spirit)}{fmtNum(b.after.spirit - b.before.spirit)}</td>
          </tr>
        )}
        {comparison.changes.map((c) => (
          <tr key={c.stat + c.label} className="border-b border-ink-700/50 last:border-0">
            <td className="py-1 pr-2 text-ink-200">{c.label}</td>
            <td className="py-1 pr-2 text-right tabular-nums text-ink-400">{fmtNum(c.before)} → {fmtNum(c.after)}</td>
            <td className={`py-1 text-right tabular-nums ${c.better ? "text-good" : "text-bad"}`}>
              {c.delta > 0 ? "+" : ""}{fmtNum(c.delta)}
              {c.percent !== undefined && c.percent !== null ? <span className="text-ink-400"> ({c.percent > 0 ? "+" : ""}{c.percent.toFixed(1)}%)</span> : null}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
    </>
  );
}

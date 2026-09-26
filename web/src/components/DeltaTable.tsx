import type { Comparison } from "../api/types";
import { fmtNum } from "./format";

export function DeltaTable({ comparison, empty = "No stat changes." }: { comparison?: Comparison; empty?: string }) {
  if (!comparison) return null;
  if (!comparison.changes.length) return <p className="text-sm text-ink-400">{empty}</p>;
  return (
    <table className="w-full text-[13px]">
      <tbody>
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
  );
}

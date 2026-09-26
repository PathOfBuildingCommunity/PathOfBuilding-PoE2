import type { StatRow, StatSummary } from "../api/types";
import { statColor, statGroup } from "./format";

function Rows({ rows }: { rows: StatRow[] }) {
  return (
    <dl className="space-y-0.5">
      {rows.map((r) => (
        <div key={`${r.stat}-${r.label}`} className="flex items-baseline justify-between gap-3 text-[13px] leading-5" title={r.warning}>
          <dt className={`truncate ${statColor(r.label)}`}>{r.label}</dt>
          <dd className={`shrink-0 tabular-nums ${r.warning ? "text-bad" : "text-ink-200"}`}>
            {r.formatted}
            {r.overCap ? <span className="text-ink-400"> (+{Math.round(r.overCap)}%)</span> : null}
          </dd>
        </div>
      ))}
    </dl>
  );
}

export function StatPanel({ stats }: { stats?: StatSummary }) {
  if (!stats) return <div className="p-4 text-sm text-ink-400">Loading stats…</div>;
  const groups = { offence: [] as StatRow[], defence: [] as StatRow[], other: [] as StatRow[] };
  for (const row of stats.player) groups[statGroup(row.label)].push(row);
  return (
    <div className="space-y-4 p-4">
      {(["offence", "defence", "other"] as const).map((g) =>
        groups[g].length ? (
          <section key={g}>
            <h3 className="label mb-1.5">{g}</h3>
            <Rows rows={groups[g]} />
          </section>
        ) : null,
      )}
      {stats.minion?.length ? (
        <section>
          <h3 className="label mb-1.5">Minion</h3>
          <Rows rows={stats.minion} />
        </section>
      ) : null}
      {stats.player.some((r) => r.warning) && (
        <section>
          <h3 className="label mb-1.5 text-bad">Warnings</h3>
          <ul className="space-y-1 text-xs text-bad">
            {stats.player.filter((r) => r.warning).map((r) => <li key={r.label}>{r.warning}</li>)}
          </ul>
        </section>
      )}
    </div>
  );
}

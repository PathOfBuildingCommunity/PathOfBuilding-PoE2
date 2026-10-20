import { AlertTriangle, Loader2, Shield, Swords } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import type { Budget, Resource } from "../api/types";
import { useBudget } from "../api/hooks";
import { fmtCompact, fmtNum } from "./format";

const RESOURCE: Record<string, { bar: string; text: string }> = {
  Mana: { bar: "bg-mana", text: "text-mana" },
  Spirit: { bar: "bg-gold", text: "text-gold-soft" },
  Rage: { bar: "bg-bad", text: "text-bad" },
  Ward: { bar: "bg-es", text: "text-es" },
  Life: { bar: "bg-life", text: "text-life" },
  ES: { bar: "bg-es", text: "text-es" },
};

/** Change chips for the headline numbers after a recalculation; they fade after a few seconds. */
function useChanges(b?: Budget) {
  const last = useRef<{ dps: number; ehp: number } | null>(null);
  const [chips, setChips] = useState<{ dps?: number; ehp?: number }>({});
  useEffect(() => {
    if (!b) return;
    const prev = last.current;
    last.current = { dps: b.effectiveDps, ehp: b.ehp };
    if (!prev) return;
    const pct = (a: number, z: number) => (a > 0 ? ((z - a) / a) * 100 : 0);
    const next = { dps: pct(prev.dps, b.effectiveDps), ehp: pct(prev.ehp, b.ehp) };
    // Ignore no-ops and wholesale changes (another build imported).
    const keep = (v: number) => (Math.abs(v) >= 0.05 && Math.abs(v) < 300 ? v : undefined);
    const shown = { dps: keep(next.dps), ehp: keep(next.ehp) };
    if (shown.dps === undefined && shown.ehp === undefined) return;
    setChips(shown);
    const t = setTimeout(() => setChips({}), 5000);
    return () => clearTimeout(t);
  }, [b]);
  return chips;
}

/** Sidebar headline: DPS and EHP large, then the resources this character has (Mana, Spirit, Rage, Ward...).
 *  Refetched whenever the build changes (useLiveRevision invalidates every query). */
export function BudgetCard() {
  const { data: b, isFetching } = useBudget();
  const chips = useChanges(b);
  if (!b) return <Skeleton />;
  const totems = b.totems !== undefined;
  return (
    <section className="relative mx-4 mt-4 rounded-lg border border-ink-700 bg-ink-850 p-3 text-[13px] shadow-sm">
      {isFetching && <Loader2 size={13} className="absolute top-3 right-3 animate-spin text-ink-400" aria-label="Recalculating" />}
      <div className={`grid grid-cols-2 gap-3 transition-opacity ${isFetching ? "opacity-60" : ""}`}>
        <Hover panel={<DpsDetail b={b} />}>
          <Headline
            icon={<Swords size={12} />}
            label="DPS"
            value={b.effectiveDps}
            chip={chips.dps}
            className="text-gold-soft"
            sub={totems ? <>{b.totems} totem{b.totems === 1 ? "" : "s"} × {fmtCompact(b.perTotemDps ?? 0)}</> : b.skill}
          />
        </Hover>
        <Hover panel={<EhpDetail b={b} />}>
          <Headline
            icon={<Shield size={12} />}
            label="EHP"
            value={b.ehp}
            chip={chips.ehp}
            className="text-good"
            sub={
              <>
                <span className="text-life">{fmtCompact(b.life)} Life</span>
                {b.es > 0 && <> · <span className="text-es">{fmtCompact(b.es)} ES</span></>}
              </>
            }
          />
        </Hover>
      </div>
      <div className={`mt-3 space-y-2.5 border-t border-ink-700 pt-2.5 transition-opacity ${isFetching ? "opacity-60" : ""}`}>
        {b.resources.map((r) => (
          <ResourceRow key={r.key} r={r} />
        ))}
        {b.spirit > 0 && <SpiritRow b={b} />}
      </div>
      {totems && b.spiritLimited && (
        <p className="mt-2 flex gap-1 text-xs text-rare">
          <AlertTriangle size={12} className="mt-0.5 shrink-0" />
          {b.totems} of {b.totemCap} totems: each reserves {fmtNum(b.totemCost ?? 0)} Spirit.{" "}
          {b.totemCost ? `${fmtNum(b.totemCost - Math.max(0, b.free))} more for the next one.` : ""}
        </p>
      )}
    </section>
  );
}

function Skeleton() {
  return (
    <section className="mx-4 mt-4 animate-pulse rounded-lg border border-ink-700 bg-ink-850 p-3" aria-label="Loading">
      <div className="grid grid-cols-2 gap-3">
        {[0, 1].map((i) => (
          <div key={i} className="space-y-1.5">
            <div className="h-2.5 w-12 rounded bg-ink-700" />
            <div className="h-6 w-20 rounded bg-ink-700" />
            <div className="h-2.5 w-16 rounded bg-ink-700" />
          </div>
        ))}
      </div>
      <div className="mt-3 space-y-2.5 border-t border-ink-700 pt-2.5">
        {[0, 1].map((i) => (
          <div key={i} className="space-y-1">
            <div className="h-3 w-full rounded bg-ink-700" />
            <div className="h-1.5 w-full rounded bg-ink-700" />
          </div>
        ))}
      </div>
    </section>
  );
}

/** Hover zone whose panel opens below the card, full card width (the sidebar clips anything wider). */
function Hover({ children, panel }: { children: ReactNode; panel: ReactNode }) {
  return (
    <div className="group/hover min-w-0 cursor-default">
      {children}
      <div className="pointer-events-none invisible absolute inset-x-0 top-full z-20 mt-1 rounded-lg border border-ink-600 bg-ink-900 p-2.5 text-xs opacity-0 shadow-lg transition-opacity group-hover/hover:visible group-hover/hover:opacity-100">
        {panel}
      </div>
    </div>
  );
}

function Chip({ pct }: { pct?: number }) {
  if (pct === undefined) return null;
  const up = pct > 0;
  return (
    <span className={`ml-auto shrink-0 rounded px-1 text-[10px] leading-4 font-medium tabular-nums ${up ? "bg-good/15 text-good" : "bg-bad/15 text-bad"}`}>
      {up ? "+" : ""}{pct.toFixed(1)}%
    </span>
  );
}

function Headline({ icon, label, value, chip, className, sub }: { icon: ReactNode; label: string; value: number; chip?: number; className: string; sub?: ReactNode }) {
  return (
    <div className="min-w-0">
      <div className="flex items-center gap-1">
        <span className="label flex min-w-0 items-center gap-1 truncate">{icon}{label}</span>
        <Chip pct={chip} />
      </div>
      <div className={`text-2xl leading-tight font-semibold tabular-nums ${className}`}>{fmtCompact(value)}</div>
      {sub && <div className="truncate text-xs text-ink-400">{sub}</div>}
    </div>
  );
}

function Bar({ pct, color }: { pct: number; color: string }) {
  return (
    <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-ink-700">
      <div className={`h-full rounded-full transition-[width] duration-500 ${color}`} style={{ width: `${Math.max(0, Math.min(100, pct))}%` }} />
    </div>
  );
}

function Sustain({ regen, cost }: { regen?: number; cost?: number }) {
  if (regen === undefined && cost === undefined) return null;
  if (cost === undefined) return <div className="mt-0.5 text-xs text-ink-400">+{fmtNum(regen ?? 0)}/s regen</div>;
  const net = (regen ?? 0) - cost;
  return (
    <div className="mt-0.5 flex justify-between gap-2 text-xs" title={`Regen ${fmtNum(regen ?? 0)}/s, main skill spends ${fmtNum(cost)}/s`}>
      <span className="text-ink-400">+{fmtNum(regen ?? 0)} regen −{fmtNum(cost)} cost</span>
      <span className={`tabular-nums font-medium ${net < 0 ? "text-bad" : "text-good"}`}>net {net >= 0 ? "+" : "−"}{fmtNum(Math.abs(net))}/s</span>
    </div>
  );
}

function ResourceRow({ r }: { r: Resource }) {
  const style = RESOURCE[r.key] ?? { bar: "bg-ink-400", text: "text-ink-200" };
  const avail = r.unreserved ?? r.total;
  const reserved = avail < r.total;
  return (
    <div>
      <div className="flex items-baseline justify-between gap-2">
        <span className={`text-sm ${style.text}`}>{r.label}</span>
        <span className="text-sm tabular-nums text-ink-200">
          {reserved ? <>{fmtNum(avail)} <span className="text-xs text-ink-400">/ {fmtNum(r.total)}</span></> : fmtNum(r.total)}
        </span>
      </div>
      <Bar pct={r.total > 0 ? (avail / r.total) * 100 : 0} color={style.bar} />
      <Sustain regen={r.regen} cost={r.costPerSecond} />
    </div>
  );
}

function SpiritRow({ b }: { b: Budget }) {
  const used = b.spirit - b.free;
  return (
    <Hover panel={<SpiritDetail b={b} />}>
      <div className="flex items-baseline justify-between gap-2">
        <span className="text-sm text-gold-soft">Spirit</span>
        <span className={`text-sm tabular-nums ${b.free < 0 ? "text-bad" : "text-ink-200"}`}>
          {fmtNum(used)} <span className="text-xs text-ink-400">/ {fmtNum(b.spirit)} · {fmtNum(b.free)} free</span>
        </span>
      </div>
      <Bar pct={b.spirit > 0 ? (used / b.spirit) * 100 : 0} color={b.free < 0 ? "bg-bad" : "bg-gold"} />
    </Hover>
  );
}

function Rows({ rows }: { rows: [ReactNode, ReactNode, string?][] }) {
  return (
    <dl className="space-y-0.5">
      {rows.map(([k, v, cls], i) => (
        <div key={i} className="flex justify-between gap-3">
          <dt className="text-ink-400">{k}</dt>
          <dd className={`tabular-nums ${cls ?? "text-ink-200"}`}>{v}</dd>
        </div>
      ))}
    </dl>
  );
}

function DpsDetail({ b }: { b: Budget }) {
  const rows: [ReactNode, ReactNode, string?][] = [["Main skill", b.skill ?? "—"]];
  if (b.totems !== undefined) {
    rows.push(["Per totem", fmtNum(b.perTotemDps ?? 0)]);
    rows.push(["Totems out", `${b.totems} / ${b.totemCap}`, b.spiritLimited ? "text-rare" : undefined]);
  }
  rows.push(["Total DPS", fmtNum(b.effectiveDps), "text-gold-soft"]);
  return (
    <>
      <Rows rows={rows} />
      {b.totems !== undefined && <p className="mt-1.5 text-ink-400">PoB shows totem DPS per totem; this counts every totem your Spirit keeps up.</p>}
    </>
  );
}

/** Element colour when capped, amber when under the 75% cap, red when negative. */
function Res({ v, cls, name }: { v: number; cls: string; name: string }) {
  const color = v < 0 ? "text-bad" : v < 75 ? "text-rare" : cls;
  return <span className={color} title={`${name}${v < 75 ? " (under cap)" : ""}`}>{Math.round(v)}%</span>;
}

function EhpDetail({ b }: { b: Budget }) {
  const d = b.defence;
  const rows: [ReactNode, ReactNode, string?][] = [
    ["Life", fmtNum(b.life), "text-life"],
    ...(b.es > 0 ? [["Energy Shield", fmtNum(b.es), "text-es"] as [ReactNode, ReactNode, string]] : []),
    ["Armour", fmtNum(d.armour)],
    ["Evasion", fmtNum(d.evasion)],
    ...(d.block > 0 ? [["Block", `${Math.round(d.block)}%`] as [ReactNode, ReactNode]] : []),
    ["Life regen", `${fmtNum(d.lifeRegen)}/s`],
    ["Max physical hit", fmtNum(d.maxHit)],
  ];
  return (
    <>
      <Rows rows={rows} />
      <div className="mt-1.5 flex justify-between border-t border-ink-700 pt-1.5 tabular-nums">
        <span className="text-ink-400">Res</span>
        <Res v={d.fire} cls="text-life" name="Fire" />
        <Res v={d.cold} cls="text-es" name="Cold" />
        <Res v={d.lightning} cls="text-gold-soft" name="Lightning" />
        <Res v={d.chaos} cls="text-unique" name="Chaos" />
      </div>
    </>
  );
}

function SpiritDetail({ b }: { b: Budget }) {
  return (
    <>
      <Rows rows={b.reservations.map((r) => [`${r.name}${r.count ? ` ×${r.count}` : ""}`, fmtNum(r.spirit)] as [ReactNode, ReactNode])} />
      <div className="mt-1.5 flex justify-between border-t border-ink-700 pt-1.5">
        <span className="text-ink-400">Free</span>
        <span className={`tabular-nums ${b.free < 0 ? "text-bad" : "text-good"}`}>{fmtNum(b.free)} / {fmtNum(b.spirit)}</span>
      </div>
    </>
  );
}

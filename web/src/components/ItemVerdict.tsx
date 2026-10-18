import { AlertTriangle, CheckCircle2, MinusCircle, XCircle } from "lucide-react";
import type { ItemCheck } from "../api/types";
import { fmtNum } from "./format";

const STYLE = {
  upgrade: { icon: <CheckCircle2 size={18} />, color: "text-good", border: "border-l-good", label: "Upgrade" },
  sidegrade: { icon: <MinusCircle size={18} />, color: "text-rare", border: "border-l-rare", label: "Sidegrade" },
  downgrade: { icon: <XCircle size={18} />, color: "text-bad", border: "border-l-bad", label: "Downgrade" },
};

const DEFENCE_LABELS: Record<string, string> = {
  TotalEHP: "Effective HP", Life: "Life", EnergyShield: "Energy Shield", Mana: "Mana",
  FireResist: "Fire res", ColdResist: "Cold res", LightningResist: "Lightning res", ChaosResist: "Chaos res",
  PhysicalMaximumHitTaken: "Phys max hit", LifeRegenRecovery: "Life regen",
};

/** "Check before you buy" result: verdict, warnings (Spirit, totems, requirements, lost skills), every damage skill. */
export function ItemVerdict({ check }: { check: ItemCheck }) {
  const st = STYLE[check.verdict];
  const changedDefence = Object.entries(check.defence).filter(([, v]) => Math.round(v.before) !== Math.round(v.after));
  return (
    <div className={`rounded border border-ink-700 border-l-4 ${st.border} bg-ink-850 p-3 text-sm`}>
      <div className={`flex items-center gap-2 font-semibold ${st.color}`}>
        {st.icon} {st.label}
        <span className="font-normal text-ink-400">in {check.slot}{check.replaces ? `, replacing ${check.replaces}` : ""}</span>
      </div>
      {check.warnings.length > 0 && (
        <ul className="mt-2 space-y-1">
          {check.warnings.map((w) => (
            <li key={w} className="flex gap-1.5 text-bad"><AlertTriangle size={14} className="mt-0.5 shrink-0" /> {w}</li>
          ))}
        </ul>
      )}
      <table className="mt-2 w-full text-[13px]">
        <tbody>
          {check.skills.map((s) => (
            <tr key={s.group} className="border-t border-ink-800">
              <td className="py-1 pr-2">
                <span className={s.isMain ? "text-gold-soft" : "text-ink-200"}>{s.name}</span>
                {s.isMain && <span className="ml-1 text-xs text-ink-400">main</span>}
                {s.totemsBefore !== undefined && (
                  <span className={`ml-1 text-xs ${s.totemsAfter !== undefined && s.totemsAfter < s.totemsBefore ? "text-bad" : "text-ink-400"}`}>
                    {s.totemsBefore}{s.totemsAfter !== undefined && s.totemsAfter !== s.totemsBefore ? ` → ${s.totemsAfter}` : ""} totem{(s.totemsAfter ?? s.totemsBefore) === 1 ? "" : "s"}
                  </span>
                )}
              </td>
              <td className="py-1 pr-2 text-right tabular-nums text-ink-400">{fmtNum(s.before)} → {s.lost ? "lost" : fmtNum(s.after)}</td>
              <td className={`py-1 text-right tabular-nums ${s.lost || (s.percent ?? 0) < -0.5 ? "text-bad" : (s.percent ?? 0) > 0.5 ? "text-good" : "text-ink-400"}`}>
                {s.percent !== undefined && s.percent !== null ? `${s.percent > 0 ? "+" : ""}${s.percent.toFixed(1)}%` : ""}
              </td>
            </tr>
          ))}
          {changedDefence.map(([k, v]) => (
            <tr key={k} className="border-t border-ink-800">
              <td className="py-1 pr-2 text-ink-200">{DEFENCE_LABELS[k] ?? k}</td>
              <td className="py-1 pr-2 text-right tabular-nums text-ink-400">{fmtNum(v.before)} → {fmtNum(v.after)}</td>
              <td className={`py-1 text-right tabular-nums ${v.after >= v.before ? "text-good" : "text-bad"}`}>{v.after - v.before > 0 ? "+" : ""}{fmtNum(v.after - v.before)}</td>
            </tr>
          ))}
          <tr className="border-t border-ink-800">
            <td className="py-1 pr-2 text-ink-200">Spirit</td>
            <td className="py-1 pr-2 text-right tabular-nums text-ink-400">{fmtNum(check.budget.before.spirit)} → {fmtNum(check.budget.after.spirit)}</td>
            <td className={`py-1 text-right tabular-nums ${check.budget.after.spirit >= check.budget.before.spirit ? "text-ink-400" : "text-bad"}`}>
              {check.budget.after.spirit !== check.budget.before.spirit ? `${check.budget.after.spirit > check.budget.before.spirit ? "+" : ""}${fmtNum(check.budget.after.spirit - check.budget.before.spirit)}` : ""}
            </td>
          </tr>
        </tbody>
      </table>
      <p className="mt-2 text-xs text-ink-400">{check.caveat}</p>
    </div>
  );
}

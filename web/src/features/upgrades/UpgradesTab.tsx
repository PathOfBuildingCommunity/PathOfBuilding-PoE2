import { useMutation, useQueries, useQuery } from "@tanstack/react-query";
import { AlertTriangle, ChevronDown, ChevronRight, CircleDot, ClipboardCheck, ExternalLink, Gem, Link2, ListOrdered, Lock, Search, ShoppingCart, Shirt, Sparkles } from "lucide-react";
import { useMemo, useState, type ReactNode } from "react";
import { api, qs } from "../../api/client";
import { useBuildMutation } from "../../api/hooks";
import type { Gain, GearSlot, GearSlotRef, GemAdvice, ItemCheck, SocketAdvice, SocketOption, SocketPlan, SocketSlot, UniqueSuggestion, UniquesAdvice } from "../../api/types";
import { ErrorText } from "../../components/ErrorText";
import { ItemVerdict } from "../../components/ItemVerdict";
import { Modal } from "../../components/Modal";

type Metric = "balanced" | "dps" | "ehp";
type Section = "check" | "gear" | "jewels" | "sockets" | "gems" | "shop";

const pct = (v: number) => `${v > 0 ? "+" : ""}${v.toFixed(1)}%`;
const tone = (v: number) => (v > 0.05 ? "text-good" : v < -0.05 ? "text-bad" : "text-ink-400");
const rarityColor = (r?: string) => (r === "UNIQUE" ? "text-unique" : r === "RARE" ? "text-rare" : r === "MAGIC" ? "text-magic" : "text-ink-200");

function GainText({ g, compact }: { g?: Pick<Gain, "dpsPercent" | "ehpPercent"> & Partial<Gain>; compact?: boolean }) {
  if (!g) return null;
  const parts: ReactNode[] = [];
  if (Math.abs(g.dpsPercent) >= 0.05) parts.push(<span key="d" className={tone(g.dpsPercent)}>{pct(g.dpsPercent)} DPS</span>);
  if (Math.abs(g.ehpPercent) >= 0.05) parts.push(<span key="e" className={tone(g.ehpPercent)}>{pct(g.ehpPercent)} EHP</span>);
  if (!compact && g.lifeDelta && Math.abs(g.lifeDelta) >= 1) parts.push(<span key="l" className={tone(g.lifeDelta)}>{g.lifeDelta > 0 ? "+" : ""}{Math.round(g.lifeDelta)} Life</span>);
  if (!compact && g.esDelta && Math.abs(g.esDelta) >= 1) parts.push(<span key="s" className={tone(g.esDelta)}>{g.esDelta > 0 ? "+" : ""}{Math.round(g.esDelta)} ES</span>);
  if (g.totemsDelta) parts.push(<span key="t" className={`font-semibold ${tone(g.totemsDelta)}`}>{g.totemsDelta > 0 ? "+" : ""}{g.totemsDelta} totem{Math.abs(g.totemsDelta) === 1 ? "" : "s"}</span>);
  if (g.spiritDelta && !compact) parts.push(<span key="p" className={tone(g.spiritDelta)}>{g.spiritDelta > 0 ? "+" : ""}{Math.round(g.spiritDelta)} Spirit</span>);
  if (!parts.length) return <span className="text-ink-400">no measured change</span>;
  return <span className="inline-flex flex-wrap gap-x-2">{parts}</span>;
}

function TradeLink({ url, label = "Search trade" }: { url?: string; label?: string }) {
  if (!url) return null;
  return (
    <a className="btn" href={url} target="_blank" rel="noreferrer" title="Opens pathofexile.com trade (sign in there to buy)">
      <Search size={13} /> {label} <ExternalLink size={11} />
    </a>
  );
}

// -- gear & jewels ------------------------------------------------------------------------------------------

function SlotCard({ data, uniques, open, onToggle }: { data: GearSlot; uniques?: UniqueSuggestion[]; open: boolean; onToggle: () => void }) {
  return (
    <div className="panel">
      <button className="flex w-full flex-wrap items-center gap-x-4 gap-y-1 px-4 py-3 text-left" onClick={onToggle}>
        {open ? <ChevronDown size={14} className="text-ink-400" /> : <ChevronRight size={14} className="text-ink-400" />}
        <span className="w-28 shrink-0 text-sm text-ink-400">{data.slot.replace(/^Jewel \d+$/, "Jewel socket")}</span>
        <span className={`min-w-0 flex-1 truncate text-sm ${rarityColor(data.item?.rarity)}`}>{data.item?.name ?? <span className="text-ink-400">Empty{data.testBase ? ` (evaluated as ${data.testBase})` : ""}</span>}</span>
        {data.modsWorth && <span className="text-xs text-ink-400">mods worth <GainText g={data.modsWorth} compact /></span>}
        {data.deadMods ? <span className="rounded bg-bad/15 px-1.5 py-0.5 text-xs text-bad">{data.deadMods} dead mod{data.deadMods > 1 ? "s" : ""}</span> : null}
        {data.headroom !== undefined && (
          <span className={`w-28 text-right text-sm font-semibold ${data.headroom >= 5 ? "text-good" : data.headroom >= 1 ? "text-gold-soft" : "text-ink-400"}`} title="How much a good replacement could add over the current item (four best mods at average rolls)">
            {data.headroom >= 0.1 ? `+${data.headroom.toFixed(1)}% room` : "near best"}
          </span>
        )}
      </button>
      {open && (
        <div className="grid gap-4 border-t border-ink-700 px-4 py-3 lg:grid-cols-2">
          <div>
            <div className="label mb-1.5">Current mods (what each is worth)</div>
            {data.mods?.length ? (
              <ul className="space-y-1 text-sm">
                {data.mods.map((m, i) => (
                  <li key={i} className="flex items-baseline gap-2">
                    <span className={`min-w-0 flex-1 ${m.kind === "implicit" ? "italic text-ink-400" : "text-magic"}`}>{m.text}</span>
                    {m.dead ? <span className="rounded bg-bad/15 px-1.5 text-xs text-bad" title="Removing it changes nothing: reroll or replace">dead</span>
                      : m.requirement ? <span className="rounded bg-gold/15 px-1.5 text-xs text-gold-soft" title={`Removing it would drop ${m.requirement} below what your gear and gems need`}>needed for {m.requirement}</span>
                        : m.unmeasured ? <span className="text-xs text-ink-400" title="PoB doesn't measure this effect in DPS or EHP">not measured</span>
                          : <span className="text-xs"><GainText g={m} compact /></span>}
                  </li>
                ))}
              </ul>
            ) : <p className="text-sm text-ink-400">{data.item ? "No mods to evaluate." : "Nothing equipped: anything below helps."}</p>}
          </div>
          <div>
            <div className="mb-1.5 flex items-center gap-2">
              <span className="label">Look for on a replacement</span>
              <span className="ml-auto"><TradeLink url={data.tradeUrl} /></span>
            </div>
            {data.unsupported ? <p className="text-sm text-ink-400">PoB can't weight trade searches for this slot.</p> : (
              <ol className="space-y-0.5 text-sm">
                {data.lookFor?.map((l) => (
                  <li key={l.id} className="flex items-baseline gap-2">
                    <span className="min-w-0 flex-1 text-magic">{l.text}</span>
                    <span className="text-xs text-good">{pct(l.percent)}</span>
                  </li>
                ))}
              </ol>
            )}
            {uniques?.length ? (
              <div className="mt-3">
                <div className="label mb-1">Uniques that would help</div>
                <UniqueRows rows={uniques.slice(0, 4)} />
              </div>
            ) : null}
          </div>
        </div>
      )}
    </div>
  );
}

function GearSection({ jewels, metric, league, uniques }: { jewels: boolean; metric: Metric; league?: string; uniques?: UniquesAdvice }) {
  const slots = useQuery({ queryKey: ["gear-slots"], queryFn: () => api.get<GearSlotRef[]>("/gear/slots") });
  const mine = (slots.data ?? []).filter((s) => !!s.jewel === jewels);
  const results = useQueries({
    queries: mine.map((s) => ({
      queryKey: ["gear-slot", s.slot, metric, league],
      queryFn: () => api.get<GearSlot>(`/gear/slot${qs({ slot: s.slot, metric, league })}`),
    })),
  });
  const [open, setOpen] = useState<string | null>(null);
  const done = results.filter((r) => r.data).map((r) => r.data!) as GearSlot[];
  const ranked = [...done].sort((a, b) => (b.headroom ?? 0) - (a.headroom ?? 0));
  const pending = results.length - done.length;
  const uniqueFor = (slot: string) => uniques?.slots.find((g) => (jewels ? g.slot === "Jewel" : slot.startsWith(g.slot)))?.items;
  const best = ranked[0];
  const emptySockets = jewels ? mine.filter((s) => !s.item).length : 0;

  return (
    <div className="space-y-3">
      <ErrorText error={slots.error ?? results.find((r) => r.error)?.error} />
      {best && best.headroom !== undefined && best.headroom >= 1 && (
        <div className="panel flex flex-wrap items-center gap-3 border-l-4 border-l-good px-4 py-3">
          <Sparkles size={16} className="text-good" />
          <div className="min-w-0 flex-1 text-sm">
            <span className="text-ink-400">Best {jewels ? "jewel" : "gear"} upgrade: </span>
            <span className="font-semibold text-ink-200">{best.slot.replace(/^Jewel \d+$/, "jewel socket")}</span>
            <span className="text-ink-400"> ({best.item?.name ?? "empty"}), room for </span>
            <span className="text-good">+{best.headroom.toFixed(1)}%</span>
            {best.lookFor?.length ? <span className="text-ink-400">. Look for {best.lookFor.slice(0, 3).map((l) => l.text).join(", ")}.</span> : null}
          </div>
          <TradeLink url={best.tradeUrl} />
        </div>
      )}
      {jewels && emptySockets > 0 && (
        <p className="flex items-center gap-2 text-sm text-rare"><AlertTriangle size={14} /> {emptySockets} allocated jewel socket{emptySockets > 1 ? "s are" : " is"} empty.</p>
      )}
      {pending > 0 && <p className="text-xs text-ink-400">Analysing {pending} more slot{pending > 1 ? "s" : ""}…</p>}
      {ranked.map((d) => (
        <SlotCard key={d.slot} data={d} uniques={uniqueFor(d.slot)} open={open === d.slot} onToggle={() => setOpen(open === d.slot ? null : d.slot)} />
      ))}
      {!slots.isLoading && mine.length === 0 && <p className="text-sm text-ink-400">No {jewels ? "allocated jewel sockets" : "gear slots"}.</p>}
    </div>
  );
}

// -- check before you buy -------------------------------------------------------------------------------------

/** Full verdict for a unique from the database: every skill (totems counted), Spirit/totems, lost skills. */
function CheckUniqueButton({ name, baseName }: { name: string; baseName?: string }) {
  const [open, setOpen] = useState(false);
  const check = useMutation({
    mutationFn: async () => {
      const u = await api.get<{ text: string }>(`/data/uniques/${encodeURIComponent(baseName ? `${name}, ${baseName}` : name)}`);
      return api.post<ItemCheck>("/items/check", { text: u.text });
    },
  });
  return (
    <>
      <button className="text-gold hover:underline" title="Check before you buy" onClick={() => { setOpen(true); check.mutate(); }}>
        <ClipboardCheck size={14} />
      </button>
      {open && (
        <Modal title={`Check: ${name}`} onClose={() => setOpen(false)} wide>
          {check.isPending && <p className="text-sm text-ink-400">Checking every skill, Spirit and totems…</p>}
          <ErrorText error={check.error} />
          {check.data && <ItemVerdict check={check.data} />}
        </Modal>
      )}
    </>
  );
}

function CheckSection() {
  const [text, setText] = useState("");
  const check = useMutation({ mutationFn: () => api.post<ItemCheck>("/items/check", { text }) });
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <div className="space-y-2">
        <p className="text-sm text-ink-400">
          Paste an item (Ctrl+C in game or on the trade site) <b>before you buy it</b>. Every damage skill is measured with
          the totems your Spirit can keep up, plus Spirit, defences, attribute requirements and skills the swap would remove.
        </p>
        <textarea className="input h-64 font-mono text-xs" value={text} onChange={(e) => setText(e.target.value)} placeholder="Paste item text…" />
        <button className="btn btn-primary" disabled={!text.trim() || check.isPending} onClick={() => check.mutate()}>
          <ClipboardCheck size={14} /> {check.isPending ? "Checking…" : "Check item"}
        </button>
        <ErrorText error={check.error} />
      </div>
      <div>{check.data && <ItemVerdict check={check.data} />}</div>
    </div>
  );
}

// -- shop ---------------------------------------------------------------------------------------------------

function UniqueRows({ rows, showSlot }: { rows: UniqueSuggestion[]; showSlot?: boolean }) {
  return (
    <table className="w-full text-sm">
      <tbody>
        {rows.map((u) => (
          <tr key={u.name} className="border-t border-ink-800">
            <td className="py-1.5 pr-2">
              <div className="text-unique">{u.name}</div>
              <div className="text-xs text-ink-400">{u.baseName}{u.levelRequirement ? ` · lvl ${u.levelRequirement}` : ""}{showSlot ? ` · ${u.slot.replace(/^Jewel \d+$/, "jewel")}` : ""}</div>
            </td>
            <td className="pr-2 text-xs"><GainText g={u} /></td>
            <td className="pr-2 text-right tabular-nums">
              {u.price ? <><div className="text-ink-200">{u.price}</div><div className="text-xs text-ink-400">{u.listings} listed</div></> : <span className="text-xs text-ink-400">no price</span>}
            </td>
            <td className="whitespace-nowrap text-right">
              <span className="inline-flex items-center gap-2">
                <CheckUniqueButton name={u.name} baseName={u.baseName} />
                {u.tradeUrl && <a className="text-gold hover:underline" href={u.tradeUrl} target="_blank" rel="noreferrer" title="Search trade"><ShoppingCart size={14} /></a>}
              </span>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function ShopSection({ uniques, loading, error, budget, setBudget }: {
  uniques?: UniquesAdvice; loading: boolean; error: unknown; budget: string; setBudget: (v: string) => void;
}) {
  const deals = useMemo(() => {
    const all = (uniques?.slots ?? []).flatMap((s) => s.items.map((i) => ({ ...i, group: s.slot })));
    return all.filter((i) => i.gainPerDivine !== undefined && i.score >= 1).sort((a, b) => (b.gainPerDivine ?? 0) - (a.gainPerDivine ?? 0)).slice(0, 8);
  }, [uniques]);
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <label className="text-ink-400" htmlFor="budget">Budget</label>
        <input id="budget" className="input w-28" inputMode="decimal" placeholder="any" value={budget} onChange={(e) => setBudget(e.target.value.replace(/[^\d.]/g, ""))} />
        <span className="text-ink-400">divine</span>
        {uniques?.rates?.exalted ? <span className="text-xs text-ink-400">(1 div ≈ {Math.round(uniques.rates.exalted)} ex)</span> : null}
        <span className="ml-auto text-xs text-ink-400">Prices from poe.ninja{uniques?.league ? ` · ${uniques.league}` : ""}. Gains measured in your build by PoB.</span>
      </div>
      <ErrorText error={error} />
      {loading && <p className="text-sm text-ink-400">Testing every unique in your build…</p>}
      {deals.length > 0 && (
        <div className="panel p-4">
          <div className="label mb-2">Best value for money</div>
          <UniqueRows rows={deals} showSlot />
        </div>
      )}
      <div className="grid gap-3 lg:grid-cols-2">
        {uniques?.slots.map((s) => (
          <div key={s.slot} className="panel p-4">
            <div className="label mb-1">{s.slot}</div>
            <UniqueRows rows={s.items} />
          </div>
        ))}
      </div>
      <p className="text-xs text-ink-400">
        Rare upgrades: open <b>Gear</b> or <b>Jewels</b> and use <b>Search trade</b>. The searches are weighted by what each stat is worth to this build.
      </p>
    </div>
  );
}

// -- sockets (runes, soul cores, idols) ---------------------------------------------------------------------

const Badge = ({ className, title, children }: { className: string; title?: string; children: ReactNode }) => (
  <span className={`rounded px-1.5 py-0.5 text-xs ${className}`} title={title}>{children}</span>
);

function AugmentLines({ o }: { o: Pick<SocketOption, "lines" | "unmodelled" | "bonded"> }) {
  if (!o.lines.length) return null;
  return (
    <div className="text-xs text-ink-400">
      {o.lines.map((l, i) => <div key={i} className={o.unmodelled?.includes(l) ? "italic" : "text-magic"}>{l}{o.unmodelled?.includes(l) ? " (not modelled)" : ""}</div>)}
      {o.bonded?.length ? <div className="text-ink-400" title="Bonded lines only apply to some classes">Bonded: {o.bonded.join("; ")}</div> : null}
    </div>
  );
}

function SocketCard({ data }: { data: SocketSlot }) {
  return (
    <div className="panel">
      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 border-b border-ink-700 px-4 py-3">
        <span className="w-28 shrink-0 text-sm text-ink-400">{data.slot}</span>
        <span className={`min-w-0 flex-1 truncate text-sm ${data.unique ? "text-unique" : "text-ink-200"}`}>{data.item}</span>
        {data.corrupted && <Badge className="bg-bad/15 text-bad" title="Corrupted: only some augments can still be changed">corrupted</Badge>}
      </div>
      <div className="divide-y divide-ink-800">
        {data.sockets.map((s) => {
          const w = s.worth;
          return (
            <div key={s.index} className="grid gap-3 px-4 py-3 lg:grid-cols-2">
              <div>
                <div className="label mb-1">Socket {s.index}</div>
                <div className="flex flex-wrap items-baseline gap-2 text-sm">
                  <span className={s.current === "None" ? "text-ink-400" : "text-ink-200"}>{s.current === "None" ? "Empty" : s.current}</span>
                  {w && (w.socketBound ? <Badge className="bg-ink-800 text-ink-400" title="Bound to this socket: it can't be swapped out"><Lock size={10} className="mr-1 inline" />socket-bound</Badge>
                    : w.dead ? <Badge className="bg-bad/15 text-bad" title="Removing it changes nothing: swap it">dead</Badge>
                      : w.unmodelled ? <Badge className="bg-gold/15 text-gold-soft" title={`PoB doesn't model: ${w.unmodelled.join("; ")}`}>unmodelled</Badge> : null)}
                  {w && !w.dead && <span className="text-xs"><GainText g={w} compact /></span>}
                </div>
                {w && <AugmentLines o={w} />}
              </div>
              <div>
                {s.alternatives ? (
                  <>
                    <div className="label mb-1">Alternatives{s.legalOptions ? ` (${s.legalOptions} options)` : ""}</div>
                    {s.alternatives.length ? (
                      <ul className="space-y-1.5 text-sm">
                        {s.alternatives.map((a) => (
                          <li key={a.name}>
                            <div className="flex flex-wrap items-baseline gap-2">
                              <span className={`min-w-0 flex-1 ${a.blockedBy ? "text-ink-400" : "text-ink-200"}`}>{a.name === "None" ? "Leave empty" : a.name}</span>
                              {a.blockedBy && <Badge className="bg-rare/15 text-rare" title="A character-wide limit: free that socket first">blocked by {a.blockedBy.map((h) => `${h.slot} socket ${h.socket} (${h.name})`).join(", ")}</Badge>}
                              {a.unmodelled && <Badge className="bg-gold/15 text-gold-soft" title={`PoB doesn't model: ${a.unmodelled.join("; ")}`}>unmodelled</Badge>}
                              <span className="text-xs"><GainText g={a} compact /></span>
                            </div>
                            <AugmentLines o={a} />
                          </li>
                        ))}
                      </ul>
                    ) : <p className="text-sm text-ink-400">No legal alternatives.</p>}
                  </>
                ) : <p className="text-sm text-ink-400">Can't be changed.</p>}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function SocketPlanPanel({ metric }: { metric: Metric }) {
  const plan = useQuery({
    queryKey: ["sockets-plan", metric],
    queryFn: () => api.get<SocketPlan>(`/sockets/plan${qs({ metric })}`),
  });
  const p = plan.data;
  // Paired swaps (freeing a limit in one socket to use it in another) arrive as consecutive steps.
  const groups = useMemo(() => {
    const out: NonNullable<typeof p>["steps"][] = [];
    const steps = p?.steps ?? [];
    for (let i = 0; i < steps.length; i++) {
      const s = steps[i], n = steps[i + 1];
      if (s.pairedWith && n && `${n.slot} socket ${n.socket}` === s.pairedWith) {
        out.push([s, n]);
        i++;
      } else out.push([s]);
    }
    return out;
  }, [p]);
  return (
    <div className="panel border-l-4 border-l-gold p-4">
      <div className="mb-2 flex items-center gap-2">
        <ListOrdered size={15} className="text-gold" />
        <span className="label">Socket plan, in order</span>
        {plan.isFetching && p && <span className="text-xs text-ink-400">updating…</span>}
      </div>
      <ErrorText error={plan.error} />
      {plan.isLoading && <p className="text-sm text-ink-400">Trying every swap, applying the best and re-measuring (about 15 s)…</p>}
      {p && (
        <>
          {groups.length ? (
            <ol className="space-y-2">
              {groups.map((g, gi) => (
                <li key={gi} className={`flex gap-3 text-sm ${g.length > 1 ? "rounded border border-ink-700 p-2" : ""}`}>
                  <span className="w-5 shrink-0 text-right tabular-nums text-ink-400">{gi + 1}.</span>
                  <div className="min-w-0 flex-1 space-y-1.5">
                    {g.length > 1 && <div className="flex items-center gap-1 text-xs text-rare"><Link2 size={12} /> Paired swap: do both together</div>}
                    {g.map((s) => (
                      <div key={`${s.slot}-${s.socket}`}>
                        <div className="flex flex-wrap items-baseline gap-x-2">
                          <span className="text-ink-400">{s.slot} socket {s.socket}:</span>
                          <span className="text-ink-200">{s.from === "None" ? "empty" : s.from}</span>
                          <span className="text-ink-400">→</span>
                          <span className="text-good">{s.to === "None" ? "empty" : s.to}</span>
                          {s.losesUnmodelled && <Badge className="bg-gold/15 text-gold-soft" title={s.losesUnmodelled.join("; ")}>loses unmodelled</Badge>}
                          <span className="ml-auto text-xs"><GainText g={s} compact /></span>
                        </div>
                        <AugmentLines o={s} />
                      </div>
                    ))}
                  </div>
                </li>
              ))}
            </ol>
          ) : <p className="text-sm text-ink-400">No swap gains enough to be worth it.</p>}
          {p.total && (
            <p className="mt-3 border-t border-ink-700 pt-2 text-sm">
              <span className="text-ink-400">All steps together: </span><GainText g={p.total} />
            </p>
          )}
          {p.warnings.length > 0 && (
            <ul className="mt-2 space-y-1 text-sm text-rare">
              {p.warnings.map((w, i) => <li key={i} className="flex gap-2"><AlertTriangle size={14} className="mt-0.5 shrink-0" /> {w}</li>)}
            </ul>
          )}
          <p className="mt-2 text-xs text-ink-400">{p.note}</p>
        </>
      )}
    </div>
  );
}

function SocketsSection({ metric }: { metric: Metric }) {
  const advice = useQuery({ queryKey: ["sockets", metric], queryFn: () => api.get<SocketAdvice>(`/sockets${qs({ metric, limit: 5 })}`) });
  const [showPlan, setShowPlan] = useState(false);
  const a = advice.data;
  const all = (a?.slots ?? []).flatMap((s) => s.sockets.map((x) => ({ slot: s.slot, ...x })));
  const dead = all.filter((x) => x.worth?.dead).length;
  const empty = all.filter((x) => x.current === "None").length;
  const best = all.filter((x) => (x.bestGain ?? 0) >= 0.5).sort((x, y) => (y.bestGain ?? 0) - (x.bestGain ?? 0))[0];
  const bestAlt = best?.alternatives?.find((o) => !o.blockedBy);
  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-3">
        <p className="min-w-0 flex-1 text-sm text-ink-400">
          What each rune, soul core and idol is worth, and the best legal replacements. Nothing in your build changes.
        </p>
        <button className="btn btn-primary" onClick={() => setShowPlan(true)} disabled={showPlan}>
          <ListOrdered size={14} /> Build plan
        </button>
      </div>
      {showPlan && <SocketPlanPanel metric={metric} />}
      <ErrorText error={advice.error} />
      {advice.isLoading && <p className="text-sm text-ink-400">Measuring every socket and its legal options…</p>}
      {best && bestAlt && (
        <div className="panel flex flex-wrap items-center gap-3 border-l-4 border-l-good px-4 py-3">
          <Sparkles size={16} className="text-good" />
          <div className="min-w-0 flex-1 text-sm">
            <span className="text-ink-400">Best single swap: </span>
            <span className="font-semibold text-ink-200">{best.slot} socket {best.index}</span>
            <span className="text-ink-400"> {best.current === "None" ? "(empty)" : best.current} → </span>
            <span className="text-good">{bestAlt.name}</span> <span className="text-xs"><GainText g={bestAlt} compact /></span>
          </div>
        </div>
      )}
      {(dead > 0 || empty > 0) && (
        <p className="flex items-center gap-2 text-sm text-rare">
          <AlertTriangle size={14} />
          {[dead ? `${dead} dead augment${dead > 1 ? "s" : ""}` : "", empty ? `${empty} empty socket${empty > 1 ? "s" : ""}` : ""].filter(Boolean).join(", ")}.
        </p>
      )}
      {a?.slots.map((s) => <SocketCard key={s.slot} data={s} />)}
      {a && a.slots.length === 0 && <p className="text-sm text-ink-400">No socketed items equipped.</p>}
      {a && <p className="text-xs text-ink-400">{a.note}</p>}
    </div>
  );
}

// -- gems ---------------------------------------------------------------------------------------------------

function GemsSection({ metric }: { metric: Metric }) {
  const advice = useQuery({ queryKey: ["gems-advice", metric], queryFn: () => api.get<GemAdvice>(`/gems/advice${qs({ metric })}`) });
  const setGem = useBuildMutation((v: { group: number; index: number; body: Record<string, unknown> }) =>
    api.post(`/skills/${v.group}/gems/${v.index}`, v.body),
  );
  const a = advice.data;
  return (
    <div className="space-y-4">
      <ErrorText error={advice.error ?? setGem.error} />
      {advice.isLoading && <p className="text-sm text-ink-400">Testing gem levels and every compatible support…</p>}
      {a && (
        <div className="panel p-4">
          <div className="label mb-2">Upgrades, best first</div>
          {a.upgrades.length ? (
            <ul className="space-y-1.5">
              {a.upgrades.map((u, i) => (
                <li key={i} className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
                  <span className="min-w-0 flex-1 text-ink-200">{u.text}</span>
                  <span className="text-xs"><GainText g={u.gain} compact /></span>
                  <button className="btn" disabled={setGem.isPending}
                    onClick={() => setGem.mutate({ group: u.group, index: u.index, body: u.kind === "swap" ? { name: u.with } : u.kind === "level" ? { level: u.to } : { quality: u.to } })}>
                    Apply
                  </button>
                </li>
              ))}
            </ul>
          ) : <p className="text-sm text-ink-400">No gem changes found that measurably help.</p>}
          <p className="mt-2 text-xs text-ink-400">Gains are PoB's calculation for your Config settings. Check a support's conditions (minions, charges, enemy state) before buying it.</p>
        </div>
      )}
      {a?.problems.length ? (
        <div className="panel border-l-4 border-l-bad p-4">
          <div className="label mb-2">Problems</div>
          <ul className="space-y-1 text-sm">
            {a.problems.map((p, i) => (
              <li key={i}><span className="text-ink-200">{p.name}</span> <span className="text-ink-400">(group {p.group}):</span> <span className="text-bad">{p.problem}</span></li>
            ))}
          </ul>
        </div>
      ) : null}
      <div className="grid gap-3 lg:grid-cols-2">
        {a?.groups.map((g) => (
          <div key={g.index} className="panel p-4">
            <div className="flex items-baseline gap-2">
              <span className="font-semibold text-gold-soft">{g.skills[0] ?? g.label}</span>
              {g.skills.length > 1 && <span className="truncate text-xs text-ink-400">+ {g.skills.slice(1).join(", ")}</span>}
              {g.isMain && <span className="rounded bg-gold/15 px-1.5 text-xs text-gold-soft">main</span>}
              <span className="ml-auto text-xs text-ink-400" title="Damage skills are measured on their own DPS; utility skills on what they do for your build">
                {g.measuredOn === "skill" ? "its own DPS" : "build"}
              </span>
            </div>
            <ul className="mt-2 space-y-1 text-sm">
              {g.gems.filter((x) => x.support).map((x) => (
                <li key={x.index} className="flex items-baseline gap-2">
                  <span className={`min-w-0 flex-1 ${x.problems.length ? "text-bad" : "text-magic"}`}>{x.name}</span>
                  {x.worth && !x.noEffect ? <span className="text-xs"><GainText g={x.worth} compact /></span> : <span className="text-xs text-ink-400" title="Cost, area or utility effects aren't measured">utility</span>}
                </li>
              ))}
            </ul>
            {g.swap && (
              <p className="mt-2 text-xs text-ink-400">
                Swap <span className="text-ink-200">{g.swap.replace}</span> → <span className="text-good">{g.swap.with}</span> (<GainText g={g.swap.gain} compact />)
                {g.swap.alternatives.length > 1 && <> · also {g.swap.alternatives.slice(1).map((alt) => alt.name).join(", ")}</>}
              </p>
            )}
            {g.lineage && <p className="mt-1 text-xs text-ink-400">Lineage option: <span className="text-unique">{g.lineage.name}</span> (<GainText g={g.lineage} compact />)</p>}
          </div>
        ))}
      </div>
    </div>
  );
}

// -- tab ----------------------------------------------------------------------------------------------------

export function UpgradesTab() {
  const [section, setSection] = useState<Section>("check");
  const [metric, setMetric] = useState<Metric>("balanced");
  const [league, setLeague] = useState<string | undefined>();
  const [budget, setBudget] = useState("");
  const leagues = useQuery({ queryKey: ["static", "leagues"], queryFn: () => api.get<{ leagues: { name: string }[]; default?: string }>("/market/leagues"), staleTime: 600_000 });
  const activeLeague = league ?? leagues.data?.default;
  const maxPrice = budget ? Number(budget) : undefined;
  const uniques = useQuery({
    queryKey: ["gear-uniques", metric, activeLeague, maxPrice],
    queryFn: () => api.get<UniquesAdvice>(`/gear/uniques${qs({ metric, league: activeLeague, maxPrice })}`),
    enabled: section === "shop" || section === "gear" || section === "jewels",
  });
  const sections: { id: Section; label: string; icon: ReactNode }[] = [
    { id: "check", label: "Check item", icon: <ClipboardCheck size={14} /> },
    { id: "gear", label: "Gear", icon: <Shirt size={14} /> },
    { id: "jewels", label: "Jewels", icon: <Sparkles size={14} /> },
    { id: "sockets", label: "Sockets", icon: <CircleDot size={14} /> },
    { id: "gems", label: "Gems", icon: <Gem size={14} /> },
    { id: "shop", label: "Shop", icon: <ShoppingCart size={14} /> },
  ];
  return (
    <div className="space-y-4 p-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex gap-1 rounded border border-ink-700 p-0.5">
          {sections.map((s) => (
            <button key={s.id} onClick={() => setSection(s.id)}
              className={`flex items-center gap-1.5 rounded px-3 py-1.5 text-sm ${section === s.id ? "bg-ink-800 text-gold-soft" : "text-ink-400 hover:text-ink-200"}`}>
              {s.icon} {s.label}
            </button>
          ))}
        </div>
        <div className="ml-auto flex flex-wrap items-center gap-2 text-xs text-ink-400">
          Optimise for
          <select className="input w-auto" value={metric} onChange={(e) => setMetric(e.target.value as Metric)}>
            <option value="balanced">Balanced</option>
            <option value="dps">Damage</option>
            <option value="ehp">Defence</option>
          </select>
          {section !== "gems" && section !== "check" && section !== "sockets" && (
            <>
              League
              <select className="input w-auto" value={activeLeague ?? ""} onChange={(e) => setLeague(e.target.value || undefined)}>
                {leagues.data?.leagues.map((l) => <option key={l.name} value={l.name}>{l.name}</option>)}
              </select>
            </>
          )}
        </div>
      </div>
      {section === "check" && <CheckSection />}
      {section === "gear" && <GearSection jewels={false} metric={metric} league={activeLeague} uniques={uniques.data} />}
      {section === "jewels" && <GearSection jewels metric={metric} league={activeLeague} uniques={uniques.data} />}
      {section === "sockets" && <SocketsSection metric={metric} />}
      {section === "gems" && <GemsSection metric={metric} />}
      {section === "shop" && <ShopSection uniques={uniques.data} loading={uniques.isLoading} error={uniques.error} budget={budget} setBudget={setBudget} />}
    </div>
  );
}

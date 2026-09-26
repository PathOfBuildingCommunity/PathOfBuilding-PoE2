import { useQuery } from "@tanstack/react-query";
import { Crosshair, Link2, RotateCcw, Search } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { api, qs } from "../../api/client";
import { useBuildMutation, useTreeLayout } from "../../api/hooks";
import type { Comparison, LayoutNode, TreeNodeInfo } from "../../api/types";
import { DeltaTable } from "../../components/DeltaTable";
import { ErrorText } from "../../components/ErrorText";
import { Modal } from "../../components/Modal";
import { draw, fitView, hitTest, type View } from "./renderer";

function useDebounced<T>(value: T, ms: number) {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return v;
}

function NodeTooltip({ node, x, y, allocated }: { node: LayoutNode; x: number; y: number; allocated: boolean }) {
  const info = useQuery({ queryKey: ["tree-node", node.id], queryFn: () => api.get<TreeNodeInfo>(`/tree/node/${node.id}`) });
  const settled = useDebounced(node.id, 180);
  const cmp = useQuery({
    queryKey: ["tree-compare", node.id, allocated],
    queryFn: () => api.post<Comparison>("/tree/compare", allocated ? { remove: [node.id] } : { add: [node.id] }),
    enabled: settled === node.id && node.type !== "AscendClassStart",
  });
  return (
    <div className="panel pointer-events-none absolute z-10 w-80 p-3 shadow-xl" style={{ left: x + 16, top: y + 16 }}>
      <div className="font-semibold text-gold-soft">{node.name ?? `Node ${node.id}`}</div>
      <div className="text-xs text-ink-400">
        {node.type}{node.ascendancy ? ` · ${node.ascendancy}` : ""} · id {node.id}
        {info.data?.pathLength && !allocated ? ` · ${info.data.pathLength} pt${info.data.pathLength > 1 ? "s" : ""}` : ""}
      </div>
      {info.data?.stats?.length ? (
        <ul className="mt-2 space-y-0.5 text-[13px] text-magic">{info.data.stats.map((s, i) => <li key={i}>{s}</li>)}</ul>
      ) : null}
      <div className="mt-2 border-t border-ink-700 pt-2">
        <div className="label mb-1">{allocated ? "Removing" : "Allocating (with path)"}</div>
        {cmp.isFetching || !cmp.data ? <p className="text-xs text-ink-400">Calculating…</p> : <DeltaTable comparison={cmp.data} />}
      </div>
    </div>
  );
}

function TreeUrlDialog({ onClose }: { onClose: () => void }) {
  const [url, setUrl] = useState("");
  const exported = useQuery({ queryKey: ["tree-url"], queryFn: () => api.get<{ url: string }>("/tree/export-url") });
  const m = useBuildMutation((u: string) => api.post("/tree/import-url", { url: u }));
  return (
    <Modal title="Passive tree link" onClose={onClose}>
      <label className="label">Current tree</label>
      <input readOnly className="input mt-1 font-mono text-xs" value={exported.data?.url ?? "…"} onFocus={(e) => e.target.select()} />
      <label className="label mt-4 block">Import from pathofexile.com tree URL</label>
      <input className="input mt-1 font-mono text-xs" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://pathofexile.com/passive-skill-tree/…" />
      <ErrorText error={m.error} />
      <div className="mt-3 flex justify-end">
        <button className="btn btn-primary" disabled={!url || m.isPending} onClick={() => m.mutate(url, { onSuccess: onClose })}>Import tree</button>
      </div>
    </Modal>
  );
}

export function TreeTab() {
  const layout = useTreeLayout();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<View | null>(null);
  const drag = useRef<{ x: number; y: number; moved: boolean } | null>(null);
  const [hover, setHover] = useState<{ node: LayoutNode; x: number; y: number } | null>(null);
  const [query, setQuery] = useState("");
  const [showUrl, setShowUrl] = useState(false);
  const [, force] = useState(0);
  const debounced = useDebounced(query.trim(), 250);

  const byId = useMemo(() => new Map(layout.data?.nodes.map((n) => [n.id, n]) ?? []), [layout.data]);
  const allocated = useMemo(() => new Set(layout.data?.allocated ?? []), [layout.data]);

  const search = useQuery({
    queryKey: ["tree-search", debounced],
    queryFn: () => api.get<TreeNodeInfo[]>(`/tree/search${qs({ q: debounced, minor: true, limit: 300 })}`),
    enabled: debounced.length >= 2,
  });
  const highlighted = useMemo(() => new Set(debounced.length >= 2 ? search.data?.map((n) => n.id) : []), [search.data, debounced]);

  const toggle = useBuildMutation((n: { id: number; alloc: boolean }) =>
    api.post(n.alloc ? "/tree/deallocate" : "/tree/allocate", { ids: [n.id] }),
  );
  const reset = useBuildMutation(() => api.post("/tree/reset"));

  const render = useCallback(() => {
    const canvas = canvasRef.current, data = layout.data, v = viewRef.current;
    if (!canvas || !data || !v) return;
    const ctx = canvas.getContext("2d");
    if (ctx) draw(ctx, data, byId, v, { allocated, highlighted, hovered: hover?.node.id ?? null });
  }, [layout.data, byId, allocated, highlighted, hover]);

  const fit = useCallback((onlyAllocated: boolean) => {
    const wrap = wrapRef.current, data = layout.data;
    if (!wrap || !data) return;
    const nodes = onlyAllocated && allocated.size > 3 ? data.nodes.filter((n) => allocated.has(n.id) && !n.ascendancy) : data.nodes.filter((n) => !n.ascendancy);
    viewRef.current = fitView(nodes, wrap.clientWidth, wrap.clientHeight);
    force((x) => x + 1);
  }, [layout.data, allocated]);

  // Size canvas to container.
  useEffect(() => {
    const wrap = wrapRef.current, canvas = canvasRef.current;
    if (!wrap || !canvas) return;
    const ro = new ResizeObserver(() => {
      const dpr = window.devicePixelRatio || 1;
      canvas.width = wrap.clientWidth * dpr;
      canvas.height = wrap.clientHeight * dpr;
      canvas.style.width = `${wrap.clientWidth}px`;
      canvas.style.height = `${wrap.clientHeight}px`;
      if (!viewRef.current) fit(false);
      force((x) => x + 1);
    });
    ro.observe(wrap);
    return () => ro.disconnect();
  }, [fit]);

  useEffect(() => {
    if (layout.data && !viewRef.current) fit(false);
  }, [layout.data, fit]);

  useEffect(() => {
    const id = requestAnimationFrame(render);
    return () => cancelAnimationFrame(id);
  });

  // Wheel zoom (non-passive so we can preventDefault).
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const v = viewRef.current;
      if (!v) return;
      const rect = canvas.getBoundingClientRect();
      const sx = e.clientX - rect.left, sy = e.clientY - rect.top;
      const factor = Math.exp(-e.deltaY * 0.0015);
      const scale = Math.min(2, Math.max(0.01, v.scale * factor));
      viewRef.current = { scale, x: sx - ((sx - v.x) * scale) / v.scale, y: sy - ((sy - v.y) * scale) / v.scale };
      force((x) => x + 1);
    };
    canvas.addEventListener("wheel", onWheel, { passive: false });
    return () => canvas.removeEventListener("wheel", onWheel);
  }, []);

  const pos = (e: React.PointerEvent) => {
    const rect = canvasRef.current!.getBoundingClientRect();
    return [e.clientX - rect.left, e.clientY - rect.top] as const;
  };

  const onPointerMove = (e: React.PointerEvent) => {
    const [sx, sy] = pos(e);
    const v = viewRef.current;
    if (!v || !layout.data) return;
    if (drag.current) {
      const dx = sx - drag.current.x, dy = sy - drag.current.y;
      if (Math.abs(dx) + Math.abs(dy) > 3) drag.current.moved = true;
      if (drag.current.moved) {
        viewRef.current = { ...v, x: v.x + dx, y: v.y + dy };
        drag.current.x = sx;
        drag.current.y = sy;
        setHover(null);
        force((x) => x + 1);
        return;
      }
    }
    const node = hitTest(layout.data, v, sx, sy);
    setHover((h) => (node ? (h?.node.id === node.id ? { ...h, x: sx, y: sy } : { node, x: sx, y: sy }) : null));
  };

  const onPointerUp = (e: React.PointerEvent) => {
    const d = drag.current;
    drag.current = null;
    if (d && !d.moved && hover && !toggle.isPending) {
      const [sx, sy] = pos(e);
      const node = hitTest(layout.data!, viewRef.current!, sx, sy);
      if (node && node.type !== "AscendClassStart") toggle.mutate({ id: node.id, alloc: allocated.has(node.id) });
    }
  };

  const centerOn = (id: number) => {
    const n = byId.get(id), wrap = wrapRef.current, v = viewRef.current;
    if (!n || !wrap || !v) return;
    const scale = Math.max(v.scale, 0.3);
    const [sx, sy] = [wrap.clientWidth / 2, wrap.clientHeight / 2];
    viewRef.current = { scale, x: sx - n.x * scale, y: sy - n.y * scale };
    force((x) => x + 1);
  };

  return (
    <div className="flex h-full min-h-[480px] flex-col">
      <div className="flex flex-wrap items-center gap-2 border-b border-ink-700 px-3 py-2">
        <div className="relative w-72">
          <Search size={14} className="absolute left-2.5 top-2.5 text-ink-400" />
          <input className="input pl-8" placeholder="Search nodes (name or stat)…" value={query} onChange={(e) => setQuery(e.target.value)} />
        </div>
        {debounced.length >= 2 && <span className="text-xs text-ink-400">{search.data?.length ?? 0} matches</span>}
        <div className="ml-auto flex gap-2">
          <button className="btn" onClick={() => fit(true)} title="Fit to allocated nodes"><Crosshair size={14} /> Fit</button>
          <button className="btn" onClick={() => setShowUrl(true)}><Link2 size={14} /> Tree URL</button>
          <button className="btn" onClick={() => confirm("Reset all passive allocations?") && reset.mutate(undefined)}><RotateCcw size={14} /> Reset</button>
        </div>
      </div>
      <ErrorText error={toggle.error ?? layout.error} />
      <div className="flex min-h-0 flex-1">
        <div ref={wrapRef} className="relative min-w-0 flex-1 overflow-hidden bg-ink-950">
          <canvas
            ref={canvasRef}
            className={`absolute inset-0 ${hover ? "cursor-pointer" : "cursor-grab"} touch-none`}
            onPointerDown={(e) => {
              const [x, y] = pos(e);
              drag.current = { x, y, moved: false };
              (e.target as HTMLElement).setPointerCapture(e.pointerId);
            }}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerLeave={() => setHover(null)}
          />
          {layout.isLoading && <div className="absolute inset-0 grid place-items-center text-sm text-ink-400">Loading tree…</div>}
          {hover && <NodeTooltip node={hover.node} x={hover.x} y={hover.y} allocated={allocated.has(hover.node.id)} />}
          <div className="pointer-events-none absolute bottom-2 left-3 text-xs text-ink-400">
            Scroll to zoom · drag to pan · click a node to allocate / remove
          </div>
        </div>
        {debounced.length >= 2 && search.data?.length ? (
          <ul className="hidden w-64 shrink-0 overflow-y-auto border-l border-ink-700 bg-ink-900 text-sm lg:block">
            {search.data.filter((n) => n.type !== "Normal" || n.ascendancy).slice(0, 80).map((n) => (
              <li key={n.id}>
                <button className="w-full px-3 py-1.5 text-left hover:bg-ink-800" onClick={() => centerOn(n.id)}>
                  <div className={n.allocated ? "text-gold-soft" : "text-ink-200"}>{n.name}</div>
                  <div className="truncate text-xs text-ink-400">{n.stats?.join(" · ")}</div>
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </div>
      {showUrl && <TreeUrlDialog onClose={() => setShowUrl(false)} />}
    </div>
  );
}

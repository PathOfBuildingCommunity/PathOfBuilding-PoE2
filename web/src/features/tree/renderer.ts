import type { LayoutNode, TreeLayout } from "../../api/types";

export interface View {
  scale: number;
  x: number; // screen offset of world origin
  y: number;
}

export interface DrawState {
  allocated: Set<number>;
  highlighted: Set<number>;
  hovered: number | null;
}

const RADIUS: Record<string, number> = {
  Keystone: 38,
  Notable: 26,
  Socket: 26,
  Mastery: 22,
  Normal: 14,
  AscendClassStart: 20,
  ClassStart: 30,
};

export function nodeRadius(n: LayoutNode): number {
  return RADIUS[n.type] ?? 14;
}

export function bounds(nodes: LayoutNode[]) {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const n of nodes) {
    minX = Math.min(minX, n.x); minY = Math.min(minY, n.y);
    maxX = Math.max(maxX, n.x); maxY = Math.max(maxY, n.y);
  }
  return { minX, minY, maxX, maxY };
}

export function fitView(nodes: LayoutNode[], width: number, height: number, padding = 40): View {
  if (!nodes.length) return { scale: 0.05, x: width / 2, y: height / 2 };
  const b = bounds(nodes);
  const w = Math.max(b.maxX - b.minX, 1), h = Math.max(b.maxY - b.minY, 1);
  const scale = Math.min((width - padding * 2) / w, (height - padding * 2) / h, 0.6);
  return { scale, x: width / 2 - ((b.minX + b.maxX) / 2) * scale, y: height / 2 - ((b.minY + b.maxY) / 2) * scale };
}

export const toScreen = (v: View, x: number, y: number) => [x * v.scale + v.x, y * v.scale + v.y] as const;
export const toWorld = (v: View, sx: number, sy: number) => [(sx - v.x) / v.scale, (sy - v.y) / v.scale] as const;

export function hitTest(layout: TreeLayout, v: View, sx: number, sy: number): LayoutNode | null {
  const [wx, wy] = toWorld(v, sx, sy);
  let best: LayoutNode | null = null;
  let bestD = Infinity;
  for (const n of layout.nodes) {
    if (n.type === "ClassStart") continue;
    const r = Math.max(nodeRadius(n), 7 / v.scale);
    const d = (n.x - wx) ** 2 + (n.y - wy) ** 2;
    if (d < r * r && d < bestD) {
      best = n;
      bestD = d;
    }
  }
  return best;
}

const COLORS = {
  edge: "#2c323b",
  edgeAlloc: "#c8a24a",
  node: "#4a515c",
  notable: "#8a7a55",
  keystone: "#a07bd0",
  socket: "#4f8fbf",
  alloc: "#e3c77e",
  highlight: "#39d0c8",
  hover: "#ffffff",
  asc: "#6a5a7a",
};

export function draw(ctx: CanvasRenderingContext2D, layout: TreeLayout, byId: Map<number, LayoutNode>, v: View, s: DrawState) {
  const { width, height } = ctx.canvas;
  const dpr = window.devicePixelRatio || 1;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, width, height);
  ctx.setTransform(dpr * v.scale, 0, 0, dpr * v.scale, dpr * v.x, dpr * v.y);

  // Edges: unallocated first, allocated on top.
  const lw = Math.max(2, 1.2 / v.scale);
  for (const alloc of [false, true]) {
    ctx.beginPath();
    for (const [a, b] of layout.edges) {
      const isAlloc = s.allocated.has(a) && s.allocated.has(b);
      if (isAlloc !== alloc) continue;
      const na = byId.get(a), nb = byId.get(b);
      if (!na || !nb) continue;
      ctx.moveTo(na.x, na.y);
      ctx.lineTo(nb.x, nb.y);
    }
    ctx.strokeStyle = alloc ? COLORS.edgeAlloc : COLORS.edge;
    ctx.lineWidth = alloc ? lw * 2.2 : lw;
    ctx.stroke();
  }

  for (const n of layout.nodes) {
    if (n.type === "ClassStart") continue;
    const r = nodeRadius(n);
    const alloc = s.allocated.has(n.id);
    let fill = COLORS.node;
    if (n.type === "Notable") fill = COLORS.notable;
    else if (n.type === "Keystone") fill = COLORS.keystone;
    else if (n.type === "Socket") fill = COLORS.socket;
    else if (n.ascendancy) fill = COLORS.asc;
    if (alloc) fill = COLORS.alloc;
    ctx.beginPath();
    ctx.arc(n.x, n.y, r, 0, Math.PI * 2);
    ctx.fillStyle = fill;
    ctx.fill();
    if (s.highlighted.has(n.id) || s.hovered === n.id) {
      ctx.lineWidth = Math.max(4, 2.5 / v.scale);
      ctx.strokeStyle = s.hovered === n.id ? COLORS.hover : COLORS.highlight;
      ctx.beginPath();
      ctx.arc(n.x, n.y, r + ctx.lineWidth, 0, Math.PI * 2);
      ctx.stroke();
    }
  }

  // Labels for notables/keystones when zoomed in enough.
  if (v.scale > 0.22) {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.font = "11px Inter, system-ui, sans-serif";
    ctx.textAlign = "center";
    for (const n of layout.nodes) {
      if ((n.type === "Notable" || n.type === "Keystone") && n.name) {
        const [sx, sy] = toScreen(v, n.x, n.y);
        if (sx < -50 || sy < -20 || sx > width / dpr + 50 || sy > height / dpr + 20) continue;
        ctx.fillStyle = s.allocated.has(n.id) ? "#e3c77e" : "#9aa3ae";
        ctx.fillText(n.name, sx, sy + nodeRadius(n) * v.scale + 13);
      }
    }
  }
}

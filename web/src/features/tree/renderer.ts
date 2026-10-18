import type { LayoutNode, TreeLayout } from "../../api/types";
import type { Sprite, TreeArt } from "./art";

export interface View {
  scale: number;
  x: number; // screen offset of world origin
  y: number;
}

export interface DrawState {
  allocated: Set<number>;
  highlighted: Set<number>;
  hovered: number | null;
  art: TreeArt | null;
  /** Reference guide nodes not yet allocated. */
  planned?: Set<number>;
  advice?: AdviceMarks;
}

/** Advisor markers: the next point and its path, the point to move, attribute nodes to switch. */
export interface AdviceMarks {
  next?: number;
  path?: Set<number>;
  target?: number;
  refund?: number;
  attributes?: Map<number, string>; // node id -> recommended attribute
}

const SHORT_ATTR: Record<string, string> = { Strength: "Str", Dexterity: "Dex", Intelligence: "Int" };

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
  return n.r ?? RADIUS[n.type] ?? 14;
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
  bg: "#0b0a09",
  edge: "#3a3631",
  edgeAlloc: "#d8b45c",
  node: "#4a515c",
  notable: "#8a7a55",
  keystone: "#a07bd0",
  socket: "#4f8fbf",
  alloc: "#e3c77e",
  highlight: "#39d0c8",
  hover: "#ffffff",
  planned: "#c17bff",
  next: "#4ade80",
  refund: "#f87171",
  attribute: "#fbbf24",
  asc: "#6a5a7a",
};

/** Draw a PoB asset centred on (x, y): PoB renders assets at twice their texture size (or `radius` * 2). */
function drawSprite(ctx: CanvasRenderingContext2D, s: Sprite, x: number, y: number, radius?: number) {
  const hw = radius ?? s.w, hh = radius ? radius * (s.h / s.w) : s.h;
  ctx.drawImage(s.img, s.sx, s.sy, s.sw, s.sh, x - hw, y - hh, hw * 2, hh * 2);
}

function drawIcon(ctx: CanvasRenderingContext2D, s: Sprite, x: number, y: number, r: number) {
  ctx.save();
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.clip();
  ctx.drawImage(s.img, s.sx, s.sy, s.sw, s.sh, x - r, y - r, r * 2, r * 2);
  ctx.restore();
}

function drawBackdrop(ctx: CanvasRenderingContext2D, layout: TreeLayout, s: DrawState, v: View, dpr: number) {
  const art = s.art!;
  const tile = art.sprite("Background2");
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = COLORS.bg;
  ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
  if (tile) {
    const pattern = ctx.createPattern(tile.img, "repeat");
    if (pattern) {
      const k = Math.max(v.scale, 0.08) * 1.4 * dpr;
      pattern.setTransform(new DOMMatrix([k, 0, 0, k, v.x * dpr, v.y * dpr]));
      ctx.globalAlpha = 0.5;
      ctx.fillStyle = pattern;
      ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
      ctx.globalAlpha = 1;
    }
  }
  ctx.setTransform(dpr * v.scale, 0, 0, dpr * v.scale, dpr * v.x, dpr * v.y);

  // Class artwork in the centre of the tree, rotated toward the class's start node.
  const cls = layout.classes?.find((c) => c.name === layout.className);
  if (cls) {
    const image = (layout.ascendClassName && cls.ascendancyImages[layout.ascendClassName]) || cls.image;
    const bg = art.sprite(image);
    if (bg) drawSprite(ctx, bg, cls.x, cls.y, cls.w);
    const start = cls.startNode != null ? layout.nodes.find((n) => n.id === cls.startNode) : undefined;
    const active = art.sprite("BGTreeActive");
    if (active && cls.activeW && start) {
      ctx.save();
      ctx.translate(cls.x, cls.y);
      ctx.rotate(Math.PI / 2 + Math.atan2(start.y - cls.y, start.x - cls.x));
      drawSprite(ctx, active, 0, 0, cls.activeW);
      ctx.restore();
    }
    const ring = art.sprite("BGTree");
    if (ring && cls.treeW) drawSprite(ctx, ring, cls.x, cls.y, cls.treeW);
  }

  // Ascendancy circles: the chosen one in full colour, the rest dimmed.
  for (const a of layout.ascendancies ?? []) {
    if ((a.replaceBy && a.replaceBy === layout.ascendClassName) || (a.replace && a.name !== layout.ascendClassName)) continue;
    const bg = art.sprite(a.image);
    if (!bg) continue;
    ctx.globalAlpha = a.name === layout.ascendClassName ? 1 : 0.45;
    drawSprite(ctx, bg, a.x, a.y, a.w);
  }
  ctx.globalAlpha = 1;

  for (const d of layout.decorations ?? []) {
    const img = art.sprite(d.image);
    if (img) drawSprite(ctx, img, d.x, d.y, d.r);
  }
}

export function draw(ctx: CanvasRenderingContext2D, layout: TreeLayout, byId: Map<number, LayoutNode>, v: View, s: DrawState) {
  const { width, height } = ctx.canvas;
  const dpr = window.devicePixelRatio || 1;
  const art = s.art;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, width, height);
  if (art) drawBackdrop(ctx, layout, s, v, dpr);
  ctx.setTransform(dpr * v.scale, 0, 0, dpr * v.scale, dpr * v.x, dpr * v.y);

  // Visible world rectangle (with margin) for culling.
  const [x0, y0] = toWorld(v, -200, -200);
  const [x1, y1] = toWorld(v, width / dpr + 200, height / dpr + 200);
  const visible = (n: LayoutNode) => n.x > x0 && n.x < x1 && n.y > y0 && n.y < y1;
  const otherAscendancy = (n: LayoutNode) => !!n.ascendancy && n.ascendancy !== layout.ascendClassName;

  // Connections: unallocated first, allocated on top. Orbit connections follow their arc.
  const lw = art ? Math.max(9, 1.4 / v.scale) : Math.max(2, 1.2 / v.scale);
  for (const alloc of [false, true]) {
    ctx.beginPath();
    for (const e of layout.edges) {
      const [a, b] = e;
      const isAlloc = s.allocated.has(a) && s.allocated.has(b);
      if (isAlloc !== alloc) continue;
      const na = byId.get(a), nb = byId.get(b);
      if (!na || !nb || (!visible(na) && !visible(nb))) continue;
      if (e.length === 5) {
        const [, , cx, cy, r] = e;
        const a1 = Math.atan2(na.y - cy, na.x - cx), a2 = Math.atan2(nb.y - cy, nb.x - cx);
        let sweep = a2 - a1;
        while (sweep <= -Math.PI) sweep += Math.PI * 2;
        while (sweep > Math.PI) sweep -= Math.PI * 2;
        ctx.moveTo(na.x, na.y);
        ctx.arc(cx, cy, r, a1, a1 + sweep, sweep < 0);
      } else {
        ctx.moveTo(na.x, na.y);
        ctx.lineTo(nb.x, nb.y);
      }
    }
    ctx.strokeStyle = alloc ? COLORS.edgeAlloc : COLORS.edge;
    ctx.lineWidth = alloc ? lw * 1.6 : lw;
    ctx.stroke();
  }

  const path = s.advice?.path;
  if (path?.size) {
    ctx.beginPath();
    for (const e of layout.edges) {
      const [a, b] = e;
      const onPath = (path.has(a) && (path.has(b) || s.allocated.has(b))) || (path.has(b) && s.allocated.has(a));
      if (!onPath) continue;
      const na = byId.get(a), nb = byId.get(b);
      if (!na || !nb) continue;
      ctx.moveTo(na.x, na.y);
      if (e.length === 5) {
        const [, , cx, cy, r] = e;
        const a1 = Math.atan2(na.y - cy, na.x - cx), a2 = Math.atan2(nb.y - cy, nb.x - cx);
        let sweep = a2 - a1;
        while (sweep <= -Math.PI) sweep += Math.PI * 2;
        while (sweep > Math.PI) sweep -= Math.PI * 2;
        ctx.arc(cx, cy, r, a1, a1 + sweep, sweep < 0);
      } else ctx.lineTo(nb.x, nb.y);
    }
    ctx.save();
    ctx.strokeStyle = COLORS.next;
    ctx.globalAlpha = 0.8;
    ctx.lineWidth = lw * 1.4;
    ctx.setLineDash([lw * 3, lw * 2]);
    ctx.stroke();
    ctx.restore();
  }

  if (art) {
    // Notable/keystone background effects.
    for (const n of layout.nodes) {
      if (!n.effect || !visible(n) || otherAscendancy(n)) continue;
      const fx = art.sprite(n.effect);
      if (!fx) continue;
      ctx.globalAlpha = s.allocated.has(n.id) ? 0.9 : 0.12;
      drawSprite(ctx, fx, n.x, n.y, n.er);
    }
    ctx.globalAlpha = 1;
  }

  for (const n of layout.nodes) {
    if (n.type === "ClassStart" || !visible(n)) continue;
    const alloc = s.allocated.has(n.id);
    const lit = alloc || s.hovered === n.id;
    if (art) {
      const dim = otherAscendancy(n);
      if (dim) ctx.globalAlpha = 0.5;
      const chosen = layout.attributes?.[String(n.id)];
      const iconName = (chosen && n.options?.find((o) => o.name === chosen)?.icon) || n.icon;
      const icon = n.type === "Socket" ? null : art.sprite(iconName, !lit);
      if (icon && n.r) drawIcon(ctx, icon, n.x, n.y, n.r);
      const state = alloc ? 2 : s.highlighted.has(n.id) || s.hovered === n.id ? 1 : 0;
      const frame = art.sprite(n.frame?.[state]);
      if (frame) drawSprite(ctx, frame, n.x, n.y, n.fr ?? n.r);
      const jewel = n.type === "Socket" ? layout.jewels?.[String(n.id)] : undefined;
      if (jewel) {
        const gem = (jewel.title && art.sprite(jewel.title)) || art.sprite(jewel.baseName);
        if (gem) drawSprite(ctx, gem, n.x, n.y, (n.fr ?? n.r ?? 40) * 0.62);
      }
      else if (!icon) {
        ctx.beginPath();
        ctx.arc(n.x, n.y, nodeRadius(n), 0, Math.PI * 2);
        ctx.fillStyle = alloc ? COLORS.alloc : COLORS.node;
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    } else {
      let fill = COLORS.node;
      if (n.type === "Notable") fill = COLORS.notable;
      else if (n.type === "Keystone") fill = COLORS.keystone;
      else if (n.type === "Socket") fill = COLORS.socket;
      else if (n.ascendancy) fill = COLORS.asc;
      if (alloc) fill = COLORS.alloc;
      ctx.beginPath();
      ctx.arc(n.x, n.y, nodeRadius(n), 0, Math.PI * 2);
      ctx.fillStyle = fill;
      ctx.fill();
    }
    if (s.planned?.has(n.id) && !alloc) {
      ctx.save();
      ctx.lineWidth = Math.max(5, 2 / v.scale);
      ctx.strokeStyle = COLORS.planned;
      ctx.setLineDash([ctx.lineWidth * 2, ctx.lineWidth * 1.5]);
      ctx.beginPath();
      ctx.arc(n.x, n.y, (n.fr ?? nodeRadius(n)) * (art ? 0.9 : 1) + ctx.lineWidth, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }
    if (s.highlighted.has(n.id) || s.hovered === n.id) {
      const r = (n.fr ?? nodeRadius(n)) * (art ? 0.85 : 1);
      ctx.lineWidth = Math.max(4, 2.5 / v.scale);
      ctx.strokeStyle = s.hovered === n.id ? COLORS.hover : COLORS.highlight;
      ctx.beginPath();
      ctx.arc(n.x, n.y, r + ctx.lineWidth, 0, Math.PI * 2);
      ctx.stroke();
    }
  }

  const ring = (n: LayoutNode, color: string, width: number, pad: number, dash?: number[]) => {
    ctx.save();
    ctx.lineWidth = width;
    ctx.strokeStyle = color;
    if (dash) ctx.setLineDash(dash);
    ctx.beginPath();
    ctx.arc(n.x, n.y, (n.fr ?? nodeRadius(n)) * (art ? 0.9 : 1) + pad, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  };
  const adv = s.advice;
  if (adv) {
    const w = Math.max(6, 2.5 / v.scale);
    for (const [id] of adv.attributes ?? []) {
      const n = byId.get(id);
      if (n && visible(n)) ring(n, COLORS.attribute, w, w);
    }
    for (const id of adv.path ?? []) {
      const n = byId.get(id);
      if (n && visible(n) && id !== adv.next && id !== adv.target) ring(n, COLORS.next, w * 0.7, w * 0.8, [w * 1.5, w]);
    }
    const target = adv.target != null ? byId.get(adv.target) : undefined;
    if (target && adv.target !== adv.next) ring(target, COLORS.next, w, w * 1.2);
    const refund = adv.refund != null ? byId.get(adv.refund) : undefined;
    if (refund) ring(refund, COLORS.refund, w * 1.4, w * 1.2);
    const next = adv.next != null ? byId.get(adv.next) : undefined;
    if (next) {
      ring(next, COLORS.next, w * 1.6, w * 1.2);
      ring(next, COLORS.next, w * 0.6, w * 4, [w, w]);
    }
  }

  // Screen-space badges for the advisor (always readable regardless of zoom).
  if (adv) {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.font = "bold 11px Inter, system-ui, sans-serif";
    ctx.textAlign = "center";
    const badge = (id: number | undefined, text: string, color: string) => {
      const n = id != null ? byId.get(id) : undefined;
      if (!n) return;
      const [sx, sy] = toScreen(v, n.x, n.y);
      const top = sy - (n.fr ?? nodeRadius(n)) * v.scale - 14;
      const tw = ctx.measureText(text).width + 10;
      ctx.fillStyle = "rgba(10,10,12,0.85)";
      ctx.fillRect(sx - tw / 2, top - 10, tw, 15);
      ctx.strokeStyle = color;
      ctx.lineWidth = 1;
      ctx.strokeRect(sx - tw / 2 + 0.5, top - 9.5, tw - 1, 14);
      ctx.fillStyle = color;
      ctx.fillText(text, sx, top + 1);
    };
    if (v.scale > 0.08) {
      for (const [id, attr] of adv.attributes ?? []) badge(id, `→ ${SHORT_ATTR[attr] ?? attr}`, COLORS.attribute);
    }
    badge(adv.refund, "MOVE", COLORS.refund);
    badge(adv.next, "NEXT", COLORS.next);
    ctx.setTransform(dpr * v.scale, 0, 0, dpr * v.scale, dpr * v.x, dpr * v.y);
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
        ctx.fillText(n.name, sx, sy + (n.fr ?? nodeRadius(n)) * v.scale + 13);
      }
    }
  }
}

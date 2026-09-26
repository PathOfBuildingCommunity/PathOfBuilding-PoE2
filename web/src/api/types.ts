export interface BuildInfo {
  name?: string;
  className: string;
  ascendClassName?: string;
  level: number;
  levelAutoMode: boolean;
  treeVersion: string;
  pointsUsed: number;
  ascendancyPointsUsed: number;
  mainSocketGroup?: number;
  mainSkill?: string;
}

export interface StatRow {
  stat: string;
  label: string;
  value: number;
  formatted: string;
  overCap?: number;
  lowerIsBetter?: boolean;
  warning?: string;
}

export interface StatSummary {
  player: StatRow[];
  minion?: StatRow[];
  skillDPS: { name: string; dps: number; count: number; source?: string }[];
}

export interface Gem {
  name: string;
  level: number;
  quality: number;
  enabled: boolean;
  support: boolean;
  recognised: boolean;
}

export interface SkillGroup {
  index: number;
  label?: string;
  displayLabel?: string;
  slot?: string;
  enabled: boolean;
  isMain: boolean;
  gems: Gem[];
  activeSkills: { index: number; name: string; isMain: boolean }[];
  warnings?: string[];
}

export interface ModLine {
  text: string;
  kind: "enchant" | "rune" | "implicit" | "explicit";
  supported: boolean;
  crafted?: boolean;
}

export interface Item {
  id: number;
  name: string;
  title?: string;
  baseName: string;
  type: string;
  rarity: "NORMAL" | "MAGIC" | "RARE" | "UNIQUE" | "RELIC";
  corrupted?: boolean;
  itemLevel?: number;
  quality?: number;
  mods?: ModLine[];
  text?: string;
}

export interface SlotItem {
  slot: string;
  label?: string;
  jewelNodeId?: number;
  item?: Item;
}

export interface Overview {
  info: BuildInfo;
  stats: StatSummary;
  skills: SkillGroup[];
  items: { slot: string; name: string; rarity: string }[];
  config: Record<string, unknown>;
  revision: number;
}

export interface StatChange {
  stat: string;
  label: string;
  before: number;
  after: number;
  delta: number;
  percent?: number;
  better: boolean;
}

export interface Comparison {
  changes: StatChange[];
  pointDelta?: number;
  slot?: string;
  item?: string;
}

export interface TreeNodeInfo {
  id: number;
  name: string;
  type: string;
  ascendancy?: string;
  allocated: boolean;
  stats?: string[];
  pathLength?: number;
}

export interface LayoutNode {
  id: number;
  x: number;
  y: number;
  type: string;
  name?: string;
  ascendancy?: string;
}

export interface TreeLayout {
  treeVersion: string;
  nodes: LayoutNode[];
  edges: [number, number][];
  allocated: number[];
}

export interface ConfigOption {
  var: string;
  type: "check" | "count" | "integer" | "float" | "list";
  label: string;
  section?: string;
  value: unknown;
  default: unknown;
  shown: boolean;
  choices?: { value: string | number; label: string }[];
}

export interface ClassInfo {
  id: number;
  name: string;
  ascendancies: string[];
}

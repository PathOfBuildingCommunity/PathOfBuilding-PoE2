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
  budget?: BudgetCompare;
}

/** Spirit and totems for one calculation (PoB reports totem DPS per totem; these count real totems). */
export interface BudgetSummary {
  spirit: number;
  reserved: number;
  unreserved: number;
  totemCap?: number;
  totems?: number;
  totemsAffordable?: number;
  totemCost?: number;
  spiritLimited?: boolean;
  spiritShort?: number;
  perTotemDps?: number;
}

export interface BudgetCompare {
  before: BudgetSummary;
  after: BudgetSummary;
  effectiveBefore: number;
  effectiveAfter: number;
  warnings: string[];
}

export interface Budget extends BudgetSummary {
  effectiveDps: number;
  free: number;
  ancestralBond?: boolean;
  reservations: { name: string; spirit: number; totem?: boolean; count?: number }[];
}

export interface ItemCheck {
  item: string;
  slot: string;
  replaces?: string;
  verdict: "upgrade" | "sidegrade" | "downgrade";
  reasons: string[];
  warnings: string[];
  budget: { before: BudgetSummary; after: BudgetSummary };
  lostSkills: string[];
  skills: { group: number; name: string; isMain?: boolean; before: number; after: number; percent?: number; totemsBefore?: number; totemsAfter?: number; lost?: boolean }[];
  defence: Record<string, { before: number; after: number }>;
  caveat: string;
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
  /** Artwork asset names (see /tree-art/<version>/manifest.json) and draw radii in tree units. */
  icon?: string;
  r?: number;
  frame?: [string, string, string]; // unallocated, can-allocate, allocated
  fr?: number;
  effect?: string;
  er?: number;
  options?: { name: string; icon: string }[];
}

/** [from, to] for a straight connection, or [from, to, cx, cy, r] for one following an orbit arc. */
export type LayoutEdge = [number, number] | [number, number, number, number, number];

export interface LayoutImage {
  x: number;
  y: number;
  image: string;
  r?: number;
}

export interface LayoutClass {
  id: number;
  name: string;
  startNode?: number;
  image: string;
  ascendancyImages: Record<string, string>;
  x: number;
  y: number;
  w: number;
  h: number;
  treeW?: number;
  activeW?: number;
}

export interface LayoutAscendancy {
  name: string;
  className: string;
  image: string;
  x: number;
  y: number;
  w: number;
  h: number;
  replace?: boolean;
  replaceBy?: string;
}

export interface TreeLayout {
  treeVersion: string;
  nodes: LayoutNode[];
  edges: LayoutEdge[];
  decorations?: LayoutImage[];
  classes?: LayoutClass[];
  ascendancies?: LayoutAscendancy[];
  allocated: number[];
  attributes?: Record<string, string>;
  jewels?: Record<string, SocketedJewel>;
  className?: string;
  ascendClassName?: string;
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

// -- reference build (PoE2 BuildPlanner .build guide) --------------------------------------------------

export interface ReferenceSummary {
  name?: string;
  author?: string;
  link?: string;
  ascendancy?: string;
  passives: number;
  skills: number;
  items: number;
}

export interface RefNode {
  id: number;
  name?: string;
  type: string;
  ascendancy?: string;
}

export interface ReferenceSkill {
  name: string;
  note?: string;
  found: boolean;
  group?: number;
  enabled?: boolean;
  supports: string[];
  missingSupports: string[];
  extraSupports: string[];
  tierDifferences: { reference: string; current: string }[];
}

export interface ReferenceItem {
  slot: string;
  uniqueName?: string;
  note?: string;
  equipped?: { name: string; title?: string; baseName?: string; rarity?: string };
  match?: boolean;
}

export interface ReferenceCompare {
  name?: string;
  author?: string;
  link?: string;
  description?: string;
  level: number;
  stages: { from: number; to: number }[];
  ascendancy?: { internalId: string; className: string; name: string };
  current: { className?: string; ascendClassName?: string; points: number; ascendancyPoints: number };
  passives: {
    referencePoints: number;
    referenceAscendancyPoints: number;
    matched: number;
    missing: RefNode[];
    extra: RefNode[];
    weaponSetMismatch: number;
    unknown: string[];
  };
  skills: ReferenceSkill[];
  items: ReferenceItem[];
  unknownGems: string[];
}

export interface ImpactSummary {
  points: number;
  dpsPercent: number;
  ehpPercent: number;
  lifeDelta: number;
  esDelta: number;
}

export interface ImpactStep extends ImpactSummary {
  id: number;
  name: string;
  type: string;
  ascendancy?: string;
  path?: number[];
  score?: number;
}

export interface ReferenceImpact {
  level: number;
  base: { dps: number; ehp: number; life: number; es: number };
  fullTree: ImpactSummary & { added: number; removed: number; changes: StatChange[] };
  steps: ImpactStep[];
  extras: ImpactStep[];
}

// -- advisor ---------------------------------------------------------------------------------------------

export interface AdviceStep extends ImpactSummary {
  score: number;
  perPoint: number;
  target: RefNode;
  first: RefNode;
  /** Allocation order: path[0] touches your tree, the last id is the target. */
  path: number[];
  reason?: string;
  inGuide: boolean;
}

export interface AdviceRefund extends ImpactSummary {
  score: number;
  node: RefNode;
  reason: string;
  notInGuide: boolean;
}

export interface AttributeAdvice {
  id: number;
  current: string;
  recommended: string;
  weaponSet: number;
  reason: string;
  dpsPercent?: number;
  ehpPercent?: number;
  lifeDelta?: number;
  esDelta?: number;
  blockedBy?: string;
}

export interface Advice {
  mode: "guide" | "free";
  guide?: { name?: string; level: number };
  metric: "balanced" | "dps" | "ehp";
  next?: AdviceStep;
  steps: AdviceStep[];
  refunds: AdviceRefund[];
  move?: { refund: AdviceRefund; allocate: AdviceStep; netPerPoint: number; reason: string };
  attributes: { totals: Record<string, { value: number; required: number }>; nodes: AttributeAdvice[]; changes: number };
}

export interface SocketedJewel {
  name: string;
  title?: string;
  baseName?: string;
  rarity?: string;
  mods?: ModLine[];
}

// -- gear, shopping and gems advisors ---------------------------------------------------------------------

export interface Gain {
  dpsPercent: number;
  ehpPercent: number;
  lifeDelta: number;
  esDelta: number;
  score: number;
  /** Totems you could keep up, and Spirit, compared with now (only present when they change). */
  totemsDelta?: number;
  spiritDelta?: number;
}

export interface GearMod extends Gain {
  text: string;
  kind: "implicit" | "explicit";
  dead?: boolean;
  unmeasured?: boolean;
  requirement?: string;
}

export interface GearSlotRef {
  slot: string;
  jewel?: boolean;
  nodeId?: number;
  item?: { name: string; rarity: string; baseName: string };
}

export interface GearSlot {
  slot: string;
  metric: string;
  jewel?: boolean;
  item?: { name: string; rarity: string; baseName: string; title?: string };
  modsWorth?: Gain;
  mods?: GearMod[];
  deadMods?: number;
  lookFor?: { id: string; text: string; value: number; percent: number }[];
  currentPercent?: number;
  idealPercent?: number;
  headroom?: number;
  tradeUrl?: string;
  league?: string;
  unsupported?: boolean;
  testBase?: string;
}

export interface UniqueSuggestion extends Gain {
  name: string;
  baseName?: string;
  slot: string;
  levelRequirement?: number;
  price?: string;
  priceDivine?: number;
  listings?: number;
  gainPerDivine?: number;
  tradeUrl?: string;
}

export interface UniquesAdvice {
  league?: string;
  rates: Record<string, number>;
  slots: { slot: string; items: UniqueSuggestion[] }[];
}

export interface GemAdviceGem {
  index: number;
  name: string;
  support: boolean;
  level?: number;
  quality?: number;
  enabled: boolean;
  problems: string[];
  worth?: Gain;
  levelUp?: Gain;
  qualityUp?: Gain;
  noEffect?: boolean;
}

export interface GemAdviceGroup {
  index: number;
  label: string;
  skills: string[];
  isMain: boolean;
  measuredOn: "skill" | "build";
  gems: GemAdviceGem[];
  swap?: { replace: string; index: number; with: string; gain: Gain; alternatives: (Gain & { name: string })[] };
  lineage?: Gain & { name: string };
}

export interface GemUpgrade {
  kind: "level" | "quality" | "swap";
  group: number;
  index: number;
  name: string;
  from?: number;
  to?: number;
  with?: string;
  gain: Gain;
  text: string;
}

export interface GemAdvice {
  metric: string;
  groups: GemAdviceGroup[];
  upgrades: GemUpgrade[];
  problems: { group: number; index: number; name: string; problem: string }[];
}

export interface SourceInfo {
  source?: string;
  character: boolean;
  league?: string;
  loadedAt?: number;
}

// -- sockets (runes, soul cores, idols) -------------------------------------------------------------------

export interface SocketDelta {
  score: number;
  dpsPercent: number;
  ehpPercent: number;
  totemsDelta?: number;
  spiritDelta?: number;
}

export interface SocketOption extends SocketDelta {
  name: string;
  type?: string;
  limitId?: string;
  lines: string[];
  bonded?: string[];
  /** Lines PoB does not model (their effect isn't in the numbers). */
  unmodelled?: string[];
  /** Only legal after freeing a character-wide limit held in these sockets. */
  blockedBy?: { slot: string; socket: number; name: string }[];
}

export interface SocketWorth extends SocketOption {
  dead?: boolean;
  socketBound?: boolean;
}

export interface SocketInfo {
  index: number;
  current: string;
  worth?: SocketWorth;
  legalOptions?: number;
  bestGain?: number;
  alternatives?: SocketOption[];
}

export interface SocketSlot {
  slot: string;
  item: string;
  corrupted?: boolean;
  unique?: boolean;
  sockets: SocketInfo[];
}

export interface SocketAdvice {
  metric: string;
  note: string;
  slots: SocketSlot[];
}

export interface SocketPlanStep extends SocketDelta {
  slot: string;
  socket: number;
  from: string;
  to: string;
  lines: string[];
  unmodelled?: string[];
  pairedWith?: string;
  losesUnmodelled?: string[];
}

export interface SocketPlan {
  metric: string;
  steps: SocketPlanStep[];
  total?: SocketDelta;
  warnings: string[];
  note: string;
}

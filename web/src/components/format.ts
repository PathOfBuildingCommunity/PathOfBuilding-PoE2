export function fmtNum(v: number, digits = 1): string {
  const abs = Math.abs(v);
  if (abs >= 1e9) return `${(v / 1e9).toFixed(2)}B`;
  if (abs >= 1e6) return `${(v / 1e6).toFixed(2)}M`;
  if (abs >= 1e4) return `${(v / 1e3).toFixed(1)}K`;
  return Number.isInteger(v) ? v.toLocaleString() : v.toFixed(digits);
}

export const rarityColor: Record<string, string> = {
  NORMAL: "text-ink-200",
  MAGIC: "text-magic",
  RARE: "text-rare",
  UNIQUE: "text-unique",
  RELIC: "text-good",
};

const OFFENCE = /DPS|Hit|Damage|Speed|Crit|Rate|Cast|Attack|Cooldown/i;
const DEFENCE = /Life|Energy Shield|Mana|Resist|Armour|Evasion|Block|Max Hit|EHP|Ward|Spirit|Recovery|Regen|Leech/i;

export function statGroup(label: string): "offence" | "defence" | "other" {
  if (/Cost|Movement/.test(label)) return "other";
  if (DEFENCE.test(label)) return "defence";
  if (OFFENCE.test(label)) return "offence";
  return "other";
}

export function statColor(label: string): string {
  if (/Energy Shield|ES /.test(label)) return "text-es";
  if (/Mana/.test(label)) return "text-mana";
  if (/Life/.test(label)) return "text-life";
  return "text-ink-200";
}

// extract_statdesc.mjs — build a zh-template -> en-template map for *all* stat
// description lines (gem/skill mechanics, mods, etc.) from the 国服 client's
// StatDescriptions (`Data/StatDescriptions/*.csd`).
//
// Why: trade /data/stats only covers *searchable* stats. Gem tooltips and many
// item mods are rendered from the client's StatDescriptions system, which the
// trade dictionary doesn't include. Each .csd file holds every language in one
// place (default section = English, then `lang "Simplified Chinese"` sections),
// keyed by the same stat ids, with {0}/{1} placeholders + [Key|Display] markup.
// We pair the English and Simplified-Chinese lines of each block by index.
//
// Output: tool/data/stat_lines.json = [[zhTemplate, enTemplate], ...] (markup
// stripped, {N} placeholders kept). build_dict.py turns this into the runtime
// lookup. Run with the sibling portable node (same as extract_items.mjs):
//   <...>/filterblade2cn/tool/node/node.exe extract_statdesc.mjs [cnInstall]

import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { openInstall, listPaths, findGuofuInstall } from './engine.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT_DATA = path.join(HERE, 'data');

async function resolveCnInstall() {
  const extra = [];
  const cli = process.argv.slice(2).find(a => !a.startsWith('--'));
  if (cli) extra.push(cli);
  try {
    const cfg = JSON.parse(await fs.readFile(path.join(OUT_DATA, 'config.json'), 'utf8'));
    if (cfg.cnInstall) extra.push(cfg.cnInstall);
  } catch {}
  const found = await findGuofuInstall(extra);
  if (!found) {
    console.error('[statdesc] FATAL: 国服 (WeGame) PoE2 client not found. Pass the path ' +
      'explicitly or set cnInstall in tool/data/config.json.');
    process.exit(1);
  }
  return found;
}

// [Key|Display] -> Display ; [Display] -> Display ; {N:fmt} -> {N}
function clean(s) {
  if (!s) return '';
  return s.replace(/\[([^\]|]+)\|([^\]]+)\]/g, '$2')
          .replace(/\[([^\]]+)\]/g, '$1')
          .replace(/\{(\d+)(?::[^}]*)?\}/g, '{$1}')
          .trim();
}

// Extract the first double-quoted string from a stat-description line
// (ignoring the leading range tokens and trailing modifiers).
function quoted(line) {
  const qi = line.indexOf('"');
  if (qi < 0) return null;
  let s = '';
  for (let j = qi + 1; j < line.length; j++) {
    const c = line[j];
    if (c === '\\' && j + 1 < line.length) { s += line[j + 1]; j++; continue; }
    if (c === '"') return s;
    s += c;
  }
  return null;
}

// Parse one .csd file into [{en:[lines], zh:[lines]}] blocks.
function parseCsd(text) {
  const lines = text.split(/\r?\n/);
  let i = 0;
  const blocks = [];
  const readSection = () => {
    const n = parseInt((lines[i] || '').trim(), 10);
    i++;
    const out = [];
    if (!Number.isFinite(n)) return out;
    for (let k = 0; k < n && i < lines.length; k++, i++) out.push(quoted(lines[i]));
    return out;
  };
  while (i < lines.length) {
    if (lines[i].trim() !== 'description') { i++; continue; }
    i++;                                   // skip "description"
    i++;                                   // skip "<count> <ids...>"
    const en = readSection();              // default (English) section
    const langs = {};
    while (i < lines.length && /^\s*lang\s+"/.test(lines[i])) {
      const name = lines[i].trim().match(/^lang\s+"(.+)"$/);
      i++;
      langs[name ? name[1] : '?'] = readSection();
    }
    blocks.push({ en, zh: langs['Simplified Chinese'] || null });
  }
  return blocks;
}

async function main() {
  const cnInstall = await resolveCnInstall();
  console.log(`[statdesc] CN install: ${cnInstall}`);
  const getFile = await openInstall(cnInstall);
  // For PoB item parsing we want the FULL StatDescriptions set (every item mod,
  // implicit, rune, enchant, skill line), not just the trade-relevant subset the
  // trade-helper kept. So take every .csd under StatDescriptions/. The `seen`
  // dedup below keeps the first en-template per zh string.
  // Priority order: the canonical item-mod files first so that when the same zh
  // string appears in several files (e.g. a monster/skill .csd), the item-mod
  // English template is the one that wins the `seen` dedup below.
  const PRIORITY = [
    /\/stat_descriptions\.csd$/i,
    /\/advanced_mod_stat_descriptions\.csd$/i,
    /\/gem_stat_descriptions\.csd$/i,
    /\/active_skill_gem_stat_descriptions\.csd$/i,
    /\/skill_stat_descriptions\.csd$/i,
  ];
  const prio = (p) => { const i = PRIORITY.findIndex(re => re.test(p)); return i < 0 ? PRIORITY.length : i; };
  const paths = listPaths(getFile)
    .filter(p => /statdescriptions\/.*\.csd$/i.test(p))
    .sort((a, b) => prio(a) - prio(b) || a.localeCompare(b));
  console.log(`[statdesc] ${paths.length} .csd files (full StatDescriptions set)`);

  const dec = new TextDecoder('utf-16le');
  const seen = new Set();
  const pairs = [];
  let files = 0;
  for (const p of paths) {
    const bytes = await getFile(p);
    if (!bytes) continue;
    files++;
    let text = dec.decode(bytes);
    if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
    for (const b of parseCsd(text)) {
      if (!b.zh) continue;
      const n = Math.min(b.en.length, b.zh.length);
      for (let k = 0; k < n; k++) {
        const en = clean(b.en[k]);
        const zh = clean(b.zh[k]);
        if (!en || !zh || en === zh) continue;
        if (seen.has(zh)) continue;        // first template wins per zh
        seen.add(zh);
        pairs.push([zh, en]);
      }
    }
  }

  await fs.mkdir(OUT_DATA, { recursive: true });
  await fs.writeFile(path.join(OUT_DATA, 'stat_lines.json'),
    JSON.stringify(pairs), 'utf8');
  await fs.writeFile(path.join(OUT_DATA, 'stat_lines.meta.json'), JSON.stringify({
    when: new Date().toISOString(), cnInstall, files, pairs: pairs.length,
  }, null, 2), 'utf8');
  console.log(`[statdesc] parsed ${files} files -> ${pairs.length} zh->en stat-line templates`);
  console.log(`[statdesc] wrote ${path.join(OUT_DATA, 'stat_lines.json')}`);
}

main().catch(e => { console.error('[statdesc] ERROR:', e); process.exit(1); });

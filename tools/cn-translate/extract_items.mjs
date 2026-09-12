// extract_items.mjs — datamine en<->zh item/skill/unique names from the 国服
// (WeGame) PoE2 client, joined on the language-independent metadata `Id` (or row
// index for Words). Self-contained: uses ./engine.mjs + this folder's
// node_modules (run `npm install` once). Run under WSL node:
//   node extract_items.mjs [cnInstallPath] [--refresh-schema]
//
// Outputs (tool/data/): item_bases.json, item_classes.json, skill_text.json,
// unique_names.json, items.meta.json. Re-run after a 国服 client patch.

import * as fs from 'fs/promises';
import { existsSync } from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import {
  getSchema, openInstall, extractTable, sanityCheckBaseItems, findGuofuInstall,
} from './engine.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const DATA = path.join(HERE, 'data');
const SCHEMA_CACHE = path.join(DATA, 'schema.cache.json');
const LANG = 'Simplified Chinese';

const args = process.argv.slice(2);
const refreshSchema = args.includes('--refresh-schema');

async function resolveCnInstall() {
  const cli = args.find(a => !a.startsWith('--'));
  const extra = cli ? [cli] : [];
  try {
    const cfg = JSON.parse(await fs.readFile(path.join(DATA, 'config.json'), 'utf8'));
    if (cfg.cnInstall) extra.push(cfg.cnInstall);
  } catch {}
  const found = await findGuofuInstall(extra);
  if (!found) {
    console.error(
      '[extract_items] FATAL: 国服 (WeGame) PoE2 client not found.\n' +
      '  This tool requires the WeGame install (the only source of the 国服\n' +
      '  Simplified-Chinese names). Pass the path explicitly, e.g.\n' +
      '    node extract_items.mjs "/mnt/c/WeGameApps/rail_apps/Path of  Exile 2(2002052)"\n' +
      '  or put {"cnInstall":"C:\\\\...\\\\Path of  Exile 2(...)"} in tool/data/config.json.');
    process.exit(1);
  }
  return found;
}

// Join an English row set against a localized set on `Id`. [{id, en, zh}].
function joinById(enRows, zhRows, enCol = 'Name', zhCol = 'Name') {
  const zhById = new Map(zhRows.map(r => [r.Id, r[zhCol]]));
  const out = []; let translated = 0;
  for (const r of enRows) {
    const en = r[enCol]; if (!en) continue;
    const zh = zhById.get(r.Id); const z = (zh != null && zh !== '') ? zh : en;
    if (z !== en) translated++;
    out.push({ id: r.Id, en, zh: z });
  }
  return { rows: out, translated };
}

async function main() {
  const cnInstall = await resolveCnInstall();
  console.log(`[extract_items] CN install: ${cnInstall}`);
  if (!existsSync(path.join(cnInstall, 'Bundles2', '_.index.bin'))) {
    console.error('[extract_items] FATAL: no Bundles2/_.index.bin at install path.');
    process.exit(1);
  }
  await fs.mkdir(DATA, { recursive: true });
  const { schema, source } = await getSchema(SCHEMA_CACHE, { forceRefresh: refreshSchema });
  console.log(`[extract_items] schema: ${source} (v${schema.version})`);
  const get = await openInstall(cnInstall);

  // BaseItemTypes (Id, Name) EN + SC
  const enBit = await extractTable(get, schema, 'BaseItemTypes');
  const sanity = sanityCheckBaseItems(enBit.rows);
  if (!sanity.ok) {
    console.error(`[extract_items] SANITY FAILED for BaseItemTypes `
      + `(rows=${sanity.rowCount}, sentinels=${JSON.stringify(sanity.sentinelsFound)}). Aborting.`);
    process.exit(2);
  }
  const zhBit = await extractTable(get, schema, 'BaseItemTypes', LANG);
  const bases = joinById(enBit.rows, zhBit.rows);

  // ItemClasses (Id, Name) EN + SC
  const enCls = await extractTable(get, schema, 'ItemClasses');
  const zhCls = await extractTable(get, schema, 'ItemClasses', LANG);
  const classes = joinById(enCls.rows, zhCls.rows);

  // ActiveSkills (Id, DisplayedName, Description) EN + SC
  const SK = ['Id', 'DisplayedName', 'Description'];
  let skills = [];
  try {
    const enSk = await extractTable(get, schema, 'ActiveSkills', null, SK);
    const zhSk = await extractTable(get, schema, 'ActiveSkills', LANG, SK);
    const zById = new Map(zhSk.rows.map(r => [r.Id, r]));
    for (const r of enSk.rows) {
      const z = zById.get(r.Id) || {};
      const row = { id: r.Id,
        en_name: r.DisplayedName || '', zh_name: z.DisplayedName || r.DisplayedName || '',
        en_desc: r.Description || '', zh_desc: z.Description || r.Description || '' };
      if (row.en_name || row.en_desc) skills.push(row);
    }
  } catch (e) { console.warn(`[extract_items] ActiveSkills failed (${e.message}); skipped.`); }

  // Words.Text2 EN + SC, joined by ROW INDEX — localized unique item names
  // (and other display words). Covers the find-items list's unique entries.
  let uniques = [];
  try {
    const enW = await extractTable(get, schema, 'Words', null, ['Text2']);
    const zhW = await extractTable(get, schema, 'Words', LANG, ['Text2']);
    const seen = new Set();
    const n = Math.min(enW.rowCount, zhW.rowCount);
    for (let i = 0; i < n; i++) {
      const en = enW.rows[i].Text2, zh = zhW.rows[i].Text2;
      if (en && zh && en !== zh && !seen.has(zh)) { seen.add(zh); uniques.push([zh, en]); }
    }
  } catch (e) { console.warn(`[extract_items] Words failed (${e.message}); uniques skipped.`); }

  await fs.writeFile(path.join(DATA, 'item_bases.json'), JSON.stringify(bases.rows), 'utf8');
  await fs.writeFile(path.join(DATA, 'item_classes.json'), JSON.stringify(classes.rows), 'utf8');
  await fs.writeFile(path.join(DATA, 'skill_text.json'), JSON.stringify(skills), 'utf8');
  await fs.writeFile(path.join(DATA, 'unique_names.json'), JSON.stringify(uniques), 'utf8');
  await fs.writeFile(path.join(DATA, 'items.meta.json'), JSON.stringify({
    when: new Date().toISOString(), schemaVersion: schema.version, cnInstall,
    baseItemTypes: { named: bases.rows.length, translated: bases.translated },
    itemClasses: { named: classes.rows.length, translated: classes.translated },
    activeSkills: skills.length, uniqueWords: uniques.length,
  }, null, 2), 'utf8');

  console.log(`[extract_items] BaseItemTypes: ${bases.rows.length} (${bases.translated} translated)`);
  console.log(`[extract_items] ItemClasses:  ${classes.rows.length}`);
  console.log(`[extract_items] ActiveSkills: ${skills.length}`);
  console.log(`[extract_items] Words(Text2): ${uniques.length} zh->en (unique names + display words)`);
  console.log('[extract_items] wrote tool/data/{item_bases,item_classes,skill_text,unique_names}.json');
}

main().catch(e => { console.error('[extract_items] ERROR:', e); process.exit(1); });

// extract_mods.mjs — datamine en<->zh affix (modifier) display names from the 国服
// client's Mods table, joined on the language-independent Id. These are the names
// inside item-paste affix annotations, e.g. { 前缀属性 "龙胆的" ... } -> the English
// affix name, so PoB can match the affix and populate prefix/suffix tiers. Run under
// WSL node:  node extract_mods.mjs
// Output: tool/data/mod_names.json = [{id, en, zh}].
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { getSchema, openInstall, extractTable, findGuofuInstall } from './engine.mjs';

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
  if (!found) { console.error('[mods] FATAL: 国服 client not found.'); process.exit(1); }
  return found;
}

async function main() {
  const cnInstall = await resolveCnInstall();
  console.log(`[mods] CN install: ${cnInstall}`);
  await fs.mkdir(DATA, { recursive: true });
  const { schema, source } = await getSchema(SCHEMA_CACHE, { forceRefresh: refreshSchema });
  console.log(`[mods] schema: ${source} (v${schema.version})`);
  const get = await openInstall(cnInstall);

  const en = await extractTable(get, schema, 'Mods', null, ['Id', 'Name']);
  const zh = await extractTable(get, schema, 'Mods', LANG, ['Id', 'Name']);
  const zhById = new Map(zh.rows.map(r => [r.Id, r.Name]));
  const out = []; const seenZh = new Set();
  for (const r of en.rows) {
    const e = r.Name; if (!e || !r.Id) continue;
    const z = zhById.get(r.Id);
    if (!z || z === e || seenZh.has(z)) continue;   // skip blank / untranslated / dup
    seenZh.add(z);
    out.push({ id: r.Id, en: e, zh: z });
  }
  await fs.writeFile(path.join(DATA, 'mod_names.json'), JSON.stringify(out), 'utf8');
  console.log(`[mods] Mods.Name: ${out.length} distinct zh affix names -> mod_names.json`);
}
main().catch(e => { console.error('[mods] ERROR:', e); process.exit(1); });

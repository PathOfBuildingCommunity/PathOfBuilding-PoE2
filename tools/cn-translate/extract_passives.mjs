// extract_passives.mjs — datamine en<->zh passive-tree node names from the 国服
// client's PassiveSkills table, joined on the language-independent Id. These are
// needed for anointment mods, which render as "Allocates <PassiveNodeName>"
// (配置 <节点名>). Run under WSL node:  node extract_passives.mjs
// Output: tool/data/passive_names.json = [{id, en, zh}].
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
  if (!found) { console.error('[passives] FATAL: 国服 client not found.'); process.exit(1); }
  return found;
}

async function main() {
  const cnInstall = await resolveCnInstall();
  console.log(`[passives] CN install: ${cnInstall}`);
  await fs.mkdir(DATA, { recursive: true });
  const { schema, source } = await getSchema(SCHEMA_CACHE, { forceRefresh: refreshSchema });
  console.log(`[passives] schema: ${source} (v${schema.version})`);
  const get = await openInstall(cnInstall);

  const COLS = ['Id', 'Name', 'IsNotable', 'IsKeystone', 'IsAnointmentOnly'];
  const en = await extractTable(get, schema, 'PassiveSkills', null, COLS);
  const zh = await extractTable(get, schema, 'PassiveSkills', LANG, ['Id', 'Name']);
  const zhById = new Map(zh.rows.map(r => [r.Id, r.Name]));
  const out = []; const seenZh = new Set(); let notables = 0;
  for (const r of en.rows) {
    const e = r.Name; if (!e || !r.Id) continue;
    const z = zhById.get(r.Id);
    if (!z || z === e || seenZh.has(z)) continue;
    seenZh.add(z);
    out.push({ id: r.Id, en: e, zh: z });
    if (r.IsNotable || r.IsKeystone || r.IsAnointmentOnly) notables++;
  }
  await fs.writeFile(path.join(DATA, 'passive_names.json'), JSON.stringify(out), 'utf8');
  console.log(`[passives] PassiveSkills: ${out.length} distinct zh names (${notables} notable/keystone/anoint) -> passive_names.json`);
}
main().catch(e => { console.error('[passives] ERROR:', e); process.exit(1); });

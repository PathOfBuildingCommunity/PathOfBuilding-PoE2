// extract_clientstrings.mjs — datamine en<->zh UI label/flag strings from the
// 国服 client's ClientStrings table (Id + Text), joined on Id. These are the
// item-paste labels (Item Class, Rarity, Requires, Quality, Sockets, Item Level,
// Grants Skill, ...) and state flags (Corrupted, Unidentified, ...). Run under WSL:
//   node extract_clientstrings.mjs [cnInstall] [--refresh-schema]
// Output: tool/data/client_strings.json = [{id, en, zh}].
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
  if (!found) { console.error('[clientstrings] FATAL: 国服 client not found.'); process.exit(1); }
  return found;
}

async function main() {
  const cnInstall = await resolveCnInstall();
  console.log(`[clientstrings] CN install: ${cnInstall}`);
  await fs.mkdir(DATA, { recursive: true });
  const { schema, source } = await getSchema(SCHEMA_CACHE, { forceRefresh: refreshSchema });
  console.log(`[clientstrings] schema: ${source} (v${schema.version})`);
  const get = await openInstall(cnInstall);

  const COLS = ['Id', 'Text'];
  const en = await extractTable(get, schema, 'ClientStrings', null, COLS);
  const zh = await extractTable(get, schema, 'ClientStrings', LANG, COLS);
  const zhById = new Map(zh.rows.map(r => [r.Id, r.Text]));
  const out = []; let translated = 0;
  for (const r of en.rows) {
    if (!r.Id) continue;
    const e = r.Text, z = zhById.get(r.Id);
    out.push({ id: r.Id, en: e || '', zh: (z != null && z !== '') ? z : (e || '') });
    if (z && z !== e) translated++;
  }
  await fs.writeFile(path.join(DATA, 'client_strings.json'), JSON.stringify(out), 'utf8');
  console.log(`[clientstrings] ClientStrings: ${out.length} (${translated} translated) -> client_strings.json`);
}
main().catch(e => { console.error('[clientstrings] ERROR:', e); process.exit(1); });

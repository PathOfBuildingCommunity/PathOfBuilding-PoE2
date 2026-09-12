// engine.mjs — self-contained .dat extraction for the trade helper's datamine.
// Reads the 国服 client's Bundles2 via the bundled pathofexile-dat (WASM Oodle).
// Designed to run under WSL node; game paths are POSIX (/mnt/c/...). No deps on
// any sibling project — `npm install` in this folder provides everything.
import * as fs from 'fs/promises';
import { existsSync } from 'fs';
import * as path from 'path';

const PKG = './node_modules/pathofexile-dat/dist/';
const { decompressSliceInBundle, decompressedBundleSize } = await import(PKG + 'bundles/bundle.js');
const { readIndexBundle, getFileInfo } = await import(PKG + 'bundles/index-bundle.js');
const { unpackPaths } = await import(PKG + 'bundles/index-paths.js');
const { getHeaderLength } = await import(PKG + 'dat/header.js');
const { readDatFile } = await import(PKG + 'dat/dat-file.js');
const { readColumn } = await import(PKG + 'dat/reader.js');
const { ValidFor } = await import('pathofexile-dat-schema');

const SCHEMA_URL = 'https://github.com/poe-tool-dev/dat-schema/releases/download/latest/schema.min.json';

// "C:\Users\x" -> "/mnt/c/Users/x"; POSIX paths pass through unchanged.
export function winToWsl(p) {
  const m = /^([A-Za-z]):[\\/](.*)$/.exec(p || '');
  return m ? `/mnt/${m[1].toLowerCase()}/${m[2].replace(/\\/g, '/')}` : p;
}

export async function getSchema(cachePath, { forceRefresh = false } = {}) {
  if (!forceRefresh && existsSync(cachePath)) {
    try { return { schema: JSON.parse(await fs.readFile(cachePath, 'utf8')), source: 'cache' }; } catch {}
  }
  try {
    const r = await (await fetch(SCHEMA_URL)).json();
    await fs.writeFile(cachePath, JSON.stringify(r));
    return { schema: r, source: 'downloaded' };
  } catch (e) {
    const c = JSON.parse(await fs.readFile(cachePath, 'utf8'));   // offline fallback
    return { schema: c, source: 'cache (download failed)' };
  }
}

// Auto-detect the 国服 (WeGame) PoE2 install under common WeGame roots (POSIX).
export async function findGuofuInstall(extra = []) {
  const valid = (dir) => existsSync(path.join(dir, 'Bundles2', '_.index.bin'));
  const cands = (extra || []).map(winToWsl);
  for (const drive of ['c', 'd', 'e', 'f']) {
    for (const root of [`/mnt/${drive}/WeGameApps/rail_apps`,
                        `/mnt/${drive}/WeGame/rail_apps`,
                        `/mnt/${drive}/Program Files/WeGame/rail_apps`,
                        `/mnt/${drive}/Program Files (x86)/WeGame/rail_apps`]) {
      let entries = [];
      try { entries = await fs.readdir(root); } catch { continue; }
      for (const e of entries) if (/path of\s+exile 2/i.test(e)) cands.push(path.join(root, e));
    }
  }
  for (const c of cands) if (valid(c)) return c;
  return null;
}

export async function openInstall(gameDir) {
  const indexBin = await fs.readFile(path.join(gameDir, 'Bundles2', '_.index.bin'));
  const ib = new Uint8Array(decompressedBundleSize(indexBin));
  decompressSliceInBundle(indexBin, 0, ib);
  const idx = readIndexBundle(ib);
  const cache = new Map();
  const getFile = async (full) => {
    const loc = getFileInfo(full, idx.bundlesInfo, idx.filesInfo);
    if (!loc) return null;
    let bin = cache.get(loc.bundle);
    if (!bin) { bin = await fs.readFile(path.join(gameDir, 'Bundles2', loc.bundle)); cache.set(loc.bundle, bin); }
    const out = new Uint8Array(loc.size); decompressSliceInBundle(bin, loc.offset, out); return out;
  };
  getFile.__idx = idx;
  return getFile;
}

export function listPaths(getFile) {
  const idx = getFile.__idx;
  const pr = new Uint8Array(decompressedBundleSize(idx.pathRepsBundle));
  decompressSliceInBundle(idx.pathRepsBundle, 0, pr);
  return unpackPaths(pr);
}

function importHeaders(schema, name, datFile) {
  const found = schema.tables.filter(s => s.name === name);
  const sch = found.find(s => s.validFor & ValidFor.PoE2) ?? found[0];
  if (!sch) throw new Error(`no schema for table "${name}"`);
  const headers = []; let off = 0;
  for (const c of sch.columns) {
    const h = { name: c.name || '', offset: off, type: {
      array: c.array, interval: c.interval,
      integer: c.type === 'u16' ? { unsigned: true, size: 2 } : c.type === 'u32' ? { unsigned: true, size: 4 }
        : c.type === 'i16' ? { unsigned: false, size: 2 } : c.type === 'i32' ? { unsigned: false, size: 4 }
        : c.type === 'enumrow' ? { unsigned: false, size: 4 } : undefined,
      decimal: c.type === 'f32' ? { size: 4 } : undefined,
      string: c.type === 'string' ? {} : undefined,
      boolean: c.type === 'bool' ? {} : undefined,
      key: (c.type === 'row' || c.type === 'foreignrow') ? { foreign: c.type === 'foreignrow' } : undefined,
    } };
    headers.push(h); off += getHeaderLength(h, datFile);
  }
  return headers;
}

// Extract `columns` from a table. langDir reads the localized overlay at
// Data/Balance/<langDir>/<table>.datc64 (e.g. 'Simplified Chinese').
export async function extractTable(getFile, schema, tableName, langDir = null,
                                   columns = ['Id', 'Name']) {
  const rel = langDir
    ? `Data/Balance/${langDir}/${tableName}.datc64`
    : `Data/Balance/${tableName}.datc64`;
  const bytes = await getFile(rel);
  if (!bytes) throw new Error(`Table not found in bundles: ${rel}`);
  const datFile = readDatFile('.datc64', bytes);
  const headers = importHeaders(schema, tableName, datFile);
  const want = columns.filter(c => headers.some(h => h.name === c));
  const cols = want.map(n => ({ n, data: readColumn(headers.find(h => h.name === n), datFile) }));
  const rows = Array(datFile.rowCount).fill(0).map((_, i) =>
    Object.fromEntries(cols.map(c => [c.n, c.data[i]])));
  return { rows, rowCount: datFile.rowCount };
}

export function sanityCheckBaseItems(rows) {
  const names = new Set(rows.map(r => r.Name).filter(Boolean));
  const must = ['Chaos Orb', 'Exalted Orb', 'Scroll of Wisdom'];
  const present = must.filter(m => names.has(m));
  return { ok: rows.length > 3000 && present.length === must.length,
    rowCount: rows.length, distinctNames: names.size, sentinelsFound: present };
}

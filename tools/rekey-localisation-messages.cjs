// 以模块、函数和控件/数据身份重命名消息 key；英文正文不参与命名。
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { analysisSource, readLiteral, parser } = require('./migrate-localisation-keys.cjs');
const root = path.resolve(__dirname, '..');
const snake = value => value.replace(/([a-z0-9])([A-Z])/g, '$1_$2').replace(/[^a-z0-9]+/gi, '_').replace(/^_|_$/g, '').toLowerCase();
const calls = new Map();
const bindingFile = path.join(root, 'src/Locales/MessageBindings.json');
const existing = fs.existsSync(bindingFile) ? JSON.parse(fs.readFileSync(bindingFile, 'utf8')) : { mapping: {} };
const established = new Set(Object.values(existing.mapping));
const hashes = [];
const files = [];
for (const folder of ['src/Classes', 'src/Modules']) {
  for (const name of fs.readdirSync(path.join(root, folder)).sort()) if (name.endsWith('.lua')) files.push(folder + '/' + name);
}
files.push(...['Launch.lua', 'LaunchInstall.lua', 'UpdateCheck.lua', 'UpdateApply.lua'].map(name => 'src/' + name).filter(name => fs.existsSync(path.join(root, name))));

// 仅使用原本已存在的函数、控件和数据标识；无法定位的引用单独输出。
for (const file of files) {
  const source = fs.readFileSync(path.join(root, file)).toString('latin1');
  hashes.push({ file, sha256: crypto.createHash('sha256').update(Buffer.from(source, 'latin1')).digest('hex') });
  const ast = parser.parse(analysisSource(source), { luaVersion: '5.3', encodingMode: 'pseudo-latin1', ranges: true, locations: true, comments: false });
  const namespace = snake(path.basename(file, '.lua'));
  const walk = (node, context = { scope: 'module', owner: '', role: 'message' }) => {
    if (!node || typeof node !== 'object') return;
    context = { ...context };
    if (node.type === 'FunctionDeclaration' && node.identifier) context.scope = snake(node.identifier.identifier?.name || node.identifier.name || context.scope);
    if (node.type === 'AssignmentStatement' || node.type === 'LocalStatement') {
      node.init.forEach((value, index) => {
        const variable = node.variables[index];
        const owner = variable && source.slice(...variable.range).replace(/^self\./, '').replace(/^controls\./, '');
        walk(value, { ...context, owner: owner ? snake(owner) : context.owner });
      });
      return;
    }
    if (node.type === 'TableConstructorExpression') {
      let identified = false;
      for (const name of ['controlName', 'var', 'stat', 'key', 'id']) {
        const identity = node.fields.find(field => field.type === 'TableKeyString' && field.key.name === name && field.value.type === 'StringLiteral');
        if (identity) { context.owner = snake(readLiteral(identity.value)); identified = true; break; }
      }
      // 计算表格行没有独立 ID 时，使用其直接显示列的原输出字段身份。
      if (!identified) {
        const columns = node.fields.filter(field => field.type === 'TableValue' && field.value.type === 'TableConstructorExpression').map(field => field.value);
        for (const column of [node, ...columns]) {
          const format = column.fields.find(field => field.type === 'TableKeyString' && field.key.name === 'format' && field.value.type === 'StringLiteral');
          const output = format && readLiteral(format.value).match(/\{(?:\d+:)?output:([a-z0-9_]+)/i);
          if (output) { context.owner = snake(output[1]); break; }
        }
      }
      if (file.endsWith('/CalcSections.lua') && node.fields[1]?.type === 'TableValue' && node.fields[1].value.type === 'StringLiteral') {
        context.scope = snake(readLiteral(node.fields[1].value));
      }
    }
    if (node.type === 'TableKeyString') {
      const name = node.key.name;
      if (name.endsWith('Key')) context.role = snake(name.slice(0, -3));
    }
    if (node.type === 'CallExpression') {
      const name = node.base.type === 'MemberExpression' ? node.base.identifier.name : node.base.name;
      if (name === 'NewSection' && node.arguments[1]?.type === 'StringLiteral') context.owner = snake(readLiteral(node.arguments[1]));
      if (name === 'AddLine') context.role = 'tooltip';
      else if (/Control$/.test(name || '')) context.role = name === 'EditControl' ? 'prompt' : 'label';
      else if (name === 'Label') context.role = 'label';
      else if (name === 'ShowErrMsg') context.role = 'error';
      else if (name === 'SetWindowTitle') context.role = 'title';
    }
    if (node.type === 'StringLiteral' && readLiteral(node).startsWith('ui.')) {
      const key = readLiteral(node);
      if (established.has(key)) return;
      const scope = context.scope === namespace ? 'init' : context.scope;
      const parts = ['ui', namespace, scope, context.owner, context.role].filter(Boolean);
      const base = parts.filter((part, index) => part !== parts[index - 1]).join('.');
      if (!calls.has(key)) calls.set(key, []);
      calls.get(key).push({ file, line: node.loc.start.line, base });
      return;
    }
    for (const [name, child] of Object.entries(node)) {
      if (['range', 'loc'].includes(name)) continue;
      if (Array.isArray(child)) child.forEach(part => walk(part, context));
      else if (child && typeof child === 'object') walk(child, context);
    }
  };
  walk(ast);
}
const used = new Set([...fs.readFileSync(path.join(root, 'src/Locales/en/Messages.csv'), 'utf8').matchAll(/^([a-z][a-z0-9_.]*),/gm)].map(match => match[1]));
const result = { files: hashes, mapping: {}, evidence: [] };
for (const [oldKey, references] of [...calls].sort((a, b) => a[0].localeCompare(b[0]))) {
  const primary = references.find(reference => reference.base.split('.').length > 4) || references[0];
  let key = primary.base, number = 1;
  while (used.has(key)) key = primary.base + '_' + (++number);
  used.add(key);
  result.mapping[oldKey] = key;
  result.evidence.push({ oldKey, key, references });
}
const destination = path.join(root, 'src/Tests/Run/key-message-rekey.json');
fs.writeFileSync(destination, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ keys: result.evidence.length, references: result.evidence.reduce((count, entry) => count + entry.references.length, 0), destination }, null, 2));

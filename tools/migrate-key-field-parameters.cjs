// 核对显式文案参数中的共享显示字段；只补引用，不改业务比较和数据来源。
const fs = require('fs');
const path = require('path');
const { analysisSource, parser } = require('./migrate-localisation-keys.cjs');
const root = path.resolve(__dirname, '..');
const apply = process.argv.includes('--apply');
const records = [];
for (const folder of ['src/Classes', 'src/Modules']) {
  for (const name of fs.readdirSync(path.join(root, folder)).sort()) {
    if (!name.endsWith('.lua') || name === 'Localisation.lua') continue;
    const file = folder + '/' + name;
    let source = fs.readFileSync(path.join(root, file)).toString('latin1');
    const ast = parser.parse(analysisSource(source), { luaVersion: '5.3', encodingMode: 'pseudo-latin1', ranges: true, locations: true, comments: false });
    const edits = new Map();
    const walk = node => {
      if (!node || typeof node !== 'object') return;
      if (node.type === 'CallExpression' && node.base.type === 'MemberExpression' && node.base.base.name === 'localisation'
          && ['Text', 'Ref', 'Label'].includes(node.base.identifier.name) && node.arguments[1]?.type === 'TableConstructorExpression') {
        for (const field of node.arguments[1].fields) {
          const value = field.value;
          if (value.type !== 'MemberExpression' || !['name', 'dn', 'label', 'text', 'section', 'description'].includes(value.identifier.name)) continue;
          const before = source.slice(...value.range);
          const owner = source.slice(...value.base.range);
          const after = value.identifier.name === 'name' && owner === 'item' ? 'localisation:ItemName(item)' : `localisation:Field(${owner}, '${value.identifier.name}')`;
          edits.set(value.range[0], { range: value.range, after });
          records.push({ file, line: value.loc.start.line, before, after });
        }
      }
      for (const [key, child] of Object.entries(node)) {
        if (['loc', 'range'].includes(key)) continue;
        if (Array.isArray(child)) child.forEach(walk);
        else if (child && typeof child === 'object') walk(child);
      }
    };
    walk(ast);
    if (apply && edits.size) {
      for (const edit of [...edits.values()].sort((a, b) => b.range[0] - a.range[0])) source = source.slice(0, edit.range[0]) + edit.after + source.slice(edit.range[1]);
      fs.writeFileSync(path.join(root, file), Buffer.from(source, 'latin1'));
    }
  }
}
fs.writeFileSync(path.join(root, 'src/Tests/Run/key-field-parameters.json'), JSON.stringify(records, null, 2));
console.log(JSON.stringify({ candidates: records.length, applied: apply }));

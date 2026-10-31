// 检查新增显示入口及已移除的旧接口；审阅清单必须逐项维护，不能自动接受新候选。
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const root = path.resolve(__dirname, '..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/localisation/display-review.json'), 'utf8'));
const modes = ['', '--fields', '--lists', '--statuses', '--display-state', '--breakdowns'];
const failures = [];
const resourceKeys = new Set();
for (const name of ['Messages.csv', 'Game.csv']) {
  const text = fs.readFileSync(path.join(root, 'src/Locales/en', name), 'utf8');
  for (const match of text.matchAll(/^([a-z][a-z0-9_.]*),/gm)) resourceKeys.add(match[1]);
}
let reviewed = 0;
for (const mode of modes) {
  execFileSync(process.execPath, [path.join(__dirname, 'migrate-localisation-keys.cjs'), ...(mode ? [mode] : [])], { cwd: root });
  const scan = JSON.parse(fs.readFileSync(path.join(root, 'src/Tests/Run/key-migration-candidates.json'), 'utf8'));
  for (const error of scan.errors) failures.push(JSON.stringify(error));
  const allowed = new Map(baseline.filter(row => row.mode === mode).map(row => [row.identity, row.count]));
  for (const row of [...scan.candidates, ...scan.pending]) {
    const sourceLine = fs.readFileSync(path.join(root, row.file), 'utf8').split(/\r?\n/)[row.line - 1].trim();
    const identity = JSON.stringify([row.file, row.context, row.expression || row.text, sourceLine]);
    const count = allowed.get(identity) || 0;
    if (count) { allowed.set(identity, count - 1); reviewed++; }
    else failures.push(`${row.file}:${row.line} ${mode || 'display'} ${row.context}: ${row.expression || row.text}`);
  }
  // 显式禁止旧显示接口重新进入产品；输入 Dictionary:Translate 保留。
  if (!mode) for (const file of scan.files) {
    const text = fs.readFileSync(path.join(root, file.file), 'utf8');
    if (/\blocalisation\s*(?:[:.]\s*(?:Translate|Match)\b|\[\s*['"](?:Translate|Match)['"]\s*\])/.test(text)) failures.push(`${file.file}: 旧全局显示接口`);
    // 只检查完整的固定 key；动态拼接身份由实际运行和资源审计覆盖。
    const references = /\blocalisation:(?:Text|Label|Ref)\(\s*['"]([a-z][a-z0-9_.]*)['"]\s*[,)]|\b(?:label|title|name|source|skillPart|tooltip|tooltipText|description|prompt|placeholder|section|text)Key\s*=\s*['"]([a-z][a-z0-9_.]*)['"]/g;
    for (const match of text.matchAll(references)) {
      const key = match[1] || match[2];
      if (!resourceKeys.has(key)) failures.push(`${file.file}: 固定资源 key 不存在：${key}`);
    }
  }
}
const localisation = fs.readFileSync(path.join(root, 'src/Modules/Localisation.lua'), 'utf8');
if (/function\s+localisation:(?:Translate|Match)\s*\(/.test(localisation)) failures.push('Localisation.lua: 旧显示接口被恢复');
if (failures.length) {
  console.error('发现未经审阅的显示入口。为产品文字绑定稳定 key；共享值须追溯来源并在审阅清单记录依据。\n' + failures.join('\n'));
  process.exitCode = 1;
} else console.log(`显示入口检查通过：${reviewed} 个已审阅入口，六种扫描模式，旧显示反查调用为 0。`);

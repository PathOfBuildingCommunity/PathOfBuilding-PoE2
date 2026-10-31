// 按 Lua 语法树定位显示参数，先生成候选；不按字符串内容替换内部标识。
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '..');
const run = path.join(root, 'src/Tests/Run');
const parser = require('luaparse');
const result = { files: [], candidates: [], resources: [], pending: [], errors: [] };
const bindings = new Map();
const keys = new Map();
const fieldsOnly = process.argv.includes('--fields');
const listsOnly = process.argv.includes('--lists');
const statusesOnly = process.argv.includes('--statuses');
const breakdownsOnly = process.argv.includes('--breakdowns');
const displayStateOnly = process.argv.includes('--display-state');
// 已落地的引用不可被后续批次重用或覆盖。
for (const match of fs.readFileSync(path.join(root, 'src/Locales/en/Messages.csv'), 'utf8').matchAll(/^([a-z][a-z0-9_.]*),/gm)) keys.set(match[1], 'reserved');

// 官方 LuaJIT 扩展仅在分析副本中等长屏蔽，原文件和替换范围保持逐字节一致。
function analysisSource(source) {
  const tokens = /--\[(?<commentEquals>=*)\[[\s\S]*?\]\k<commentEquals>\]|--[^\r\n]*|\[(?<stringEquals>=*)\[[\s\S]*?\]\k<stringEquals>\]|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|#@[^\r\n]*|\bcontinue\b|\.\.=|[+*/%&|^-]=|\?\.\[|\?\.|\?\[|\?\?/g;
  return source.replace(tokens, (token, _commentEquals, _stringEquals, offset) => {
    if (token === 'continue' && /(?:goto\s+|::\s*)$/.test(source.slice(Math.max(0, offset - 20), offset))) return token;
    if (token.startsWith('#@') || token === 'continue') return ' '.repeat(token.length);
    if (token === '?.[') return '  [';
    if (token === '?.') return ' .';
    if (token === '?[') return ' [';
    if (token === '??') return 'or';
    if (/^(\.\.|[+*/%&|^-])=$/.test(token)) return '=' + ' '.repeat(token.length - 1);
    return token;
  }).replace(/\|[^|\r\n]*\|\s*->[^\r\n}]+/g, token => 'function() end'.padEnd(token.length));
}

// 语法树按字节解析，避免中文注释改变源码替换位置。
function readLiteral(node) {
  const value = Buffer.from(node.value, 'latin1').toString('utf8');
  return node.raw.startsWith('[') ? value.replace(/\r\n|\n\r|\r/g, '\n') : value;
}

// 参数名由表达式末端字段确定，碰撞时保留可读编号。
function parameterName(node, used) {
  let name = node.type === 'Identifier' ? node.name : node.type === 'MemberExpression' ? node.identifier.name : 'value';
  name = name.replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase();
  if (!/^[a-z_][a-z0-9_]*$/.test(name)) name = 'value';
  const base = name;
  let number = 1;
  while (used.has(name)) name = `${base}_${++number}`;
  used.add(name);
  return name;
}

// 识别明确的 string.format，不展开任意函数或猜测其返回值。
function isFormat(node) {
  return node.type === 'CallExpression' && (node.base.type === 'Identifier' && node.base.name === 's_format'
    || node.base.type === 'MemberExpression' && node.base.identifier.name === 'format'
      && node.base.base.type === 'Identifier' && node.base.base.name === 'string');
}

// 把整句拼接和格式化转换为一个命名模板，保留参数的求值顺序。
function template(node, source, resolveChoice) {
  const parameters = [];
  const names = new Set();
  const literal = value => value.replaceAll('{', '{{').replaceAll('}', '}}');
  const parameter = (value, format = '') => {
    const name = parameterName(value, names);
    parameters.push({ name, expression: resolveChoice(value), format });
    return `{${name}${format ? ':' + format : ''}}`;
  };
  const visit = value => {
    if (value.type === 'StringLiteral') return literal(readLiteral(value));
    if (value.type === 'BinaryExpression' && value.operator === '..') return visit(value.left) + visit(value.right);
    if (isFormat(value)) {
      const styles = [];
      const readFormat = part => {
        if (part.type === 'StringLiteral') return readLiteral(part);
        if (part.type === 'BinaryExpression' && part.operator === '..') return readFormat(part.left) + readFormat(part.right);
        const color = part.type === 'MemberExpression' && part.base.name === 'colorCodes'
          || part.type === 'CallExpression' && part.base.type === 'MemberExpression'
            && part.base.base.name === 'main' && part.base.identifier.name === 'StatColor';
        const reportTerm = breakdownsOnly && /^(?:val\.text|skillNameLabel|additionalSkillNameLabel|timeType|ailment)$/.test(source.slice(...part.range));
        const reportColor = breakdownsOnly && /colorCodes\./.test(source.slice(...part.range));
        if (!color && !reportTerm && !reportColor) throw new Error('动态格式串');
        styles.push(parameter(part));
        return '\x01' + (styles.length - 1) + '\x02';
      };
      const text = readFormat(value.arguments[0]);
      // 颜色表达式先于 printf 数值参数求值；标记仅用于工具分析，不写入产品资源。
      const segmentText = segment => segment.split(/(\x01\d+\x02)/).map(part => /^\x01/.test(part) ? styles[Number(part.slice(1, -1))] : literal(part)).join('');
      let output = '', position = 0, index = 1;
      const format = /%([-+ #0]*\d*(?:\.\d*)?[cdiouxXeEfgGs]|%)/g;
      for (const match of text.matchAll(format)) {
        const segment = text.slice(position, match.index);
        if (segment.includes('%')) throw new Error('未支持的格式指令');
        output += segmentText(segment);
        if (match[1] === '%') output += '%';
        else {
          if (!value.arguments[index]) throw new Error('格式参数不足');
          output += parameter(value.arguments[index++], match[1].replace(/\.([a-z])$/i, '.0$1'));
        }
        position = match.index + match[0].length;
      }
      if (text.slice(position).includes('%') || index !== value.arguments.length) throw new Error('格式参数或指令需复核');
      return output + segmentText(text.slice(position));
    }
    return parameter(value);
  };
  const pieces = [];
  const flatten = value => {
    if (value.type === 'BinaryExpression' && value.operator === '..') { flatten(value.left); flatten(value.right); }
    else pieces.push(value);
  };
  flatten(node);
  const style = value => value.type === 'MemberExpression' && value.base.name === 'colorCodes'
    || value.type === 'StringLiteral' && /^(?:\^x[0-9a-f]{6}|\^\d|\s)*$/i.test(readLiteral(value));
  const prefix = [], suffix = [];
  while (pieces.length > 1 && style(pieces[0])) prefix.push(source.slice(...pieces.shift().range));
  while (pieces.length > 1 && style(pieces[pieces.length - 1])) suffix.unshift(source.slice(...pieces.pop().range));
  const text = pieces.map(visit).join('');
  if (!/[A-Za-z]{2}/.test(text.replace(/\{[^{}]*\}/g, '').replace(/\^x[0-9A-Fa-f]{6}|\^\d/g, ''))) return null;
  return { text, parameters, prefix, suffix };
}

// key 在写入调用点后固定，不会在英文资源后续编辑时重新生成。
function createKey(file, context, value) {
  const namespace = path.basename(file, '.lua').replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase();
  const signature = JSON.stringify([file, context, value]);
  if (bindings.has(signature)) return bindings.get(signature);
  const identity = context.replace(/([a-z])([A-Z])/g, '$1_$2').replace(/[^a-z0-9_.]/gi, '_').toLowerCase();
  const base = context.startsWith('report.') ? `calc.${namespace.replace(/^calc_/, '')}.${identity.slice(7)}` : `ui.${namespace}.${identity}`;
  let key = base, number = 1;
  while (keys.has(key) && keys.get(key) !== signature) key = `${base}_${++number}`;
  keys.set(key, signature); bindings.set(signature, key);
  return key;
}

// 只选显式显示入口；未知表达式保留完整证据，不擅自改写。
function scan(file) {
  if (breakdownsOnly && !/^src\/Modules\/Calc(Breakdown|Offence|Defence|Triggers|Perform|Setup)\.lua$/.test(file)) return;
  const buffer = fs.readFileSync(path.join(root, file));
  const source = buffer.toString('latin1');
  let ast;
  try { ast = parser.parse(analysisSource(source), { luaVersion: '5.3', encodingMode: 'pseudo-latin1', ranges: true, locations: true, comments: false }); }
  catch (error) { result.errors.push({ file, error: error.message }); return; }
  const candidates = [];
  const reportRanges = [];
  // 计算模块中只提取报告容器和明确的 breakdown 分支；数值、内部索引和修饰词来源保持原样。
  const collectReports = (node, scope = 'details') => {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'FunctionDeclaration') {
      scope = node.identifier?.identifier?.name || node.identifier?.name || scope;
      if (/breakdown/i.test(scope) || file.endsWith('/CalcBreakdown.lua')) reportRanges.push({ range: node.range, scope });
    }
    if (node.type === 'IfClause' && /\bbreakdown\b/.test(source.slice(...node.condition.range)) && !/^\s*not\b/.test(source.slice(...node.condition.range))) {
      for (const statement of node.body) reportRanges.push({ range: statement.range, scope });
    }
    if (node.type === 'AssignmentStatement') node.variables.forEach((variable, index) => {
      const target = source.slice(...variable.range);
      if (/breakdown/i.test(target) && node.init[index]) reportRanges.push({ range: node.init[index].range, scope: variable.identifier?.name || scope });
    });
    if (node.type === 'CallExpression' && node.base.name === 't_insert' && /breakdown/i.test(source.slice(...node.arguments[0].range))) {
      const value = node.arguments[node.arguments.length - 1];
      reportRanges.push({ range: value.range, scope });
    }
    for (const [name, child] of Object.entries(node)) {
      if (['range', 'loc'].includes(name)) continue;
      if (Array.isArray(child)) child.forEach(part => collectReports(part, scope));
      else if (child && typeof child === 'object') collectReports(child, scope);
    }
  };
  if (breakdownsOnly) {
    collectReports(ast);
    reportRanges.sort((a, b) => (a.range[1] - a.range[0]) - (b.range[1] - b.range[0]));
  }
  const listSources = new Map(), processedLists = new Set();
  // 只追踪唯一的字面列表定义；重名或动态构造的列表留给人工核对。
  const collectLists = node => {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'LocalStatement' || node.type === 'AssignmentStatement') node.variables.forEach((variable, index) => {
      if (node.init[index]?.type !== 'TableConstructorExpression') return;
      const name = source.slice(...variable.range);
      if (!listSources.has(name)) listSources.set(name, []);
      listSources.get(name).push(node.init[index]);
    });
    for (const [name, child] of Object.entries(node)) {
      if (['range', 'loc'].includes(name)) continue;
      if (Array.isArray(child)) child.forEach(collectLists);
      else if (child && typeof child === 'object') collectLists(child);
    }
  };
  if (listsOnly) collectLists(ast);
  const proposeList = node => {
    if (!node) return;
    if (node.type !== 'TableConstructorExpression') {
      const definitions = listSources.get(source.slice(...node.range));
      if (definitions?.length !== 1) return;
      node = definitions[0];
    }
    if (processedLists.has(node.range[0]) || !node.fields.length || node.fields.some(field => field.type !== 'TableValue' || field.value.type !== 'StringLiteral')) return;
    const references = [], resources = [];
    node.fields.forEach((field, index) => {
      const value = template(field.value, source, part => source.slice(...part.range));
      if (!value) return;
      const context = 'list.label';
      const key = createKey(file, context, value);
      resources.push({ file, line: field.loc.start.line, context, key, ...value });
      references.push('[' + (index + 1) + '] = "' + key + '"');
    });
    if (!resources.length) return;
    processedLists.add(node.range[0]);
    result.resources.push(...resources);
    candidates.push({ ...resources[0], range: node.range, before: source.slice(...node.range),
      after: 'localisation:List(' + source.slice(...node.range) + ', { ' + references.join(', ') + ' })' });
  };
  const proposeField = node => {
    if (['label', 'tooltip', 'footer', 'warnFunc'].includes(node.key.name) && node.value.type === 'FunctionDeclaration') {
      propose(node.value, false, 'field.' + node.key.name + '.return');
      return;
    }
    if (!['label', 'section', 'tooltip', 'format', 'extra', 'title', 'suffix', 'text', 'footer', 'inactiveText', 'description'].includes(node.key.name)) return;
    if (new RegExp('^\\s*,\\s*' + node.key.name + 'Key\\s*=').test(source.slice(node.range[1], node.range[1] + 140))) return;
    if (!['StringLiteral', 'BinaryExpression'].includes(node.value.type)) return;
    if (['format', 'extra'].includes(node.key.name) && node.value.type === 'StringLiteral' && readLiteral(node.value).includes('{')) {
      const literal = readLiteral(node.value);
      if (!/[a-z]/i.test(literal.replace(/\{[^{}]+\}/g, '').replace(/\^x[0-9a-f]{6}|\^\d/gi, ''))) return;
      const parameters = [], used = new Set();
      const text = literal.replace(/\{((?:\d+:)?(?:output|mod):[a-z0-9_.,:]+)\}/gi, (token, expression) => {
        const id = expression.split(':').slice(2).join('_') || expression.split(':')[1];
        const name = parameterName({ type: 'Identifier', name: id.replace(/[^a-z0-9_]/gi, '_') }, used);
        parameters.push({ name, expression: JSON.stringify(token), format: '' });
        return '{' + name + '}';
      });
      if (!parameters.length) return;
      const value = { text, parameters, prefix: [], suffix: [] };
      const context = 'field.' + node.key.name;
      const key = createKey(file, context, value);
      candidates.push({ file, line: node.loc.start.line, context, key, ...value, range: node.range,
        before: source.slice(...node.range), after: source.slice(...node.range) + `, ${node.key.name}Key = "${key}", ${node.key.name}Tokens = { ` + parameters.map(p => p.name + ' = ' + p.expression).join(', ') + ' }' });
      return;
    }
    let value;
    try { value = template(node.value, source, part => source.slice(...part.range)); } catch { return; }
    if (!value || value.parameters.length && !['tooltip'].includes(node.key.name)) return;
    const context = 'field.' + node.key.name;
    const key = createKey(file, context, value);
    const metadata = [`${node.key.name}Key = "${key}"`];
    if (value.parameters.length) metadata.push(`${node.key.name}Params = { ` + value.parameters.map(p => p.name + ' = ' + p.expression).join(', ') + ' }');
    if (value.prefix.length) metadata.push(`${node.key.name}Prefix = ${value.prefix.join(' .. ')}`);
    if (value.suffix.length) metadata.push(`${node.key.name}Suffix = ${value.suffix.join(' .. ')}`);
    candidates.push({ file, line: node.loc.start.line, context, key, ...value, range: node.range,
      before: source.slice(...node.range), after: source.slice(...node.range) + ', ' + metadata.join(', ') });
  };
  const propose = (node, lazy, context) => {
    if (!node || node.type === 'NilLiteral' || node.type === 'NumericLiteral' || node.type === 'BooleanLiteral') return;
    if (node.type === 'CallExpression' && node.base.type === 'MemberExpression' && node.base.base.name === 'localisation') return;
    if (!lazy && node.type === 'CallExpression' && node.base.name === 'formatNumSep') {
      propose(node.arguments[0], false, context); return;
    }
    if (node.type === 'LogicalExpression') {
      propose(node.left, lazy, context); propose(node.right, lazy, context); return;
    }
    if (node.type === 'FunctionDeclaration') {
      const returns = body => {
        for (const statement of body) {
          if (statement.type === 'ReturnStatement' && statement.arguments.length === 1) propose(statement.arguments[0], false, context);
          else if (statement.type === 'IfStatement') for (const clause of statement.clauses) returns(clause.body);
        }
      };
      returns(node.body); return;
    }
    if (!['StringLiteral', 'BinaryExpression', 'CallExpression'].includes(node.type)) {
      result.pending.push({ file, line: node.loc.start.line, context, expression: Buffer.from(source.slice(...node.range), 'latin1').toString('utf8'), reason: '变量或共享数据需要显式显示引用' });
      return;
    }
    if (node.type === 'BinaryExpression' && node.operator !== '..' || node.type === 'CallExpression' && !isFormat(node)) return;
    const resolveChoice = value => {
      if (value.type === 'LogicalExpression') return `(${resolveChoice(value.left)} ${value.operator} ${resolveChoice(value.right)})`;
      if (value.type !== 'StringLiteral' || !/[a-z]{2}/i.test(readLiteral(value))) return source.slice(...value.range);
      const text = readLiteral(value).replaceAll('{', '{{').replaceAll('}', '}}');
      const key = createKey(file, context + '.parameter', { text, parameters: [] });
      result.resources.push({ file, line: value.loc.start.line, context: context + '.parameter', key, text, parameters: [] });
      return `localisation:Ref("${key}")`;
    };
    let value;
    try { value = template(node, source, resolveChoice); }
    catch (error) { result.pending.push({ file, line: node.loc.start.line, context, reason: error.message }); return; }
    if (!value) return;
    const key = createKey(file, context, value);
    const parameters = value.parameters.length ? ', { ' + value.parameters.map(p => `${p.name} = ${p.expression}`).join(', ') + ' }' : '';
    const expression = [...value.prefix, `localisation:Text("${key}"${parameters})`, ...value.suffix].join(' .. ');
    const styles = value.prefix.length || value.suffix.length;
    const styleArguments = styles ? ', ' + (value.prefix.join(' .. ') || 'nil') + (value.suffix.length ? ', ' + value.suffix.join(' .. ') : '') : '';
    const after = lazy ? `localisation:Label("${key}"${parameters || (styles ? ', nil' : '')}${styleArguments})` : expression;
    candidates.push({ file, line: node.loc.start.line, context, key, ...value, range: node.range,
      before: source.slice(...node.range), after });
  };
  // 错误 API 的可变参数仍由原有 printf 边界接收，完整句子先按 key 格式化。
  const proposeError = args => {
    if (file === 'src/Launch.lua' || !args.length) return;
    const first = args[0];
    if (first.type === 'StringLiteral' && args.length > 1) {
      const range = [first.range[0], args[args.length - 1].range[1]];
      const formatted = { type: 'CallExpression', base: { type: 'Identifier', name: 's_format' }, arguments: args, range, loc: first.loc };
      const count = candidates.length;
      propose(formatted, false, 'ShowErrMsg');
      if (candidates.length > count) candidates[candidates.length - 1].after = '"%s", ' + candidates[candidates.length - 1].after;
    } else if (args.length === 1) {
      const count = candidates.length;
      propose(first, false, 'ShowErrMsg');
      if (candidates.length > count) candidates[candidates.length - 1].after = '"%s", ' + candidates[candidates.length - 1].after;
    }
  };
  const walk = (node, scope) => {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'FunctionDeclaration') scope = node.identifier?.identifier?.name || node.identifier?.name || scope || 'details';
    if (node.type === 'TableKeyString' && node.value.type === 'FunctionDeclaration') scope = node.key.name;
    if (displayStateOnly && node.type === 'FunctionDeclaration' && ['FormatModValue', 'FormatCalcModValue'].includes(scope)) propose(node, false, 'format.' + scope);
    if (breakdownsOnly) {
      const report = reportRanges.find(entry => node.range && entry.range[0] <= node.range[0] && entry.range[1] >= node.range[1]);
      if (report && isFormat(node)) propose(node, false, 'report.' + report.scope + '.line');
      else if (report && node.type === 'CallExpression' && node.base.name === 't_insert') propose(node.arguments[node.arguments.length - 1], false, 'report.' + report.scope + '.line');
      else if (report && node.type === 'TableKeyString' && ['label', 'description', 'footer'].includes(node.key.name)) proposeField(node);
      else if (report && node.type === 'TableValue' && ['StringLiteral', 'BinaryExpression'].includes(node.value.type)) {
        const owner = reportRanges.find(entry => entry.range[0] === report.range[0]);
        // 带 printf 的链条数组由 FormatArray 处理；普通报告列表才直接生成文本。
        if (node.value.type !== 'StringLiteral' || !readLiteral(node.value).includes('%')) propose(node.value, false, 'report.' + report.scope + '.line');
      }
      else if (report && node.type === 'TableConstructorExpression' && node.fields[0]?.type === 'TableValue' && node.fields[0].value.type === 'StringLiteral' && !node.fields.some(field => field.type === 'TableKeyString' && field.key.name === 'formatKey')) {
        const values = node.fields.filter(field => field.type === 'TableValue').map(field => field.value);
        const synthetic = { type: 'CallExpression', base: { type: 'Identifier', name: 's_format' }, arguments: values, range: node.range, loc: node.loc };
        let value;
        try { value = template(synthetic, source, part => source.slice(...part.range)); } catch (_) { value = null; }
        if (value && value.parameters.length) {
          const key = createKey(file, 'report.' + report.scope + '.factor', value);
          const positions = value.parameters.map((parameter, index) => parameter.name + ' = ' + (index + 2));
          candidates.push({ file, line: node.loc.start.line, context: 'report.factor', key, ...value, range: node.range,
            before: source.slice(...node.range), after: source.slice(node.range[0], node.range[1] - 1).replace(/[,\s]*$/, '') + ', formatKey = "' + key + '", formatParams = { ' + positions.join(', ') + ' } }' });
        } else if (report.range[0] === node.range[0] && report.range[1] === node.range[1]) {
          for (const field of node.fields) if (field.type === 'TableValue' && ['StringLiteral', 'BinaryExpression'].includes(field.value.type)) propose(field.value, false, 'report.' + report.scope + '.line');
        }
      }
    }
    if (fieldsOnly && node.type === 'TableKeyString') proposeField(node);
    if (listsOnly && node.type === 'CallExpression') {
      const name = node.base.type === 'MemberExpression' ? node.base.identifier.name : node.base.name;
      if (name === 'DropDownControl') proposeList(node.arguments[2]);
      else if (name === 'SetList') proposeList(node.arguments[0]);
    }
    if (displayStateOnly && node.type === 'CallExpression') {
      const name = node.base.type === 'MemberExpression' ? node.base.identifier.name : node.base.name;
      if (name === 'InsertIfNew' && /controls\.warnings\.lines$/.test(source.slice(...node.arguments[0].range))) propose(node.arguments[1], false, 'warning.' + scope);
      if (name === 't_insert' && node.arguments[0]?.name === 'statBoxList' && node.arguments[1]?.type === 'TableConstructorExpression') {
        for (const field of node.arguments[1].fields) if (field.type === 'TableValue') propose(field.value, false, 'sidebar.' + scope);
      }
    }
    if (!fieldsOnly && !listsOnly && !statusesOnly && !breakdownsOnly && !displayStateOnly && node.type === 'CallExpression') {
      const name = node.base.type === 'MemberExpression' ? node.base.identifier.name : node.base.name;
      const args = node.arguments;
      if (['LabelControl', 'ButtonControl', 'CheckBoxControl', 'SectionControl'].includes(name)) {
        propose(args[2], true, name);
        if (name === 'CheckBoxControl') propose(args[4], true, 'CheckBoxControl.tooltip');
      }
      else if (name === 'DropDownControl') propose(args[4], true, 'DropDownControl.tooltip');
      else if (name === 'EditControl') propose(args[3], true, 'EditControl.prompt');
      else if (name === 'newPlainNumericEdit') propose(args[3], true, 'EditControl.prompt');
      else if (name === 'AddLine') propose(args[1], false, 'Tooltip.AddLine');
      else if (name === 'AddBuildPlannerNote') {
        propose(args[1], false, 'Tooltip.BuildPlannerNote.body');
        if (args[2]) propose(args[2], false, 'Tooltip.BuildPlannerNote.prefix');
      }
      else if (name === 'DrawString') propose(args[5], false, name);
      else if (name === 'DrawStringWidth') propose(args[2], false, name);
      else if (name === 'SetWindowTitle') propose(args[0], false, name);
      else if (name === 'AddStatComparesToTooltip') propose(args[3], false, name + '.header');
      else if (name === 't_insert' && file === 'src/Classes/ItemsTab.lua' && scope === 'AddItemTooltip' && args[0]?.name === 'stats') propose(args[1], false, 'Tooltip.stat');
      else if (name === 'OpenPopup' || name === 'PopupDialog') propose(args[2], true, name + '.title');
      else if (name === 'OpenMessagePopup' || name === 'OpenConfirmPopup') {
        propose(args[0], false, name + '.title');
        propose(args[1], false, name + '.message');
        if (name === 'OpenConfirmPopup') { propose(args[2], false, name + '.confirm'); propose(args[4], false, name + '.extra'); }
      }
      else if (name === 'ShowErrMsg') proposeError(args);
    }
    if (statusesOnly && node.type === 'AssignmentStatement') node.variables.forEach((variable, index) => {
      // 这些字段只承载界面状态，业务控制始终读取独立的模式和有效性字段。
      const name = variable.type === 'MemberExpression' && variable.base.name === 'self' ? variable.identifier.name : variable.type === 'Identifier' ? variable.name : '';
      if (['charImportStatus', 'importCodeDetail', 'loginStatus', 'stateText'].includes(name)) propose(node.init[index], true, 'status.' + name);
    });
    if (displayStateOnly && node.type === 'AssignmentStatement') node.variables.forEach((variable, index) => {
      // 这些字段仅在侧栏显示；触发标识和技能分段原名仍由业务逻辑读取。
      if (variable.type === 'MemberExpression' && ['infoMessage', 'infoMessage2', 'disableReason'].includes(variable.identifier.name)) propose(node.init[index], false, 'state.' + scope + '.' + variable.identifier.name);
    });
    if (displayStateOnly && ['AssignmentStatement', 'LocalStatement'].includes(node.type)) node.variables.forEach((variable, index) => {
      if (variable.type !== 'Identifier') return;
      const name = variable.name;
      const approved = file === 'src/Classes/CalcBreakdownControl.lua' && scope === 'AddModSection' && ['desc', 'cond'].includes(name)
        || file === 'src/Classes/ExtBuildListControl.lua' && scope === 'Draw' && ['dpsText', 'lifeText', 'ehpText'].includes(name)
        || file === 'src/Classes/CompareTab.lua' && scope === 'DrawConfig' && name === 'labelText';
      if (approved) propose(node.init[index], false, 'display.' + scope + '.' + name);
    });
    if (!fieldsOnly && !listsOnly && !statusesOnly && !breakdownsOnly && !displayStateOnly && node.type === 'AssignmentStatement') node.variables.forEach((variable, index) => {
      if (variable.type === 'Identifier' && variable.name === 'header' && file === 'src/Classes/ItemsTab.lua' && scope === 'AddItemTooltip') propose(node.init[index], false, 'Tooltip.header');
      if (variable.type !== 'MemberExpression') return;
      const name = variable.identifier.name;
      const owner = source.slice(...variable.base.range);
      if (name === 'tooltipText' || name === 'label' && (/controls[.\[]/.test(owner) || owner === 'self')) propose(node.init[index], true, name);
    });
    for (const [name, child] of Object.entries(node)) {
      if (['range', 'loc'].includes(name)) continue;
      if (Array.isArray(child)) child.forEach(part => walk(part, scope));
      else if (child && typeof child === 'object') walk(child, scope);
    }
  };
  walk(ast);
  // 外层整句覆盖的嵌套测宽/显示表达式只迁移一次。
  candidates.sort((a, b) => a.range[0] - b.range[0] || b.range[1] - a.range[1]);
  let end = -1;
  for (const candidate of candidates) {
    if (candidate.range[0] < end) continue;
    result.candidates.push(candidate); end = candidate.range[1];
  }
  result.files.push({ file, sha256: crypto.createHash('sha256').update(buffer).digest('hex') });
}

if (require.main === module) {
  for (const folder of ['src/Classes', 'src/Modules']) {
    for (const name of fs.readdirSync(path.join(root, folder)).sort()) {
      if (!name.endsWith('.lua') || name === 'Localisation.lua') continue;
      scan(`${folder}/${name}`);
    }
  }
  for (const name of ['Launch.lua', 'LaunchInstall.lua', 'UpdateCheck.lua', 'UpdateApply.lua']) {
    if (fs.existsSync(path.join(root, 'src', name))) scan('src/' + name);
  }
  fs.mkdirSync(run, { recursive: true });
  fs.writeFileSync(path.join(run, 'key-migration-candidates.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ files: result.files.length, candidates: result.candidates.length, pending: result.pending.length, errors: result.errors }, null, 2));
}

module.exports = { analysisSource, readLiteral, parser };

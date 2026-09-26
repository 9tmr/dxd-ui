'use strict';
const fs = require('node:fs');
const path = require('node:path');
const parser = require('luaparse');
const root = path.resolve(__dirname, '..');
let count = 0;
for (const folder of ['src', 'examples', 'tests']) {
  const directory = path.join(root, folder);
  if (!fs.existsSync(directory)) continue;
  for (const file of fs.readdirSync(directory).filter((name) => name.endsWith('.lua'))) {
    const source = fs.readFileSync(path.join(directory, file), 'utf8').replace(/^\uFEFF/, '');
    parser.parse(source, { luaVersion: '5.1', locations: true });
    if (folder === 'src') {
      if (/\b(?:loadstring|HttpGet|httpget)\s*\(/.test(source)) throw new Error(`Unexpected dynamic code or network in ${file}`);
      if (/\b(?:TODO|FIXME)\b/.test(source)) throw new Error(`Unfinished marker in ${file}`);
    }
    count++;
  }
}
console.log(`${count} Lua files pass Lua 5.1 syntax and runtime-source hygiene checks. No static type checker applies to this untyped Lua project.`);

'use strict';
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const commands = [
  ['node_modules/@johnnymorganz/stylua-bin/run.js', '--check', 'src', 'examples', 'tests'],
  ['scripts/lint.cjs'],
  ['scripts/build.cjs'],
  ['scripts/test.cjs'],
];
for (const args of commands) {
  const result = spawnSync(process.execPath, args, { cwd: root, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}
console.log('All release checks passed. Tests exercised the freshly assembled production Lua file.');

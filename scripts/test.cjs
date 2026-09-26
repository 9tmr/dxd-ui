'use strict';

const path = require('node:path');
const { spawnSync } = require('node:child_process');
const result = spawnSync(process.execPath, ['--test', path.resolve(__dirname, '../tests/library.test.cjs')], { stdio: 'inherit' });
process.exitCode = result.status ?? 1;

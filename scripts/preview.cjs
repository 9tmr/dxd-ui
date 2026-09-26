'use strict';

// Capture real library output through a deterministic Drawing adapter. No native host is implied.
// Usage: node scripts/preview.cjs --output ../../work/preview.json --width 1440 --height 900 --tab Settings
const fs = require('node:fs');
const path = require('node:path');
const { createRuntime } = require('./lua-runtime.cjs');
const args = process.argv.slice(2);
const option = (name, fallback) => { const index = args.indexOf(`--${name}`); return index >= 0 ? args[index + 1] : fallback; };
const width = Number(option('width', '1440'));
const height = Number(option('height', '900'));
if (!Number.isFinite(width) || width < 100 || !Number.isFinite(height) || height < 100) throw new Error('Preview dimensions must be at least 100 pixels.');
const runtime = createRuntime();
try {
  runtime.run(`__resize(${width}, ${height})`);
  runtime.load();
  const tab = option('tab', '');
  if (tab) runtime.run(`local wanted = ${JSON.stringify(tab)}; local found=false; for _, tab in ipairs(DxD.Tabs) do if tab.Title == wanted then tab:Select(); found=true; break end end; assert(found, "Unknown preview tab: "..wanted)`);
  const character = option('character', '');
  if (character) runtime.run(`DxD:SetCharacter(${JSON.stringify(character)})`);
  runtime.run('__settle(240)');
  const snapshot = runtime.snapshot();
  snapshot.generator = 'Deterministic Lua Drawing capture; native Matcha rendering is not validated';
  snapshot.drawings = Array.isArray(snapshot.drawings) ? snapshot.drawings.sort((a, b) => a.ZIndex - b.ZIndex || a.index - b.index) : [];
  const output = path.resolve(option('output', '../../work/drawing-preview.json'));
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, `${JSON.stringify(snapshot, null, 2)}\n`);
  const errorList = Array.isArray(snapshot.stats.errors) ? snapshot.stats.errors : [];
  const warnings = Array.isArray(snapshot.stats.warnings) ? snapshot.stats.warnings : [];
  console.log(`Captured ${snapshot.drawings.length} drawings at ${width} × ${height}: ${output}`);
  if (errorList.length || warnings.length) throw new Error(`Capture reported runtime errors: ${[...errorList, ...warnings].join('; ')}`);
} finally { runtime.close(); }

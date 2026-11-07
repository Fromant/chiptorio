import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import vm from 'node:vm';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { buildCatalog, layers, offlineHTML, completed, future } from '../catalog.mjs';
import { bounds } from '../src/preview.mjs';
import { root, cache, template, getCatalog, detectTools, exists } from '../host.mjs';

const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64');
test('sprite layers preserve projection, tint and timing', () => {
  const result = layers({ north: { layers: [{ filename: '__chiptorio__/graphics/test.png', width: 12, height: 16, scale: .5, shift: [1, -1], frame_count: 24, line_length: 8, animation_speed: .2, tint: { r: .4 } }] } }, key => key);
  assert.equal(result.length, 1); assert.equal(result[0].fps, 12); assert.equal(result[0].columns, 8);
  assert.equal(result[0].tint.r, .4); assert.deepEqual(result[0].shift, [1, -1]);
  const box = bounds({ idle: result, working: result }); assert.ok(box.width > 12); assert.ok(box.height > 16);
});
test('unsupported structures fail explicitly instead of inventing a preview', () => assert.throws(() => layers({ invalid: true }, x => x), /Unsupported/));
test('redo CLI refuses the protected QLN Terminal before launching tools', () => {
  const result=spawnSync(process.execPath,[path.join(root,'tools/asset-studio/render-batch.mjs'),'--asset=qln-terminal','--install'],{encoding:'utf8'});
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/approved and protected/);
});
test('requester retains batch four; fresh non-facing conversions form batch five', () => {
  assert.deepEqual(completed[4], ['qln-requester-node']);
  assert.deepEqual(completed[5], ['qln-terminal', 'training-cluster', 'inference-lab', 'circuit-assembler', 'network-monitor']);
  assert.equal(future[0][0], 'wafer-fab');
});
test('scan discovers unexpected images, creates a schedule and exports fully embedded HTML', async () => {
  const temp = await mkdtemp(path.join(process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, 'Temp/opencode') : os.tmpdir(), 'asset-studio-test-'));
  try {
    for (const file of ['thumbnail.png', 'graphics/answer-ending.png', 'graphics/icons/test.png', 'graphics/entity/new-art.png']) {
      await mkdir(path.dirname(path.join(temp, file)), { recursive: true }); await writeFile(path.join(temp, file), png);
    }
    await writeFile(path.join(temp, 'info.json'), '{"version":"test"}');
    const catalog = await buildCatalog({ root: temp });
    assert.equal(catalog.data.ownedFiles.length, 4);
    assert.ok(catalog.data.entries.some(e => e.name === 'new-art' && e.group === 'archive'));
    const html = await offlineHTML(catalog, template);
    assert.match(html, /data:image\/png;base64,/); assert.doesNotMatch(html, /src="https?:/);
    assert.doesNotMatch(html, /<!--ASSET_DATA-->/);
    const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
    for (const [, script] of scripts) assert.doesNotThrow(() => new vm.Script(script));
  } finally { await rm(temp, { recursive: true, force: true }); }
});
test('real prototype catalog covers every shipped image and installs batch five with correct footprints', async t => {
  if (!await exists(path.join(cache, 'prototypes.json'))) return t.skip('Launch the app once to read Factorio prototypes');
  const catalog = await getCatalog(await detectTools()), d = catalog.data;
  assert.deepEqual(d.warnings, []);
  for (const file of d.ownedFiles) assert.ok(catalog.registry.has(file), `Not covered: ${file}`);
  for (const name of completed[5]) {
    const entry = d.entries.find(e => e.id === `entity:${name}`);
    assert.equal(entry.group, 'done-5'); assert.ok(entry.model);
    assert.ok(entry.idle.length); assert.ok(entry.working.length);
    assert.equal(entry.idle[0].frames, 1);
    assert.equal(entry.working[0].frames, { 'qln-terminal':24, 'training-cluster':24, 'inference-lab':32, 'circuit-assembler':48, 'network-monitor':48 }[name]);
    assert.equal(await exists(path.join(root, 'graphics/entity', name)), true);
    assert.equal(await exists(path.join(root, 'tools/graphics/blender', name)), true);
    assert.equal(entry.source, 'Blender / installed');
    const size={ 'qln-terminal':1, 'training-cluster':9, 'inference-lab':7, 'circuit-assembler':5, 'network-monitor':3 }[name];
    assert.deepEqual(entry.footprint, [size,size]);
  }
  assert.ok(d.entries.find(e => e.id === 'entity:qln-requester-node').model);
  assert.equal(d.entries.filter(e => d.groups.find(g => g.id === e.group).status === 'done').length, 22);
});

test('approved terminal and earlier entity art are byte-for-byte unchanged by the redo', async t => {
  const filename=path.join(cache,'batch5-redo-baseline.json');
  if(!await exists(filename))return t.skip('Local revision baseline not available');
  const baseline=JSON.parse(await readFile(filename,'utf8'));
  for(const [file,hash] of Object.entries(baseline)){
    if(file==='terminalFunction')continue;
    assert.equal(createHash('sha256').update(await readFile(path.join(root,file))).digest('hex'),hash,`Protected asset changed: ${file}`);
  }
  const source=await readFile(path.join(root,'tools/graphics/blender/batch5_models.py'),'utf8');
  const terminal=source.match(/def terminal\(w\):[\s\S]*?(?=\n\n(?:def |from ))/)[0].trim();
  assert.equal(terminal,baseline.terminalFunction.trim());
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';
import {root} from '../host.mjs';
import {loadRegistry} from '../registry.mjs';

test('batch nine keeps five independent 64px icon targets and configured geometry',async()=>{
 const assets=(await loadRegistry(root)).assets.filter(a=>a.group==='batch-9');
 assert.deepEqual(assets.map(a=>a.name),['3d-nand-module','accelerator-board','advanced-circuit','agi-model','analytical-engine']);
 for(const a of assets){
  assert.equal(a.profile,'image');assert.equal(a.mode,'image');assert.equal(a.render.frames,1);
  assert.equal(a.render.width,64);assert.equal(a.render.height,64);assert.equal(a.source.format,'python');
  await readFile(path.join(root,a.source.builder));
  assert.deepEqual(a.targets,[{artifact:'image.png',path:`graphics/icons/${a.name}.png`}]);
  const m=await sharp(path.join(root,a.targets[0].path)).metadata();assert.equal(m.width,64);assert.equal(m.height,64);
 }
});

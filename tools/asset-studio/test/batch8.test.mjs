import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {root} from '../host.mjs';
import {loadRegistry} from '../registry.mjs';
import {checkBinding,bindingArtifact} from '../integration.mjs';

test('batch eight stages the Datacenter hall with an explicit capacity owner and no installed resize',async()=>{
 const assets=(await loadRegistry(root)).assets.filter(a=>a.group==='batch-8');
 assert.equal(assets.length,1);const a=assets[0];assert.equal(a.id,'entity:datacenter');
 assert.deepEqual(a.render.footprint,[11,11]);assert.equal(a.mode,'scripted');assert.equal(a.activity,'datacenter');
 assert.equal(a.render.frames,48);assert.equal(a.render.period,96);checkBinding(a);
 assert.equal(a.source.format,'python');await readFile(path.join(root,a.source.builder));
 const binding=await bindingArtifact(root,a);assert.match(binding.bytes.toString(),/\["datacenter"\]=\{type="container", mode="scripted"/);
 const raw=JSON.parse(await readFile(path.join(root,'tools/asset-studio/.cache/prototypes.json'),'utf8'));
 const box=raw.container.datacenter.selection_box;assert.equal(box[1][0]-box[0][0],3);
 const published=JSON.parse((await readFile(path.join(root,'graphics/published-assets.lua'),'utf8')).match(/^-- metadata: (.+)$/m)[1]);
 assert.equal(published.datacenter,undefined);
});

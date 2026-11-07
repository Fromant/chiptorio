import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { readFile } from 'node:fs/promises';
import { loadRegistry, exists, validateAsset } from '../registry.mjs';
import { root, detectTools, getCatalog } from '../host.mjs';
import { checkBinding } from '../integration.mjs';
import { bindingArtifact } from '../integration.mjs';

const names=['crystal-puller','wafer-fab','assembly-fab','computer-assembler','vlsi-fab'];
test('batch six candidates all use the authorized 5x5 footprint and explicit native crafting',async()=>{
  const plan=await loadRegistry(root),assets=plan.assets.filter(a=>a.group==='batch-6');
  assert.deepEqual(assets.map(a=>a.name).sort(),[...names].sort());
  for(const asset of assets){
    assert.deepEqual(asset.render.footprint,[5,5]);assert.equal(asset.mode,'native-crafting');assert.equal(asset.render.frames,96);assert.equal(asset.render.period,192);
    assert.equal(asset.source.format,'python');assert.equal(asset.source.placeholder,false);assert.equal(asset.locked,!!asset.installed?.revision);checkBinding(asset);
    assert.ok(await exists(path.join(root,asset.source.builder)));
    for(const dep of asset.source.dependencies)assert.ok(await exists(path.join(root,dep)));
    assert.ok(!/__|\.\./.test(path.basename(asset.source.builder)));
  }
});
test('reviewed fluid-port plans retain every inherited connection and put it on the new perimeter',async()=>{
  const plan=await loadRegistry(root),raw=JSON.parse(await readFile(path.join(root,'tools/asset-studio/.cache/prototypes.json'),'utf8'));
  for(const name of names.filter(n=>n!=='crystal-puller')){
    const asset=plan.assets.find(a=>a.name===name),ports=asset.integration.fluidPorts,boxes=raw['assembling-machine'][name].fluid_boxes;
    assert.equal(ports.length,boxes.reduce((n,b)=>n+b.pipe_connections.length,0));validateAsset(asset);
    for(const port of ports){const original=boxes[port.box-1].pipe_connections[port.connection-1];assert.deepEqual(asset.installed?.revision?port.position:port.from,original.position);assert.equal(port.direction,original.direction);assert.equal(Math.abs(port.position[1]),2);}
    const binding=await bindingArtifact(root,asset);assert.match(binding.bytes.toString(),/fluid_ports=/);assert.match(binding.bytes.toString(),/position=\{[-\d,]+\}/);
  }
  const bad=structuredClone(plan.assets.find(a=>a.name==='wafer-fab'));bad.integration.fluidPorts[0].position=[-1,-1];assert.throws(()=>validateAsset(bad),/perimeter/);
});
test('batch six planning does not claim installation or resize the current prototype inventory',async()=>{
  const {data}=await getCatalog(await detectTools());
  const plan=await loadRegistry(root),bindings=JSON.parse((await readFile(path.join(root,'graphics/published-assets.lua'),'utf8')).match(/^-- metadata: (.+)$/m)?.[1]??'{}');
  for(const name of names){const entry=data.entries.find(e=>e.id===`entity:${name}`),published=!!plan.assets.find(a=>a.name===name).installed?.revision;assert.deepEqual(entry.footprint,published?[5,5]:[3,3]);assert.equal(!!bindings[name],published);}
});

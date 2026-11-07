import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { Pipeline } from '../pipeline.mjs';
import { ProductionPipeline } from '../publish.mjs';
import { atomicJSON, registryPath, loadRegistry, digest, selectAssets, inside } from '../registry.mjs';
import { changeAsset } from '../planning.mjs';

const asset={id:'file:graphics/test.png',name:'test',profile:'image',mode:'image',locked:false,render:{frames:1,period:1,footprint:[1,1]},targets:[{artifact:'image.png',path:'graphics/test.png'}]};
async function fixture(t){const root=await mkdtemp(path.join(os.tmpdir(),'chiptorio-pipeline-'));t.after(()=>rm(root,{recursive:true,force:true}));await mkdir(path.join(root,'graphics'));await writeFile(path.join(root,'graphics/test.png'),'installed');return new Pipeline(root);}
test('intake and approval never alter installed artifacts; repeat intake is cached',async t=>{
  const p=await fixture(t),artifacts={'image.png':Buffer.from('candidate')};
  const first=await p.stage(asset,artifacts),second=await p.stage(asset,artifacts);
  assert.equal(first.revision,second.revision);assert.equal(second.cached,true);
  await p.review(first.revision,'approved');await p.approved(first.revision);
  assert.equal(await readFile(path.join(p.root,'graphics/test.png'),'utf8'),'installed');
});
test('new revisions do not inherit approval and tampering invalidates old approval',async t=>{
  const p=await fixture(t),first=await p.stage(asset,{'image.png':Buffer.from('one')});
  await p.review(first.revision,'approved');
  const next=await p.stage(asset,{'image.png':Buffer.from('two')});
  await assert.rejects(p.approved(next.revision));
  await writeFile(path.join(p.folder(first.revision),'artifacts/image.png'),'tampered');
  await assert.rejects(p.approved(first.revision),/integrity/);
});
test('locks and installed conflicts fail closed',async t=>{
  const p=await fixture(t);
  await assert.rejects(p.stage({...asset,locked:true},{'image.png':Buffer.from('one')}),/locked/);
  const first=await p.stage(asset,{'image.png':Buffer.from('one')});await p.review(first.revision,'approved');
  await writeFile(path.join(p.root,'graphics/test.png'),'user edit');
  await assert.rejects(p.approved(first.revision),/Installed target changed/);
});
async function production(t,runner=async()=>{}){
  const base=await fixture(t);await mkdir(path.join(base.root,'scripts'));await writeFile(path.join(base.root,'scripts/control.lua'),'-- fixture');
  const registered={...asset,group:'batch-42',render:{...asset.render,width:1,height:1},source:{format:'image',image:'graphics/test.png'}};
  await atomicJSON(registryPath(base.root),{version:1,groups:[{id:'batch-42',batch:42}],assets:[registered]});
  return {p:new ProductionPipeline(base.root,{runner}),asset:registered};
}
test('full publication requires explicit confirmation, approval and current isolated validation',async t=>{
  const {p,asset}=await production(t);const {revision}=await p.stage(asset,{'image.png':Buffer.from('approved exact bytes')});
  await assert.rejects(p.publish(revision),/confirmation/);
  await assert.rejects(p.validate(revision,{factorio:'fixture'}));
  await p.review(revision,'approved');await assert.rejects(p.publish(revision,{confirm:revision}));
  await p.validate(revision,{factorio:'fixture'});
  assert.equal(await readFile(path.join(p.root,'graphics/test.png'),'utf8'),'installed');
  const result=await p.publish(revision,{confirm:revision});assert.equal(result.files[0].hash,digest(Buffer.from('approved exact bytes')));
  assert.equal(await readFile(path.join(p.root,'graphics/test.png'),'utf8'),'approved exact bytes');
  assert.equal((await loadRegistry(p.root)).assets[0].locked,true);
});
test('failed validation and changes to runtime invalidate publication',async t=>{
  const {p,asset}=await production(t,async()=>{throw new Error('fixture failure');});const {revision}=await p.stage(asset,{'image.png':Buffer.from('next')});await p.review(revision,'approved');
  await assert.rejects(p.validate(revision,{factorio:'fixture'}),/fixture failure/);
  await assert.rejects(p.publish(revision,{confirm:revision}),/validation/);
  p.runner=async()=>{};await p.validate(revision,{factorio:'fixture'});
  await writeFile(path.join(p.root,'scripts/control.lua'),'-- user changed runtime');
  await assert.rejects(p.publish(revision,{confirm:revision}),/stale/);
  assert.equal(await readFile(path.join(p.root,'graphics/test.png'),'utf8'),'installed');
});
test('drafts, placeholders, source edits and stale descriptors never inherit approval',async t=>{
  const {p,asset}=await production(t);
  const draft=await p.stage(asset,{'image.png':Buffer.from('draft')},{draft:true});await assert.rejects(p.review(draft.revision,'approved'),/Drafts/);
  const plan=await loadRegistry(p.root),placeholderAsset={...asset,source:{...asset.source,placeholder:true}};plan.assets=[placeholderAsset];await atomicJSON(registryPath(p.root),plan);
  const placeholder=await p.stage(placeholderAsset,{'image.png':Buffer.from('placeholder')});await assert.rejects(p.review(placeholder.revision,'approved'),/Scaffolds/);
  plan.assets=[asset];await atomicJSON(registryPath(p.root),plan);
  const full=await p.stage(asset,{'image.png':Buffer.from('full')},{sources:{'scripts/control.lua':digest('-- fixture')}});await p.review(full.revision,'approved');
  await writeFile(path.join(p.root,'scripts/control.lua'),'edit');await assert.rejects(p.approved(full.revision),/Source changed/);
  await writeFile(path.join(p.root,'scripts/control.lua'),'-- fixture');
  await changeAsset(p.root,{id:asset.id,expected:digest(asset),asset:{...asset,render:{...asset.render,period:2}}});
  await assert.rejects(p.approved(full.revision),/descriptor/);
  await assert.rejects(changeAsset(p.root,{id:asset.id,expected:digest(asset),locked:true,confirm:asset.id,reason:'test'}),/Descriptor changed/);
});
test('all batches use explicit stable selection and unsafe paths are refused',()=>{
  const plan={groups:[{id:'batch-42',batch:42},{id:'batch-99',batch:99}],assets:[{...asset,group:'batch-42'},{...asset,id:'file:other',name:'other',group:'batch-99'}]};
  assert.equal(selectAssets(plan,{batch:42})[0].id,asset.id);assert.equal(selectAssets(plan,{batch:'batch-99'})[0].name,'other');
  assert.throws(()=>selectAssets(plan),/explicitly/);assert.throws(()=>inside('C:/fixture','graphics/../protected.png'),/Unsafe/);assert.throws(()=>inside('C:/fixture','graphics/test.png:stream'),/Unsafe/);
});
test('batch candidates validate once and publish exact member files transactionally',async t=>{
  let runs=0;const {p,asset:a}=await production(t,async()=>{runs++;});
  const plan=await loadRegistry(p.root),b={...a,id:'file:graphics/other.png',name:'other',targets:[{artifact:'image.png',path:'graphics/other.png'}]};plan.assets.push(b);await atomicJSON(registryPath(p.root),plan);
  const first=await p.stage(a,{'image.png':Buffer.from('first')}),second=await p.stage(b,{'image.png':Buffer.from('second')});
  const bundle=await p.bundle([first.revision,second.revision]);
  await p.review(bundle.revision,'approved');await p.validate(bundle.revision,{factorio:'fixture'});assert.equal(runs,1);
  await p.publish(bundle.revision,{confirm:bundle.revision});assert.equal(await readFile(path.join(p.root,'graphics/test.png'),'utf8'),'first');assert.equal(await readFile(path.join(p.root,'graphics/other.png'),'utf8'),'second');
  assert.ok((await loadRegistry(p.root)).assets.every(a=>a.locked));
});
test('interrupted publication recovery restores originals without discarding later user edits',async t=>{
  const {p}=await production(t),folder=path.join(p.workspace,'transactions','00000000-0000-0000-0000-000000000001');await mkdir(folder,{recursive:true});
  await writeFile(path.join(folder,'0.old'),'installed');await writeFile(path.join(p.root,'graphics/test.png'),'partially published');
  const journal={revision:'a'.repeat(64),state:'applying',files:[{path:'graphics/test.png',baseline:digest('installed'),hash:digest('partially published'),index:0}]};await atomicJSON(path.join(folder,'journal.json'),journal);
  await p.recover();assert.equal(await readFile(path.join(p.root,'graphics/test.png'),'utf8'),'installed');
  await atomicJSON(path.join(folder,'journal.json'),journal);await writeFile(path.join(p.root,'graphics/test.png'),'user edit after crash');
  await assert.rejects(p.recover(),/Recovery conflict/);assert.equal(await readFile(path.join(p.root,'graphics/test.png'),'utf8'),'user edit after crash');
});

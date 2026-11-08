import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,rm} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {ModelReview} from '../model-review.mjs';
import {Pipeline} from '../pipeline.mjs';
import {digest,registryPath,atomicJSON} from '../registry.mjs';
import {root as repository} from '../host.mjs';
async function fixture(t){
 const root=await mkdtemp(path.join(os.tmpdir(),'chiptorio-model-'));t.after(()=>rm(root,{recursive:true,force:true}));
 const plan=JSON.parse(await readFile(registryPath(repository),'utf8')),asset=plan.assets.find(a=>a.id==='entity:wafer-fab');
 await atomicJSON(registryPath(root),{...plan,assets:[asset]});
 const store=new ModelReview(root),buildKey='a'.repeat(64),model=`steps/build/${buildKey}/model.blend`,bytes=Buffer.from('staged blend');
 const file=path.join(store.workspace,model);await mkdir(path.dirname(file),{recursive:true});await writeFile(file,bytes);
 await atomicJSON(path.join(path.dirname(file),'complete.json'),{'model.blend':digest(bytes)});
 const source=asset.source.builder;await mkdir(path.dirname(path.join(root,source)),{recursive:true});await writeFile(path.join(root,source),'geometry');
 const built={asset,details:{buildKey,model,modelHash:digest(bytes),sources:{[source]:digest(Buffer.from('geometry'))}}};
 return {root,store,built,file,source};
}
test('model decisions bind exact geometry, preserve inspection copies and cannot approve shipping files',async t=>{
 const {root,store,built,file}=await fixture(t),{revision}=await store.stage(built);
 await store.review(revision,'approved','clearances checked');
 assert.equal((await store.read(revision)).review.decision,'approved');
 await assert.rejects(new Pipeline(root).approved(revision));
 const copy=await store.inspectionCopy(built.details);await writeFile(copy,'edited inspection');assert.equal(await readFile(file,'utf8'),'staged blend');
 assert.equal((await store.stage(built)).revision,revision);assert.equal((await store.read(revision)).review.comment,'clearances checked');
 await writeFile(file,'modified cache');await assert.rejects(store.current(await store.read(revision)),/integrity/);
});
test('source changes invalidate model review and unsafe model paths fail closed',async t=>{
 const {root,store,built,source}=await fixture(t),{revision}=await store.stage(built);
 await writeFile(path.join(root,source),'new geometry');
 assert.equal((await store.list())[0].stale,true);await assert.rejects(store.review(revision,'approved'),/source changed/);
 await assert.rejects(store.model({...built.details,model:'../../outside.blend'}),/No staged/);
 await assert.rejects(store.read('../outside'),/Invalid model revision/);
});

test('renderer-only changes preserve legacy geometry approvals',async t=>{
 const {root,store,built}=await fixture(t),renderer='tools/graphics/blender/render.py';
 await mkdir(path.dirname(path.join(root,renderer)),{recursive:true});await writeFile(path.join(root,renderer),'old renderer');
 built.details.sources[renderer]=digest(Buffer.from('old renderer'));
 const {revision}=await store.stage(built);await store.review(revision,'approved');
 await writeFile(path.join(root,renderer),'GPU renderer policy');
 await store.current(await store.read(revision));
 assert.equal((await store.read(revision)).review.decision,'approved');
});

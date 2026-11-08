import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,readFile,writeFile,rm} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {Pipeline} from '../pipeline.mjs';
import {approvedLibrary} from '../library.mjs';

async function fixture(t){
 const root=await mkdtemp(path.join(os.tmpdir(),'chiptorio-library-'));t.after(()=>rm(root,{recursive:true,force:true}));
 await mkdir(path.join(root,'graphics'));await writeFile(path.join(root,'graphics/test.png'),'installed');
 const asset={id:'file:graphics/test.png',name:'test',profile:'image',mode:'image',locked:false,render:{frames:1,period:1,footprint:[1,1]},targets:[{artifact:'image.png',path:'graphics/test.png'}]};
 const catalog={data:{entries:[{id:asset.id,name:'test',group:'batch-test',image:'graphics/test.png',files:['graphics/test.png']}],images:{'graphics/test.png':{src:'/installed.png'}},groups:[{id:'batch-test',status:'future'}]},registry:new Map([['graphics/test.png',path.join(root,'graphics/test.png')]])};
 return {root,asset,catalog,pipeline:new Pipeline(root)};
}
test('library shows exact approved bytes and retains the installed comparison without publishing',async t=>{
 const {root,asset,catalog,pipeline}=await fixture(t);
 const {revision}=await pipeline.stage(asset,{'image.png':Buffer.from('approved')},{preview:{image:'image.png'}});await pipeline.review(revision,'approved');
 const result=await approvedLibrary(root,catalog),entry=result.data.entries[0];
 assert.equal(entry.approval.revision,revision);assert.equal(entry.source,'Approved artwork · not published');
 assert.equal(await readFile(result.registry.get(entry.image),'utf8'),'approved');
 assert.equal(result.data.installedEntries[0].image,'graphics/test.png');assert.equal(catalog.data.entries[0].image,'graphics/test.png');
 assert.equal(await readFile(path.join(root,'graphics/test.png'),'utf8'),'installed');assert.equal(result.data.groups[0].status,'approved');
 await writeFile(path.join(root,'graphics/test.png'),'unrelated installed edit');
 assert.equal((await approvedLibrary(root,catalog)).data.entries[0].approval.current,false);
});
test('drafts, rejected revisions and damaged artifacts do not replace the library preview',async t=>{
 const {root,asset,catalog,pipeline}=await fixture(t);
 const c=await pipeline.stage(asset,{'image.png':Buffer.from('draft')},{draft:true,preview:{image:'image.png'}});
 assert.equal((await approvedLibrary(root,catalog)).data.entries[0].approval,undefined);
 const next=await pipeline.stage(asset,{'image.png':Buffer.from('candidate')},{preview:{image:'image.png'}});await pipeline.review(next.revision,'rejected');
 assert.equal((await approvedLibrary(root,catalog)).data.entries[0].approval,undefined);
 await pipeline.review(next.revision,'approved');await writeFile(path.join(pipeline.folder(next.revision),'artifacts/image.png'),'damaged');
 assert.equal((await approvedLibrary(root,catalog)).data.entries[0].approval,undefined);
});

test('a published newer revision never gets replaced by an older unpublished approval',async t=>{
 const {root,asset,catalog,pipeline}=await fixture(t);
 const old=await pipeline.stage(asset,{'image.png':Buffer.from('older approval')},{preview:{image:'image.png'}});await pipeline.review(old.revision,'approved');
 const latest=await pipeline.stage(asset,{'image.png':Buffer.from('published approval')},{preview:{image:'image.png'}});await pipeline.review(latest.revision,'approved');
 await mkdir(path.join(pipeline.workspace,'published'),{recursive:true});
 await writeFile(path.join(pipeline.workspace,'published',latest.revision+'.json'),JSON.stringify({revision:latest.revision}));
 assert.equal((await approvedLibrary(root,catalog)).data.entries[0].approval,undefined);
});

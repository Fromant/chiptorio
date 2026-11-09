import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import { pack } from '../pack.mjs';
import { buildAsset } from '../build.mjs';
import { Pipeline } from '../pipeline.mjs';
import { atomicJSON, registryPath } from '../registry.mjs';
import { checkBinding } from '../integration.mjs';

async function fixture(t){const root=await mkdtemp(path.join(os.tmpdir(),'chiptorio-pack-'));t.after(()=>rm(root,{recursive:true,force:true}));return root;}
async function sprite(left,top,width=14,height=16){return sharp({create:{width:64,height:64,channels:4,background:'#00000000'}}).composite([{input:await sharp({create:{width,height,channels:4,background:'#afc6bfff'}}).png().toBuffer(),left,top}]).png().toBuffer();}
async function renders(root,directional=false){
  const work={entity:'fixture',frames:2,footprint:[1,1],origin_px:[32,32],fps:12,animation_speed:.2,directions:{}},idle={...work,frames:1,directions:{}};
  await mkdir(path.join(root,'working'),{recursive:true});await mkdir(path.join(root,'idle'),{recursive:true});
  for(const view of directional?['north','east','south','west']:['game']){
    for(const [frame,left] of [[0,22],[1,24]])await writeFile(path.join(root,'working',`${view}-${frame}.png`),await sprite(left,16));
    await writeFile(path.join(root,'idle',`${view}.png`),await sprite(22,16));
    await writeFile(path.join(root,'idle',`fixture_${view}_shadow.png`),await sprite(38,32,12,8));
    work.directions[view]={size:64,files:[`${view}-0.png`,`${view}-1.png`]};idle.directions[view]={size:64,files:[`${view}.png`]};
  }
  await atomicJSON(path.join(root,'working/render-manifest.json'),work);await atomicJSON(path.join(root,'idle/render-manifest.json'),idle);
}
test('generic entity pack emits exact previews, dynamic atlas layout and paired idle/work definitions',async t=>{
  const root=await fixture(t);await renders(root);const out=path.join(root,'packed');
  const asset={name:'fixture',profile:'entity',mode:'native-crafting',render:{footprint:[1,1]},targets:['working.png','idle.png','shadow.png','sprite-def.lua'].map(f=>({artifact:f,path:`graphics/entity/fixture/${f}`}))};
  const meta=await pack(asset,root,out);assert.equal(meta.frames,2);assert.equal(meta.columns,2);assert.deepEqual(meta.views.game,{working:'working.png',idle:'idle.png',shadow:'shadow.png'});
  const png=await sharp(path.join(out,'working.png')).metadata();assert.equal(png.width,meta.width*2);assert.equal(png.height,meta.height);
  assert.match(await readFile(path.join(out,'sprite-def.lua'),'utf8'),/on_animation=.*frame_count=2/);
});
test('directional adapter packs every view using the established layers contract',async t=>{
  const root=await fixture(t);await renders(root,true);const out=path.join(root,'packed'),views=['north','east','south','west'];
  const asset={name:'fixture',profile:'entity',mode:'existing-directional',render:{footprint:[1,1]},targets:views.flatMap(v=>['working.png','shadow.png'].map(f=>({artifact:`${v}/${f}`,path:`graphics/entity/fixture/${v}-${f}`})))};
  const meta=await pack(asset,root,out),lua=await readFile(path.join(out,'sprite-def.lua'),'utf8');
  assert.equal(Object.keys(meta.views).length,4);for(const view of views)assert.ok(lua.includes(`${view}={layers={`));assert.ok(!lua.includes('north={animation='));
});

test('faint shadow-catcher noise does not trigger full-animation reframing',async t=>{
  const root=await fixture(t);await renders(root);
  const file=path.join(root,'idle/fixture_game_shadow.png');
  const bytes=await sharp(file).composite([{input:await sharp({create:{width:64,height:64,channels:4,background:{r:0,g:0,b:0,alpha:.045}}}).png().toBuffer()}]).png().toBuffer();
  await writeFile(file,bytes);
  const asset={name:'fixture',profile:'entity',mode:'native-crafting',render:{footprint:[1,1]},targets:['working.png','idle.png','shadow.png','sprite-def.lua'].map(f=>({artifact:f,path:`graphics/entity/fixture/${f}`}))};
  const meta=await pack(asset,root,path.join(root,'packed'));assert.ok(meta.width<64);assert.ok(meta.height<64);
});

test('rotatable native machines retain working and idle animations in every direction',async t=>{
  const root=await fixture(t);await renders(root,true);const out=path.join(root,'packed'),views=['north','east','south','west'];
  const asset={name:'fixture',profile:'entity',mode:'native-crafting',integration:{directional:true},render:{footprint:[1,1],views},targets:[...views.flatMap(v=>['working.png','idle.png','shadow.png'].map(f=>({artifact:`${v}/${f}`,path:`graphics/entity/fixture/${v}-${f}`}))),{artifact:'sprite-def.lua',path:'graphics/entity/fixture/sprite-def.lua'}]};
  const meta=await pack(asset,root,out),lua=await readFile(path.join(out,'sprite-def.lua'),'utf8');
  for(const view of views){assert.ok(meta.views[view].idle);assert.equal((lua.match(new RegExp(`${view}=`, 'g'))??[]).length,2);}
  assert.match(lua,/on_animation=\{north=\{layers=\{.*frame_count=2/);
  assert.match(lua,/off_animation=\{north=\{layers=\{.*frame_count=1, repeat_count=2/);
});
for(const profile of ['image','cable','presentation'])test(`${profile} PNG intake preserves bytes and resumes/rebuilds only a corrupt packing stage`,async t=>{
  const root=await fixture(t),bytes=await sprite(22,16);await writeFile(path.join(root,'source.png'),bytes);
  const asset={id:`file:graphics/${profile}.png`,name:profile,profile,mode:'image',locked:false,group:'batch-42',source:{format:'image',image:'source.png'},render:{frames:1,period:1,footprint:[1,1],width:64,height:64},targets:[{artifact:'image.png',path:`graphics/${profile}.png`}]};
  await atomicJSON(registryPath(root),{version:1,groups:[{id:'batch-42',batch:42}],assets:[asset]});
  const job={log:''},first=await buildAsset(root,asset,{job});assert.deepEqual(first.artifacts['image.png'],bytes);
  const pipeline=new Pipeline(root),candidate=await pipeline.stage(first.asset,first.artifacts,first.details);
  const second=await buildAsset(root,asset,{job});assert.match(job.log,/Source CACHED/);assert.match(job.log,/Pack CACHED/);
  assert.equal((await pipeline.stage(second.asset,second.artifacts,second.details)).revision,candidate.revision);
  await writeFile(path.join(root,'tools/asset-studio/workspace/steps/pack',first.details.packKey,'image.png'),'corrupt');
  const repaired=await buildAsset(root,asset,{job});assert.deepEqual(repaired.artifacts['image.png'],bytes);assert.match(job.log,/Source CACHED/);assert.match(job.log,/Pack PASS/);
});
test('unregistered activity and incompatible native clocks fail explicitly',()=>{
  assert.throws(()=>checkBinding({name:'new-device',profile:'entity',mode:'scripted',activity:'new-device',prototype:{type:'container'},render:{frames:24,period:48}}),/activity owner/);
  assert.throws(()=>checkBinding({name:'training-cluster',profile:'entity',mode:'scripted',activity:'training-cluster',prototype:{type:'assembling-machine'},render:{frames:16,period:48}}),/12 fps/);
  assert.throws(()=>checkBinding({name:'new-device',profile:'entity',mode:'native-lab',prototype:{type:'container'}}),/incompatible/);
});

import path from 'node:path';
import { readFile, writeFile, mkdir, cp, rm, stat } from 'node:fs/promises';
import sharp from 'sharp';
import { digest, inside, safePath, hashFile, exists, workspacePath, atomicJSON, validateAsset } from './registry.mjs';
import { walk } from './catalog.mjs';
import { processLog } from './process.mjs';
import { pack } from './pack.mjs';
import { bindingArtifact, checkBinding } from './integration.mjs';

async function completed(folder) {
  try{const files=JSON.parse(await readFile(path.join(folder,'complete.json'),'utf8'));for(const [name,hash] of Object.entries(files))if(await hashFile(inside(folder,name))!==hash)return false;return Object.keys(files).length>0;}catch{return false;}
}
async function seal(folder) {
  const files={};for(const file of await walk(folder))if(!file.endsWith('complete.json'))files[path.relative(folder,file).replaceAll('\\','/')]=await hashFile(file);
  await atomicJSON(path.join(folder,'complete.json'),files);
}
export async function buildAsset(root,asset,{draft=false,modelOnly=false,tools,job={log:''}}={}) {
  validateAsset(asset);checkBinding(asset);
  if(modelOnly&&asset.source?.format==='image')throw new Error('Image assets have no Blender model');
  if(asset.locked)throw new Error(`${asset.name} is locked; explicitly unlock it first`);
  if(!asset.source||asset.source.format==='unconfigured')throw new Error(`${asset.name}: configure a Python builder, .blend, or PNG source first`);
  const workspace=workspacePath(root),events=[],say=s=>{events.push(s);job.log=events.join('\n');};
  const dependencies=new Set(asset.source.dependencies??[]);
  if(asset.source.builder)dependencies.add(asset.source.builder);
  if(asset.source.model&&asset.source.format==='blend')dependencies.add(asset.source.model);
  if(asset.source.image)dependencies.add(asset.source.image);
  if(asset.source.format!=='image'){
    if(!tools?.blender)throw new Error('Blender not detected; set BLENDER_EXE');
    // Legacy imports are implicit; conservatively snapshot/hash all Python helpers, never installed models.
    for(const f of await walk(path.join(root,'tools/graphics/blender')))if(f.endsWith('.py'))dependencies.add(path.relative(root,f).replaceAll('\\','/'));
  }
  const hashes={};for(const dep of [...dependencies].sort()){const file=await safePath(root,dep);hashes[dep]=await hashFile(file);if(!hashes[dep])throw new Error(`Missing source dependency: ${dep}`);}
  const tool=tools?.blender?await stat(tools.blender).then(s=>({path:tools.blender,size:s.size,mtime:s.mtimeMs})):null;
  const worker=path.join(root,'tools/asset-studio/worker.py');
  const buildHashes=Object.fromEntries(Object.entries(hashes).filter(([name])=>!['tools/graphics/blender/render.py','tools/graphics/blender/gpu_device.py'].includes(name)));
  const buildKey=digest({source:asset.source,name:asset.name,footprint:asset.render.footprint,period:asset.render.period,hashes:buildHashes,tool,worker:await hashFile(worker)});
  const buildFolder=path.join(workspace,'steps/build',buildKey),snapshot=path.join(buildFolder,'source'),model=path.join(buildFolder,'model.blend');
  let renderFolder,renderKey;
  if(asset.source.format==='image'){
    if(!asset.source.image)throw new Error('Configure source.image');
    renderKey=digest({buildKey,image:true});renderFolder=path.join(workspace,'steps/render',renderKey);
    if(!await completed(renderFolder)){
      await rm(renderFolder,{recursive:true,force:true});await mkdir(renderFolder,{recursive:true});
      const file=await safePath(root,asset.source.image),bytes=await readFile(file),meta=await sharp(bytes).metadata();
      if(meta.format!=='png'||meta.width!==asset.render.width||meta.height!==asset.render.height)throw new Error('PNG source must match the declared output dimensions');
      await writeFile(path.join(renderFolder,'image.png'),bytes);await seal(renderFolder);say('Source PASS');
    }else say('Source CACHED');
  }else{
    if(!await completed(buildFolder)){
      await rm(buildFolder,{recursive:true,force:true});await mkdir(snapshot,{recursive:true});
      for(const dep of dependencies){const dest=inside(snapshot,dep);await mkdir(path.dirname(dest),{recursive:true});await cp(await safePath(root,dep),dest);if(await hashFile(dest)!==hashes[dep])throw new Error('Source changed during snapshot; retry');}
      const config=path.join(buildFolder,'build.json');await atomicJSON(config,{snapshot,asset,model,build:true,buildOnly:true});
      await processLog(tools.blender,['-b','--python-exit-code','1','-P',worker,'--',config],{cwd:snapshot,log:path.join(workspace,'logs',`${buildKey}-build.log`)});
      if(!await exists(model))throw new Error('Builder did not produce a staged model');
      await seal(buildFolder);say('Build PASS');
    }else say('Build CACHED');
    if(modelOnly)return {asset,details:{buildKey,model:path.relative(workspace,model).replaceAll('\\','/'),sources:buildHashes,modelHash:await hashFile(model)}};
    const frames=draft?Math.min(asset.render.frames,8):asset.render.frames,samples=draft?(asset.render.draftSamples??8):asset.render.samples;
    const renderer=path.join(root,'tools/graphics/blender/render.py');
    const gpuHelper=path.join(root,'tools/graphics/blender/gpu_device.py');
    renderKey=digest({model:await hashFile(model),period:asset.render.period,resolution:asset.render.resolution,views:asset.render.views,frames,samples,tool,renderer:await hashFile(renderer),gpuHelper:await hashFile(gpuHelper),worker:await hashFile(worker)});
    renderFolder=path.join(workspace,'steps/render',renderKey);
    if(!await completed(renderFolder)){
      await rm(renderFolder,{recursive:true,force:true});await mkdir(renderFolder,{recursive:true});
      const rendererCopy=path.join(renderFolder,'renderer.py');await cp(renderer,rendererCopy);
      await cp(gpuHelper,path.join(renderFolder,'gpu_device.py'));
      const config=path.join(renderFolder,'render.json');await atomicJSON(config,{snapshot,asset,model,build:false,renderer:rendererCopy,output:renderFolder,frames,samples,resolution:asset.render.resolution});
      await processLog(tools.blender,['-b','--python-exit-code','1','-P',worker,'--',config],{cwd:snapshot,log:path.join(workspace,'logs',`${renderKey}-render.log`)});
      await seal(renderFolder);say(`Render PASS · ${frames} frames`);
    }else say('Render CACHED');
  }
  const packKey=digest({renderKey,targets:asset.targets,profile:asset.profile,mode:asset.mode,render:asset.render,packer:await hashFile(path.join(root,'tools/asset-studio/pack.mjs'))});
  const packed=path.join(workspace,'steps/pack',packKey);
  let preview;
  if(!await completed(packed)){
    await rm(packed,{recursive:true,force:true});await mkdir(packed,{recursive:true});
    if(asset.source.format==='image'){
      await cp(path.join(renderFolder,'image.png'),path.join(packed,'image.png'));
      preview={image:'image.png',width:asset.render.width,height:asset.render.height,frames:1,checks:['PNG format','exact output dimensions']};
    }else {
      try{preview=await pack(asset,renderFolder,packed);}
      catch(error){
        if(/Clipped sprite/.test(error.message)&&asset.render.resolution<4096){
          const framed=await buildAsset(root,{...asset,render:{...asset.render,resolution:Math.min(4096,asset.render.resolution+256)}},{draft,tools,job});
          job.log=`Auto-framed canvas ${asset.render.resolution} → ${framed.asset.render.resolution} px; physical scale unchanged\n${job.log}`;
          return framed;
        }
        throw error;
      }
    }
    await atomicJSON(path.join(packed,'preview.json'),preview);await seal(packed);say('Pack PASS');
  }else {preview=JSON.parse(await readFile(path.join(packed,'preview.json'),'utf8'));say('Pack CACHED');}
  const artifacts={};for(const target of asset.targets)artifacts[target.artifact]=await readFile(inside(packed,target.artifact));
  const binding=await bindingArtifact(root,asset),targets=[...asset.targets];
  if(binding){artifacts[binding.artifact]=binding.bytes;targets.push({path:binding.path,artifact:binding.artifact});}
  return {asset:{...asset,targets},artifacts,details:{draft,preview,buildKey,renderKey,packKey,modelHash:asset.source.format==='image'?null:await hashFile(model),sources:hashes,model:asset.source.format==='image'?null:path.relative(workspace,model).replaceAll('\\','/')}};
}

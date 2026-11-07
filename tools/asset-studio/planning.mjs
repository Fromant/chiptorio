import path from 'node:path';
import { mkdir, writeFile, open, rm } from 'node:fs/promises';
import { loadRegistry, registryPath, atomicJSON, validateAsset, digest, assetKey, workspacePath } from './registry.mjs';
import { checkBinding } from './integration.mjs';

export async function changeAsset(root,input) {
  await mkdir(workspacePath(root),{recursive:true});const lock=path.join(workspacePath(root),'publish.lock');
  let handle;try{handle=await open(lock,'wx');}catch{throw new Error('Another metadata/publication operation is active; retry after it finishes or recover a stale lock');}
  try{await handle.writeFile(JSON.stringify({pid:process.pid,operation:'metadata'}));return await changeLocked(root,input);}
  finally{await handle.close();await rm(lock,{force:true});}
}
async function changeLocked(root,{id,expected,asset,locked,confirm,reason}) {
  const plan=await loadRegistry(root),index=plan.assets.findIndex(a=>a.id===id),current=plan.assets[index];
  if(!current)throw new Error('Unknown registered asset');
  if(expected!==digest(current))throw new Error('Descriptor changed; reload before saving');
  let next;
  if(locked!==undefined){
    if(typeof locked!=='boolean'||confirm!==id||typeof reason!=='string'||!reason.trim())throw new Error('Lock changes need the asset ID and a reason');
    next={...current,locked,lockReason:reason.trim()};
  }else{
    if(current.locked)throw new Error('Asset is locked');
    if(!asset||asset.id!==id||asset.name!==current.name||asset.profile!==current.profile)throw new Error('Cannot change asset identity/profile');
    if(asset.locked!==current.locked||JSON.stringify(asset.installed)!==JSON.stringify(current.installed))throw new Error('Use explicit lock controls; installed metadata is managed by publication');
    next=validateAsset(asset);checkBinding(next);
    if(!plan.groups.some(g=>g.id===next.group))throw new Error('Unknown batch');
    for(const other of plan.assets.filter(a=>a.id!==id))for(const target of next.targets??[])if(other.targets?.some(t=>t.path.toLowerCase()===target.path.toLowerCase()))throw new Error(`Target belongs to ${other.id}`);
  }
  plan.assets[index]=next;await atomicJSON(registryPath(root),plan);return {asset:next,hash:digest(next)};
}
export async function scaffold(root,id,expected) {
  const plan=await loadRegistry(root),asset=plan.assets.find(a=>a.id===id);
  if(!asset||digest(asset)!==expected)throw new Error('Descriptor changed; reload before scaffolding');
  if(asset.locked)throw new Error('Asset is locked');
  if(asset.source?.format!=='unconfigured')throw new Error('Asset already has a configured source');
  const relative=`tools/graphics/assets/${assetKey(id)}/model.py`,file=path.join(root,relative);
  await mkdir(path.dirname(file),{recursive:true});
  const size=Math.min(...asset.render.footprint)-.12;
  await writeFile(file,`"""${asset.name}: replace this scaffold with the actual design, then clear source.placeholder."""\ndef build(w):\n    w.base(${Math.max(.5,size)})\n    w.box("SCaffold placeholder", (0, 0, .7), (.4, .4, .5), w.paint)\n    return ${JSON.stringify(asset.render.footprint)}, .65, 4\n`,{flag:'wx'});
  const next={...asset,source:{format:'python',builder:relative,dependencies:[],placeholder:true}};
  return changeAsset(root,{id,expected,asset:next});
}

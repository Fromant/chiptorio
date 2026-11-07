/** Model approval never approves rendered files or authorizes publication. */
import path from 'node:path';
import {readFile,readdir,mkdir,cp} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {workspacePath,safePath,hashFile,digest,atomicJSON,loadRegistry} from './registry.mjs';
const valid=id=>{if(!/^[a-f0-9]{64}$/.test(id))throw new Error('Invalid model revision');return id;};
export class ModelReview {
  constructor(root){this.root=root;this.workspace=workspacePath(root);}
  file(id){return path.join(this.workspace,'model-reviews',valid(id)+'.json');}
  async stage(built){
    const payload={asset:built.asset,details:built.details},revision=digest(payload);
    await this.current(payload);
    try{await this.read(revision);return {revision};}catch(error){if(error.code!=='ENOENT')throw error;}
    await atomicJSON(this.file(revision),{...payload,revision,createdAt:Date.now(),review:null});
    return {revision};
  }
  async read(id){const m=JSON.parse(await readFile(this.file(id),'utf8'));if(m.revision!==id||digest({asset:m.asset,details:m.details})!==id)throw new Error('Model manifest integrity failure');return m;}
  async current(m){
    const asset=(await loadRegistry(this.root)).assets.find(a=>a.id===m.asset.id);
    if(!asset||asset.locked||digest(asset)!==digest(m.asset))throw new Error('Model descriptor changed; rebuild model');
    for(const [name,hash] of Object.entries(m.details.sources))if(await hashFile(await safePath(this.root,name))!==hash)throw new Error('Model source changed; rebuild model');
    return this.model(m.details);
  }
  async model(details){
    if(!/^[a-f0-9]{64}$/.test(details.buildKey)||details.model!==`steps/build/${details.buildKey}/model.blend`)throw new Error('No staged Blender model');
    const file=await safePath(this.workspace,details.model);
    const seal=JSON.parse(await readFile(path.join(path.dirname(file),'complete.json'),'utf8'));
    const hash=await hashFile(file);
    if(!seal['model.blend']||hash!==seal['model.blend']||(details.modelHash&&hash!==details.modelHash))throw new Error('Staged model integrity failure');
    return file;
  }
  async list(){
    const names=await readdir(path.join(this.workspace,'model-reviews')).catch(()=>[]);
    return Promise.all(names.filter(n=>/^[a-f0-9]{64}\.json$/.test(n)).map(async n=>{const m=await this.read(n.slice(0,-5));try{await this.current(m);return {...m,stale:false};}catch{return {...m,stale:true};}}));
  }
  async review(id,decision,comment=''){
    if(!['approved','rejected'].includes(decision)||typeof comment!=='string'||comment.length>4000)throw new Error('Invalid model review');
    const m=await this.read(id);await this.current(m);
    if(decision==='approved'&&m.asset.source.placeholder)throw new Error('Scaffolds cannot be approved');
    m.review={decision,comment,at:new Date().toISOString()};await atomicJSON(this.file(id),m);return m.review;
  }
  async rendered(id,revision){
    valid(revision);const m=await this.read(id);await this.current(m);
    if(m.review?.decision!=='approved')throw new Error('Model is not approved');
    m.renderedRevision=revision;await atomicJSON(this.file(id),m);
  }
  async inspectionCopy(details){
    const source=await this.model(details),folder=path.join(this.workspace,'inspection',randomUUID());await mkdir(folder,{recursive:true});
    const copy=path.join(folder,'model.blend');await cp(source,copy);return copy;
  }
}

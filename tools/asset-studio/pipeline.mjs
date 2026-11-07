/** Immutable artifact intake and revision-bound review. Never writes installed files. */

import path from 'node:path';

import { readFile, mkdir, writeFile, readdir, rm, stat } from 'node:fs/promises';

import { randomUUID } from 'node:crypto';

import { digest, stable, inside, safePath, hashFile, atomicJSON, workspacePath, assetKey, validateAsset, exists, loadRegistry, registryPath, renameRetry } from './registry.mjs';

import { bindingArtifact } from './integration.mjs';



const revisionPattern = /^[a-f0-9]{64}$/;

export class Pipeline {

  constructor(root) { this.root=root; this.workspace=workspacePath(root); }

  folder(revision) {

    if(!revisionPattern.test(revision))throw new Error('Invalid candidate revision');

    return path.join(this.workspace,'candidates',revision);

  }

  async stage(asset, artifacts, details={}) {

    validateAsset(asset);

    if(asset.locked)throw new Error('Asset is locked; explicit unlock is required');

    if(!asset.targets?.length)throw new Error('Candidate has no publication targets');

    const files=[];

    for(const target of asset.targets){

      const bytes=artifacts[target.artifact];

      if(!Buffer.isBuffer(bytes))throw new Error(`Missing artifact: ${target.artifact}`);

      files.push({...target,hash:digest(bytes),baseline:await hashFile(await safePath(this.root,target.path))});

    }

    if(new Set(files.map(f=>f.path)).size!==files.length)throw new Error('Duplicate publication target');

    const plan=await exists(registryPath(this.root))?await loadRegistry(this.root):null;

    const registered=plan?.assets.find(a=>a.id===asset.id);

    if(registered?.locked)throw new Error('Registered asset is locked');

    if(registered){

      const comparable={...asset,targets:registered.targets,render:{...asset.render,resolution:registered.render.resolution}};

      if(digest(comparable)!==digest(registered))throw new Error('Descriptor changed while building; rebuild the candidate');

    }

    const members=[];

    for(const revision of details.members??[]){const member=await this.verify(revision);if(member.details?.members||member.details?.draft)throw new Error('Bundles require full individual candidates');members.push(member);}

    if(plan&&!registered&&(!members.length||asset.id!==`bundle:${digest(details.members)}`))throw new Error('Unknown registered asset');

    for(const file of files){

      if(registered&&!registered.targets.some(t=>t.path===file.path&&t.artifact===file.artifact)&&file.path!=='graphics/published-assets.lua')throw new Error('Candidate target is not registered');

      const owner=plan?.assets.find(a=>a.id!==asset.id&&a.targets?.some(t=>t.path===file.path));if(owner&&!members.some(m=>m.asset.id===owner.id))throw new Error(`Target belongs to ${owner.id}`);

    }

    const payload={version:1,asset:structuredClone(asset),files,details,descriptor:registered?digest(registered):null};

    const revision=digest(payload),folder=this.folder(revision);

    await mkdir(path.join(this.workspace,'candidates'),{recursive:true});

    if(await exists(folder)){await this.verify(revision);return {revision,cached:true};}

    const temporary=path.join(this.workspace,'candidates',`.intake-${randomUUID()}`);await mkdir(temporary);

    // The manifest is the completion marker; interrupted intake is never reviewable.

    try{

      for(const file of files){const destination=inside(temporary,`artifacts/${file.artifact}`);await mkdir(path.dirname(destination),{recursive:true});await writeFile(destination,artifacts[file.artifact],{flag:'wx'});}

      await writeFile(path.join(temporary,'manifest.json'),stable({...payload,revision}),{flag:'wx'});

      await renameRetry(temporary,folder);

    }catch(error){await rm(temporary,{recursive:true,force:true});if(await exists(folder)){await this.verify(revision);return {revision,cached:true};}throw error;}

    return {revision,cached:false};

  }

  async verify(revision) {

    const folder=this.folder(revision),manifest=JSON.parse(await readFile(path.join(folder,'manifest.json'),'utf8'));

    const {revision:recorded,...payload}=manifest;

    if(recorded!==revision||digest(payload)!==revision)throw new Error('Candidate manifest integrity failure');

    validateAsset(manifest.asset);

    if(manifest.files.length!==manifest.asset.targets.length)throw new Error('Artifact target mismatch');

    for(const [i,file] of manifest.files.entries()){

      const target=manifest.asset.targets[i];if(file.path!==target.path||file.artifact!==target.artifact)throw new Error('Artifact target mismatch');

      if(await hashFile(await safePath(folder,`artifacts/${file.artifact}`))!==file.hash)throw new Error(`Artifact integrity failure: ${file.artifact}`);

    }

    return manifest;

  }

  async review(revision,decision,comment='') {

    const manifest=await this.verify(revision);

    if(manifest.details?.draft)throw new Error('Drafts cannot be approved; build a full review candidate');

    if(decision==='approved'&&manifest.asset.source?.placeholder)throw new Error('Scaffolds are not finished art; replace the design and clear source.placeholder');

    if(!['approved','rejected'].includes(decision))throw new Error('Invalid review decision');

    if(typeof comment!=='string'||comment.length>4000)throw new Error('Invalid review comment');

    const review={revision,decision,comment,at:new Date().toISOString()};

    await atomicJSON(path.join(this.workspace,'reviews',`${revision}.json`),review);

    return review;

  }

  async approved(revision) {

    const manifest=await this.verify(revision);

    const review=JSON.parse(await readFile(path.join(this.workspace,'reviews',`${revision}.json`),'utf8'));

    if(review.revision!==revision||review.decision!=='approved')throw new Error('Exact revision has not been approved');

    await this.assertCurrent(manifest);

    return manifest;

  }

  async assertCurrent(manifest) {

    if(manifest.details?.draft)throw new Error('Drafts cannot be published');

    if(manifest.descriptor){const asset=(await loadRegistry(this.root)).assets.find(a=>a.id===manifest.asset.id);if(!asset||asset.locked||digest(asset)!==manifest.descriptor)throw new Error('Asset descriptor or lock changed; build a new candidate');}

    for(const [source,hash] of Object.entries(manifest.details?.sources??{}))if(await hashFile(await safePath(this.root,source))!==hash)throw new Error(`Source changed; build a new candidate: ${source}`);

    for(const file of manifest.files){if(await hashFile(await safePath(this.root,file.path))!==file.baseline)throw new Error(`Installed target changed: ${file.path}`);}

    for(const revision of manifest.details?.members??[])await this.assertCurrent(await this.verify(revision));

  }

  async bundle(revisions) {

    if(!Array.isArray(revisions)||revisions.length<2||revisions.length>100||new Set(revisions).size!==revisions.length)throw new Error('Select 2..100 unique candidate revisions');

    revisions=[...revisions].sort();

    const members=[];for(const revision of revisions){const manifest=await this.verify(revision);if(manifest.details?.draft||manifest.details?.members||manifest.asset.source?.placeholder)throw new Error('Bundles require finished individual review candidates');await this.assertCurrent(manifest);members.push(manifest);}

    if(new Set(members.map(m=>m.asset.id)).size!==members.length)throw new Error('Only one revision per asset in a batch candidate');

    const targets=[],artifacts={};

    for(const member of members)for(const file of member.files){if(file.path==='graphics/published-assets.lua')continue;if(targets.some(t=>t.path===file.path))throw new Error('Conflicting bundle targets');const artifact=`${assetKey(member.asset.id)}/${file.artifact}`;targets.push({path:file.path,artifact});artifacts[artifact]=await readFile(await safePath(this.folder(member.revision),`artifacts/${file.artifact}`));}

    const binding=await bindingArtifact(this.root,members.map(m=>m.asset));if(binding){targets.push({path:binding.path,artifact:binding.artifact});artifacts[binding.artifact]=binding.bytes;}

    const name=`bundle-${digest(revisions).slice(0,12)}`;

    return this.stage({id:`bundle:${digest(revisions)}`,name,profile:'presentation',mode:'image',locked:false,render:{frames:1,period:1,footprint:[1,1]},targets},{...artifacts},{members:revisions,draft:false});

  }

  async list() {

    const names=await readdir(path.join(this.workspace,'candidates')).catch(()=>[]);

    return Promise.all(names.filter(n=>revisionPattern.test(n)).map(async revision=>{

      try {const manifest=JSON.parse(await readFile(path.join(this.folder(revision),'manifest.json'),'utf8'));const review=await readFile(path.join(this.workspace,'reviews',`${revision}.json`),'utf8').then(JSON.parse,()=>null);const validation=await readFile(path.join(this.workspace,'validations',`${revision}.json`),'utf8').then(JSON.parse,()=>null);const publication=await readFile(path.join(this.workspace,'published',`${revision}.json`),'utf8').then(JSON.parse,()=>null);let stale=false;if(!review&&!publication&&!manifest.details?.draft){try{await this.assertCurrent(manifest);}catch{stale=true;}}return {buildKey:manifest.details?.buildKey,stale,createdAt:(await stat(path.join(this.folder(revision),'manifest.json'))).mtimeMs,revision,asset:manifest.asset.id,key:assetKey(manifest.asset.id),members:manifest.details?.members,draft:!!manifest.details?.draft,review,validation,publication};}

      catch(error){return {revision,error:error.message};}

    }));

  }

}

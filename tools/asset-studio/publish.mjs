import path from 'node:path';
import { cp, mkdir, readFile, writeFile, rm, readdir, stat } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { Pipeline } from './pipeline.mjs';
import { digest, safePath, inside, hashFile, atomicJSON, loadRegistry, registryPath, renameRetry } from './registry.mjs';
import { processLog } from './process.mjs';

// Only content that can affect shipped behavior, its verification, or asset bindings.
export function included(relative) {
  if(!relative)return true;
  if(relative.startsWith('.'))return false;
  if(['docs','node_modules','dist','aseprite'].some(d=>relative===d||relative.startsWith(d+'/')))return false;
  if(relative==='tools/asset-studio'||relative.startsWith('tools/asset-studio/'))return false;
  if(relative==='tools/graphics'||relative.startsWith('tools/graphics/'))return false;
  const top=relative.split('/')[0];
  return ['graphics','scripts','locale','sound','tools'].includes(top)||/^[^/]+\.lua$/.test(relative)||['info.json','thumbnail.png'].includes(relative);
}
export async function contextHash(root) {
  const records={};
  async function visit(folder,rel=''){
    for(const entry of await readdir(folder,{withFileTypes:true})){
      const name=rel?`${rel}/${entry.name}`:entry.name;
      if(!included(name))continue;
      if(entry.isSymbolicLink())throw new Error(`Snapshot cannot contain symlinks: ${name}`);
      if(entry.isDirectory())await visit(path.join(folder,entry.name),name);
      else if(entry.isFile())records[name]=await hashFile(path.join(folder,entry.name));
    }
  }
  await visit(root);return digest(records);
}
export async function copySnapshot(root,destination) {
  async function visit(folder,relative=''){
    for(const entry of await readdir(folder,{withFileTypes:true})){
      const name=relative?`${relative}/${entry.name}`:entry.name;
      if(!included(name))continue;
      if(entry.isSymbolicLink())throw new Error(`Snapshot cannot contain symlinks: ${name}`);
      const target=inside(destination,name);
      if(entry.isDirectory()){await mkdir(target,{recursive:true});await visit(path.join(folder,entry.name),name);}
      else if(entry.isFile()){await mkdir(path.dirname(target),{recursive:true});await cp(path.join(folder,entry.name),target);}
    }
  }
  await mkdir(destination,{recursive:true});await visit(root);
}
async function replace(file,bytes) {
  await mkdir(path.dirname(file),{recursive:true});const temp=`${file}.${randomUUID()}.pipeline-tmp`;
  try{await writeFile(temp,bytes);await renameRetry(temp,file);}finally{await rm(temp,{force:true});}
}
export class ProductionPipeline extends Pipeline {
  constructor(root,{runner=processLog}={}){super(root);this.runner=runner;}
  async validate(revision,tools,job={log:''}) {
    const manifest=await this.approved(revision);
    if(!tools?.factorio)throw new Error('Factorio is required for isolated validation');
    const before=await contextHash(this.root),folder=path.join(this.workspace,'validation-runs',randomUUID()),snapshot=path.join(folder,'repository');
    await mkdir(folder,{recursive:true});
    job.log='Copying isolated validation snapshot…';
    await copySnapshot(this.root,snapshot);
    if(await contextHash(snapshot)!==before||await contextHash(this.root)!==before)throw new Error('Repository changed while snapshotting; retry validation');
    for(const file of manifest.files){const target=await safePath(snapshot,file.path);await mkdir(path.dirname(target),{recursive:true});await cp(await safePath(this.folder(revision),`artifacts/${file.artifact}`),target);if(await hashFile(target)!==file.hash)throw new Error('Candidate changed while copying validation artifacts');}
    const log=path.join(this.workspace,'logs',`${revision}-validation.log`);
    const report={revision,context:before,manifest:digest(manifest),status:'running',log:path.relative(this.workspace,log).replaceAll('\\','/'),at:new Date().toISOString()};
    const destination=path.join(this.workspace,'validations',`${revision}.json`);
    await atomicJSON(destination,report);
    try{
      job.log='Running all six Factorio suites in the isolated candidate repository…';
      const executable=process.platform==='win32'?'powershell.exe':'pwsh';
      await this.runner(executable,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(snapshot,'tools/test-all.ps1'),'-Factorio',tools.factorio],{cwd:snapshot,log,timeout:1800000});
      await this.approved(revision);
      for(const file of manifest.files)if(await hashFile(await safePath(snapshot,file.path))!==file.hash)throw new Error('Validation snapshot artifacts changed during testing');
      if(await contextHash(this.root)!==before)throw new Error('Repository changed during validation; validate again');
      report.status='passed';report.suites=['smoke','contract','registration','save/load','power-grid','performance'];
      job.log=`Validation PASS · all six suites\nLog: ${report.log}`;
    }catch(error){report.status='failed';report.error=error.message;throw error;}
    finally{await atomicJSON(destination,report);}
    return report;
  }
  async publish(revision,{confirm}={}) {
    if(confirm!==revision)throw new Error('Explicit publication confirmation must match the exact revision');
    await mkdir(path.join(this.workspace,'transactions'),{recursive:true});
    const lock=path.join(this.workspace,'publish.lock');
    let handle;try{handle=await import('node:fs/promises').then(fs=>fs.open(lock,'wx'));}catch{throw new Error('Publication is locked; recover the outstanding transaction before retrying');}
    this.publishing=true;
    let journal,folder;
    try{
      await handle.writeFile(JSON.stringify({pid:process.pid,operation:'publication'}));
      const manifest=await this.approved(revision);
      const report=JSON.parse(await readFile(path.join(this.workspace,'validations',`${revision}.json`),'utf8'));
      if(report.status!=='passed'||report.revision!==revision||report.manifest!==digest(manifest)||report.context!==await contextHash(this.root))throw new Error('Full isolated validation is missing or stale');
      const registryBaseline=await hashFile(registryPath(this.root));
      const plan=await loadRegistry(this.root),ids=manifest.details?.members?await Promise.all(manifest.details.members.map(async revision=>(await this.verify(revision)).asset.id)):[manifest.asset.id];
      const registryFile=registryPath(this.root),registryRelative=path.relative(this.root,registryFile).replaceAll('\\','/');
      for(const id of ids){const asset=plan.assets.find(a=>a.id===id);if(!asset)throw new Error('Asset is no longer registered');asset.locked=true;asset.installed={revision,at:new Date().toISOString()};}
      const writes=manifest.files.map(f=>({...f,bytes:null}));
      writes.push({path:registryRelative,baseline:registryBaseline,bytes:Buffer.from(JSON.stringify(plan,null,2)+'\n')});
      folder=path.join(this.workspace,'transactions',randomUUID());await mkdir(folder);
      journal={revision,state:'prepared',files:[]};
      for(const [i,file] of writes.entries()){
        const target=await safePath(this.root,file.path);
        if(await hashFile(target)!==file.baseline)throw new Error(`Publication conflict: ${file.path}`);
        const bytes=file.bytes??await readFile(await safePath(this.folder(revision),`artifacts/${file.artifact}`));
        if(file.hash&&digest(bytes)!==file.hash)throw new Error('Candidate changed during publication');
        await writeFile(path.join(folder,`${i}.new`),bytes);
        if(file.baseline!==null)await cp(target,path.join(folder,`${i}.old`));
        journal.files.push({path:file.path,baseline:file.baseline,hash:digest(bytes),index:i});
      }
      await atomicJSON(path.join(folder,'journal.json'),journal);
      // Recheck everything before the first installed-file write.
      await this.approved(revision);
      if(report.context!==await contextHash(this.root))throw new Error('Repository changed before publication');
      journal.state='applying';await atomicJSON(path.join(folder,'journal.json'),journal);
      for(const file of journal.files){const target=await safePath(this.root,file.path);if(await hashFile(target)!==file.baseline)throw new Error(`Publication conflict: ${file.path}`);const bytes=await readFile(path.join(folder,`${file.index}.new`));if(digest(bytes)!==file.hash)throw new Error('Prepared publication artifact integrity failure');await replace(target,bytes);}
      for(const file of journal.files)if(await hashFile(await safePath(this.root,file.path))!==file.hash)throw new Error(`Publication verification failed: ${file.path}`);
      const result={revision,at:new Date().toISOString(),files:manifest.files.map(f=>({path:f.path,hash:f.hash}))};
      await atomicJSON(path.join(this.workspace,'published',`${revision}.json`),result);
      journal.state='committed';await atomicJSON(path.join(folder,'journal.json'),journal);
      return result;
    }catch(error){
      if(journal?.state==='applying'){await this.rollback(folder,journal);}
      throw error;
    }finally{this.publishing=false;await handle.close();if(!journal||journal.state!=='applying')await rm(lock,{force:true});}
  }
  async rollback(folder,journal) {
    // Never overwrite unrelated user edits made after an interrupted publish.
    for(const file of [...journal.files].reverse()){
      const target=await safePath(this.root,file.path),current=await hashFile(target);
      if(current===file.baseline)continue;
      if(current!==file.hash)throw new Error(`Recovery conflict; preserve user work at ${file.path}`);
      if(file.baseline===null)await rm(target,{force:true});
      else {const bytes=await readFile(path.join(folder,`${file.index}.old`));if(digest(bytes)!==file.baseline)throw new Error('Recovery backup integrity failure');await replace(target,bytes);}
    }
    journal.state='rolled-back';await atomicJSON(path.join(folder,'journal.json'),journal);
    await rm(path.join(this.workspace,'published',`${journal.revision}.json`),{force:true});
  }
  async recover() {
    const lockFile=path.join(this.workspace,'publish.lock'),raw=await readFile(lockFile,'utf8').catch(error=>{if(error.code==='ENOENT')return 'null';throw error;});
    let lock;
    try{lock=JSON.parse(raw);}catch{if(Date.now()-(await stat(lockFile)).mtimeMs<30000)throw new Error('Lock metadata is incomplete; retry recovery after 30 seconds');lock=null;}
    if(lock?.pid){let alive=false;try{process.kill(lock.pid,0);alive=true;}catch{}if(alive&&(lock.pid!==process.pid||this.publishing||lock.operation==='metadata'))throw new Error('Publication/metadata process is still running; recovery refused');}
    const names=await readdir(path.join(this.workspace,'transactions')).catch(()=>[]),result=[];
    for(const name of names){if(!/^[a-f0-9-]{36}$/.test(name))continue;const folder=path.join(this.workspace,'transactions',name);const journal=JSON.parse(await readFile(path.join(folder,'journal.json'),'utf8').catch(()=>'null'));if(journal?.state==='applying'){await this.rollback(folder,journal);result.push(name);}}
    await rm(path.join(this.workspace,'publish.lock'),{force:true});return {recovered:result};
  }
}

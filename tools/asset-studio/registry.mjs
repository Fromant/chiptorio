import path from 'node:path';
import { readFile, writeFile, mkdir, stat, rename, lstat } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';

export const digest = value => createHash('sha256').update(typeof value === 'string' || Buffer.isBuffer(value) ? value : stable(value)).digest('hex');
export function stable(value) {
  if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort().filter(k=>value[k]!==undefined).map(k=>`${JSON.stringify(k)}:${stable(value[k])}`).join(',')}}`;
  return JSON.stringify(value);
}
export async function exists(file) { return stat(file).then(()=>true,()=>false); }
export async function hashFile(file) { return exists(file).then(async yes=>yes?digest(await readFile(file)):null); }
export function inside(root, relative) {
  if (typeof relative!=='string' || !relative || relative.includes('\\') || relative.includes(':') || path.isAbsolute(relative) || relative.split('/').some(s=>s==='..'||s==='.'||s==='')) throw new Error(`Unsafe relative path: ${relative}`);
  if(relative.split('/').some(s=>/[. ]$/.test(s)||/[<>"|?*]/.test(s)||/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(s)))throw new Error(`Unsafe Windows path: ${relative}`);
  const result=path.resolve(root,relative);
  if (!result.startsWith(path.resolve(root)+path.sep)) throw new Error('Path escapes workspace');
  return result;
}
export async function safePath(root, relative) {
  const result=inside(root,relative);
  for(let part=result;part!==path.dirname(root);part=path.dirname(part)){
    const info=await lstat(part).catch(error=>{if(error.code==='ENOENT')return null;throw error;});
    if(info?.isSymbolicLink())throw new Error(`Symlinks are not pipeline targets: ${relative}`);
    if(part===path.resolve(root))break;
  }
  return result;
}
export async function atomicJSON(file, value) {
  await mkdir(path.dirname(file),{recursive:true});
  const temporary=`${file}.${randomUUID()}.tmp`;
  await writeFile(temporary,JSON.stringify(value,null,2)+'\n');
  await renameRetry(temporary,file);
}
export async function renameRetry(source,destination) {
  // Windows virus scanners/watchers can briefly hold newly written files/directories.
  for(let attempt=0;;attempt++){
    try{return await rename(source,destination);}
    catch(error){if(attempt>=7||!['EPERM','EACCES','EBUSY'].includes(error.code))throw error;await delay(25*2**attempt);}
  }
}
export const registryPath = root => path.join(root,'tools/asset-studio/assets.json');
export const workspacePath = root => path.join(root,'tools/asset-studio/workspace');
export const assetKey = id => `${id.replace(/[^a-zA-Z0-9_-]/g,'-').slice(0,65)}-${digest(id).slice(0,10)}`;
export function validateAsset(asset) {
  if (!asset?.id || !/^[a-zA-Z0-9_:/.-]+$/.test(asset.id) || !/^[a-zA-Z0-9_-]+$/.test(asset.name)) throw new Error('Invalid asset identity');
  if (!['entity','image','cable','presentation'].includes(asset.profile)) throw new Error('Unsupported asset profile');
  if (!Number.isInteger(asset.render?.frames)||asset.render.frames<1||asset.render.frames>128) throw new Error('Frames must be 1..128');
  if (!Number.isInteger(asset.render.period)||asset.render.period<1||asset.render.period>512) throw new Error('Invalid animation period');
  if (asset.render.samples!==undefined && (!Number.isInteger(asset.render.samples)||asset.render.samples<1||asset.render.samples>1024)) throw new Error('Invalid samples');
  if (asset.render.resolution!==undefined && (!Number.isInteger(asset.render.resolution)||asset.render.resolution<64||asset.render.resolution>4096)) throw new Error('Invalid resolution');
  if (!Array.isArray(asset.render.footprint)||asset.render.footprint.length!==2||asset.render.footprint.some(n=>!Number.isInteger(n)||n<1||n>64)) throw new Error('Invalid footprint');
  if (!['native-crafting','native-lab','accumulator','static','scripted','existing-directional','image'].includes(asset.mode)) throw new Error('Invalid graphics mode');
  if (asset.profile==='entity' && asset.mode==='static' && asset.render.frames!==1) throw new Error('Static entities cannot advertise an unowned working animation');
  if (asset.source?.builder) inside('/validation-root',asset.source.builder);
  for (const dep of asset.source?.dependencies??[]) inside('/validation-root',dep);
  if (asset.source?.model) inside('/validation-root',asset.source.model);
  if (asset.source?.image) inside('/validation-root',asset.source.image);
  if (!['legacy-builder','python','blend','image','unconfigured'].includes(asset.source?.format??'unconfigured')) throw new Error('Invalid source format');
  const format=asset.source?.format;
  if(['python','legacy-builder'].includes(format)&&!asset.source.builder?.endsWith('.py'))throw new Error('Python sources need a .py builder');
  if(['blend','legacy-builder'].includes(format)&&!asset.source.model?.endsWith('.blend'))throw new Error('Blender sources need a .blend model path');
  if(format==='image'&&(!asset.source.image?.endsWith('.png')||asset.profile==='entity'))throw new Error('PNG sources are for static images, not entity animation adapters');
  if(asset.profile!=='entity'&&format&&format!=='unconfigured'){
    if(asset.render.frames!==1)throw new Error('Image/cable/presentation exports are single-frame PNGs');
    if(![asset.render.width,asset.render.height].every(n=>Number.isInteger(n)&&n>0&&n<=8192))throw new Error('Images require explicit output width/height (1..8192)');
  }
  if(asset.targets&&!Array.isArray(asset.targets))throw new Error('Targets must be an array');
  if(new Set((asset.targets??[]).map(t=>t.path.toLowerCase())).size!==(asset.targets??[]).length||new Set((asset.targets??[]).map(t=>t.artifact.toLowerCase())).size!==(asset.targets??[]).length)throw new Error('Duplicate asset targets');
  if(asset.mode==='scripted' && !asset.activity) throw new Error('Scripted animation needs an explicit activity owner');
  if(asset.integration?.fluidPorts!==undefined){
    if(asset.mode!=='native-crafting'||!Array.isArray(asset.integration.fluidPorts))throw new Error('Explicit fluid ports require native crafting');
    const used=new Set(),[width,height]=asset.render.footprint;
    for(const port of asset.integration.fluidPorts){
      if(!Number.isInteger(port.box)||port.box<1||!Number.isInteger(port.connection)||port.connection<1||![0,4,8,12].includes(port.direction))throw new Error('Invalid fluid-port binding');
      for(const p of [port.from,port.position])if(!Array.isArray(p)||p.length!==2||!p.every(Number.isFinite))throw new Error('Invalid fluid-port position');
      const [x,y]=port.position;
      if(Math.abs(x)>width/2-.5||Math.abs(y)>height/2-.5||
        (port.direction===0&&y!==-(height/2-.5))||(port.direction===8&&y!==height/2-.5)||
        (port.direction===4&&x!==width/2-.5)||(port.direction===12&&x!==-(width/2-.5)))throw new Error('Fluid ports must sit on the approved perimeter');
      const key=`${port.box}:${port.connection}`;if(used.has(key))throw new Error('Duplicate fluid-port binding');used.add(key);
    }
  }
  for (const target of asset.targets??[]) {
    inside('/validation-root',target.path);
    if (!/^(graphics\/|thumbnail\.png$)/.test(target.path) || !/\.(png|lua)$/.test(target.path)) throw new Error('Publishing is limited to graphics and sprite definitions');
    if (!/^[a-zA-Z0-9_./-]+$/.test(target.artifact) || target.artifact.includes('..')) throw new Error('Invalid artifact name');
  }
  if (asset.prototype && (!['container','assembling-machine','furnace','lab','accumulator'].includes(asset.prototype.type)||asset.prototype.name!==asset.name)) throw new Error('Invalid prototype binding');
  return asset;
}
export async function loadRegistry(root) {
  const plan=JSON.parse(await readFile(registryPath(root),'utf8'));
  if(plan.version!==1||!Array.isArray(plan.assets)||!Array.isArray(plan.groups))throw new Error('Unsupported asset registry');
  const ids=new Set(),targets=new Map();
  const groupIds=new Set(plan.groups.map(g=>g.id));
  if(groupIds.size!==plan.groups.length)throw new Error('Duplicate batch identity');
  for(const asset of plan.assets){validateAsset(asset);if(ids.has(asset.id))throw new Error('Duplicate asset identity');if(!groupIds.has(asset.group))throw new Error('Unknown asset batch');ids.add(asset.id);for(const target of asset.targets??[]){const key=target.path.toLowerCase();if(targets.has(key))throw new Error(`Target is shared by ${targets.get(key)} and ${asset.id}`);targets.set(key,asset.id);}}
  return plan;
}
export function selectAssets(plan,{asset,batch}={}) {
  let result;
  if(asset){result=plan.assets.filter(a=>a.id===asset);if(!result.length)result=plan.assets.filter(a=>a.name===asset);if(result.length!==1)throw new Error('Use an unambiguous asset ID');}
  else if(batch!==undefined){const group=plan.groups.find(g=>g.id===String(batch)||g.batch===Number(batch));if(!group)throw new Error('Unknown batch');result=plan.assets.filter(a=>a.group===group.id);}
  else throw new Error('Select an asset or batch explicitly; no implicit rebuild-all');
  return result;
}

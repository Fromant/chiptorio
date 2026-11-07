/** One-time inventory import. Writes planning metadata only, never game assets. */
import { root, detectTools, getCatalog } from './host.mjs';
import { registryPath, exists, atomicJSON, validateAsset } from './registry.mjs';

if(await exists(registryPath(root)))throw new Error('Registry already exists; migration never overwrites planning work');
const {data}=await getCatalog(await detectTools());
if(!data.hasPrototypes)throw new Error('Read installed prototypes before importing the full inventory');
const common=['lab_models.py','infrastructure_models.py','logistics_models.py','batch5_models.py','batch5_redesign.py'].map(n=>`tools/graphics/blender/${n}`);
const assets=[];
for(const entry of data.entries){
  if(entry.kind==='Reference')continue;
  const entity=entry.kind==='Entity',directional=entry.name==='server-rack'&&entity;
  if(entity&&entry.prototype==='pipe')continue; // Shared cable shapes are the editable sources, not four tinted aliases.
  const profile=entity?'entity':entry.kind==='Cable shape'?'cable':entry.kind==='Presentation'?'presentation':'image';
  let mode=!entity?'image':['assembling-machine','furnace'].includes(entry.prototype)?'native-crafting':entry.prototype==='lab'?'native-lab':entry.prototype==='accumulator'?'accumulator':'static';
  const scripted=['metrology-lab','answer-engine','qln-storage-drive','quantum-entanglement-core','foup-dock','wireless-access-point','qln-import-node','qln-export-node','qln-provider-node','qln-requester-node','qln-terminal','training-cluster','inference-lab','network-monitor'];
  if(entity&&scripted.includes(entry.name))mode='scripted';
  if(directional)mode='existing-directional';
  const done=data.groups.find(g=>g.id===entry.group).status==='done';
  const first=entry.working?.[0],image=data.images[entry.image];
  const frames=entity?(first?.frames>1?first.frames:1):1;
  const footprint=entity?entry.footprint.map(Math.round):[1,1];
  const period=entity&&frames>1?Math.round(frames/(first?.fps||12)*24):48;
  const builder=entry.model?directional?'tools/graphics/blender/build.py':`tools/graphics/blender/${entry.name}/build.py`:null;
  let targets;
  if(directional)targets=[...['north','east','south','west'].flatMap(v=>[
    {artifact:`${v}/working.png`,path:`graphics/entity/${entry.name}/${entry.name}_${v}_sheet.png`},
    {artifact:`${v}/shadow.png`,path:`graphics/entity/${entry.name}/${entry.name}_${v}_shadow.png`}]),{artifact:'sprite-def.lua',path:`graphics/entity/${entry.name}/sprite-def.lua`}];
  else targets=entity?['working.png','idle.png','shadow.png','sprite-def.lua'].map(f=>({artifact:f,path:`graphics/entity/${entry.name}/${f}`})):[{artifact:'image.png',path:entry.image}];
  assets.push({id:entry.id,name:entry.name,kind:entry.kind,group:entry.group,order:entry.order,profile,mode,locked:done,
    installed:done?{legacy:true}:null,
    prototype:entity&&entry.prototype!=='pipe'?{type:entry.prototype,name:entry.name}:null,
    activity:mode==='scripted'?entry.name:null,
    source:{format:builder?'legacy-builder':'unconfigured',builder,model:entry.model??null,dependencies:builder&&!directional?common:[],placeholder:false},
    render:{frames,period:Math.max(period,1),footprint,samples:32,draftSamples:8,resolution:Math.max(512,Math.ceil((Math.max(...footprint)*64+384)/256)*256),width:image?.width??null,height:image?.height??null,fit:profile==='cable'?'canvas':'contain',views:directional?['north','east','south','west']:['game']},targets});
}
const groups=data.groups.filter(g=>g.id!=='archive').map(g=>({...g,batch:g.id==='done-0'?0:Number(g.title.match(/Batch (\d+)/)?.[1])||null}));
for(const asset of assets)validateAsset(asset);
await atomicJSON(registryPath(root),{version:1,groups,assets});
console.log(JSON.stringify({registry:registryPath(root),assets:assets.length,batches:groups.length,installedFilesChanged:0}));

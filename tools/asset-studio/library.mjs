/** Library presentation of approved bytes. Never installs or edits artwork. */
import path from 'node:path';
import {Pipeline} from './pipeline.mjs';

export async function approvedLibrary(root,catalog){
  const data=structuredClone(catalog.data),registry=new Map(catalog.registry);
  data.installedEntries=structuredClone(data.entries);
  const pipeline=new Pipeline(root),latest=new Map();
  for(const c of (await pipeline.list()).sort((a,b)=>b.createdAt-a.createdAt))
    if(!c.draft&&!c.members&&c.review?.decision==='approved'&&!latest.has(c.asset))latest.set(c.asset,c);
  for(const c of latest.values()){
    if(c.publication)continue;
    let manifest;
    try{manifest=await pipeline.verify(c.revision);}catch{continue;}
    const entry=data.entries.find(e=>e.id===c.asset),meta=manifest.details.preview;
    if(!entry||!meta)continue;
    const add=(file,width=meta.width,height=meta.height)=>{
      const key=`approved:${c.revision}:${file}`;
      data.images[key]={src:`/api/pipeline/artifact/${c.revision}?file=${encodeURIComponent(file)}`,width,height};
      registry.set(key,path.join(pipeline.folder(c.revision),'artifacts',file));
      return key;
    };
    let current=true;try{await pipeline.assertCurrent(manifest);}catch{current=false;}
    entry.approval={revision:c.revision,level:'artwork',published:false,current};
    entry.source='Approved artwork · not published';
    entry.installedFiles=[...entry.files];
    entry.files=[];
    entry.model=manifest.details.model?`tools/asset-studio/workspace/${manifest.details.model}`:null;
    if(meta.image){entry.image=add(meta.image);entry.files=[entry.image];continue;}
    const view=meta.views.game??meta.views.north??Object.values(meta.views)[0];
    const layer=(file,frames,shadow=false)=>{
      const columns=frames===1?1:meta.columns;
      return {image:add(file,meta.width*columns,meta.height*Math.ceil(frames/columns)),width:meta.width,height:meta.height,frames,
        columns,fps:frames===1?0:meta.fps,scale:meta.scale,shift:meta.shift,shadow};
    };
    delete entry.image;
    entry.idle=[layer(view.idle,1),layer(view.shadow,1,true)];
    entry.working=[layer(view.working,meta.frames),layer(view.shadow,1,true)];
    entry.footprint=meta.footprint;
    entry.files=[...new Set([...entry.idle,...entry.working].map(l=>l.image))];
  }
  for(const group of data.groups){
    const members=data.entries.filter(e=>e.group===group.id);
    if(group.status==='future'&&members.length&&members.every(e=>e.approval)){
      group.status='approved';group.note='Showing approved artwork. Publication to the game is a separate step.';
    }
  }
  return {data,registry};
}

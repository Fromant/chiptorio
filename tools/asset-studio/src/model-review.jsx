import React,{useState} from 'react';
import {useQuery} from '@tanstack/react-query';
function GeometryInspection({revision,busy,action}){
  const [open,setOpen]=useState(false),[view,setView]=useState('game');
  const {data,error}=useQuery({queryKey:['geometry-inspection',revision],enabled:open,refetchInterval:open?5000:false,queryFn:async()=>{
    const r=await fetch(`/api/pipeline/model/${revision}/diagnostics`),d=await r.json();if(!r.ok)throw new Error(d.error);return d;
  }});
  return <details onToggle={e=>setOpen(e.currentTarget.open)}><summary>Geometry inspection renders</summary>
    <p>Key poses from seven cameras, including a close-up. These views check geometry and motion; they are separate from final sprite review.</p>
    {error&&<p role="alert">{error.message}</p>}
    {data?.available?<><label>Inspection camera <select aria-label="Inspection camera" value={view} onChange={e=>setView(e.target.value)}>{data.images.map(i=><option key={i.view}>{i.view}</option>)}</select></label>
    <p><a href={data.images.find(i=>i.view===view)?.url} target="_blank" rel="noreferrer">Open full-size pose sheet</a> · <a href={`/api/pipeline/model/${revision}/diagnostic/report.json`} target="_blank" rel="noreferrer">Contact report ({data.contacts} pairs)</a></p>
    <img style={{width:'100%',height:'auto'}} src={data.images.find(i=>i.view===view)?.url} alt={`${view} geometry inspection poses`}/>
    <p>{data.note}</p></>:<p>{open?'No inspection renders yet.':''}</p>}
    <button disabled={busy} onClick={()=>action(`/api/pipeline/model/${revision}/diagnose`,{})}>Generate inspection views</button>
  </details>;
}
function ModelLinks({revision,kind,action,busy}){
  const base=`/api/pipeline/model/${revision}`,suffix=kind==='model'?'?kind=model':'';
  return <div className="review-controls"><a className="button" href={base+suffix} download>Download .blend</a><button disabled={busy} onClick={()=>action(base+'/open'+suffix,{})}>Open in Blender</button><button disabled={busy} onClick={()=>action(base+'/still'+suffix,{})}>Quick camera still</button></div>;
}
export function ModelReviewPanel({data,busy,action}){
  const [chosen,setChosen]=useState(()=>new URLSearchParams(location.search).get('model')??''),[comment,setComment]=useState(''),[historyId,setHistory]=useState('');
  const latest=new Map();
  for(const m of [...(data.models??[])].sort((a,b)=>b.createdAt-a.createdAt))if(!latest.has(m.asset.id))latest.set(m.asset.id,m);
  const queue=[...latest.values()].filter(m=>!m.stale&&!m.renderedRevision&&m.review?.decision!=='rejected');
  const m=queue.find(m=>m.revision===chosen)??queue[0];
  const old=new Map();
  for(const c of [...data.candidates].sort((a,b)=>b.createdAt-a.createdAt))if(!c.draft&&!c.members&&!c.error&&!old.has(c.asset))old.set(c.asset,c);
  const history=[...old.values()],previous=history.find(c=>c.revision===historyId)??history[0];
  return <section className="model-review"><h3>1. Model and motion {queue.length?`(${queue.length})`:''}</h3><p>Review geometry and the complete handling cycle using Blender and inspection renders before final sprite production. A model decision does not approve final artwork.</p>
    {m?<article className="model-detail"><h3>{m.asset.name}</h3><ModelLinks revision={m.revision} kind="model" action={action} busy={busy}/><p>In Blender: press Space to play the timeline; scrub for contacts, clearances and handoffs. Use camera view (Numpad 0) for the game angle. Quick camera still renders one frame, without the animation.</p>
    <GeometryInspection key={m.revision} revision={m.revision} busy={busy} action={action}/>
    {m.review?.decision==='approved'?<><p>Model accepted. Next: render the final animation for a separate look review.</p><button disabled={busy} onClick={()=>action(`/api/pipeline/model/${m.revision}/render`,{})}>Render final animation</button></>:<><textarea aria-label="Model feedback" placeholder="Geometry, collisions, process and motion feedback" value={comment} onChange={e=>setComment(e.target.value)}/><div className="review-controls"><button disabled={busy} onClick={()=>{action(`/api/pipeline/model/${m.revision}/review`,{decision:'rejected',comment});setComment('');}}>Request model changes</button><button disabled={busy} onClick={()=>{action(`/api/pipeline/model/${m.revision}/review`,{decision:'approved',comment});setComment('');}}>Model looks good</button></div></>}
    <button disabled={queue.length<2} onClick={()=>{setChosen(queue[(queue.indexOf(m)+1)%queue.length].revision);setComment('');}}>Next model</button></article>:<p>No new models awaiting review. Future iterations can stop at the model stage.</p>}
    <details><summary>Previously reviewed assets - Blender files and feedback</summary><p>These are the exact models behind the existing renders. Opening uses a disposable copy; edits there do not replace the source model.</p>
    <select aria-label="Previously reviewed model" value={previous?.revision??''} onChange={e=>setHistory(e.target.value)}>{history.map(c=><option key={c.revision} value={c.revision}>{data.registry.assets.find(a=>a.id===c.asset)?.name??c.asset}</option>)}</select>
    {previous&&<><p>{previous.review?.comment??'No feedback recorded.'}</p><ModelLinks revision={previous.revision} action={action} busy={busy}/></>}
    </details></section>;
}

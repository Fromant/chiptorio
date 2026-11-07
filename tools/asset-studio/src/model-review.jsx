import React,{useState} from 'react';
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
  return <section className="model-review"><h3>1. Model and motion {queue.length?`(${queue.length})`:''}</h3><p>Review geometry and the complete handling cycle in Blender before rendering an animation. A model decision does not approve final artwork.</p>
    {m?<article className="model-detail"><h3>{m.asset.name}</h3><ModelLinks revision={m.revision} kind="model" action={action} busy={busy}/><p>In Blender: press Space to play the timeline; scrub for contacts, clearances and handoffs. Use camera view (Numpad 0) for the game angle. Quick camera still renders one frame, without the animation.</p>
    {m.review?.decision==='approved'?<><p>Model accepted. Next: render the final animation for a separate look review.</p><button disabled={busy} onClick={()=>action(`/api/pipeline/model/${m.revision}/render`,{})}>Render final animation</button></>:<><textarea aria-label="Model feedback" placeholder="Geometry, collisions, process and motion feedback" value={comment} onChange={e=>setComment(e.target.value)}/><div className="review-controls"><button disabled={busy} onClick={()=>{action(`/api/pipeline/model/${m.revision}/review`,{decision:'rejected',comment});setComment('');}}>Request model changes</button><button disabled={busy} onClick={()=>{action(`/api/pipeline/model/${m.revision}/review`,{decision:'approved',comment});setComment('');}}>Model looks good</button></div></>}
    <button disabled={queue.length<2} onClick={()=>{setChosen(queue[(queue.indexOf(m)+1)%queue.length].revision);setComment('');}}>Next model</button></article>:<p>No new models awaiting review. Future iterations can stop at the model stage.</p>}
    <details><summary>Previously reviewed assets - Blender files and feedback</summary><p>These are the exact models behind the existing renders. Opening uses a disposable copy; edits there do not replace the source model.</p>
    <select aria-label="Previously reviewed model" value={previous?.revision??''} onChange={e=>setHistory(e.target.value)}>{history.map(c=><option key={c.revision} value={c.revision}>{data.registry.assets.find(a=>a.id===c.asset)?.name??c.asset}</option>)}</select>
    {previous&&<><p>{previous.review?.comment??'No feedback recorded.'}</p><ModelLinks revision={previous.revision} action={action} busy={busy}/></>}
    </details></section>;
}

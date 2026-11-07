import { ModelReviewPanel } from './model-review.jsx';
import React, { useEffect, useRef, useState } from 'react';

import { useQuery, useQueryClient } from '@tanstack/react-query';

import { bounds, draw } from './preview.mjs';



async function request(url,body){const response=await fetch(url,body===undefined?{}:{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const data=await response.json();if(!response.ok)throw new Error(data.error??'Request failed');return data;}

function Comparison({installed,manifest,images}) {

  const left=useRef(),right=useRef(),[working,setWorking]=useState(true),[playing,setPlaying]=useState(true),[frame,setFrame]=useState(0),[view,setView]=useState('game');

  const meta=manifest.details.preview,revision=manifest.revision;

  const artifact=file=>`/api/pipeline/artifact/${revision}?file=${encodeURIComponent(file)}`;

  const activeView=meta.views?.[view]??Object.values(meta.views??{})[0];

  useEffect(()=>{

    if(!activeView)return;

    const layer=(image,frames,shadow=false)=>({image,width:meta.width,height:meta.height,frames,columns:frames===1?1:meta.columns,fps:frames===1?0:meta.fps,scale:meta.scale,shift:meta.shift,shadow});

    const candidate={footprint:meta.footprint,idle:[layer(activeView.idle,1),layer(activeView.shadow,1,true)],working:[layer(activeView.working,meta.frames),layer(activeView.shadow,1,true)]};

    const sources={...images,...Object.fromEntries(Object.values(activeView).map(f=>[f,{src:artifact(f)}]))};

    const old=installed?.idle?.length?installed:{idle:[],working:[],footprint:manifest.asset.render.footprint};

    const a=bounds(old),b=bounds(candidate),common={left:Math.min(a.left,b.left),top:Math.min(a.top,b.top)};

    common.width=Math.max(a.left*2+a.width,b.left*2+b.width)-common.left*2;

    common.height=Math.max(a.top*2+a.height,b.top*2+b.height)-common.top*2;

    let animation,last=0,time=frame/(meta.fps||12)*1000;

    const tick=now=>{if(playing&&last)time+=Math.min(now-last,100);last=now;draw(left.current,old,sources,time,working,true,common);draw(right.current,candidate,sources,time,working,true,common);animation=requestAnimationFrame(tick);};

    animation=requestAnimationFrame(tick);return()=>cancelAnimationFrame(animation);

  },[manifest,images,installed,working,playing,frame,view]);

  if(meta.image)return <div className="review-comparison"><section><h4>Installed</h4>{installed?.image?<img src={images[installed.image].src} alt="Installed artifact"/>:<p>No installed image</p>}</section><section><h4>Candidate · exact shipping PNG</h4><img src={artifact(meta.image)} alt="Candidate artifact"/></section></div>;

  return <><div className="review-controls"><button onClick={()=>setWorking(!working)}>{working?'Show idle':'Show working'}</button><button onClick={()=>setPlaying(!playing)}>{playing?'Pause review':'Play review'}</button><label>Frame <input aria-label="Review frame" type="range" min="0" max={meta.frames-1} value={frame} onChange={e=>{setPlaying(false);setFrame(+e.target.value);}}/> {frame+1}/{meta.frames}</label>{Object.keys(meta.views).length>1&&<select aria-label="Candidate direction" value={view in meta.views?view:Object.keys(meta.views)[0]} onChange={e=>setView(e.target.value)}>{Object.keys(meta.views).map(v=><option key={v}>{v}</option>)}</select>}</div><div className="review-comparison"><section><h4>Installed{manifest.asset.mode==='existing-directional'?' · north view':''}</h4><canvas ref={left} aria-label="Installed comparison"/></section><section><h4>Candidate · exact shipping sheets</h4><canvas ref={right} aria-label="Candidate comparison"/></section></div><p>Same world scale and origin; outlined occupied tiles. {installed?.footprint?.join(' × ')??'—'} → {manifest.asset.render.footprint.join(' × ')} tiles.</p></>;

}

function BundleMember({revision,catalog}) {

  const {data,error}=useQuery({queryKey:['candidate',revision],queryFn:()=>request(`/api/pipeline/candidate/${revision}`)});

  if(error)return <p role="alert">{error.message}</p>;

  if(!data)return <p>Loading batch member…</p>;

  return <section><h4>{data.asset.name} · {revision.slice(0,12)}</h4><Comparison installed={catalog.entries.find(e=>e.id===data.asset.id)} manifest={data} images={catalog.images}/></section>;

}

function CandidateLogs({manifest,validation}) {

  const details=manifest.details;

  return <div className="review-controls">{manifest.asset.source?.format!=='image'&&details.buildKey&&<a href={`/api/pipeline/log/${details.buildKey}-build.log`} target="_blank" rel="noreferrer">Full build log</a>}{manifest.asset.source?.format!=='image'&&details.renderKey&&<a href={`/api/pipeline/log/${details.renderKey}-render.log`} target="_blank" rel="noreferrer">Full render log</a>}{validation&&<a href={`/api/pipeline/log/${manifest.revision}-validation.log`} target="_blank" rel="noreferrer">Full validation log</a>}</div>;

}

export function PipelinePanel({catalog,busy,action}) {

  const client=useQueryClient(),[open,setOpen]=useState(true),[advanced,setAdvanced]=useState(false),[batch,setBatch]=useState('batch-6'),[assetId,setAssetId]=useState(''),[revision,setRevision]=useState(()=>new URLSearchParams(location.search).get('review')??''),[editor,setEditor]=useState(''),[comment,setComment]=useState(''),[localError,setError]=useState('');

  const {data,error}=useQuery({queryKey:['pipeline'],queryFn:()=>request('/api/pipeline'),enabled:open,refetchInterval:open?5000:false});

  const detail=useQuery({queryKey:['candidate',revision],queryFn:()=>request(`/api/pipeline/candidate/${revision}`),enabled:open&&!!revision});

  const asset=data?.registry.assets.find(a=>a.id===assetId);

  useEffect(()=>{setEditor(asset?JSON.stringify(asset,null,2):'');},[assetId,data?.hashes[assetId]]);

  async function edit(body){setError('');try{await request('/api/pipeline/asset',body);await client.invalidateQueries();}catch(error){setError(error.message);}}

  const latest=new Map();

  for(const c of [...(data?.candidates??[])].sort((a,b)=>(b.createdAt??0)-(a.createdAt??0)))

    if(!c.draft&&!c.members&&!c.error&&!latest.has(c.asset))latest.set(c.asset,c);

  const candidates=[...latest.values()].filter(c=>!c.review&&!c.publication&&!c.stale);

  useEffect(()=>{

    if(!advanced&&data&&!candidates.some(c=>c.revision===revision)) {

      setRevision(candidates[0]?.revision??'');setComment('');

      history.replaceState(null,'',candidates.length?`?review=${candidates[0].revision}`:location.pathname);

    }

  },[data,advanced,revision]);

  const selected=data?.candidates.find(c=>c.revision===revision),manifest=detail.data;

  return <section className="pipeline-panel"><button className="pipeline-toggle" aria-expanded={open} onClick={()=>setOpen(!open)}>Review finished assets</button>{open&&<div className="pipeline-body">

    <p>Review one finished asset at a time. Approve or request changes to move to the next. Your feedback is saved; installation happens separately.</p>

    {(error||localError||detail.error)&&<p role="alert">{localError||error?.message||detail.error?.message}</p>}

    {!data?<p>Loading production registry…</p>:<>

      <details onToggle={e=>setAdvanced(e.currentTarget.open)}><summary>Production tools</summary><div className="review-controls"><label>Batch <select aria-label="Pipeline batch" value={batch} onChange={e=>{setBatch(e.target.value);setAssetId('');}}>{data.registry.groups.map(g=><option value={g.id} key={g.id}>{g.title}</option>)}</select></label><label>Asset <select aria-label="Pipeline asset" value={assetId} onChange={e=>setAssetId(e.target.value)}><option value="">All configured, unlocked assets in batch</option>{data.registry.assets.filter(a=>a.group===batch).map(a=><option value={a.id} key={a.id}>{a.name}{a.locked?' · locked':a.source?.format==='unconfigured'?' · needs source':''}</option>)}</select></label><button disabled={busy||asset?.locked} onClick={()=>action('/api/pipeline/build',{...(assetId?{asset:assetId}:{batch}),modelOnly:true})}>Build model only (no animation render)</button><button disabled={busy||asset?.locked} onClick={()=>action('/api/pipeline/build',{...(assetId?{asset:assetId}:{batch}),draft:true})}>Build draft</button><button disabled={busy||asset?.locked} onClick={()=>action('/api/pipeline/build',assetId?{asset:assetId}:{batch})}>Build review candidate</button></div>

      {asset&&<details><summary>Source configuration · {asset.locked?'protected':'editable'}</summary><p>Source: {asset.source.builder??asset.source.model??asset.source.image??'Not configured'} · {asset.profile} / {asset.mode}</p><div className="review-controls"><button disabled={busy} onClick={()=>{const reason=window.prompt(`${asset.locked?'Unlock':'Lock'} ${asset.name}: enter a reason. This does not approve any art.`);if(reason)edit({id:assetId,expected:data.hashes[assetId],locked:!asset.locked,confirm:assetId,reason});}}>{asset.locked?'Explicitly unlock asset':'Lock asset'}</button><button disabled={busy||asset.locked||asset.source.format!=='unconfigured'} onClick={()=>action('/api/pipeline/scaffold',{id:assetId,expected:data.hashes[assetId]})}>Scaffold model.py</button></div><textarea aria-label="Asset descriptor" value={editor} disabled={asset.locked||busy} onChange={e=>setEditor(e.target.value)}/><button disabled={busy||asset.locked} onClick={()=>{try{edit({id:assetId,expected:data.hashes[assetId],asset:JSON.parse(editor)});}catch(e){setError(e.message);}}}>Save descriptor</button></details>}

      <label>Candidate history <select aria-label="Candidate history" value={revision} onChange={e=>{setRevision(e.target.value);setComment('');}}><option value="">Select a version</option>{data.candidates.map(c=><option key={c.revision} value={c.revision}>{c.asset} · {c.draft?'draft':c.members?'batch':c.review?.decision??'awaiting review'} · {c.revision.slice(0,8)}</option>)}</select></label>

      </details>

      <ModelReviewPanel data={data} busy={busy} action={action}/>
      <p>2. Final render: approve the look of the exact shipping images, then validate and publish separately.</p>
      <h3>Ready for review · {candidates.length}</h3>

      <button disabled={busy||candidates.length<2} onClick={()=>{const i=candidates.findIndex(c=>c.revision===revision);setRevision(candidates[(i+1)%candidates.length].revision);setComment('');}}>Skip to next asset</button>

      {!candidates.length&&!advanced&&<p>No finished assets awaiting review. Requested changes are saved; revised models will appear here when ready.</p>}

      {manifest&&(advanced||candidates.some(c=>c.revision===revision))&&<article className="candidate-detail"><h3>{manifest.asset.name} · {manifest.details.draft?'DRAFT — cannot publish':manifest.details.members?'Batch review candidate — approve and validate once':'Review candidate'}</h3><code hidden={!advanced} className="revision-id">{manifest.revision}</code>{manifest.details.members?.map(r=><BundleMember key={r} revision={r} catalog={catalog}/>)}{manifest.details.preview?<Comparison installed={catalog.entries.find(e=>e.id===manifest.asset.id)} manifest={manifest} images={catalog.images}/>:!manifest.details.members&&<p>Artifact intake has no render preview.</p>}<p hidden={!advanced}>Checks: {manifest.details.preview?.checks?.join(' · ')}</p><details><summary>Exact publication files</summary>{manifest.files.map(f=><p key={f.path}><a href={`/api/pipeline/artifact/${revision}?file=${encodeURIComponent(f.artifact)}`} target="_blank" rel="noreferrer">{f.path}</a><small> SHA-256 {f.hash}</small></p>)}</details>{selected?.review&&<p>Review: {selected.review.decision} · {selected.review.comment}</p>}{selected?.validation&&<p>Validation: {selected.validation.status} · {selected.validation.suites?.join(', ')} {selected.validation.error}</p>}

      <CandidateLogs manifest={manifest} validation={selected?.validation}/><textarea aria-label="Review comment" placeholder="Feedback / requested changes" value={comment} onChange={e=>setComment(e.target.value)}/><div className="review-controls"><button disabled={busy||manifest.details.draft||!!selected?.publication} onClick={()=>action('/api/pipeline/review',{revision,decision:'rejected',comment})}>Request changes</button><button disabled={busy||manifest.details.draft||!!selected?.publication} onClick={()=>{if(window.confirm(`Approve the exact artifacts of ${manifest.asset.name}, revision ${revision.slice(0,12)}? This does not install them.`))action('/api/pipeline/review',{revision,decision:'approved',comment});}}>Approve exact revision</button><button hidden={!advanced} disabled={busy||selected?.review?.decision!=='approved'||!!selected?.publication} onClick={()=>action('/api/pipeline/validate',{revision})}>Validate in isolated Factorio</button><button hidden={!advanced} className="primary" disabled={busy||selected?.review?.decision!=='approved'||selected?.validation?.status!=='passed'||!!selected?.publication} onClick={()=>{if(window.confirm(`PUBLISH ${manifest.asset.name}? This installs the exact approved files and locks the asset. Revision: ${revision}`))action('/api/pipeline/publish',{revision,confirm:revision});}}>Publish approved files</button></div></article>}

      {data.recovery&&<div className="banner">Publication recovery is needed.<button disabled={busy} onClick={()=>{if(window.confirm('Recover interrupted publication? Conflicting user edits will not be overwritten.'))action('/api/pipeline/recover',{confirm:'recover'});}}>Recover publication</button></div>}

    </>}

  </div>}</section>;

}

import React, { useEffect, useRef, useState } from 'react';

import { createRoot } from 'react-dom/client';

import { QueryClient, QueryClientProvider, useQuery, useQueryClient } from '@tanstack/react-query';

import { Boxes, Search, RefreshCw, Download, Play, Pause, Box, ExternalLink, Check, Clock3, Image as ImageIcon, Layers3, ChevronRight, X, Terminal, ScanLine, Grid2X2, AlertCircle, Cpu } from 'lucide-react';

import { draw } from './preview.mjs';

import './style.css';

import { PipelinePanel } from './pipeline.jsx';



async function request(url, body) {

  const response = await fetch(url, body === undefined ? {} : { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

  const data = await response.json(); if (!response.ok) throw new Error(data.error ?? 'Request failed'); return data;

}

function Preview({ entry, images, working, paused, footprint, large = false }) {

  const ref = useRef(null), clock = useRef(0);

  useEffect(() => {

    if (entry.image) return;

    let frame, last = 0, visible = false;

    const observer = new IntersectionObserver(([e]) => { visible = e.isIntersecting; });

    observer.observe(ref.current);

    const tick = time => {

      if (!paused && !document.hidden) clock.current += last ? Math.min(time - last, 100) : 0;

      last = time;

      if (visible) draw(ref.current, entry, images, clock.current, working, footprint);

      frame = requestAnimationFrame(tick);

    };

    frame = requestAnimationFrame(tick);

    return () => { cancelAnimationFrame(frame); observer.disconnect(); };

  }, [entry, images, working, paused, footprint]);

  return <div className={`art ${large ? 'large' : ''}`}>{entry.image

    ? <img loading="lazy" src={images[entry.image].src} alt={entry.name} />

    : <canvas ref={ref} role="img" aria-label={`${entry.name}, ${working ? 'working' : 'idle'} sprite preview`} />}</div>;

}

function AssetCard({ entry, group, images, settings, select, action, busy, tools }) {

  return <article className="asset-card">

    <button className="art-button" onClick={() => select(entry)} aria-label={`Inspect ${entry.name}`}><Preview entry={entry} images={images} {...settings} /><span className="art-kind">{entry.kind}</span>{entry.model && <span className="model-mark"><Box size={13} /> .blend</span>}</button>

    <div className="card-body"><div className={`status-label ${group.status}`}><span />{entry.source}</div><h3>{entry.name}</h3>

      <div className="card-meta">{entry.footprint ? `${entry.footprint.map(n => +n.toFixed(2)).join(' × ')} tiles` : `${images[entry.image].width} × ${images[entry.image].height} px`}<span>·</span>{entry.files.length} source{entry.files.length === 1 ? '' : 's'}</div>

      <div className="card-actions"><button onClick={() => select(entry)}><Layers3 size={14} /> Inspect</button>{entry.model && <><button title="Open editable model in Blender" disabled={!tools.blender} onClick={() => action('/api/model/open', { id: entry.id })}><ExternalLink size={14} /> Blender</button><button title="Render one low-sample game-view preview. Does not install graphics." disabled={busy || !tools.blender} onClick={() => action('/api/model/preview', { id: entry.id })}><Play size={14} /> Render</button></>}</div>

    </div>

  </article>;

}

function App() {

  const client = useQueryClient(), [search, setSearch] = useState(''), [stage, setStage] = useState('all'), [kind, setKind] = useState('all');

  const [selectedGroup, setSelectedGroup] = useState(() => new URLSearchParams(location.search).get('batch') ?? 'all');

  const [selected, setSelected] = useState(null), [working, setWorking] = useState(true), [paused, setPaused] = useState(false), [footprint, setFootprint] = useState(false);

  const [showLibrary, setShowLibrary] = useState(false), [consoleOpen, setConsoleOpen] = useState(false), [notice, setNotice] = useState(''), [pending, setPending] = useState(false);

  const { data, error, isFetching } = useQuery({ queryKey: ['catalog'], queryFn: () => request('/api/catalog'), refetchInterval: 15000 });

  const { data: jobs = [] } = useQuery({ queryKey: ['jobs'], queryFn: () => request('/api/jobs'), refetchInterval: 2000 });

  const previous = useRef('');

  useEffect(() => {

    const signature = jobs.map(j => j.id + j.status).join('');

    if (signature !== previous.current) { previous.current = signature; client.invalidateQueries({ queryKey: ['catalog'] }); }

  }, [jobs, client]);

  useEffect(() => { if (selected) document.querySelector('#asset-detail')?.showModal(); }, [selected]);

  const busy = pending || jobs.some(j => j.status === 'running');

  async function action(url, body = {}) {

    setPending(true);

    try { const result = await request(url, body); setNotice(result.path ? `Saved ${result.path}` : result.opened ? `Opened ${result.opened} in Blender` : result.decision ? `Exact revision ${result.decision}; nothing installed` : result.asset ? 'Source configuration saved' : result.revision ? `Candidate ${result.revision.slice(0,12)} ready` : 'Job started'); if (result.id) setConsoleOpen(true); await client.invalidateQueries(); }

    catch (error) { setNotice(error.message); }

    finally { setPending(false); }

  }

  async function scan() {

    try { client.setQueryData(['catalog'], await request('/api/catalog?scan=1')); setNotice('Asset library rescanned'); }

    catch (error) { setNotice(error.message); }

  }

  if (error) return <div className="loading"><AlertCircle /><h1>Couldn’t read the library</h1><p>{error.message}</p><button onClick={() => client.invalidateQueries()}>Retry</button></div>;

  if (!data) return <div className="loading"><Boxes size={40} /><h1>Discovering your graphics…</h1><p>Reading shipped assets, models and installed prototypes.</p></div>;

  const groups = new Map(data.groups.map(g => [g.id, g]));

  const tokens = search.toLowerCase().trim().split(/\s+/).filter(Boolean);

  const filtered = data.entries.filter(e => {

    const text = `${e.name} ${e.source} ${e.kind} ${e.files.join(' ')} ${groups.get(e.group).title}`.toLowerCase();

    return tokens.every(t => text.includes(t)) && (stage === 'all' || groups.get(e.group).status === stage) && (kind === 'all' || e.kind === kind) && (selectedGroup === 'all' || e.group === selectedGroup);

  });

  const done = data.entries.filter(e => groups.get(e.group).status === 'done').length, entities = data.entries.filter(e => e.kind === 'Entity').length;

  const settings = { working, paused, footprint }, selectedEntry = data.entries.find(e => e.id === selected?.id) ?? selected;

  return <div className={`app-shell ${showLibrary?'':'review-focus'}`}>

    <aside className="sidebar"><a className="brand" href="/" aria-label="Chiptorio Asset Studio"><div className="brand-icon"><Boxes size={24} /></div><div>CHIPTORIO<span>Asset Studio</span></div></a>

      <div className="sidebar-label">LIBRARY</div>

      {[['all', 'All graphics', ImageIcon], ['done', 'Completed Blender', Check], ['future', 'Render queue', Clock3], ['reference', 'Legacy & reference', Layers3]].map(([id, label, Icon]) => <button key={id} className={`nav-item ${stage === id ? 'active' : ''}`} onClick={() => { setStage(id); setSelectedGroup('all'); }}><Icon size={17} />{label}<span>{id === 'all' ? data.entries.length : data.entries.filter(e => groups.get(e.group).status === id).length}</span></button>)}

      <div className="sidebar-label batch-label">PRODUCTION ORDER <span>{data.groups.length}</span></div>

      <nav className="batch-nav">{data.groups.filter(g => data.entries.some(e => e.group === g.id)).map(g => <button key={g.id} className={`batch-link ${selectedGroup === g.id ? 'selected' : ''}`} title={g.title} onClick={() => { setSelectedGroup(g.id); setStage('all'); }}><span className={`dot ${g.status}`} />{g.title}<ChevronRight size={12} /></button>)}</nav>

      <div className="tool-status"><div className="sidebar-label">AUTO-DETECTED TOOLS</div><p title={data.tools.factorio ?? 'Set FACTORIO_EXE'}><span className={`dot ${data.tools.factorio ? 'done' : 'future'}`} />Factorio <span>{data.tools.factorio ? 'Ready' : 'Not found'}</span></p><p title={data.tools.blender ?? 'Set BLENDER_EXE'}><span className={`dot ${data.tools.blender ? 'done' : 'future'}`} />Blender <span>{data.tools.blender ? 'Ready' : 'Not found'}</span></p><p><Cpu size={12} />Node.js <span>{data.tools.node}</span></p></div>

    </aside>

    <main><div className="topbar"><span>Workspace <ChevronRight size={13} /> Graphics atlas</span><div><span className="live-dot" />Auto-scan every 15s<button className="icon-button" title="View tool jobs" onClick={() => setConsoleOpen(!consoleOpen)}><Terminal size={18} />{jobs.some(j => j.status === 'running') && <i />}</button></div></div>

      <header><div className="eyebrow">ART DIRECTION / PRODUCTION OVERVIEW</div><div className="heading"><div><h1>Your factory, pixel by pixel.</h1><p>One library. Every graphic. A clear path from placeholder to finished machine.</p></div><div className="header-actions"><button onClick={scan} disabled={isFetching}><ScanLine size={16} /> Rescan</button><a className="primary button" href="/api/export" download><Download size={16} /> Export single HTML</a></div></div>

        <div className="stats"><div><span className="stat-icon green"><Box /></span><div><strong>{done}<small> / {entities || '—'}</small></strong><label>Blender entities installed</label></div></div><div><span className="stat-icon blue"><ImageIcon /></span><div><strong>{data.ownedFiles.length}</strong><label>Shipped image files</label></div></div><div><span className="stat-icon gold"><Clock3 /></span><div><strong>{data.groups.filter(g => g.status === 'future').length}</strong><label>Proposed future batches</label></div></div><div><span className="stat-icon lavender"><Layers3 /></span><div><strong>{data.entries.length}</strong><label>Graphics & reference entries</label></div></div></div>

      </header>

      {!data.hasPrototypes && <div className="banner"><AlertCircle size={18} /><div>Prototype discovery needed. All files are visible, but inherited machine previews need Factorio.</div><button disabled={busy || !data.tools.factorio} onClick={() => action('/api/refresh')}>Read prototypes</button></div>}

      {data.warnings.map(w => <div className="banner" key={w}>{w}</div>)}

      {!showLibrary&&<h1 className="review-heading">Asset review</h1>}
      <PipelinePanel catalog={data} busy={busy} action={action}/>

      <button onClick={()=>setShowLibrary(!showLibrary)}>{showLibrary?'Hide asset library':'Browse installed assets and references'}</button>

      {showLibrary&&<><div className="filters"><div className="search"><Search size={18} /><input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search names, paths, batches…" aria-label="Search all assets" />{search && <button className="icon-button" onClick={() => setSearch('')} aria-label="Clear search"><X size={14} /></button>}</div><select value={kind} onChange={e => setKind(e.target.value)} aria-label="Graphic type"><option value="all">All types</option>{[...new Set(data.entries.map(e => e.kind))].map(k => <option key={k}>{k}</option>)}</select><div className="segmented"><button className={working ? 'on' : ''} onClick={() => setWorking(true)}>Working</button><button className={!working ? 'on' : ''} onClick={() => setWorking(false)}>Idle</button></div><button className="icon-button" aria-label={paused ? 'Resume animations' : 'Pause animations'} title={paused ? 'Resume' : 'Pause'} onClick={() => setPaused(!paused)}>{paused ? <Play size={17} /> : <Pause size={17} />}</button><button className={`icon-button ${footprint ? 'on' : ''}`} title="Show selection footprints" aria-pressed={footprint} onClick={() => setFootprint(!footprint)}><Grid2X2 size={17} /></button></div>

      <div className="results"><span>{filtered.length} graphics {search && `matching “${search}”`}</span><div>{selectedGroup !== 'all' && <button onClick={() => setSelectedGroup('all')}>Clear batch <X size={12} /></button>}<button disabled={busy || !data.tools.factorio} title="Read current prototypes in isolated headless Factorio; no player save is loaded" onClick={() => action('/api/refresh')}><RefreshCw size={12} /> Refresh prototypes</button></div></div>

      {data.groups.map(g => { const entries = filtered.filter(e => e.group === g.id); return entries.length ? <section key={g.id} className="batch-section"><div className="section-title"><span className={`dot ${g.status}`} /><h2>{g.title}</h2><span className="count">{entries.length}</span><span className={`stage-badge ${g.status}`}>{g.status === 'done' ? 'INSTALLED' : g.status === 'future' ? 'PROPOSED' : 'REFERENCE'}</span></div><p className="section-note">{g.note}</p><div className="asset-grid">{entries.map(entry => <AssetCard key={entry.id} entry={entry} group={g} images={data.images} settings={settings} select={setSelected} action={action} busy={busy} tools={data.tools} />)}</div></section> : null; })}

      {!filtered.length && <div className="empty"><Search size={32} /><h2>No graphics found</h2><p>Try another name, or clear a batch or type filter.</p><button onClick={() => { setSearch(''); setSelectedGroup('all'); setStage('all'); setKind('all'); }}>Reset filters</button></div>}

      </>}

      <footer>CHIPTORIO {data.version} <span>·</span> Live filesystem inventory <span>·</span> Previews show art cycles, not gameplay simulation.<br />Every PNG in graphics/ and thumbnail.png is accounted for, including legacy files. Unchanged vanilla terrain and native UI styles are provided by Factorio.</footer>

    </main>

    {notice && <div className="toast" role="status">{notice}<button aria-label="Dismiss notification" onClick={() => setNotice('')}><X size={15} /></button></div>}

    {consoleOpen && <aside className="job-panel"><div className="panel-title"><Terminal size={17} /><h2>Tool activity</h2><button className="icon-button" aria-label="Close activity" onClick={() => setConsoleOpen(false)}><X size={18} /></button></div><p>Preview renders never rebuild models or overwrite installed graphics.</p>{jobs.length === 0 && <p>No tool jobs yet.</p>}{jobs.map(job => <details key={job.id} open={job.status === 'running'}><summary><span className={`dot ${job.status === 'complete' ? 'done' : 'future'}`} />{job.label}<span>{job.status}</span></summary>{job.preview && <a href={job.preview} target="_blank" rel="noreferrer"><img src={job.preview} alt={job.label} /></a>}<pre>{job.log || 'Starting…'}</pre></details>)}</aside>}

    {selectedEntry && <dialog id="asset-detail" onClose={() => setSelected(null)} onClick={e => { if (e.target === e.currentTarget) e.currentTarget.close(); }}><div className="panel-title"><span className="eyebrow">ASSET INSPECTOR</span><button className="icon-button" aria-label="Close inspector" onClick={() => document.querySelector('#asset-detail').close()}><X size={20} /></button></div><h2>{selectedEntry.name}</h2><p>{selectedEntry.kind} / {selectedEntry.source}</p><Preview entry={selectedEntry} images={data.images} {...settings} large /><div className="inspector-info"><span>{selectedEntry.prototype ?? selectedEntry.kind}</span>{selectedEntry.model && <code>{selectedEntry.model}</code>}</div><h3>Source images <span>{selectedEntry.files.length}</span></h3><div className="source-grid">{selectedEntry.files.map(key => <a key={key} href={data.images[key].src} target="_blank" rel="noreferrer"><img loading="lazy" src={data.images[key].src} alt={key} /><code>{key}</code><small>{data.images[key].width} × {data.images[key].height} px <ExternalLink size={12} /></small></a>)}</div>{selectedEntry.model && <div className="inspector-actions"><button disabled={!data.tools.blender} onClick={() => action('/api/model/open', { id: selectedEntry.id })}><ExternalLink size={15} /> Open in Blender</button><button className="primary" disabled={busy || !data.tools.blender} onClick={() => action('/api/model/preview', { id: selectedEntry.id })}><Play size={15} /> Render game-view preview</button></div>}<p className="muted">Single fixed game camera. Current installed sprites above; preview renders are separate and never installed automatically.</p></dialog>}

  </div>;

}

const client = new QueryClient({ defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: true } } });

createRoot(document.getElementById('root')).render(<QueryClientProvider client={client}><App /></QueryClientProvider>);

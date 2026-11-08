import express from 'express';
import { createServer } from 'vite';
import path from 'node:path';
import { mkdir } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { directory, root, cache, detectTools, exists, startJob, jobs, refreshPrototypes, getCatalog, exportCatalog, runProcess } from './host.mjs';
import { offlineHTML } from './catalog.mjs';
import { template } from './host.mjs';
import { loadRegistry, digest, safePath, workspacePath } from './registry.mjs';
import { selectAssets } from './registry.mjs';
import { ProductionPipeline } from './publish.mjs';
import { ModelReview } from './model-review.mjs';
import {diagnoseModel,diagnosticFolder} from './diagnostics.mjs';
import {approvedLibrary} from './library.mjs';
import { buildAsset } from './build.mjs';
import { changeAsset, scaffold } from './planning.mjs';

const port = Number(process.env.PORT ?? 4173);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('PORT must be 1024..65535');
const app = express();
app.disable('x-powered-by');
// Local actions are same-origin JSON only. Never expose a shell or arbitrary path API.
app.use('/api', (req, res, next) => {
  const allowed = [`127.0.0.1:${port}`, `localhost:${port}`];
  if (!allowed.includes(req.headers.host)) return res.status(403).json({ error: 'Local host only' });
  if (req.headers.origin && !allowed.some(h => req.headers.origin === `http://${h}`)) return res.status(403).json({ error: 'Cross-origin access denied' });
  if (req.method !== 'GET' && !req.is('application/json')) return res.status(415).json({ error: 'JSON required' });
  next();
});
app.use(express.json({ limit: '64kb' }));
const pipeline=new ProductionPipeline(root),models=new ModelReview(root);
app.get('/api/pipeline',async(req,res)=>{
  const registry=await loadRegistry(root);
  res.json({registry,hashes:Object.fromEntries(registry.assets.map(a=>[a.id,digest(a)])),candidates:await pipeline.list(),models:await models.list(),recovery:await exists(path.join(workspacePath(root),'publish.lock'))});
});
app.post('/api/pipeline/asset',async(req,res)=>{if(jobs.some(j=>j.status==='running'))throw new Error('Wait for the active job before editing descriptors');res.json(await changeAsset(root,req.body));current=null;});
app.post('/api/pipeline/scaffold',async(req,res)=>{if(jobs.some(j=>j.status==='running'))throw new Error('Wait for the active job');res.json(await scaffold(root,req.body.id,req.body.expected));current=null;});
app.post('/api/pipeline/build',async(req,res)=>{
  const plan=await loadRegistry(root),selected=selectAssets(plan,req.body);
  const ready=selected.filter(a=>!a.locked&&a.source?.format!=='unconfigured');
  if(!ready.length)throw new Error('No unlocked, configured assets in this selection');
  const job=startJob(`${req.body.draft?'Draft':'Candidate'} / ${req.body.asset??req.body.batch}`,async job=>{
    const results=[],errors=[],revisions=[];
    for(const asset of ready){try{const built=await buildAsset(root,asset,{draft:req.body.draft===true,modelOnly:req.body.modelOnly===true,tools,job});const candidate=req.body.modelOnly?await models.stage(built):await pipeline.stage(built.asset,built.artifacts,built.details);revisions.push(candidate.revision);results.push(`${asset.name} · ${candidate.revision.slice(0,12)}${candidate.cached?' · cached':''}`);}catch(error){errors.push(`${asset.name}: ${error.message}`);}}
    if(!req.body.modelOnly&&!req.body.draft&&!errors.length&&revisions.length>1){const bundle=await pipeline.bundle(revisions);results.push(`Batch candidate · ${bundle.revision}`);}
    job.log=[...results,`Skipped ${selected.length-ready.length} locked/unconfigured assets`,...errors].join('\n');
    if(errors.length)throw new Error(`${errors.length} asset(s) failed; completed candidates were retained`);
  });res.status(202).json({id:job.id});
});
// Revision-bound model access; opening always uses a disposable inspection copy.
async function modelDetails(req){
  return req.query.kind==='model'?(await models.read(req.params.revision)).details:(await pipeline.verify(req.params.revision)).details;
}
app.get('/api/pipeline/model/:revision',async(req,res)=>{
  res.set('Cache-Control','no-store');res.download(await models.model(await modelDetails(req)),'chiptorio-'+req.params.revision.slice(0,12)+'.blend');
});
app.post('/api/pipeline/model/:revision/open',async(req,res)=>{
  if(!tools.blender)throw new Error('Blender not detected');
  const copy=await models.inspectionCopy(await modelDetails(req));
  const child=spawn(tools.blender,[copy],{cwd:root,detached:true,stdio:'ignore',shell:false});
  await new Promise((resolve,reject)=>{child.once('spawn',resolve);child.once('error',reject);});child.unref();res.json({opened:'inspection copy'});
});
app.post('/api/pipeline/model/:revision/still',async(req,res)=>{
  if(!tools.blender)throw new Error('Blender not detected');
  const details=await modelDetails(req),m=req.query.kind==='model'?await models.read(req.params.revision):await pipeline.verify(req.params.revision);
  const copy=await models.inspectionCopy(details);
  const job=startJob('Quick camera still / '+m.asset.name,async job=>{
    const out=path.join(cache,'previews',job.id);await mkdir(out,{recursive:true});
    await runProcess(tools.blender,['-b',copy,'--python-exit-code','1','-P',path.join(root,'tools/graphics/blender/render.py'),'--','--game-view','--samples','16','--resolution',String(m.asset.render.resolution??768),'--no-shadows','--output-dir',out],job);
    job.previewFile=m.asset.name+'_game.png';if(!await exists(path.join(out,job.previewFile)))throw new Error('No camera preview produced');
    job.preview='/api/preview/'+job.id;
  });res.status(202).json({id:job.id});
});
app.post('/api/pipeline/model/:revision/review',async(req,res)=>res.json(await models.review(req.params.revision,req.body.decision,req.body.comment??'')));
app.get('/api/pipeline/model/:revision/diagnostics',async(req,res)=>{
  const folder=await diagnosticFolder(root,req.params.revision);
  if(!await exists(path.join(folder,'report.json')))return res.json({available:false});
  const {readFile}=await import('node:fs/promises');
  const report=JSON.parse(await readFile(path.join(folder,'report.json'),'utf8'));
  res.json({available:true,contacts:report.contacts.length,note:report.note,render_device:report.render_device,timings:report.timings,
    images:['game','front','left','right','rear','top','detail'].map(view=>({view,url:`/api/pipeline/model/${req.params.revision}/diagnostic/${view}-sheet.png`}))});
});
app.get('/api/pipeline/model/:revision/diagnostic/:file',async(req,res)=>{
  if(!/^(game|front|left|right|rear|top|detail)-sheet\.png$/.test(req.params.file)&&req.params.file!=='report.json')return res.status(404).end();
  res.set('Cache-Control','no-store');res.sendFile(await safePath(await diagnosticFolder(root,req.params.revision),req.params.file));
});
app.post('/api/pipeline/model/:revision/diagnose',async(req,res)=>{
  const m=await models.read(req.params.revision);await models.current(m);
  const job=startJob('Geometry inspection / '+m.asset.name,async job=>{
    const result=await diagnoseModel(root,m.revision,tools);
    job.log=`Seven-camera pose sheets ready. ${result.contacts} contact pairs for inspection; these include intended joints and supports.`;
  });res.status(202).json({id:job.id});
});
app.post('/api/pipeline/model/:revision/render',async(req,res)=>{
  const m=await models.read(req.params.revision);await models.current(m);
  if(m.review?.decision!=='approved')throw new Error('Review the model before rendering');
  const job=startJob('Render reviewed model',async job=>{
    const built=await buildAsset(root,m.asset,{tools,job});
    if(built.details.buildKey!==m.details.buildKey||built.details.modelHash!==m.details.modelHash)throw new Error('Model changed; review the new model before rendering');
    const c=await pipeline.stage(built.asset,built.artifacts,built.details);await models.rendered(m.revision,c.revision);job.log+=`\nFinal render ready for separate review: ${c.revision}`;
  });res.status(202).json({id:job.id});
});
app.get('/api/pipeline/candidate/:revision',async(req,res)=>res.json(await pipeline.verify(req.params.revision)));
app.get('/api/pipeline/log/:name',async(req,res)=>{
  if(!/^[a-f0-9]{64}-(build|render|validation)\.log$/.test(req.params.name))return res.status(404).end();
  const file=await safePath(workspacePath(root),`logs/${req.params.name}`);if(!await exists(file))return res.status(404).end();res.type('text/plain').sendFile(file);
});
app.post('/api/pipeline/bundle',async(req,res)=>{if(jobs.some(j=>j.status==='running'))throw new Error('Wait for the active job');res.json(await pipeline.bundle(req.body.revisions));});
app.get('/api/pipeline/artifact/:revision',async(req,res)=>{
  const manifest=await pipeline.verify(req.params.revision),file=manifest.files.find(f=>f.artifact===req.query.file);
  if(!file)return res.status(404).end();
  res.set('Cache-Control','no-store');res.sendFile(await safePath(pipeline.folder(req.params.revision),`artifacts/${file.artifact}`));
});
app.post('/api/pipeline/review',async(req,res)=>{if(jobs.some(j=>j.status==='running'))throw new Error('Wait for the active job');res.json(await pipeline.review(req.body.revision,req.body.decision,req.body.comment??''));});
app.post('/api/pipeline/validate',async(req,res)=>{await pipeline.approved(req.body.revision);const job=startJob('Validate approved candidate',job=>pipeline.validate(req.body.revision,tools,job));res.status(202).json({id:job.id});});
app.post('/api/pipeline/publish',async(req,res)=>{
  const job=startJob('Publish approved candidate',async job=>{const result=await pipeline.publish(req.body.revision,{confirm:req.body.confirm});current=null;job.log=`Published exact revision ${result.revision}\nRefreshing installed catalog…`;await refreshPrototypes(tools,job);await exportCatalog(await catalog(true));job.log=`Published ${result.files.length} exact approved files. Catalog and offline export refreshed.`;});
  res.status(202).json({id:job.id});
});
app.post('/api/pipeline/recover',async(req,res)=>{if(req.body.confirm!=='recover')throw new Error('Explicit recovery confirmation required');const job=startJob('Recover interrupted publication',async job=>{job.log=JSON.stringify(await pipeline.recover());current=null;});res.status(202).json({id:job.id});});
let tools = await detectTools(), current, catalogTime = 0, catalogFlight;
async function catalog(force = false) {
  if (catalogFlight) return catalogFlight;
  if (force || !current || Date.now() - catalogTime > 10000) {
    catalogFlight = getCatalog(tools).then(result => { current = result; catalogTime = Date.now(); return result; }).finally(() => { catalogFlight = null; });
    return catalogFlight;
  }
  return current;
}
app.get('/api/catalog', async (req, res) => res.json((await approvedLibrary(root,await catalog(req.query.scan === '1'))).data));
app.get('/api/jobs', (req, res) => res.json(jobs.map(({ promise, ...job }) => job)));
app.get('/api/image', async (req, res) => {
  const file = (await catalog()).registry.get(req.query.key);
  if (!file) return res.status(404).end();
  res.sendFile(file);
});
app.post('/api/refresh', async (req, res) => {
  tools = await detectTools();
  const job = startJob('Refresh installed prototypes', async job => { await refreshPrototypes(tools, job); current = null; });
  res.status(202).json({ id: job.id });
});
app.get('/api/export', async (req, res) => {
  const c = await catalog(true);
  if (!c.data.hasPrototypes) throw new Error('Refresh prototypes first to include inherited machine graphics.');
  res.attachment('chiptorio-asset-overview.html').type('html').send(await offlineHTML(c, template));
});
app.post('/api/export', async (req, res) => {
  const c = await catalog(true);
  if (!c.data.hasPrototypes) throw new Error('Refresh prototypes first.');
  res.json({ path: await exportCatalog(c) });
});
app.post('/api/model/:action', async (req, res) => {
  if (!['open', 'preview'].includes(req.params.action)) return res.status(404).end();
  const entry = (await catalog(true)).data.entries.find(e => e.id === req.body.id && e.kind === 'Entity');
  if (!entry?.model) return res.status(404).json({ error: 'No editable Blender model for this asset' });
  if (!tools.blender) throw new Error('Blender not detected. Set BLENDER_EXE and restart.');
  const model = path.join(root, entry.model);
  if (!await exists(model)) throw new Error('Model no longer exists. Rescan the library.');
  if (req.params.action === 'open') {
    // Only a model discovered by the catalog can be opened. No shell interpolation.
    const child = spawn(tools.blender, [model], { cwd: root, detached: true, stdio: 'ignore', shell: false });
    await new Promise((resolve, reject) => { child.once('spawn', resolve); child.once('error', reject); });
    child.unref(); return res.json({ opened: entry.name });
  }
  const job = startJob(`Preview / ${entry.name}`, async job => {
    const out = path.join(cache, 'previews', job.id);
    await mkdir(out, { recursive: true });
    // Preview only: one game-applicable camera, low samples, no install or rebuild.
    const resolution=Math.max(512,Math.ceil((Math.max(...entry.footprint)*64+384)/256)*256);
    await runProcess(tools.blender, ['-b', model, '--python-exit-code', '1', '-P', path.join(root, 'tools/graphics/blender/render.py'), '--', '--game-view', '--samples', '16', '--resolution', String(resolution), '--no-shadows', '--output-dir', out], job);
    const filename = `${entry.name}_game.png`;
    if (!await exists(path.join(out, filename))) throw new Error('Render finished without a preview image');
    job.preview = `/api/preview/${job.id}`;
    job.previewFile = filename;
  });
  res.status(202).json({ id: job.id });
});
app.get('/api/preview/:id', async (req, res) => {
  const job = jobs.find(j => j.id === req.params.id && j.status === 'complete' && j.preview);
  if (!job) return res.status(404).end();
  res.sendFile(path.join(cache, 'previews', job.id, job.previewFile));
});
if (process.argv.includes('--production')) app.use(express.static(path.join(directory, 'dist')));
else {
  const vite = await createServer({ root: directory, server: { middlewareMode: true, watch: { ignored: ['**/workspace/**','**/.cache/**','**/dist/**'] } }, appType: 'spa' });
  app.use(vite.middlewares);
}
app.use((error, req, res, next) => { console.error(error.message); res.status(400).json({ error: error.message }); });
app.listen(port, '127.0.0.1', () => console.log(`Chiptorio Asset Studio: http://127.0.0.1:${port}`));
// Auto-detection reads prototypes on first use; Blender never runs automatically.
if (tools.factorio && !await exists(path.join(cache, 'prototypes.json'))) startJob('Initial prototype detection', async job => { await refreshPrototypes(tools, job); current = null; });

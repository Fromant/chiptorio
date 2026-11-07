import { ModelReview } from './model-review.mjs';
import { root, detectTools } from './host.mjs';
import { loadRegistry, selectAssets } from './registry.mjs';
import { buildAsset } from './build.mjs';
import { ProductionPipeline } from './publish.mjs';

const [command,...args]=process.argv.slice(2),value=name=>args.find(a=>a.startsWith(`--${name}=`))?.slice(name.length+3);
const pipeline=new ProductionPipeline(root);
try{
  if(command==='status'){
    const plan=await loadRegistry(root),candidates=await pipeline.list();console.log(JSON.stringify({assets:plan.assets.length,batches:plan.groups.length,configured:plan.assets.filter(a=>a.source.format!=='unconfigured').length,candidates:candidates.length,drafts:candidates.filter(c=>c.draft).length,approved:candidates.filter(c=>c.review?.decision==='approved').length,published:candidates.filter(c=>c.publication).length,...(args.includes('--json')?{details:candidates}:{})},null,2));
  }else if(command==='build'){
    const selected=selectAssets(await loadRegistry(root),{asset:value('asset'),batch:value('batch')}),tools=await detectTools(),revisions=[];let failures=0;
    for(const asset of selected){
      if(asset.locked||asset.source.format==='unconfigured'){console.log(`${asset.name} · skipped (${asset.locked?'locked':'unconfigured'})`);continue;}
      const job={log:''};try{const built=await buildAsset(root,asset,{draft:args.includes('--draft'),modelOnly:args.includes('--model-only'),tools,job});const result=args.includes('--model-only')?await new ModelReview(root).stage(built):await pipeline.stage(built.asset,built.artifacts,built.details);revisions.push(result.revision);console.log(`${asset.name} · ${result.revision} · ${result.cached?'cached':'ready'}\n${job.log}\nReview: http://127.0.0.1:4173/?${args.includes('--model-only')?'model':'review'}=${result.revision}`);}catch(error){failures++;console.error(`${asset.name} · FAIL\n${error.message}`);}
    }
    if(failures)process.exitCode=1;
    else if(!args.includes('--model-only')&&!args.includes('--draft')&&revisions.length>1){const bundle=await pipeline.bundle(revisions);console.log(`Batch candidate · ${bundle.revision}\nReview: http://127.0.0.1:4173/?review=${bundle.revision}`);}
  }else if(command==='validate')console.log(JSON.stringify(await pipeline.validate(value('revision'),await detectTools())));
  else if(command==='publish')console.log(JSON.stringify(await pipeline.publish(value('revision'),{confirm:value('confirm')})));
  else throw new Error('Usage: npm run pipeline -- status | build --asset=<id> / --batch=<id> [--draft] | validate --revision=<hash> | publish --revision=<hash> --confirm=<same hash>. Visual approval is recorded only through Asset Studio.');
}catch(error){console.error(error.message);process.exitCode=1;}

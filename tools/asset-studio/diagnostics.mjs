import path from 'node:path';
import {readFile,mkdir} from 'node:fs/promises';
import sharp from 'sharp';
import {ModelReview} from './model-review.mjs';
import {workspacePath,digest,hashFile,atomicJSON,exists} from './registry.mjs';
import {processLog} from './process.mjs';

export async function diagnosticFolder(root,revision){
  const models=new ModelReview(root),m=await models.read(revision);
  await models.current(m);
  const key=digest({revision,worker:await hashFile(path.join(root,'tools/asset-studio/diagnostic-worker.py')),size:384});
  return path.join(workspacePath(root),'diagnostics',key);
}

export async function diagnoseModel(root,revision,tools){
  const models=new ModelReview(root),m=await models.read(revision);
  await models.current(m);
  if(!tools.blender)throw new Error('Blender not detected');
  const worker=path.join(root,'tools/asset-studio/diagnostic-worker.py');
  const folder=await diagnosticFolder(root,revision);
  await mkdir(folder,{recursive:true});
  const reportFile=path.join(folder,'report.json');
  if(!await exists(reportFile)){
    const model=await models.inspectionCopy(m.details),config=path.join(folder,'config.json');
    await atomicJSON(config,{model,output:folder,size:384});
    await processLog(tools.blender,['-b','--python-exit-code','1','-P',worker,'--',config],{cwd:root,log:path.join(folder,'diagnostic.log')});
  }
  const report=JSON.parse(await readFile(reportFile,'utf8')),sheets=[];
  for(const view of [...new Set(report.images.map(i=>i.view))]){
    const frames=report.images.filter(i=>i.view===view),columns=4,width=384,height=410;
    const layers=[];
    for(const [i,frame] of frames.entries()){
      const x=i%columns*width,y=Math.floor(i/columns)*height;
      layers.push({input:path.join(folder,frame.file),left:x,top:y+26});
      const label=Buffer.from(`<svg width="384" height="26"><rect width="384" height="26" fill="#182126"/><text x="10" y="18" fill="white" font-family="sans-serif" font-size="14">${report.name} / ${view} / phase ${frame.phase}</text></svg>`);
      layers.push({input:label,left:x,top:y});
    }
    const output=path.join(folder,view+'-sheet.png');
    await sharp({create:{width:columns*width,height:Math.ceil(frames.length/columns)*height,channels:4,background:'#182126'}}).composite(layers).png().toFile(output);
    sheets.push(output);
  }
  return {revision,folder,report:reportFile,sheets,contacts:report.contacts.length};
}

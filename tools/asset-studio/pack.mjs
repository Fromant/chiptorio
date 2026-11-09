import path from 'node:path';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import sharp from 'sharp';
import { digest } from './registry.mjs';

const union=(a,b)=>!a?b:{left:Math.min(a.left,b.left),top:Math.min(a.top,b.top),right:Math.max(a.right,b.right),bottom:Math.max(a.bottom,b.bottom)};
async function alpha(file,size,shadow=false) {
  const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  if(info.width!==size||info.height!==size)throw new Error('Render dimensions mismatch');
  let left=size,top=size,right=0,bottom=0,mass=0,xsum=0;
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){const a=data[(y*size+x)*4+3];if(a>(shadow?32:8)){left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x+1);bottom=Math.max(bottom,y+1);mass+=a;xsum+=x*a;}}
  if(!mass)throw new Error(`Empty sprite: ${path.basename(file)}`);
  if(left<2||top<2||right>size-2||bottom>size-2)throw new Error(`Clipped sprite: ${path.basename(file)}; increase render.resolution, never shrink the physical machine`);
  return {left,top,right,bottom,centroid:xsum/mass};
}
export async function pack(asset,renderFolder,output) {
  await mkdir(output,{recursive:true});
  const work=JSON.parse(await readFile(path.join(renderFolder,'working/render-manifest.json'),'utf8'));
  if(asset.profile!=='entity'){
    const first=Object.values(work.directions)[0];
    let image=sharp(path.join(renderFolder,'working',first.files[0]));
    if(asset.render.fit!=='canvas')image=image.trim();
    const bytes=await image.resize(asset.render.width,asset.render.height,{fit:'contain',background:'#00000000'}).png().toBuffer();
    await writeFile(path.join(output,'image.png'),bytes);
    return {image:'image.png',width:asset.render.width,height:asset.render.height,frames:1,checks:['image dimensions','transparent canvas']};
  }
  const idle=JSON.parse(await readFile(path.join(renderFolder,'idle/render-manifest.json'),'utf8'));
  if(work.entity!==asset.name||idle.entity!==asset.name||idle.frames!==1)throw new Error('Mismatched render identity');
  for(const key of ['origin_px','footprint'])if(JSON.stringify(work[key])!==JSON.stringify(idle[key]))throw new Error(`Working/idle ${key} mismatch`);
  if(JSON.stringify(work.footprint)!==JSON.stringify(asset.render.footprint))throw new Error('Mismatched footprint');
  const legacyDirectional=asset.mode==='existing-directional',directional=legacyDirectional||asset.integration?.directional,views=directional?['north','east','south','west']:['game'];
  let total,body;const sources={};
  for(const view of views){
    const w=work.directions[view],rest=idle.directions[view];
    if(!w||!rest||w.size!==rest.size)throw new Error('Missing render direction');
    const files=w.files.map(f=>path.join(renderFolder,'working',f));
    const still=path.join(renderFolder,'idle',rest.files[0]),shadow=path.join(renderFolder,'idle',`${asset.name}_${view}_shadow.png`);
    for(const file of [...files,still,shadow]){const b=await alpha(file,w.size,file===shadow);total=union(total,b);if(file!==shadow)body=union(body,b);else if(b.centroid<=w.size/2+.5)throw new Error('Shadow must cast screen-right');}
    sources[view]={files,still,shadow};
  }
  const size=work.directions[views[0]].size;
  const origin=work.origin_px??[size/2,size/2+asset.render.cameraTarget*64/Math.sqrt(2)];
  if(!origin.every(Number.isFinite))throw new Error('Directional rendering requires render.cameraTarget');
  const scale=.5;
  if((body.right-body.left)*scale>Math.max(...asset.render.footprint)*32+3)throw new Error('Body exceeds occupied width');
  const crop={left:total.left-2,top:total.top-2,width:total.right-total.left+4,height:total.bottom-total.top+4};
  const width=crop.width,height=crop.height,frames=work.frames;
  const columns=Math.min(frames,Math.max(1,Math.min(8,Math.floor(8192/width))));
  if(height*Math.ceil(frames/columns)>8192)throw new Error('Atlas exceeds texture bounds');
  const shift=[(crop.left+width/2-origin[0])*scale/32,(crop.top+height/2-origin[1])*scale/32];
  const viewMeta={};
  for(const view of views){
    const source=sources[view],prefix=directional?`${view}/`:'';await mkdir(path.join(output,prefix),{recursive:true});
    const hashes=new Set();
    const tiles=await Promise.all(source.files.map(async(file,i)=>{const input=await sharp(file).extract(crop).png().toBuffer();hashes.add(digest(input));return {input,left:i%columns*width,top:Math.floor(i/columns)*height};}));
    if(frames>1&&hashes.size<2)throw new Error('Working animation is frozen');
    await sharp({create:{width:width*columns,height:height*Math.ceil(frames/columns),channels:4,background:'#00000000'}}).composite(tiles).png().toFile(path.join(output,prefix+'working.png'));
    await sharp(source.still).extract(crop).png().toFile(path.join(output,prefix+'idle.png'));
    await sharp(source.shadow).extract(crop).png().toFile(path.join(output,prefix+'shadow.png'));
    viewMeta[view]={working:prefix+'working.png',idle:prefix+'idle.png',shadow:prefix+'shadow.png'};
  }
  const sprite=(file,animated=false,shadow=false)=>`{filename=${JSON.stringify('__chiptorio__/'+file)}, width=${width}, height=${height}, scale=0.5, shift={${shift}}, frame_count=${animated?frames:1}${animated?`, line_length=${columns}, animation_speed=${work.animation_speed}`:''}${shadow?', draw_as_shadow=true':''}}`;
  let lua;
  if(legacyDirectional){
    lua=`return {\n${views.map(view=>`${view}={layers={${sprite(asset.targets.find(t=>t.artifact===view+'/working.png').path,true)},${sprite(asset.targets.find(t=>t.artifact===view+'/shadow.png').path,false,true).replace('frame_count=1',`repeat_count=${frames}`)}}}`).join(',\n')}\n}\n`;
  }else if(directional){
    const target=f=>asset.targets.find(t=>t.artifact===f)?.path;
    const state=(working)=>`{${views.map(view=>`${view}={layers={${sprite(target(view+'/'+(working?'working.png':'idle.png')),working).replace(/frame_count=1(?=[,}])/,`frame_count=1, repeat_count=${frames}`)},${sprite(target(view+'/shadow.png'),false,true).replace(/frame_count=1(?=[,}])/,`frame_count=1, repeat_count=${frames}`)}}}`).join(',')}}`;
    lua=`return {footprint={${asset.render.footprint}}, on_animation=${state(true)}, off_animation=${state(false)}}\n`;
  }else{
    const target=f=>asset.targets.find(t=>t.artifact===f)?.path;
    for(const f of ['working.png','idle.png','shadow.png','sprite-def.lua'])if(!target(f))throw new Error(`Missing entity target ${f}`);
    const common=`width=${width}, height=${height}, scale=0.5, shift={${shift}}`;
    lua=`return {footprint={${asset.render.footprint}}, on_animation={layers={${sprite(target('working.png'),true)},{filename=${JSON.stringify('__chiptorio__/'+target('shadow.png'))}, ${common}, repeat_count=${frames}, draw_as_shadow=true}}}, off_animation={layers={${sprite(target('idle.png'))},${sprite(target('shadow.png'),false,true)}}}}\n`;
  }
  await writeFile(path.join(output,'sprite-def.lua'),'-- Generated by Asset Studio; exact reviewed artifact.\n'+lua);
  const meta={width,height,frames,columns,shift,scale,fps:work.fps,footprint:asset.render.footprint,views:viewMeta,checks:['alpha / clipping','fixed origin','shadow direction','occupied width','animation changes','atlas limits']};
  await writeFile(path.join(output,'preview.json'),JSON.stringify(meta,null,2));
  const reviewFrames=[...new Set([0,Math.floor(frames/4),Math.floor(frames/2),Math.floor(frames*3/4)])];
  const sheet=path.join(output,viewMeta[views[0]].working),thumbs=[];
  for(let i=0;i<reviewFrames.length;i++){const f=reviewFrames[i];thumbs.push({input:await sharp(sheet).extract({left:f%columns*width,top:Math.floor(f/columns)*height,width,height}).resize(256,256,{fit:'contain',background:'#182124'}).png().toBuffer(),left:i*256,top:0});}
  await sharp({create:{width:256*thumbs.length,height:256,channels:4,background:'#182124'}}).composite(thumbs).png().toFile(path.join(output,'contact.png'));
  return meta;
}

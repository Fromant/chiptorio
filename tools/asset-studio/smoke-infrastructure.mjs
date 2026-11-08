/** Exercise future infrastructure bindings only in a disposable mod copy. */
import path from 'node:path';
import os from 'node:os';
import {mkdtemp,mkdir,writeFile,readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {root,detectTools} from './host.mjs';
import {copySnapshot,contextHash} from './publish.mjs';
import {loadRegistry} from './registry.mjs';
import {bindingArtifact} from './integration.mjs';
import {processLog} from './process.mjs';

const baseline=await contextHash(root),folder=await mkdtemp(path.join(os.tmpdir(),'chiptorio-infrastructure-'));
const mods=path.join(folder,'mods'),fixture=path.join(mods,'chiptorio'),probe=path.join(mods,'infrastructure-probe');
await copySnapshot(root,fixture);await mkdir(probe,{recursive:true});
const assets=(await loadRegistry(root)).assets.filter(a=>a.group==='batch-7'&&a.name!=='quantum-fab');
// Small synthetic texture fixtures test prototype/runtime wiring, not visual approval.
for(const a of assets){
  const dir=path.join(fixture,'graphics/entity',a.name);await mkdir(dir,{recursive:true});
  await sharp({create:{width:24,height:1,channels:4,background:'#6080a0'}}).png().toFile(path.join(dir,'fixture.png'));
  const image=`__chiptorio__/graphics/entity/${a.name}/fixture.png`;
  const layer=(work)=>`{filename=${JSON.stringify(image)},width=1,height=1,scale=0.5,frame_count=${work?24:1}${work?',line_length=24,animation_speed=0.2':',repeat_count=24'}}`;
  const animation=work=>`{layers={${layer(work)}}}`;
  const state=work=>a.integration?.directional?`{${['north','east','south','west'].map(v=>v+'='+animation(work)).join(',')}}`:animation(work);
  await writeFile(path.join(dir,'sprite-def.lua'),`return {footprint={${a.render.footprint}},on_animation=${state(true)},off_animation=${state(false)}}\n`);
}
const binding=await bindingArtifact(fixture,assets);await writeFile(path.join(fixture,binding.path),binding.bytes);
await writeFile(path.join(probe,'info.json'),JSON.stringify({name:'infrastructure-probe',version:'0.1.0',title:'Disposable infrastructure test',author:'Chiptorio test fixture',factorio_version:'2.1',dependencies:['base','chiptorio']}));
await writeFile(path.join(mods,'mod-list.json'),JSON.stringify({mods:[{name:'base',enabled:true},{name:'chiptorio',enabled:true},{name:'infrastructure-probe',enabled:true}]}));
await writeFile(path.join(probe,'data-updates.lua'),`
local cooler=data.raw['assembling-machine']['cooling-tower']
for _,flag in ipairs(cooler.flags or {}) do assert(flag~='not-rotatable','Cooling must rotate') end
for _,direction in ipairs({'north','east','south','west'}) do
  assert(cooler.graphics_set.animation[direction].layers[1].frame_count==24)
  assert(cooler.graphics_set.idle_animation[direction].layers[1].repeat_count==24)
end
for _,box in ipairs(cooler.fluid_boxes) do
  local picture=box.pipe_picture.north
  assert((picture.filename or picture.layers[1].filename):find('__base__',1,true),'Must use native connector sprites')
  assert(box.pipe_covers.north.layers[1].filename:find('__base__',1,true))
end
for _,name in ipairs({'network-switch','network-router','memory-bank'}) do
  assert(data.raw.animation['chiptorio-device-'..name].frame_count==24)
end
data:extend({{type='recipe',name='infrastructure-port-test',categories={'chiptorio-cooling'},main_product='coolant',ingredients={{type='fluid',name='water',amount=1},{type='fluid',name='steam',amount=1}},results={{type='fluid',name='coolant',amount=1},{type='fluid',name='cryogen',amount=1}}}})
log('INFRASTRUCTURE DATA PASS')
`);
await writeFile(path.join(probe,'control.lua'),`
local function active(entity)
  for _,r in ipairs(remote.call('chiptorio-art','status')) do if r.unit_number==entity.unit_number then return true end end
  return false
end
script.on_init(function()
  local s=game.surfaces[1];s.request_to_generate_chunks({0,0},4);s.force_generate_chunk_requests()
  for _,e in ipairs(s.find_entities_filtered({area={{-5,-10},{110,10}}})) do if e.type~='character' then e.destroy() end end
  local function place(name,x,y,direction)
    local e=assert(s.create_entity{name=name,position={x,y},force='player',direction=direction})
    script.raise_event(defines.events.script_raised_built,{entity=e});return e
  end
  local switch=place('network-switch',.5,.5);local router=place('network-router',8.5,.5);local memory=place('memory-bank',15.5,.5)
  for _,range in ipairs({{2,6},{10,12}}) do for x=range[1],range[2] do place('network-cable',x+.5,.5) end end
  remote.call('chiptorio-network','tick')
  assert(active(switch) and active(router),'Connected switch/router must indicate a link')
  assert(not active(memory),'Empty memory must stay idle')
  memory.insert{name='sram-module',count=1};remote.call('chiptorio-network','tick')
  assert(active(memory),'Connected populated memory must light')
  memory.get_inventory(defines.inventory.chest).clear();remote.call('chiptorio-network','tick')
  assert(not active(memory),'Removing memory must stop its heartbeat')
  memory.insert{name='sram-module',count=1};memory.teleport({100.5,.5})
  script.raise_event(defines.events.script_raised_built,{entity=memory});remote.call('chiptorio-network','tick')
  assert(not active(memory),'Disconnected populated memory must stay idle')
  for _,direction in ipairs({defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}) do
    local cooler=place('cooling-tower',40.5,.5,direction);local pipes={}
    -- Recipe unlocks the native fluid boxes on an otherwise idle machine.
    cooler.set_recipe('infrastructure-port-test')
    for box=1,4 do
      local connections=cooler.get_fluid_box_pipe_connections(box)
      assert(connections and #connections==1,'Missing cooler fluid connection '..box)
      local p=connections[1].target_position;pipes[#pipes+1]=place('pipe',p.x,p.y)
      local connected=cooler.get_fluid_box_pipe_connections(box)[1]
      assert(connected.target and connected.target.name=='pipe','Native pipe failed to connect after rotation')
    end
    for _,pipe in ipairs(pipes) do pipe.destroy() end;cooler.destroy()
  end
  log('INFRASTRUCTURE RUNTIME PASS: link/capacity signals and 16 rotated fluid connections')
end)
`);
const tools=await detectTools(),config=path.join(folder,'config.ini');
await writeFile(config,`[path]\nread-data=${tools.dataRoot.replaceAll('\\','/')}\nwrite-data=${folder.replaceAll('\\','/')}\n`);
const log=path.join(folder,'test.log');
await processLog(tools.factorio,['--config',config,'--mod-directory',mods,'--create',path.join(folder,'fixture.zip')],{cwd:folder,log});
const result=await readFile(log,'utf8');assert.match(result,/INFRASTRUCTURE DATA PASS/);assert.match(result,/INFRASTRUCTURE RUNTIME PASS/);
assert.equal(await contextHash(root),baseline,'Production context changed during isolated check');
console.log(`Infrastructure bindings PASS: native four-direction sprites, base pipe connectors, link/capacity signals, 16 rotated pipe connections.\nProduction unchanged. Fixture: ${folder}`);

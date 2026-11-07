/** Exercise real six-suite validation and publication only in a disposable mod copy. */
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { root, detectTools } from './host.mjs';
import { loadRegistry, atomicJSON, registryPath, digest, hashFile } from './registry.mjs';
import { ProductionPipeline, copySnapshot } from './publish.mjs';
import { bindingArtifact } from './integration.mjs';
import { walk } from './catalog.mjs';

const baseline={};for(const file of await walk(path.join(root,'graphics')))baseline[file]=await hashFile(file);
const fixture=path.join(process.env.LOCALAPPDATA?path.join(process.env.LOCALAPPDATA,'Temp/opencode'):path.join(root,'tools/asset-studio/workspace'),`cv-${randomUUID().slice(0,8)}`);
await copySnapshot(root,fixture);
const plan=await loadRegistry(root),asset=structuredClone(plan.assets.find(a=>a.id==='entity:network-monitor'));asset.locked=false;
await atomicJSON(registryPath(fixture),{version:1,groups:plan.groups,assets:[asset]});
const artifacts={};for(const target of asset.targets)artifacts[target.artifact]=await readFile(path.join(fixture,target.path));
const binding=await bindingArtifact(fixture,asset);artifacts[binding.artifact]=binding.bytes;
const staged={...asset,targets:[...asset.targets,{artifact:binding.artifact,path:binding.path}]};
const pipeline=new ProductionPipeline(fixture),candidate=await pipeline.stage(staged,artifacts,{fixture:true});
await pipeline.review(candidate.revision,'approved','Automated disposable-fixture test of already installed bytes; not production approval.');
const job={log:''};await pipeline.validate(candidate.revision,await detectTools(),job);
await pipeline.publish(candidate.revision,{confirm:candidate.revision});
for(const file of staged.targets)assert.equal(await hashFile(path.join(fixture,file.path)),digest(artifacts[file.artifact]));
assert.equal((await loadRegistry(fixture)).assets[0].locked,true);
for(const [file,hash] of Object.entries(baseline))assert.equal(await hashFile(file),hash,`Production file changed: ${file}`);
console.log(`Isolated six-suite validation + exact-artifact publication PASS\nProduction graphics unchanged · fixture: ${fixture}`);

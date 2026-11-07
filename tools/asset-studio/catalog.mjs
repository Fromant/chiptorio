import { readdir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { loadRegistry, registryPath, exists } from './registry.mjs';

export const completed = [
  ['server-rack'],
  ['analytical-engine', 'tube-mainframe', 'mainframe-cluster', 'datacenter-lab', 'cryostat'],
  ['metrology-lab', 'answer-engine', 'qln-storage-drive', 'quantum-entanglement-core', 'construction-core'],
  ['foup-dock', 'wireless-access-point', 'qln-import-node', 'qln-export-node', 'qln-provider-node'],
  ['qln-requester-node'],
  ['qln-terminal', 'training-cluster', 'inference-lab', 'circuit-assembler', 'network-monitor'],
];
export const future = [
  ['wafer-fab', 'crystal-puller', 'assembly-fab', 'computer-assembler', 'vlsi-fab'],
  ['cooling-tower', 'quantum-fab', 'network-switch', 'network-router', 'memory-bank'],
  ['datacenter'],
];
export async function walk(directory) {
  const result = [];
  for (const file of await readdir(directory, { withFileTypes: true }).catch(() => [])) {
    const full = path.join(directory, file.name);
    if (file.isDirectory()) result.push(...await walk(full));
    else if (file.isFile()) result.push(full);
  }
  return result.sort();
}
export function layers(sprite, addImage) {
  if (!sprite) return [];
  if (sprite.layers) return sprite.layers.flatMap(s => layers(s, addImage));
  if (sprite.north) return layers(sprite.north, addImage);
  if (sprite.sheet) return layers(sprite.sheet, addImage);
  if (sprite.sheets) return sprite.sheets.flatMap(s => layers(s, addImage));
  if (!sprite.filename) throw new Error('Unsupported sprite structure');
  const width = sprite.width ?? (Array.isArray(sprite.size) ? sprite.size[0] : sprite.size);
  const height = sprite.height ?? (Array.isArray(sprite.size) ? sprite.size[1] : sprite.size);
  if (!width || !height) throw new Error(`Missing sprite dimensions: ${sprite.filename}`);
  return [{ image: addImage(sprite.filename), width, height, x: sprite.x ?? 0, y: sprite.y ?? 0,
    shift: sprite.shift ?? [0, 0], scale: sprite.scale ?? 1, frames: sprite.frame_count ?? 1,
    columns: sprite.line_length ?? sprite.frame_count ?? 1, fps: 60 * (sprite.animation_speed ?? 1),
    tint: sprite.tint, shadow: sprite.draw_as_shadow === true }];
}
export async function buildCatalog({ root, dataRoot, raw = {} }) {
  const groups = [], entries = [], images = {}, registry = new Map(), covered = new Set();
  const assignment = new Map(), order = new Map();
  const owned = (await walk(path.join(root, 'graphics'))).filter(f => /\.png$/i.test(f));
  owned.push(path.join(root, 'thumbnail.png'));
  const relative = f => path.relative(root, f).replaceAll('\\', '/');
  const ownedFiles = owned.map(relative);
  function addImage(key) {
    key = key.replace(/^__chiptorio__\//, '');
    if (!registry.has(key)) {
      const match = key.match(/^__(base|core)__\/(.*)$/);
      const file = match ? path.join(dataRoot ?? '', match[1], match[2]) : path.join(root, key);
      registry.set(key, file);
      if (!match) covered.add(key);
      images[key] = { src: `/api/image?key=${encodeURIComponent(key)}` };
    }
    return key;
  }
  function group(id, title, status, note) { groups.push({ id, title, status, note }); }
  completed.forEach((names, i) => {
    group(`done-${i}`, i === 0 ? 'Original / Server Rack' : `Batch ${i} / ${i === 4 ? 'retained' : 'completed'}`, 'done',
      i === 4 ? 'Requester retained from the original fourth batch. Batch 5 contains fresh non-facing replacements for the rejected conversions.' :
      i === 5 ? 'Revision 04: square robotic assembly, GPU training hall, model-serving library and Ethernet-style monitor. The approved 1×1 QLN Terminal is unchanged.' :
      'Installed Blender graphics. One game-view preview; source files include every shipped layer.');
    names.forEach((name, n) => { assignment.set(name, `done-${i}`); order.set(name, n); });
  });
  let batch = 6;
  for (const names of future) {
    const id = `batch-${batch++}`;
    group(id, `Batch ${batch - 1} / world machinery`, 'future', 'Proposed order. Showing current installed graphics, not a finished concept. Preserve actual footprints; model non-facing machinery with functional detail.');
    names.forEach((name, n) => { assignment.set(name, id); order.set(name, n); });
  }
  const warnings = [];
  for (const type of ['container', 'assembling-machine', 'furnace', 'lab', 'accumulator', 'pipe']) {
    for (const [name, p] of Object.entries(raw[type] ?? {})) {
      if (!p.minable?.result || !p.icon?.includes('__chiptorio__/') || p.hidden) continue;
      let off, on;
      if (type === 'lab') { off = p.off_animation; on = p.on_animation; }
      else if (type === 'container') { off = on = p.picture; }
      else if (type === 'accumulator') { off = p.chargable_graphics?.picture; on = p.chargable_graphics?.charge_animation; }
      else if (type === 'pipe') { off = on = p.pictures?.straight_vertical_single; }
      else { off = p.graphics_set?.idle_animation ?? p.graphics_set?.animation; on = p.graphics_set?.animation; }
      if (raw.animation?.[`chiptorio-device-${name}`]) on = { layers: [raw.animation[`chiptorio-device-${name}`], ...(off.layers ?? []).filter(l => l.draw_as_shadow)] };
      if (name === 'server-rack') on = { layers: [raw.animation?.['chiptorio-rack-north'], ...(off.north?.layers ?? []).filter(l => l.draw_as_shadow)].filter(Boolean) };
      let idle = [], working = [];
      try { idle = layers(off, addImage); working = layers(on, addImage); }
      catch (error) { warnings.push(`${name}: ${error.message}`); }
      const files = new Set([...idle, ...working].map(l => l.image));
      for (const file of owned.filter(f => path.dirname(f) === path.join(root, 'graphics/entity', name))) files.add(addImage(relative(file)));
      let groupId = type === 'pipe' ? 'cables' : assignment.get(name);
      if (!groupId) {
        groupId = 'unscheduled';
        if (!groups.some(g => g.id === groupId)) group(groupId, 'Newly detected / needs scheduling', 'future', 'New assets are never silently omitted. Assign these to a batch in catalog.mjs.');
      }
      const box = p.selection_box;
      const footprint = box ? [box[1][0] - box[0][0], box[1][1] - box[0][1]] : undefined;
      entries.push({ id: `entity:${name}`, name, kind: 'Entity', group: groupId, order: order.get(name) ?? 100,
        source: [...files].some(f => f.startsWith('__base__/')) ? 'Inherited Factorio art' : groupId.startsWith('done-') ? 'Blender / installed' : 'Legacy / generated',
        idle, working, files: [...files], footprint, prototype: type });
    }
  }
  const addFile = (file, kind, groupId, source) => {
    const key = addImage(file);
    entries.push({ id: `file:${file}`, name: path.basename(file, '.png'), kind, group: groupId, source, files: [key], image: key, order: entries.length + 1000 });
  };
  function fileBatches(prefix, title, kind) {
    const files = ownedFiles.filter(f => f.startsWith(prefix));
    for (let n = 0; n < files.length; n++) {
      if (n % 5 === 0) group(`batch-${batch}`, `Batch ${batch} / ${title}`, 'future', 'Optional Blender refresh of existing generated artwork. Five individual graphics per batch; the final batch may be smaller.');
      addFile(files[n], kind, `batch-${batch}`, 'Generated / not Blender');
      if (n % 5 === 4 || n === files.length - 1) batch++;
    }
  }
  fileBatches('graphics/icons/', 'item, fluid & interface icons', 'Icon');
  fileBatches('graphics/technology/', 'technology icons', 'Technology');
  group('cables', `Batch ${batch++} / cable system`, 'future', 'Four tiers share sixteen geometry sprites with prototype tints. All shapes are included; tier previews use installed tints.');
  for (const file of ownedFiles.filter(f => f.startsWith('graphics/entity/cable/'))) addFile(file, 'Cable shape', 'cables', 'Shared generated geometry');
  group('misc', `Batch ${batch} / presentation artwork`, 'future', 'Thumbnail and ending artwork. Native Factorio UI controls reuse built-in styles and the item icons above; there are no separate custom UI textures.');
  addFile('thumbnail.png', 'Presentation', 'misc', 'Generated / not Blender');
  addFile('graphics/answer-ending.png', 'Presentation', 'misc', 'Generated / not Blender');
  group('archive', 'Reference / legacy & supporting files', 'reference', 'Superseded flat art and supporting graphics still on disk. Retained deliberately, not claimed to be installed or queued for rendering.');
  for (const file of ownedFiles) if (!covered.has(file)) addFile(file, 'Reference', 'archive', 'Legacy / supporting image');
  for (const [key, file] of registry) {
    const bytes = await readFile(file);
    if (bytes.toString('hex', 0, 8) !== '89504e470d0a1a0a') throw new Error(`Not a PNG: ${file}`);
    images[key].width = bytes.readUInt32BE(16); images[key].height = bytes.readUInt32BE(20);
    images[key].src += `&v=${(await stat(file)).mtimeMs}`;
  }
  // Discover editable files rather than assuming an asset has a Blender model.
  const models = (await walk(path.join(root, 'tools/graphics/blender'))).filter(f => f.endsWith('.blend') && !f.includes(`${path.sep}renders${path.sep}`));
  for (const entry of entries) {
    if (entry.kind !== 'Entity') continue;
    const model = models.find(f => path.basename(f, '.blend') === entry.name);
    if (model) { entry.model = relative(model); entry.modelModified = (await stat(model)).mtime.toISOString(); }
  }
  if(await exists(registryPath(root))){
    const plan=await loadRegistry(root),descriptors=new Map(plan.assets.map(a=>[a.id,a]));
    const legacyGroups=[...groups];groups.splice(0,groups.length,...plan.groups);
    for(const entry of entries){const asset=descriptors.get(entry.id);if(asset){entry.group=asset.group;entry.order=asset.order;entry.pipeline={locked:asset.locked,configured:asset.source?.format!=='unconfigured',profile:asset.profile};}
      else if(entry.kind!=='Reference'&&entry.prototype!=='pipe')entry.group='unscheduled';
      if(!groups.some(g=>g.id===entry.group))groups.push(legacyGroups.find(g=>g.id===entry.group)??{id:entry.group,title:'New / unscheduled',status:'future',note:'Assign new assets explicitly in assets.json; existing batches never renumber.'});}
  }
  entries.sort((a, b) => a.order - b.order);
  const version = JSON.parse(await readFile(path.join(root, 'info.json'), 'utf8')).version;
  return { data: { groups, entries, images, ownedFiles, warnings, generated: new Date().toISOString().slice(0, 10), version }, registry };
}

export async function offlineHTML(catalog, templatePath) {
  const data = structuredClone(catalog.data);
  for (const [key, file] of catalog.registry) data.images[key].src = `data:image/png;base64,${(await readFile(file)).toString('base64')}`;
  const json = JSON.stringify(data).replaceAll('<', '\\u003c').replaceAll('>', '\\u003e').replaceAll('&', '\\u0026');
  return (await readFile(templatePath, 'utf8')).replace('<!--ASSET_DATA-->', json);
}

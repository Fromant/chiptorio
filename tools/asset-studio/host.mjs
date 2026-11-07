import { access, cp, mkdir, readFile, readdir, stat, writeFile } from 'node:fs/promises';
import { constants } from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { buildCatalog, offlineHTML } from './catalog.mjs';

export const directory = path.dirname(fileURLToPath(import.meta.url));
export const root = path.resolve(directory, '../..');
export const cache = path.join(directory, '.cache');
export const template = path.join(root, 'tools/graphics/asset-overview.template.html');
export const exists = f => access(f, constants.F_OK).then(() => true, () => false);

async function findExecutable(name, candidates) {
  const result = spawnSync(process.platform === 'win32' ? 'where.exe' : 'which', [name], { encoding: 'utf8', windowsHide: true });
  candidates.push(...(result.stdout ?? '').trim().split(/\r?\n/).filter(Boolean));
  for (const file of candidates) {
    if (!file) continue;
    if (await stat(file).then(s => s.isFile(), () => false)) return path.resolve(file);
    const inside = path.join(file, 'bin/x64', name);
    if (await stat(inside).then(s => s.isFile(), () => false)) return path.resolve(inside);
  }
  return null;
}
export async function detectTools() {
  const env = await readFile(path.join(root, '.env'), 'utf8').catch(() => '');
  let configured = env.match(/^\s*FACTORIO_EXE\s*=\s*(.*?)\s*$/m)?.[1]?.replace(/^["']|["']$/g, '');
  configured = configured?.replace(/%([^%]+)%/g, (_, key) => process.env[key] ?? `%${key}%`);
  const steamRoots = [process.env['ProgramFiles(x86)'], process.env.ProgramFiles].filter(Boolean).map(p => path.join(p, 'Steam'));
  // Steam may live outside Program Files. Registry discovery is read-only.
  if (process.platform === 'win32') {
    const registry = spawnSync('reg.exe', ['query', 'HKCU\\Software\\Valve\\Steam', '/v', 'SteamPath'], { encoding: 'utf8', windowsHide: true });
    const location = registry.stdout?.match(/SteamPath\s+REG_SZ\s+(.+)/)?.[1]?.trim();
    if (location) steamRoots.unshift(location);
  }
  const libraries = [...steamRoots];
  for (const steam of steamRoots) {
    const vdf = await readFile(path.join(steam, 'steamapps/libraryfolders.vdf'), 'utf8').catch(() => '');
    for (const match of vdf.matchAll(/"path"\s+"([^"]+)"/g)) libraries.push(match[1].replaceAll('\\\\', '\\'));
  }
  const factorio = await findExecutable(process.platform === 'win32' ? 'factorio.exe' : 'factorio', [process.env.FACTORIO_EXE, configured,
    ...libraries.map(p => path.join(p, 'steamapps/common/Factorio/bin/x64', process.platform === 'win32' ? 'factorio.exe' : 'factorio')),
    ...[process.env.ProgramFiles, process.env['ProgramFiles(x86)']].filter(Boolean).map(p => path.join(p, 'Factorio/bin/x64/factorio.exe'))]);
  const blenderCandidates = [process.env.BLENDER_EXE];
  if (process.env.ProgramFiles) {
    const foundation = path.join(process.env.ProgramFiles, 'Blender Foundation');
    for (const dir of (await readdir(foundation).catch(() => [])).sort().reverse()) blenderCandidates.push(path.join(foundation, dir, 'blender.exe'));
  }
  const blender = await findExecutable(process.platform === 'win32' ? 'blender.exe' : 'blender', blenderCandidates);
  return { factorio, blender, node: process.version, dataRoot: factorio ? path.resolve(path.dirname(factorio), '../../data') : null };
}

export const jobs = [];
let active = false;
export function runProcess(executable, args, job) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, { cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], shell: false });
    const log = bytes => { job.log = (job.log + bytes.toString()).slice(-30000); };
    child.stdout.on('data', log); child.stderr.on('data', log);
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve() : reject(new Error(`Process exited with code ${code}`)));
  });
}
export function startJob(label, work) {
  if (active) throw new Error('Another tool job is already running. Wait for it to finish.');
  const job = { id: crypto.randomUUID(), label, status: 'running', log: '', started: new Date().toISOString() };
  jobs.unshift(job); if (jobs.length > 20) jobs.pop(); active = true;
  job.promise = Promise.resolve().then(() => work(job)).then(() => { job.status = 'complete'; }, error => { job.status = 'failed'; job.log += `\n${error.message}`; }).finally(() => { active = false; job.finished = new Date().toISOString(); });
  return job;
}
export async function refreshPrototypes(tools, job) {
  if (!tools.factorio) throw new Error('Factorio not detected. Set FACTORIO_EXE in the environment or repository .env.');
  const work = path.join(process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, 'Temp/opencode') : os.tmpdir(), `chiptorio-assets-${crypto.randomUUID()}`);
  const mods = path.join(work, 'mods');
  await mkdir(mods, { recursive: true });
  await cp(root, path.join(mods, 'chiptorio'), { recursive: true, filter: source => {
    const rel = path.relative(root, source).replaceAll('\\', '/');
    return !['.git', 'tools', 'docs', 'dist', 'aseprite', 'node_modules'].some(d => rel === d || rel.startsWith(d + '/')) && !['.env', 'asset-overview.html'].includes(rel);
  } });
  await writeFile(path.join(mods, 'mod-list.json'), JSON.stringify({ mods: [{ name: 'base', enabled: true }, { name: 'chiptorio', enabled: true }] }));
  const config = path.join(work, 'config.ini');
  await writeFile(config, `[path]\nread-data=${tools.dataRoot.replaceAll('\\', '/')}\nwrite-data=${work.replaceAll('\\', '/')}\n`);
  await runProcess(tools.factorio, ['--config', config, '--mod-directory', mods, '--dump-data'], job);
  const json = await readFile(path.join(work, 'script-output/data-raw-dump.json'), 'utf8');
  JSON.parse(json); // Never replace the last working cache with partial output.
  await mkdir(cache, { recursive: true });
  await writeFile(path.join(cache, 'prototypes.json'), json);
}
export async function getCatalog(tools) {
  const raw = JSON.parse(await readFile(path.join(cache, 'prototypes.json'), 'utf8').catch(() => '{}'));
  const catalog = await buildCatalog({ root, dataRoot: tools.dataRoot, raw });
  catalog.data.tools = tools;
  catalog.data.hasPrototypes = Object.keys(raw).length > 0;
  return catalog;
}
export async function exportCatalog(catalog, destination = path.join(root, 'asset-overview.html')) {
  await writeFile(destination, await offlineHTML(catalog, template));
  return destination;
}

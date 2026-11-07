import { detectTools, exists, cache, startJob, refreshPrototypes, getCatalog, exportCatalog } from './host.mjs';
import path from 'node:path';
const tools = await detectTools();
if (!await exists(path.join(cache, 'prototypes.json'))) {
  const job = startJob('Read Factorio prototypes', job => refreshPrototypes(tools, job));
  await job.promise;
  if (job.status === 'failed') throw new Error(job.log);
}
const catalog = await getCatalog(tools);
console.log(`Exported ${catalog.data.ownedFiles.length} shipped images: ${await exportCatalog(catalog)}`);

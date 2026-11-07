import { test, expect } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import { root, directory } from '../../host.mjs';
import { readFile } from 'node:fs/promises';

test('live catalog filters, inspects, animates and adapts to mobile', async ({ page }) => {
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  const catalog = await (await page.request.get('/api/catalog')).json();
  await expect(page.getByRole('heading', { name: 'Asset review',exact:true })).toBeVisible();
  await expect(page.locator('.asset-card')).toHaveCount(0);
  await page.getByRole('button',{name:'Browse installed assets and references'}).click();
  await expect(page.locator('.asset-card')).toHaveCount(catalog.entries.length);
  await page.getByRole('button', { name: /Completed Blender/ }).click();
  await expect(page.locator('.asset-card')).toHaveCount(22);
  const canvas = page.locator('.asset-card canvas').first(); await canvas.scrollIntoViewIfNeeded();
  await expect.poll(() => canvas.evaluate(c => c.getContext('2d').getImageData(0, 0, c.width, c.height).data.some((n, i) => i % 4 === 3 && n > 0))).toBe(true);
  await page.getByRole('button', { name: 'Idle', exact: true }).click();
  await page.getByRole('button', { name: 'Inspect server-rack', exact: true }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await expect(page.locator('.source-grid a')).toHaveCount(8);
  await page.getByRole('button', { name: 'Close inspector' }).click();
  await page.getByRole('button', { name: /All graphics/ }).click();
  await page.getByRole('combobox', { name: 'Graphic type' }).selectOption('Entity');
  await page.getByRole('textbox', { name: 'Search all assets' }).fill('training-cluster');
  await expect(page.locator('.asset-card')).toHaveCount(1);
  await expect(page.locator('.asset-card')).toContainText('Blender / installed');
  await expect(page.locator('.asset-card').getByRole('button', { name: 'Blender', exact: true })).toHaveCount(1);
  await page.getByRole('textbox', { name: 'Search all assets' }).fill('zzzz-no-asset');
  await expect(page.getByRole('heading', { name: 'No graphics found' })).toBeVisible();
  await page.getByRole('button', { name: 'Reset filters' }).click();
  await page.screenshot({ path: path.join(directory, '.cache/studio-desktop.png'), fullPage: false });
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.getByRole('heading', { name: 'Your factory, pixel by pixel.' })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: path.join(directory, '.cache/studio-mobile.png') });
  expect(errors).toEqual([]);
});

test('export works without the server and loads embedded images', async ({ page }) => {
  const errors = [], external = []; page.on('pageerror', e => errors.push(e.message));
  page.on('request', req => { if (/^https?:/.test(req.url())) external.push(req.url()); });
  await page.goto(pathToFileURL(path.join(root, 'asset-overview.html')).href);
  await expect(page.getByRole('heading', { name: 'The graphics atlas.' })).toBeVisible();
  const expected = await page.locator('#asset-data').evaluate(el => JSON.parse(el.textContent).entries.length);
  await expect(page.locator('article.card')).toHaveCount(expected);
  await page.locator('#status').selectOption('done');
  await expect(page.locator('article.card:visible')).toHaveCount(22);
  await page.getByRole('button', { name: 'Enlarge server-rack' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  expect(external).toEqual([]); expect(errors).toEqual([]);
});

test('API rejects cross-origin writes and unknown model paths', async ({ request }) => {
  const origin = await request.post('/api/model/open', { headers: { Origin: 'http://malicious.example' }, data: { id: 'entity:server-rack' } });
  expect(origin.status()).toBe(403);
  const unknown = await request.post('/api/model/open', { data: { id: '../../arbitrary-file' } });
  expect(unknown.status()).toBe(404);
});

test('batch-five deep link shows all five distinct installed machines and working motion', async ({ page }) => {
  const errors=[]; page.on('pageerror', error=>errors.push(error.message));
  await page.goto('/?batch=done-5');
  await page.getByRole('button',{name:'Browse installed assets and references'}).click();
  await expect(page.locator('.asset-card')).toHaveCount(5);
  await expect(page.getByRole('heading', {name:'Batch 5 / completed'})).toBeVisible();
  await expect(page.locator('.asset-card').getByRole('button', {name:'Blender',exact:true})).toHaveCount(5);
  const canvas=page.locator('.asset-card canvas').first(); await canvas.scrollIntoViewIfNeeded();
  await expect.poll(()=>canvas.evaluate(c=>c.getContext('2d').getImageData(0,0,c.width,c.height).data.some((n,i)=>i%4===3&&n>0))).toBe(true);
  await page.screenshot({path:path.join(directory,'.cache/batch-5.png'),fullPage:true});
  const before=await canvas.evaluate(c=>c.toDataURL());
  await expect.poll(()=>canvas.evaluate(c=>c.toDataURL())).not.toBe(before);
  for(const name of ['circuit-assembler','network-monitor']){
    const revised=page.getByRole('button',{name:`Inspect ${name}`,exact:true}).locator('canvas');
    await revised.scrollIntoViewIfNeeded();
    await expect.poll(()=>revised.evaluate(c=>c.getContext('2d').getImageData(0,0,c.width,c.height).data.some((n,i)=>i%4===3&&n>0))).toBe(true);
    const first=await revised.evaluate(c=>c.toDataURL());
    await expect.poll(()=>revised.evaluate(c=>c.toDataURL())).not.toBe(first);
  }
  await page.getByRole('button',{name:'Idle',exact:true}).click();
  await expect.poll(()=>canvas.evaluate(c=>c.toDataURL())).not.toBe(before);
  expect(errors).toEqual([]);
});
test('shared production registry exposes all batches and protects approved art',async({page})=>{
  await page.goto('/');await page.getByText('Production tools',{exact:true}).click();
  await expect(page.getByLabel('Pipeline batch').locator('option')).toHaveCount(46);
  await page.getByLabel('Pipeline batch').selectOption('done-5');await page.getByLabel('Pipeline asset').selectOption('entity:qln-terminal');
  await expect(page.getByRole('button',{name:'Build review candidate',exact:true})).toBeDisabled();
  await page.getByText('Source configuration · protected').click();
  await expect(page.getByRole('button',{name:'Explicitly unlock asset'})).toBeVisible();
  await expect(page.getByLabel('Asset descriptor')).toBeDisabled();
  await page.setViewportSize({width:390,height:844});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
test('mocked visual review keeps approve, validate and publish separate and pins the exact hash',async({page,request})=>{
  const baseline=await(await request.get('/api/pipeline')).json(),revision='b'.repeat(64),calls=[];
  const asset=baseline.registry.assets.find(a=>a.id==='file:thumbnail.png');let decision,validated=false;
  const bytes=await readFile(path.join(root,'thumbnail.png'));
  const manifest={revision,asset,details:{draft:false,preview:{image:'image.png',width:144,height:144,checks:['exact PNG']}},files:[{path:'thumbnail.png',artifact:'image.png',hash:'c'.repeat(64)}]};
  await page.route('**/api/pipeline**',async route=>{
    const url=new URL(route.request().url()),body=route.request().method()==='POST'?route.request().postDataJSON():null;
    if(url.pathname.includes('/artifact/'))return route.fulfill({contentType:'image/png',body:bytes});
    if(url.pathname.includes('/candidate/'))return route.fulfill({json:manifest});
    if(body){calls.push({path:url.pathname,body});if(url.pathname.endsWith('/review'))decision=body.decision;if(url.pathname.endsWith('/validate'))validated=true;return route.fulfill({json:{revision}});}
    return route.fulfill({json:{...baseline,candidates:[{revision,asset:asset.id,review:decision?{decision,comment:'fixture'}:null,validation:validated?{status:'passed',suites:['fixture']} :null}]}});
  });
  page.on('dialog',dialog=>dialog.accept());await page.goto(`/?review=${revision}`);
  await expect(page.getByRole('img',{name:'Candidate artifact',exact:true})).toBeVisible();
  const publish=page.getByRole('button',{name:'Publish approved files'}),validate=page.getByRole('button',{name:'Validate in isolated Factorio'});
  await page.getByText('Production tools',{exact:true}).click();
  await expect(publish).toBeDisabled();await expect(validate).toBeDisabled();
  await page.getByRole('button',{name:'Approve exact revision'}).click();await expect(validate).toBeEnabled();await expect(publish).toBeDisabled();
  await validate.click();await expect(publish).toBeEnabled();await publish.click();
  expect(calls.map(c=>c.path)).toEqual(['/api/pipeline/review','/api/pipeline/validate','/api/pipeline/publish']);
  expect(calls[2].body).toEqual({revision,confirm:revision});
});
test('pipeline rejects cross-origin approval and invalid candidate revisions',async({request})=>{
  expect((await request.post('/api/pipeline/review',{headers:{Origin:'http://malicious.example'},data:{revision:'a'.repeat(64),decision:'approved'}})).status()).toBe(403);
  expect((await request.get('/api/pipeline/candidate/not-a-revision')).status()).toBe(400);
});
test('entity review draws exact shipping sheets at a shared scale and supports frame inspection',async({page,request})=>{
  const baseline=await(await request.get('/api/pipeline')).json(),catalog=await(await request.get('/api/catalog')).json(),revision='d'.repeat(64),entry=catalog.entries.find(e=>e.id==='entity:network-monitor'),asset=baseline.registry.assets.find(a=>a.id===entry.id),body=entry.working.find(l=>!l.shadow);
  const manifest={revision,asset,details:{draft:false,preview:{width:body.width,height:body.height,frames:body.frames,columns:body.columns,shift:body.shift,scale:body.scale,fps:body.fps,footprint:entry.footprint,views:{game:{working:'working.png',idle:'idle.png',shadow:'shadow.png'}},checks:['fixture exact shipped sheets']}},files:[]};
  await page.route('**/api/pipeline**',async route=>{
    const url=new URL(route.request().url());
    if(url.pathname.includes('/artifact/'))return route.fulfill({contentType:'image/png',body:await readFile(path.join(root,'graphics/entity/network-monitor',url.searchParams.get('file')))});
    return route.fulfill({json:url.pathname.includes('/candidate/')?manifest:{...baseline,candidates:[{revision,asset:asset.id}]}});
  });
  await page.goto(`/?review=${revision}`);await page.getByRole('button',{name:'Pause review',exact:true}).click();
  const left=page.getByLabel('Installed comparison'),right=page.getByLabel('Candidate comparison');
  await expect.poll(()=>right.evaluate(c=>c.getContext('2d').getImageData(0,0,c.width,c.height).data.some((n,i)=>i%4===3&&n>0))).toBe(true);
  await expect.poll(async()=>await left.evaluate(c=>c.toDataURL())===await right.evaluate(c=>c.toDataURL())).toBe(true);
  await page.getByLabel('Review frame').press('End');await expect(page.getByLabel('Review frame')).toHaveValue(String(body.frames-1));
  await page.locator('.candidate-detail').screenshot({path:path.join(directory,'.cache/pipeline-review.png')});
  await page.getByRole('button',{name:'Show idle',exact:true}).click();await expect(page.getByRole('button',{name:'Show working',exact:true})).toBeVisible();
});

test('review queue hides drafts, batches and reviewed versions and advances one asset at a time',async({page,request})=>{
  const baseline=await(await request.get('/api/pipeline')).json();
  const assets=baseline.registry.assets.slice(0,4), id=n=>String(n).repeat(64);
  let candidates=[
    {revision:id(1),asset:assets[0].id,createdAt:1},
    {revision:id(2),asset:assets[0].id,createdAt:2},
    {revision:id(3),asset:assets[1].id,draft:true,createdAt:3},
    {revision:id(4),asset:'bundle:fixture',members:[id(1),id(2)],createdAt:4},
    {revision:id(5),asset:assets[2].id,review:{decision:'rejected'},createdAt:5},
    {revision:id(6),asset:assets[3].id,createdAt:6}
  ];
  await page.route('**/api/pipeline**',async route=>{
    const url=new URL(route.request().url());
    if(url.pathname.includes('/candidate/')){
      const revision=url.pathname.split('/').at(-1),c=candidates.find(c=>c.revision===revision);
      return route.fulfill({json:{revision,asset:assets.find(a=>a.id===c.asset),details:{draft:false},files:[]}});
    }
    if(route.request().method()==='POST'){
      const body=route.request().postDataJSON();candidates=candidates.map(c=>c.revision===body.revision?{...c,review:{decision:body.decision,comment:body.comment}}:c);
      return route.fulfill({json:{}});
    }
    return route.fulfill({json:{...baseline,candidates}});
  });
  await page.goto(`/?review=${id(4)}`);
  await expect(page.getByRole('heading',{name:'Ready for review · 2'})).toBeVisible();
  await expect(page.locator('.candidate-detail')).toHaveCount(1);
  await expect(page.locator('.candidate-detail h3')).toContainText(assets[3].name);
  await expect(page.locator('.asset-card')).toHaveCount(0);
  await page.getByLabel('Review comment').fill('Please fix this');
  await page.getByRole('button',{name:'Request changes',exact:true}).click();
  await expect(page.getByRole('heading',{name:'Ready for review · 1'})).toBeVisible();
  await expect(page.locator('.candidate-detail h3')).toContainText(assets[0].name);
  await expect(page.locator('.revision-id')).toHaveText(id(2));
});


test('model review precedes explicit rendering and keeps Blender downloads available',async({page,request})=>{
  const baseline=await(await request.get('/api/pipeline')).json(),revision='e'.repeat(64),asset=baseline.registry.assets.find(a=>a.id==='entity:wafer-fab');
  const calls=[];let review=null,renderedRevision=null;
  await page.route('**/api/pipeline**',async route=>{
    const url=new URL(route.request().url());
    if(route.request().method()==='POST'){
      calls.push(url.pathname);const body=route.request().postDataJSON();
      if(url.pathname.endsWith('/review'))review={decision:body.decision};
      if(url.pathname.endsWith('/render'))renderedRevision='f'.repeat(64);
      return route.fulfill({json:{decision:body.decision}});
    }
    return route.fulfill({json:{...baseline,candidates:[],models:[{revision,asset,details:{buildKey:'a'.repeat(64)},createdAt:1,review,renderedRevision}]}});
  });
  await page.goto('/');
  await expect(page.getByRole('link',{name:'Download .blend'})).toHaveAttribute('href',`/api/pipeline/model/${revision}?kind=model`);
  await expect(page.getByRole('button',{name:'Render final animation'})).toHaveCount(0);
  await page.getByRole('button',{name:'Model looks good'}).click();
  await expect(page.getByRole('button',{name:'Render final animation'})).toBeVisible();
  expect(calls).toEqual([`/api/pipeline/model/${revision}/review`]);
  await page.getByRole('button',{name:'Render final animation'}).click();
  await expect(page.getByText('No new models awaiting review. Future iterations can stop at the model stage.')).toBeVisible();
});

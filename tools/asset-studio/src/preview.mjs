const images = new Map(), tinted = new Map();
function image(key, sources) {
  const src = sources[key].src;
  if (!images.has(src)) { const img = new Image(); img.src = src; images.set(src, img); }
  return images.get(src);
}
export function bounds(entry) {
  let left = 0, top = 0, right = 1, bottom = 1;
  for (const l of [...entry.idle, ...entry.working]) {
    const w = l.width * l.scale, h = l.height * l.scale, x = l.shift[0] * 32, y = l.shift[1] * 32;
    left = Math.min(left, x - w / 2); top = Math.min(top, y - h / 2);
    right = Math.max(right, x + w / 2); bottom = Math.max(bottom, y + h / 2);
  }
  return { left, top, width: Math.ceil((right - left) * 2) + 16, height: Math.ceil((bottom - top) * 2) + 16 };
}
function texture(layer, sources) {
  const img = image(layer.image, sources);
  if (!img.complete || !img.naturalWidth) return null;
  if (!layer.tint) return img;
  const key = img.src + JSON.stringify(layer.tint);
  if (!tinted.has(key)) {
    const canvas = document.createElement('canvas'); canvas.width = img.width; canvas.height = img.height;
    const ctx = canvas.getContext('2d'); ctx.drawImage(img, 0, 0);
    const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height), t = layer.tint;
    const rgba = [t.r ?? t[0] ?? 1, t.g ?? t[1] ?? 1, t.b ?? t[2] ?? 1, t.a ?? t[3] ?? 1];
    for (let i = 0; i < pixels.data.length; i++) pixels.data[i] *= rgba[i % 4];
    ctx.putImageData(pixels, 0, 0); tinted.set(key, canvas);
  }
  return tinted.get(key);
}
export function draw(canvas, entry, sources, time, working, footprint, viewport) {
  const b = viewport ?? bounds(entry), ctx = canvas.getContext('2d');
  if (canvas.width !== b.width || canvas.height !== b.height) { canvas.width = b.width; canvas.height = b.height; }
  ctx.clearRect(0, 0, canvas.width, canvas.height); ctx.imageSmoothingEnabled = false;
  const layers = working ? entry.working : entry.idle;
  for (const l of [...layers.filter(l => l.shadow), ...layers.filter(l => !l.shadow)]) {
    const img = texture(l, sources); if (!img) continue;
    const f = Math.floor(time / 1000 * l.fps) % l.frames, w = l.width * l.scale * 2, h = l.height * l.scale * 2;
    ctx.drawImage(img, (l.x ?? 0) + f % l.columns * l.width, (l.y ?? 0) + Math.floor(f / l.columns) * l.height, l.width, l.height,
      (l.shift[0] * 32 - b.left) * 2 - w / 2 + 8, (l.shift[1] * 32 - b.top) * 2 - h / 2 + 8, w, h);
  }
  if (footprint && entry.footprint) {
    const [w, h] = entry.footprint.map(n => n * 64);
    ctx.strokeStyle = '#a0e2c580'; ctx.lineWidth = 1;
    ctx.strokeRect(-b.left * 2 + 8 - w / 2, -b.top * 2 + 8 - h / 2, w, h);
  }
}

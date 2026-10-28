/* QaSHE Watchman: offline shell. Keeps the app itself available with no signal.
   Data and uploads are handled inside the app (IndexedDB), never here. */
const V = 'wm-shell-v1';
const SHELL = ['./', 'index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'supabase-js.umd.js'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(V).then(c => Promise.all(SHELL.map(u => c.add(u).catch(() => {})))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
function timeout(ms, p){ return new Promise((res, rej) => { const t = setTimeout(() => rej(new Error('timeout')), ms); p.then(v => { clearTimeout(t); res(v); }, e => { clearTimeout(t); rej(e); }); }); }
self.addEventListener('fetch', e => {
  const req = e.request; if(req.method !== 'GET') return;
  const u = new URL(req.url);
  if(/supabase\.(co|in)$/.test(u.hostname)) return;                 // data goes through the app
  if(u.origin === self.location.origin){
    e.respondWith((async () => {
      const cache = await caches.open(V);
      const net = fetch(req).then(r => { if(r && r.ok) cache.put(req, r.clone()); return r; });
      try{ return await timeout(req.mode === 'navigate' ? 4000 : 6000, net); }
      catch(err){
        net.catch(() => {});
        const hit = await cache.match(req, { ignoreSearch: true }) || (req.mode === 'navigate' ? await cache.match('index.html', { ignoreSearch: true }) || await cache.match('./') : null);
        if(hit) return hit; return net;
      }
    })());
    return;
  }
  if(/(esm\.sh|cdn\.jsdelivr\.net|fonts\.googleapis\.com|fonts\.gstatic\.com|cdnjs\.cloudflare\.com)$/.test(u.hostname)){
    e.respondWith(caches.open(V).then(async cache => {
      const hit = await cache.match(req); if(hit) return hit;
      const r = await fetch(req); if(r && (r.ok || r.type === 'opaque')) cache.put(req, r.clone()); return r;
    }));
  }
});

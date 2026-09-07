/* Cross-origin isolation for hosts that will not set the headers.
 *
 * The guest blocks on Atomics.wait for its next frame tick, which needs a
 * SharedArrayBuffer, which needs the document to be cross-origin isolated —
 * i.e. COOP: same-origin and COEP: require-corp on every response.  A static
 * host (GitHub Pages, S3, …) usually will not send those.  A service worker
 * can put them on the responses it serves, which is enough.
 *
 * Loaded as a classic script from index.html, so the same file is both the
 * registrar (window side) and the worker (no window).  The first load
 * registers and reloads once; after that the page is isolated.
 *
 * Not needed when the server already sets the headers (serve.py does).
 */
if (typeof window === 'undefined') {
  self.addEventListener('install', () => self.skipWaiting());
  self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
  self.addEventListener('fetch', (event) => {
    const req = event.request;
    if (req.cache === 'only-if-cached' && req.mode !== 'same-origin') return;
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res.status === 0) return res;            // opaque: leave alone
          const headers = new Headers(res.headers);
          headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
          headers.set('Cross-Origin-Opener-Policy', 'same-origin');
          headers.set('Cross-Origin-Resource-Policy', 'same-origin');
          return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
        })
        .catch((e) => { console.error('[coi]', e); throw e; })
    );
  });
} else {
  (() => {
    if (window.crossOriginIsolated) return;             // server already did it
    if (!window.isSecureContext) {
      console.warn('[coi] needs https or localhost');
      return;
    }
    if (!navigator.serviceWorker) {
      console.warn('[coi] no service worker support');
      return;
    }
    const src = document.currentScript.src;
    // The document itself has to come through the worker, so the first load
    // registers and reloads once; from then on it is controlled and isolated.
    let reloaded = false;
    const reload = () => { if (!reloaded) { reloaded = true; window.location.reload(); } };
    navigator.serviceWorker.addEventListener('controllerchange', reload);
    navigator.serviceWorker.register(src).then((reg) => {
      if (reg.active && !navigator.serviceWorker.controller) reload();
      reg.addEventListener('updatefound', () => {
        const w = reg.installing;
        if (w) w.addEventListener('statechange', () => { if (w.state === 'activated') reload(); });
      });
    }, (e) => console.error('[coi] register failed', e));
  })();
}

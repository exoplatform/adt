'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./load');

const ORIGIN = 'http://adt.example';
const PAGE = '<!DOCTYPE html><html><head><title>t</title></head><body>dashboard</body></html>';

// The service worker with an in-memory Cache Storage and a fetch we script.
function env() {
  const stores = new Map(); // cache name -> Map(url -> {body, init})
  const handlers = {};
  const state = { fetch: () => Promise.reject(new TypeError('network down')), added: [] };
  const keyOf = (req) => new URL(typeof req === 'string' ? req : req.url, ORIGIN).href; // the Cache API resolves relative URLs
  function cacheOf(name) {
    if (!stores.has(name)) stores.set(name, new Map());
    const m = stores.get(name);
    const rebuild = (e) => {
      const r = new Response(e.body, e.init);
      Object.defineProperty(r, 'type', { value: 'basic' });
      Object.defineProperty(r, 'redirected', { value: false });
      return r;
    };
    return {
      async put(req, res) { m.set(keyOf(req), { body: await res.text(), init: { status: res.status, headers: [...res.headers] } }); },
      async match(req) { const e = m.get(keyOf(req)); return e ? rebuild(e) : undefined; },
      async keys() { return [...m.keys()].map((url) => ({ url })); },
      async delete(req) { return m.delete(keyOf(req)); },
      async addAll(reqs) { state.added.push(...reqs.map((r) => new URL(r.url, ORIGIN).pathname)); },
    };
  }
  const caches = {
    async open(name) { return cacheOf(name); },
    async keys() { return [...stores.keys()]; },
    async delete(name) { return stores.delete(name); },
    async match(req) {
      for (const name of stores.keys()) { const r = await cacheOf(name).match(req); if (r) return r; }
      return undefined;
    },
  };
  const self = {
    location: { origin: ORIGIN },
    addEventListener: (type, fn) => { handlers[type] = fn; },
    skipWaiting() {}, clients: { claim: async () => {} },
  };
  const w = load('sw.js', { self, caches, fetch: (...a) => state.fetch(...a), Request: class { constructor(u, o) { this.url = u; Object.assign(this, o); } } });
  // a top-level const is not a property of the sandbox: read the name the way the file spells it
  const cacheName = /const CACHE = '([^']+)'/.exec(require('node:fs').readFileSync(require('node:path').join(__dirname, '..', 'static', 'sw.js'), 'utf8'))[1];

  // Runs a fetch event and returns what the worker answered (undefined: it let the browser handle it)
  async function request(path, { mode = 'navigate', method = 'GET' } = {}) {
    let answer, waits = [];
    const ev = { request: { method, url: ORIGIN + path, mode }, respondWith: (p) => { answer = p; }, waitUntil: (p) => waits.push(p) };
    handlers.fetch(ev);
    const res = answer === undefined ? undefined : await answer;
    await Promise.all(waits);
    await new Promise((r) => setImmediate(r)); // the cache write that follows a response
    return res;
  }
  async function cached() { return (await cacheOf(cacheName).keys()).map((k) => new URL(k.url).pathname); }
  const page = (status = 200, headers = {}) => new Response(PAGE, { status, headers: { 'content-type': 'text/html; charset=UTF-8', Date: 'Sat, 21 Nov 2026 18:47:06 GMT', ...headers } });
  return { w, state, request, cached, cacheOf: () => cacheOf(cacheName), handlers, page, stores };
}

function patched(res) { Object.defineProperty(res, 'type', { value: 'basic' }); Object.defineProperty(res, 'redirected', { value: false }); return res; }

test('install keeps the offline page', async () => {
  const e = env();
  let p;
  e.handlers.install({ waitUntil: (x) => { p = x; } });
  await p;
  assert.ok(e.state.added.includes('/offline.html'), e.state.added.join(' '));
});

test('online: the dashboard page is served from the network and kept for later', async () => {
  const e = env();
  e.state.fetch = async () => patched(e.page());
  const res = await e.request('/qa');
  assert.equal(await res.text(), PAGE);
  assert.deepEqual(await e.cached(), ['/qa']);
});

test('the network is gone: the kept copy is served, marked as such with the date the server sent it', async () => {
  const e = env();
  e.state.fetch = async () => patched(e.page());
  await e.request('/');
  e.state.fetch = async () => { throw new TypeError('down'); };
  const res = await e.request('/');
  const html = await res.text();
  assert.equal(res.status, 200);
  assert.ok(html.startsWith('<!DOCTYPE html><html><head><meta name="adt-offline" content="Sat, 21 Nov 2026 18:47:06 GMT"><title>'), html);
  assert.ok(html.includes('dashboard'));
});

test('the copy is re-encoded: no stale Content-Length or Content-Encoding on the rewritten body', async () => {
  const e = env();
  e.state.fetch = async () => patched(e.page(200, { 'content-length': '999999', 'content-encoding': 'br' }));
  await e.request('/');
  e.state.fetch = async () => { throw new TypeError('down'); };
  const res = await e.request('/');
  assert.equal(res.headers.get('content-length'), null);
  assert.equal(res.headers.get('content-encoding'), null);
});

test('adt-web down behind a running Apache (502/503/504): the kept copy replaces the proxy error', async () => {
  for (const status of [502, 503, 504]) {
    const e = env();
    e.state.fetch = async () => patched(e.page());
    await e.request('/sales');
    e.state.fetch = async () => new Response('<h1>Proxy Error</h1>', { status });
    const res = await e.request('/sales');
    assert.equal(res.status, 200, `status ${status}`);
    assert.ok((await res.text()).includes('adt-offline'));
  }
});

test('502 with nothing kept: the proxy error is shown as it is (not hidden behind a made-up page)', async () => {
  const e = env();
  e.state.fetch = async () => new Response('<h1>Proxy Error</h1>', { status: 502 });
  const res = await e.request('/sales');
  assert.equal(res.status, 502);
});

test('other server errors are not "the server is down": a 500 or 404 is shown, not the kept copy', async () => {
  for (const status of [404, 500, 501]) {
    const e = env();
    e.state.fetch = async () => patched(e.page());
    await e.request('/qa');
    e.state.fetch = async () => new Response('x', { status });
    assert.equal((await e.request('/qa')).status, status);
  }
});

test('a page that was never kept gets the offline page (navigations), a script gets an error, not HTML', async () => {
  const e = env();
  await (await e.cacheOf()).put(ORIGIN + '/offline.html', new Response('<h1>You are offline</h1>', { status: 200 }));
  const nav = await e.request('/debug-health');
  assert.ok((await nav.text()).includes('You are offline'));
  const xhr = await e.request('/qa', { mode: 'cors' });
  assert.equal(xhr.status, 408);
});

test('the date of the copy cannot inject markup: only a plain date goes into the meta', async () => {
  const e = env();
  e.state.fetch = async () => patched(e.page(200, { Date: 'x"><script>alert(1)</script>' }));
  await e.request('/');
  e.state.fetch = async () => { throw new TypeError('down'); };
  const html = await (await e.request('/')).text();
  assert.ok(!html.includes('<script'), html);
  assert.ok(html.includes('<meta name="adt-offline" content="">'), html);
});

test('only the plain dashboard pages are kept: not a page with a query, not a redirect, not a debug page', async () => {
  const e = env();
  e.state.fetch = async () => patched(e.page());
  await e.request('/qa?filter=secret');
  await e.request('/debug-sessions');
  await e.request('/logs');
  assert.deepEqual(await e.cached(), []);
  e.state.fetch = async () => { const r = new Response(PAGE, { status: 200 }); Object.defineProperty(r, 'type', { value: 'basic' }); Object.defineProperty(r, 'redirected', { value: true }); return r; };
  await e.request('/qa');
  assert.deepEqual(await e.cached(), [], 'a redirect (the login form answered in its place) is not kept');
});

test('the pages of the person are forgotten on /logout and when the page says the session ended', async () => {
  const e = env();
  e.state.fetch = async () => patched(e.page());
  for (const p of ['/', '/qa', '/servers']) await e.request(p);
  await (await e.cacheOf()).put(ORIGIN + '/manifest.json', new Response('{}'));
  assert.equal((await e.cached()).length, 4);

  const waits = [];
  e.handlers.message({ data: { action: 'forgetPages' }, waitUntil: (p) => waits.push(p) });
  await Promise.all(waits);
  assert.deepEqual(await e.cached(), ['/manifest.json'], 'pages gone, static files kept');

  for (const p of ['/', '/qa']) await e.request(p);
  e.state.fetch = async () => new Response('', { status: 200 });
  await e.request('/logout');
  assert.deepEqual(await e.cached(), ['/manifest.json']);
});

test('the login page forgets the saved pages: a session that expired (nobody pressed Logout) must not leave them for the next person', async () => {
  const e = env();
  e.state.fetch = async () => patched(e.page());
  for (const p of ['/', '/qa']) await e.request(p);
  assert.equal((await e.cached()).length, 2);
  e.state.fetch = async () => new Response('<h1>login</h1>', { status: 200 });
  await e.request('/login'); // a navigation to the login page
  assert.deepEqual(await e.cached(), []);

  // a script fetching /login in the background is not a visit of the page
  e.state.fetch = async () => patched(e.page());
  await e.request('/');
  e.state.fetch = async () => new Response('x', { status: 200 });
  await e.request('/login', { mode: 'cors' });
  assert.deepEqual(await e.cached(), ['/']);
});

test('a redirected answer is never kept as a static file: an expired session would store the login page under the URL of a script', async () => {
  const e = env();
  const redirected = () => { const r = new Response('<h1>login</h1>', { status: 200, headers: { 'content-type': 'text/html' } }); Object.defineProperty(r, 'type', { value: 'basic' }); Object.defineProperty(r, 'redirected', { value: true }); return r; };
  e.state.fetch = async () => redirected();
  await e.request('/js/head.js', { mode: 'no-cors' });
  await e.request('/style.css', { mode: 'no-cors' });
  assert.deepEqual(await e.cached(), []);
  // an ordinary answer is kept
  e.state.fetch = async () => patched(new Response('var x', { status: 200 }));
  await e.request('/js/head.js', { mode: 'no-cors' });
  assert.deepEqual(await e.cached(), ['/js/head.js']);
});

test('the live socket path and non-GET requests are left to the browser', async () => {
  const e = env();
  assert.equal(await e.request('/ws', { mode: 'cors' }), undefined);
  assert.equal(await e.request('/qa', { method: 'POST' }), undefined);
});

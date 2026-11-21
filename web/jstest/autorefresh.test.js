'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// autorefresh.js hands its pure core to the tests through module.exports (a browser has no `module`)
const src = fs.readFileSync(path.join(__dirname, '..', 'static', 'js', 'autorefresh.js'), 'utf8');
const mod = { exports: {} };
new Function('module', src)(mod);
const core = mod.exports;

test('plan: nothing changed, nothing to do', () => {
  assert.deepEqual(core.plan([{ sig: 'a' }, { sig: 'b' }], ['a', 'b']), ['keep', 'keep']);
});

test('plan: a changed part is replaced, the others are kept', () => {
  assert.deepEqual(core.plan([{ sig: 'a' }, { sig: 'b' }, { sig: 'c' }], ['a', 'B', 'c']), ['keep', 'replace', 'keep']);
});

test('plan: a part in use is never replaced or removed: it is skipped, to try again', () => {
  assert.deepEqual(core.plan([{ sig: 'a', busy: true }, { sig: 'b', busy: true }], ['A', 'b']), ['skip', 'keep']);
  assert.deepEqual(core.plan([{ sig: 'a' }, { sig: 'b', busy: true }], ['a']), ['keep', 'skip']);
});

test('plan: a part in use that did not change is not a reason to wait', () => {
  assert.deepEqual(core.plan([{ sig: 'a', busy: true }], ['a']), ['keep']);
});

test('plan: new parts are inserted, parts that are gone are removed', () => {
  assert.deepEqual(core.plan([{ sig: 'a' }], ['a', 'b', 'c']), ['keep', 'insert', 'insert']);
  assert.deepEqual(core.plan([{ sig: 'a' }, { sig: 'b' }, { sig: 'c' }], ['a']), ['keep', 'remove', 'remove']);
  assert.deepEqual(core.plan([], []), []);
  assert.deepEqual(core.plan([], ['a']), ['insert']);
});

test('interval: long while the socket is open, as it always was without it', () => {
  assert.equal(core.interval(true), 600000);
  assert.equal(core.interval(false), 120000);
  assert.equal(core.interval(undefined), 120000);
});

test('delay: a burst of deployments does not make every dashboard ask the server after each one', () => {
  // just looked: wait the minimum gap
  assert.equal(core.delay(1000, 1000, 2000), 10000);
  assert.equal(core.delay(1000, 1000, 0), 10000);
  // looked long ago: the wait asked for
  assert.equal(core.delay(100000, 1000, 2000), 2000);
  assert.equal(core.delay(100000, 1000, 0), 0);
  // in between
  assert.equal(core.delay(6000, 1000, 2000), 5000);
});

test('classify: a signed-out answer needs the page itself, server trouble keeps what is shown', () => {
  // redirect:"manual" gives an opaque redirect when the session is gone (Apache sends the visitor to the login page)
  assert.equal(core.classify('opaqueredirect', 0, ''), 'signedout');
  assert.equal(core.classify('basic', 401, 'text/html'), 'signedout');
  assert.equal(core.classify('basic', 403, 'text/html'), 'signedout');
  assert.equal(core.classify('basic', 200, 'text/html; charset=UTF-8'), 'apply');
  for (const status of [404, 500, 502, 503, 504]) assert.equal(core.classify('basic', status, 'text/html'), 'ignore', String(status));
  assert.equal(core.classify('basic', 200, 'application/json'), 'ignore', 'not a page');
  assert.equal(core.classify('basic', 200, null), 'ignore');
});

// The parts to swap are found anywhere under #main: the QA, Sales, Company and Customers pages keep them inside
// .container-fluid > .row > .col-12, only the home page directly in #main. A selector for direct children matched nothing there,
// and those four pages stopped updating (they used to be reloaded as a whole).
test('parts: the selector looks under the whole of #main, not at its direct children', () => {
  const asked = [];
  const root = { querySelectorAll(sel) { asked.push(sel); return ['a', 'b']; } };
  assert.deepEqual(core.parts(root, '.instances-section'), ['a', 'b']);
  assert.deepEqual(asked, ['.instances-section']);
  for (const sel of asked) assert.ok(!/:scope|>/.test(sel), `selector ${sel} only matches direct children`);
});

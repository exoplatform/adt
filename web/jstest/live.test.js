'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./load');

// A browser stand-in: a WebSocket we drive by hand, a clock we advance by hand, and the few globals live.js touches.
function env(opts = {}) {
  const sockets = [];
  class FakeWebSocket {
    constructor(url) { this.url = url; this.closed = false; sockets.push(this); }
    close() { this.closed = true; }
    open() { this.onopen(); }
    say(obj) { this.onmessage({ data: typeof obj === 'string' ? obj : JSON.stringify(obj) }); }
    drop(code = 1006) { this.onclose({ code }); }
  }
  let now = 0, id = 0;
  const timers = new Map();
  const listeners = {};
  const posted = [], assigned = [];
  const g = {
    WebSocket: FakeWebSocket,
    location: { protocol: opts.protocol || 'http:', host: 'adt.example', href: 'http://adt.example/qa', assign: (u) => assigned.push(u) },
    navigator: { serviceWorker: opts.noSW ? undefined : { controller: { postMessage: (m) => posted.push(JSON.parse(JSON.stringify(m))) } } },
    setTimeout: (fn, ms) => { timers.set(++id, { fn, at: now + ms }); return id; },
    clearTimeout: (t) => timers.delete(t),
    Math: Object.assign(Object.create(Math), { random: () => 0.5 }), // jitter factor 1.0
    addEventListener: (type, fn) => { listeners[type] = fn; },
  };
  const w = load('js/live.js', g);
  return {
    live: w.adtLive, sockets, posted, assigned, listeners,
    advance(ms) {
      now += ms;
      for (const [k, t] of [...timers]) if (t.at <= now) { timers.delete(k); t.fn(); }
    },
    pending: () => timers.size,
  };
}

test('nothing is opened until something listens; then one socket to /ws on the page origin', () => {
  const e = env();
  assert.equal(e.sockets.length, 0);
  e.live.on('deployed', () => {});
  assert.equal(e.sockets.length, 1);
  assert.equal(e.sockets[0].url, 'ws://adt.example/ws');
  e.live.on('reconnect', () => {});
  assert.equal(e.sockets.length, 1, 'a second listener shares the socket');
});

test('https pages use wss', () => {
  const e = env({ protocol: 'https:' });
  e.live.on('x', () => {});
  assert.equal(e.sockets[0].url, 'wss://adt.example/ws');
});

test('messages go to the listeners of their type; garbage is ignored; a failing listener does not stop the others', () => {
  const e = env();
  const got = [];
  e.live.on('deployed', () => { throw new Error('boom'); });
  e.live.on('deployed', (m) => got.push(m.key));
  e.sockets[0].open();
  assert.equal(e.live.connected(), true);
  e.sockets[0].say({ type: 'deployed', key: 'plf-7.3.x' });
  e.sockets[0].say('not json');
  e.sockets[0].say({ nottype: 1 });
  e.sockets[0].say({ type: 'other', key: 'k' });
  assert.deepEqual(got, ['plf-7.3.x']);
});

test('a lost socket comes back with backoff, and the page is told it may have missed messages (not on the first connection)', () => {
  const e = env();
  const events = [];
  e.live.on('reconnect', () => events.push('reconnect'));
  e.sockets[0].open();
  assert.deepEqual(events, [], 'first connection is not a reconnection');
  e.sockets[0].drop(1006);
  assert.equal(e.live.connected(), false);
  e.advance(999);
  assert.equal(e.sockets.length, 1, 'waits the backoff');
  e.advance(1);
  assert.equal(e.sockets.length, 2);
  e.sockets[1].open();
  assert.deepEqual(events, ['reconnect']);
});

test('the backoff doubles up to 30 s and starts again after a connection', () => {
  const e = env();
  e.live.on('x', () => {});
  const waits = [];
  for (let i = 0; i < 7; i++) {
    const before = e.sockets.length;
    e.sockets[before - 1].drop(1006); // never opened
    let waited = 0;
    while (e.sockets.length === before) { e.advance(250); waited += 250; }
    waits.push(waited);
  }
  assert.deepEqual(waits, [1000, 2000, 4000, 8000, 16000, 30000, 30000]);
  e.sockets[e.sockets.length - 1].open();
  e.sockets[e.sockets.length - 1].drop(1006);
  let waited = 0, n = e.sockets.length;
  while (e.sockets.length === n) { e.advance(250); waited += 250; }
  assert.equal(waited, 1000);
});

test('the server ended the socket on purpose (1000): reconnect at once and quietly', () => {
  const e = env();
  const events = [];
  e.live.on('reconnect', () => events.push('reconnect'));
  e.sockets[0].open();
  e.sockets[0].drop(1000);
  e.advance(0);
  assert.equal(e.sockets.length, 2, 'no wait');
  e.sockets[1].open();
  assert.deepEqual(events, [], 'nothing was missed: no reload');
});

test('a quiet reconnection that fails is not quiet any more: messages may have been missed', () => {
  const e = env();
  const events = [];
  e.live.on('reconnect', () => events.push('reconnect'));
  e.sockets[0].open();
  e.sockets[0].drop(1000);
  e.advance(0);
  e.sockets[1].drop(1006); // the server is down
  e.advance(2000);
  e.sockets[2].open();
  assert.deepEqual(events, ['reconnect']);
});

test('eviction: the "logout" message stops everything: no reconnection, saved pages forgotten, the page asks for its URL again', () => {
  const e = env();
  const events = [];
  e.live.on('logout', () => events.push('logout'));
  e.sockets[0].open();
  e.sockets[0].say({ type: 'logout' });
  assert.deepEqual(events, ['logout']);
  assert.equal(e.sockets[0].closed, true);
  assert.deepEqual(e.posted, [{ action: 'forgetPages' }]);
  // NOT /logout: that would end a session opened again in another tab
  assert.deepEqual(e.assigned, ['http://adt.example/qa']);
  e.sockets[0].drop(1008);
  e.advance(600000);
  assert.equal(e.sockets.length, 1, 'the server is not bothered again');
  assert.equal(e.pending(), 0, 'and nothing is scheduled');
});

test('eviction: a 1008 close alone (the message was lost) does the same, once', () => {
  const e = env();
  e.live.on('x', () => {});
  e.sockets[0].open();
  e.sockets[0].drop(1008);
  assert.equal(e.assigned.length, 1);
  assert.deepEqual(e.posted, [{ action: 'forgetPages' }]);
  e.sockets[0].say({ type: 'logout' }); // a late message
  assert.equal(e.assigned.length, 1, 'not twice');
  e.advance(600000);
  assert.equal(e.sockets.length, 1);
});

test('logout without a service worker still leaves', () => {
  const e = env({ noSW: true });
  e.live.on('x', () => {});
  e.sockets[0].open();
  e.sockets[0].say({ type: 'logout' });
  assert.equal(e.assigned.length, 1);
  assert.deepEqual(e.posted, []);
});

test('leaving the page closes the socket and does not reconnect', () => {
  const e = env();
  e.live.on('x', () => {});
  e.sockets[0].open();
  e.listeners.pagehide();
  assert.equal(e.sockets[0].closed, true);
  e.sockets[0].drop(1001);
  e.advance(600000);
  assert.equal(e.sockets.length, 1);
});

test('without WebSocket support the page works: listeners are accepted, nothing is connected', () => {
  const g = { location: { protocol: 'http:', host: 'h' }, addEventListener() {}, setTimeout, clearTimeout };
  const w = load('js/live.js', g);
  w.adtLive.on('deployed', () => {});
  assert.equal(w.adtLive.connected(), false);
});

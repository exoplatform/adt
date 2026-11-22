'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./load');

// A browser stand-in: elements with attributes and a selector matcher, a Bootstrap Tooltip that behaves like the real one
// (it takes the title away at construction, dispose gives the ORIGINAL title back), and the document's listeners.
function env({ hover = true, bootstrap = true } = {}) {
  const listeners = {};
  class El {
    constructor(attrs = {}, tag = 'button') { this.attrs = { ...attrs }; this.tag = tag; this.parent = null; }
    getAttribute(n) { return n in this.attrs ? this.attrs[n] : null; }
    setAttribute(n, v) { this.attrs[n] = String(v); }
    removeAttribute(n) { delete this.attrs[n]; }
    matches(sel) {
      return sel.split(',').map((s) => s.trim()).some((s) => {
        if (/^\[.+\]$/.test(s)) { const [k, v] = s.slice(1, -1).split('='); return v === undefined ? k in this.attrs : this.attrs[k] === v; }
        return s === this.tag;
      });
    }
    closest(sel) { for (let e = this; e; e = e.parent) if (e.matches(sel)) return e; return null; }
  }
  const instances = new Map(), made = [];
  class Tooltip {
    constructor(el, opts) {
      this.el = el; this.opts = opts; this.shown = 0;
      el.setAttribute('data-bs-original-title', el.getAttribute('title')); el.removeAttribute('title');
      this.text = el.getAttribute('data-bs-original-title');
      instances.set(el, this); made.push(this);
    }
    static getInstance(el) { return instances.get(el) || null; }
    show() { this.shown++; }
    dispose() { this.el.setAttribute('title', this.el.getAttribute('data-bs-original-title')); instances.delete(this.el); }
  }
  const g = {
    document: { addEventListener: (t, fn) => { listeners[t] = fn; } },
    window: { matchMedia: (q) => ({ matches: q === '(hover: hover)' ? hover : false }) },
  };
  g.window.document = g.document;
  if (bootstrap) g.bootstrap = { Tooltip };
  load('js/pills.js', g);
  return { El, listeners, made, instances, over: (el) => listeners.mouseover({ target: el }), focus: (el) => listeners.focusin({ target: el }) };
}

test('the first hover turns the title into a pill, shown at once, and the browser has no title left to show', () => {
  const e = env();
  const el = new e.El({ title: 'Clear the active filter' });
  e.over(el);
  assert.equal(e.made.length, 1);
  assert.equal(e.made[0].text, 'Clear the active filter');
  assert.equal(e.made[0].shown, 1);
  assert.equal(el.getAttribute('title'), null);
  assert.equal(e.made[0].opts.container, 'body');
});

test('the focus does the same (keyboard)', () => {
  const e = env();
  e.focus(new e.El({ title: 'Sign out' }));
  assert.equal(e.made.length, 1);
});

test('the title of a child element counts: the pointer lands on an icon inside the button', () => {
  const e = env();
  const btn = new e.El({ title: 'Copy' }), icon = new e.El({}, 'i');
  icon.parent = btn;
  e.over(icon);
  assert.equal(e.made.length, 1);
  assert.equal(e.made[0].el, btn);
});

test('a second hover, with no title left, makes nothing more', () => {
  const e = env();
  const el = new e.El({ title: 'Stats' });
  e.over(el); e.over(el); e.over(el);
  assert.equal(e.made.length, 1);
});

test('a title the page changed meanwhile is used, not the old text', () => {
  const e = env();
  const el = new e.El({ title: 'Collapse sidebar' });
  e.over(el);
  el.setAttribute('title', 'Expand sidebar'); // what head.js does
  e.over(el);
  assert.equal(e.made.length, 2);
  assert.equal(e.made[1].text, 'Expand sidebar');
  assert.equal(e.instances.get(el), e.made[1], 'one instance per element');
});

test('empty titles, frames, SVG, popovers and what opts out are left alone', () => {
  const e = env();
  e.over(new e.El({ title: '' }));
  e.over(new e.El({ title: 'x' }, 'iframe'));
  e.over(new e.El({ title: 'x' }, 'svg'));
  e.over(new e.El({ title: 'x', rel: 'popover' }));
  e.over(new e.El({ title: 'x', 'data-no-pill': '' }));
  e.over(new e.El({}));
  e.over({}); // not an element
  assert.equal(e.made.length, 0);
});

test('on a touch screen nothing is installed: a tap would leave the pill on screen', () => {
  const e = env({ hover: false });
  assert.deepEqual(Object.keys(e.listeners), []);
});

test('without Bootstrap the browser keeps its own tooltips and nothing throws', () => {
  const e = env({ bootstrap: false });
  const el = new e.El({ title: 'Stats' });
  e.over(el);
  assert.equal(el.getAttribute('title'), 'Stats');
});

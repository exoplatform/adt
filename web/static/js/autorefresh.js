// Keeps the dashboard up to date WITHOUT reloading it. When the server says something changed (a deployment, pushed
// on the /ws socket, see live.js), when the socket came back after a loss, and as a slow safety net, the page asks
// the server for its own URL again (with its own cookies: every access rule applies to what comes back, nothing about
// the page travels on the socket) and swaps the parts that changed: the figures at the top and each section of
// instances. Scroll position, search, view, sort, favorites, bells, open menus and focus stay as they are.
//
// A part is left alone while the person is using it (a modal is open, a field has the focus, a details control or a
// menu is open, some text is selected in it) and tried again shortly. Nothing is fetched while the tab is hidden: it
// is done when the tab is shown again.
//
// The status of an instance (up, down) is not pushed: the safety net looks every 10 minutes while the socket is open,
// every 2 minutes without it (blocked by a proxy, server restarting).
(function() {
  var NO_SOCKET = 120000, SAFETY_NET = 600000, RETRY = 15000, MIN_GAP = 10000, AFTER_DEPLOY = 2000;

  // What to do with the parts of one kind, in order. live: [{sig, busy}] (what is on the page: the signature of the HTML
  // the server sent for it, and whether the person is using it), fresh: [signature] (what the server sends now).
  // Returns, per index: keep (same), replace, insert (new part), remove (gone), skip (changed but in use: later).
  function plan(live, fresh) {
    var ops = [], n = Math.max(live.length, fresh.length);
    for (var i = 0; i < n; i++) {
      if (i >= live.length) ops.push('insert');
      else if (i >= fresh.length) ops.push(live[i].busy ? 'skip' : 'remove');
      else if (live[i].sig === fresh[i]) ops.push('keep');
      else ops.push(live[i].busy ? 'skip' : 'replace');
    }
    return ops;
  }
  // How long the page may go without looking: long while the socket tells it what happens
  function interval(connected) { return connected ? SAFETY_NET : NO_SOCKET; }
  // When to look, given the last time (ms) and the wait asked for: never sooner than MIN_GAP after the last time
  function delay(now, last, wait) { return Math.max(wait, MIN_GAP - (now - last)); }

  // What the answer to the page's own URL means: "signedout" (redirect, 401/403: the page itself is needed, the login
  // page comes back), "apply" (an HTML page), "ignore" (server trouble, anything else: keep what is shown)
  function classify(type, status, contentType) {
    if (type === 'opaqueredirect' || status === 401 || status === 403) return 'signedout';
    if (status < 200 || status > 299) return 'ignore';
    return /text\/html/.test(contentType || '') ? 'apply' : 'ignore';
  }

  var core = { plan: plan, interval: interval, delay: delay, classify: classify, AFTER_DEPLOY: AFTER_DEPLOY };
  if (typeof module !== 'undefined' && module.exports) { module.exports = core; return; } // the unit tests

  // The copy kept for when the server is down (see sw.js) does not update itself: js/offline.js brings the live page
  // back when the server answers again
  if (document.querySelector('meta[name="adt-offline"]')) return;
  var live = window.adtLive;
  var KINDS = ['.bento', '.instances-section'];
  var sigs = new WeakMap(); // part of the page -> signature of the HTML the server sent for it
  var last = Date.now(), timer = null, inflight = false, dirty = false;

  function main() { return document.getElementById('main'); }
  function parts(root, kind) { return [].slice.call(root.querySelectorAll(':scope > ' + kind)); }
  // Taken before any script decorates the page. This script runs in <head>, where #main does not exist yet: everything
  // starts on DOMContentLoaded, and this listener is registered before the one of head.js (which decorates).
  function snapshot() {
    var m = main();
    if (m) KINDS.forEach(function(k) { parts(m, k).forEach(function(el) { sigs.set(el, el.outerHTML); }); });
  }

  function inUse(el) {
    if (document.querySelector('.modal.show')) return true;
    if (el.querySelector('details[open], .dropdown-menu.show, .collapse.show .form-control:focus')) return true;
    var a = document.activeElement;
    if (a && el.contains(a) && /^(INPUT|TEXTAREA|SELECT)$/.test(a.tagName)) return true;
    var sel = window.getSelection && window.getSelection();
    return !!(sel && !sel.isCollapsed && sel.anchorNode && el.contains(sel.anchorNode));
  }

  // Swaps what changed; returns {changed, skipped}
  function apply(fresh) {
    var m = main(), fm = fresh.getElementById('main'), out = { changed: false, skipped: false };
    KINDS.forEach(function(kind) {
      var liveEls = parts(m, kind), freshEls = parts(fm, kind);
      var ops = plan(liveEls.map(function(el) { return { sig: sigs.get(el), busy: inUse(el) }; }),
                     freshEls.map(function(el) { return el.outerHTML; }));
      var prev = liveEls.length ? null : (m.querySelector(kind === '.bento' ? '.page-header' : '.instances-search, .bento, .page-header'));
      ops.forEach(function(op, i) {
        var el = liveEls[i], next;
        if (op === 'skip') { out.skipped = true; prev = el; return; }
        if (op === 'keep') { prev = el; return; }
        if (op === 'remove') { disposeOverlays(el); el.remove(); out.changed = true; return; }
        next = document.importNode(freshEls[i], true);
        sigs.set(next, freshEls[i].outerHTML);
        if (op === 'replace') { disposeOverlays(el); el.replaceWith(next); }
        else if (prev) prev.after(next); else m.prepend(next);
        prev = next;
        out.changed = true;
      });
    });
    return out;
  }
  function disposeOverlays(el) { if (window.adtDisposeOverlays) window.adtDisposeOverlays(el); }

  function refresh() {
    if (inflight) return;
    if (document.visibilityState === 'hidden') { dirty = true; return; }
    inflight = true;
    dirty = false;
    last = Date.now();
    fetch(location.pathname + location.search, { credentials: 'same-origin', cache: 'no-store', redirect: 'manual', headers: { Accept: 'text/html' } })
      .then(function(r) {
        var what = classify(r.type, r.status, r.headers.get('content-type'));
        // Signed out (session expired or evicted): the one case that needs the page itself, the login page comes back
        if (what === 'signedout') { window.location.assign(location.href); return null; }
        return what === 'apply' ? r.text() : null; // else server trouble: keep what is shown
      })
      .then(function(html) {
        if (!html) return;
        var doc = new DOMParser().parseFromString(html, 'text/html');
        // The service worker answers with the saved copy when the server is down: that is not news
        if (doc.querySelector('meta[name="adt-offline"]') || !doc.getElementById('main')) return;
        var r = apply(doc);
        if (r.skipped) dirty = true; // in use: the check below tries again
        if (r.changed && window.adtAfterSwap) window.adtAfterSwap();
      })
      .catch(function() { /* unreachable: the page stays as it is, the next trigger tries again */ })
      .then(function() { inflight = false; });
  }
  window.adtRefresh = refresh;

  // After wait ms, and never sooner than MIN_GAP after the last look: a night of deployments must not make every open
  // dashboard ask the server (which queries all the acceptance servers) after each one. Requests meanwhile merge.
  function soon(wait) {
    if (timer) return;
    timer = setTimeout(function() { timer = null; refresh(); }, delay(Date.now(), last, wait));
  }
  function start() {
    snapshot();
    if (!main()) return;
    if (live) {
      // A short wait: the server has dropped its cached lists when it announced the deployment
      live.on('deployed', function() { soon(AFTER_DEPLOY); });
      live.on('reconnect', function() { soon(0); });
    }
    // Checked often rather than with one long timer: a timer of a background tab can be throttled or frozen
    setInterval(function() {
      if (Date.now() - last >= interval(live && live.connected())) soon(0);
      else if (dirty && document.visibilityState === 'visible') soon(0);
    }, RETRY);
    document.addEventListener('visibilitychange', function() { if (document.visibilityState === 'visible' && dirty) soon(0); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();

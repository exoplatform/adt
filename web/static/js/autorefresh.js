// Keeps the dashboard up to date WITHOUT reloading it. When the server says something changed (a deployment, pushed
// on the /ws socket, see live.js), when the socket came back after a loss, and as a slow safety net, the page asks
// the server for its own URL again (with its own cookies: every access rule applies to what comes back, nothing about
// the page travels on the socket) and swaps the parts that changed: the figures at the top, each section of instances,
// each section of feature branches. Scroll position, search, filters, view, sort, favorites, bells, open menus and focus stay
// as they are: what a page decorates its parts with is applied again by its own hook (head.js adtAfterSwap, features.js
// adtPageAfterSwap).
//
// A part is left alone while the person is using it (a modal is open, a field has the focus, a details control or a
// menu is open, some text is selected in it) and tried again shortly. Nothing is fetched while the tab is hidden: it
// is done when the tab is shown again.
//
// The status of an instance (up, down) is not pushed: the safety net looks every 10 minutes while the socket is open,
// every 2 minutes without it (blocked by a proxy, server restarting). A change of the feature branches is announced by the
// server ("branches": adt.sh fetched the repositories).
//
// A page that cannot be updated part by part sets window.adtLiveMode = 'reload' in its own script: it is then reloaded whole
// when idle, every 2 minutes, as every page used to be (STOPGAP: the Git Activity page, see git_activity.js for what is
// missing). A page with nothing to swap and no mode (Servers polls its own data) is left alone: no fetch for nothing.
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

  // The parts of one kind, in document order, wherever they are under #main: the home page keeps them directly in #main,
  // the QA, Sales, Company and Customers pages inside .container-fluid > .row > .col-12
  function parts(root, kind) { return [].slice.call(root.querySelectorAll(kind)); }

  var core = { parts: parts, plan: plan, interval: interval, delay: delay, classify: classify, AFTER_DEPLOY: AFTER_DEPLOY };
  if (typeof module !== 'undefined' && module.exports) { module.exports = core; return; } // the unit tests

  // The copy kept for when the server is down (see sw.js) does not update itself: js/offline.js brings the live page
  // back when the server answers again
  if (document.querySelector('meta[name="adt-offline"]')) return;
  var live = window.adtLive;
  var KINDS = ['.bento', '.instances-section', '.features-section'];
  var sigs = new WeakMap(); // part of the page -> signature of the HTML the server sent for it
  var last = Date.now(), timer = null, inflight = false, dirty = false;

  function main() { return document.getElementById('main'); }
  // The page of the features says so itself (data-live="features"): with no branch at all it has no section and no filters,
  // and must still listen, to show the first branch when it comes
  function featuresPage() { var m = main(); return !!m && m.getAttribute('data-live') === 'features'; }
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
        else {
          // The first part of its kind: where the fresh page has it, after the element it follows there (when that one is on the
          // page too: the section of features comes after #featuresNoMatch), else after the header
          var before = freshEls[i].previousElementSibling, anchor = before && before.id && document.getElementById(before.id);
          if (!liveEls.length && anchor) prev = anchor;
          if (prev) prev.after(next); else m.prepend(next);
        }
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
        // The page of the features goes from "no branch" to some (or back): its filters and sections do not exist on one side,
        // there is nothing to swap part by part. The page is loaded again, once nobody is using it.
        if (featuresPage() && main().getAttribute('data-state') !== doc.getElementById('main').getAttribute('data-state')) {
          if (busy()) dirty = true; else window.location.reload();
          return;
        }
        var r = apply(doc);
        if (r.skipped) dirty = true; // in use: the check below tries again
        if (r.changed && window.adtAfterSwap) window.adtAfterSwap(doc);
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
  // Busy with the page: a modal, a field, an editor open (the reload of the stopgap waits for it as the swaps do)
  function busy() {
    var a = document.activeElement;
    return document.visibilityState === 'hidden' || document.querySelector('.modal.show') ||
      document.querySelector('.feature-more[open], .feature-base[open]') || (a && /^(INPUT|TEXTAREA|SELECT)$/.test(a.tagName));
  }

  // A small dot to the right of the page title says whether the page is kept up to date: green while the live channel
  // is open (hovering it says the person does not need to refresh), amber when it has been down for a while (the page then
  // looks every 2 minutes instead of being told, and reconnects by itself). A short loss (a restart, a reconnection) does
  // not turn it amber. Only the pages that use the channel have it (this runs only where the parts are swapped).
  var DOWN_AFTER = 10000;
  function healthText(up, since) {
    return up ? 'Live: this page updates by itself. No need to refresh it.' :
      'Live updates paused since ' + since.toLocaleTimeString() + ': reconnecting by itself, checking every 2 minutes. No need to refresh it.';
  }
  function watchHealth(l) {
    var el = null, tip = null, timer = null, since = null, isUp = true;
    function show(up) {
      isUp = up;
      if (!el) {
        el = document.createElement('div');
        el.setAttribute('role', 'status');
        el.tabIndex = 0;
        // To the right of the page title; in a corner of the page when it has none
        var title = document.querySelector('.page-header__title');
        if (title) title.appendChild(el);
        else { el.classList.add('live-status--corner'); document.body.appendChild(el); }
        // The text is a pill like every title of the pages (see pills.js). Given as a function: it is read each time the
        // pill opens, so it follows the state. Without Bootstrap, the browser's own tooltip.
        if (window.bootstrap && window.bootstrap.Tooltip) {
          tip = new window.bootstrap.Tooltip(el, {
            title: function() { return healthText(isUp, since || new Date()); },
            placement: title ? 'right' : 'left', container: 'body', trigger: 'hover focus'
          });
        }
      }
      el.classList.add('live-status');
      el.classList.toggle('live-status--up', up);
      el.classList.toggle('live-status--down', !up);
      var text = healthText(up, since || new Date());
      el.setAttribute('aria-label', text);
      if (!tip) el.title = text;
    }
    function down() {
      if (timer) return;
      since = new Date();
      timer = setTimeout(function() { timer = null; show(false); }, DOWN_AFTER);
    }
    function up() { clearTimeout(timer); timer = null; since = null; show(true); }
    l.on('state', function(m) { if (m.up) up(); else down(); });
    if (l.connected()) up(); else down(); // not open yet: the same wait before it is amber
  }

  function start() {
    snapshot();
    if (!main()) return;
    // STOPGAP for the pages that cannot be swapped part by part (window.adtLiveMode = 'reload'): reload when idle, as before
    if (window.adtLiveMode === 'reload') {
      setTimeout(function again() {
        if (busy()) { setTimeout(again, RETRY); return; }
        window.location.reload();
      }, NO_SOCKET);
      return;
    }
    // Nothing to swap on this page (Servers refreshes its own data): do not ask the server for a page that changes nothing
    if (!featuresPage() && !main().querySelector(KINDS.join(',') + ', #featureFilters')) return;
    if (live) {
      // A short wait: the server has dropped its cached lists when it announced the deployment
      live.on('deployed', function() { soon(AFTER_DEPLOY); });
      // adt.sh fetched the repositories and says which ones moved: the feature branches changed. Only the page that lists them cares
      // (the cards of the instances do not show them): asking the server for a page that cannot have changed would be load for nothing
      if (featuresPage() || main().querySelector('.features-section, #featureFilters')) live.on('branches', function() { soon(AFTER_DEPLOY); });
      live.on('reconnect', function() { soon(0); });
      watchHealth(live);
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

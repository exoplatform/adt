// Fill the status dots from the server endpoint (GitHub Actions API, cached
// and rate-limit aware), a few requests at a time. When it has no result,
// fall back to the shields.io badge JSON: its first lookup can time out while
// it cold-fetches from GitHub but is fast right after, so retry that once.
(function () {
  // Each status is shown in both views: fetch every URL once, update all its links
  var byUrl = {};
  document.querySelectorAll('.crowdin-status[data-status-url]').forEach(function (link) {
    var url = link.getAttribute('data-status-url');
    (byUrl[url] = byUrl[url] || []).push(link);
  });
  var links = Object.keys(byUrl).map(function (url) { return byUrl[url]; });
  var CONCURRENCY = 6;
  // A hung request must not keep one of the CONCURRENCY slots forever
  function get(url) {
    var opts = window.AbortSignal && AbortSignal.timeout ? { signal: AbortSignal.timeout(20000) } : {};
    return fetch(url, opts).then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.json();
    });
  }
  function level(status) {
    var color = (status.color || '').toLowerCase(), message = (status.message || '').toLowerCase();
    if (message === 'passing') return 'ok';
    if (message === 'failing') return 'fail';
    // e.g. "repo or workflow not found" (red) or "no status": not a build failure
    if (/not found|no status|invalid|inaccessible/.test(message)) return 'unknown';
    if (color === 'brightgreen' || color === 'green') return 'ok';
    if (color === 'red' || color === 'critical') return 'fail';
    if (color === 'yellow' || color === 'orange' || color === 'important') return 'warn';
    return 'unknown';
  }
  function show(group, cls, message) {
    group.forEach(function (link) {
      link.querySelector('.status-dot').className = 'status-dot ' + cls;
      link.title = link.getAttribute('data-title') + ': ' + message;
    });
    scheduleUpdate();
  }
  // update() walks the whole page: once per animation frame at most, not once per answer
  var updateQueued = false;
  function scheduleUpdate() {
    if (updateQueued) return;
    updateQueued = true;
    requestAnimationFrame(function () { updateQueued = false; update(); });
  }

  // Summary counts and "Failing only" filter (saved per browser)
  var grid = document.querySelector('.crowdin-cards');
  var table = document.querySelector('.crowdin-table');
  var failingBtn = document.getElementById('crowdinFailingOnly');
  var failingOnly = getPref('crowdin-failing-only', '0') === '1';
  function update() {
    if (!grid) return;
    var counts = {};
    grid.querySelectorAll('.crowdin-status .status-dot').forEach(function (dot) {
      var cls = dot.className.replace('status-dot', '').trim();
      counts[cls] = (counts[cls] || 0) + 1;
    });
    document.querySelectorAll('.crowdin-summary [data-count]').forEach(function (b) {
      b.textContent = counts[b.getAttribute('data-count')] || 0;
    });
    document.querySelectorAll('.crowdin-summary [data-if]').forEach(function (el) {
      el.classList.toggle('d-none', !counts[el.getAttribute('data-if')]);
    });
    failingBtn.classList.toggle('active', failingOnly);
    failingBtn.setAttribute('aria-pressed', failingOnly ? 'true' : 'false');
    var visible = 0, chips = grid.querySelectorAll('.project-chip');
    chips.forEach(function (chip) {
      var failing = 0;
      chip.querySelectorAll('.crowdin-status').forEach(function (pill) {
        var isFail = !!pill.querySelector('.status-dot.fail');
        if (isFail) failing++;
        pill.classList.toggle('d-none', failingOnly && !isFail);
      });
      chip.querySelectorAll('.crowdin-branch-group').forEach(function (group) {
        group.classList.toggle('d-none', failingOnly && !group.querySelector('.crowdin-status:not(.d-none)'));
      });
      var show = !failingOnly || failing > 0;
      chip.classList.toggle('d-none', !show);
      if (show) visible++;
    });
    // Table rows: same rule, non-failing cells blanked
    table.querySelectorAll('tbody tr').forEach(function (row) {
      var failing = 0;
      row.querySelectorAll('td').forEach(function (cell) {
        var isFail = !!cell.querySelector('.status-dot.fail');
        if (isFail) failing++;
        cell.classList.toggle('cell-nomatch', failingOnly && !isFail && cell.querySelector('.crowdin-status'));
      });
      row.classList.toggle('d-none', failingOnly && !failing);
    });
    var badge = document.getElementById('crowdinModulesCount');
    badge.textContent = visible == chips.length ? chips.length : visible + ' / ' + chips.length;
    var loading = counts['is-loading'] || 0;
    document.getElementById('crowdinNoFailure').classList.toggle('d-none', !(failingOnly && visible === 0 && !loading));
  }
  // Cards/Table view switch, saved per browser
  var viewBtns = document.querySelectorAll('.crowdin-toolbar [data-view]');
  function applyView(view) {
    document.documentElement.classList.toggle('crowdin-table-view', view === 'table');
    viewBtns.forEach(function (b) {
      var on = b.getAttribute('data-view') === view;
      b.classList.toggle('active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  }
  viewBtns.forEach(function (b) {
    b.addEventListener('click', function () {
      setPref('crowdin-view', this.getAttribute('data-view'));
      applyView(this.getAttribute('data-view'));
    });
  });
  applyView(getPref('crowdin-view', 'cards'));
  if (failingBtn) {
    failingBtn.addEventListener('click', function () {
      failingOnly = !failingOnly;
      setPref('crowdin-failing-only', failingOnly ? '1' : '0');
      update();
    });
  }
  update();
  function loadBadge(link, retried) {
    return get(link[0].getAttribute('data-fallback-url')).then(function (status) {
      show(link, level(status), (status.message || 'unknown') + ' (badge)');
    }).catch(function () {
      if (!retried) return new Promise(function (res) { setTimeout(res, 3000); }).then(function () { return loadBadge(link, true); });
      show(link, 'unknown', 'status unavailable');
    });
  }
  function load(link) {
    return get(link[0].getAttribute('data-status-url')).then(function (status) {
      if (!status.level) return loadBadge(link, false);
      show(link, status.level, status.message || 'unknown');
    }).catch(function () {
      return loadBadge(link, false);
    });
  }
  function next() {
    var link = links.shift();
    if (link) return load(link).then(next);
  }
  for (var i = 0; i < CONCURRENCY; i++) next();
})();

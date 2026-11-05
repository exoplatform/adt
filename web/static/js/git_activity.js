document.addEventListener('DOMContentLoaded', function() {
  // the numbers of the page, written by the server as JSON
  var chartData = JSON.parse(document.getElementById('chartData').textContent);

  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[rel=tooltip]'));
  tooltipTriggerList.map(function(tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl);
  });

  // Dependency explorer: filter and sort the repository cards, select one to light up what it depends on, what uses it
  // and what is affected indirectly. The lists come from the data attributes written by the server.
  (function() {
    var root = document.getElementById('depExplorer');
    var grid = root && root.querySelector('.dep-grid');
    if (!grid) return;
    var detail = document.getElementById('depDetail'), search = root.querySelector('.dep-search__input');
    var count = root.querySelector('.dep-count'), repos = {}, cards = [].slice.call(grid.querySelectorAll('.dep-card'));
    var split = function(v) { return v ? v.split(' ') : []; };
    cards.forEach(function(el) {
      repos[el.dataset.repo] = { el: el, label: el.dataset.label, deps: split(el.dataset.deps), used: split(el.dataset.used) };
    });
    // every repository reached by following `key` (deps or used) from `start`, without `start` itself
    function closure(start, key) {
      var seen = {}, out = [], todo = [start];
      while (todo.length) {
        var n = repos[todo.pop()];
        if (!n) continue;
        n[key].forEach(function(r) { if (!seen[r] && r !== start && repos[r]) { seen[r] = true; out.push(r); todo.push(r); } });
      }
      return out;
    }
    var byLabel = function(a, b) { return repos[a].label.localeCompare(repos[b].label, undefined, { sensitivity: 'base' }); };
    function chips(parent, names, cls) {
      names.sort(byLabel).forEach(function(r) {
        var a = document.createElement('a');
        a.href = '#repo-' + r; a.className = 'dep-chip dep-chip--' + cls; a.textContent = repos[r].label;
        parent.appendChild(a);
      });
    }
    function group(parent, title, names, cls) {
      if (!names.length) return;
      var g = document.createElement('div'), l = document.createElement('span');
      g.className = 'dep-detail__group'; l.className = 'dep-detail__label'; l.textContent = title + ' (' + names.length + ')';
      g.appendChild(l); chips(g, names, cls); parent.appendChild(g);
    }
    var current = '';
    function clear() {
      current = '';
      root.classList.remove('has-selection');
      cards.forEach(function(el) { el.classList.remove('is-selected', 'is-dep', 'is-used', 'is-indirect'); });
      detail.hidden = true; detail.textContent = '';
    }
    function select(name, scroll) {
      var n = repos[name];
      if (!n) return clear();
      clear();
      current = name;
      var allDeps = closure(name, 'deps'), allUsed = closure(name, 'used');
      var indirect = allUsed.filter(function(r) { return n.used.indexOf(r) < 0; });
      root.classList.add('has-selection');
      n.el.classList.add('is-selected');
      n.deps.forEach(function(r) { if (repos[r]) repos[r].el.classList.add('is-dep'); });
      n.used.forEach(function(r) { repos[r].el.classList.add('is-used'); });
      indirect.forEach(function(r) { repos[r].el.classList.add('is-indirect'); });
      var top = document.createElement('div'), h = document.createElement('div'), sum = document.createElement('span'), x = document.createElement('button');
      top.className = 'dep-detail__top'; h.className = 'dep-detail__title'; h.textContent = n.label;
      sum.className = 'dep-detail__sum';
      sum.textContent = 'Depends on ' + n.deps.length + ' (' + allDeps.length + ' in all) · used by ' + n.used.length + ' · changing it can affect ' + allUsed.length + ' repositories';
      x.type = 'button'; x.className = 'dep-detail__close'; x.textContent = 'Clear (Esc)';
      x.addEventListener('click', function() { history.replaceState(null, '', location.pathname + location.search); clear(); });
      top.appendChild(h); top.appendChild(sum); top.appendChild(x);
      detail.appendChild(top);
      group(detail, 'Depends on', n.deps.filter(function(r) { return repos[r]; }), 'dep');
      group(detail, 'Used by', n.used.slice(), 'used');
      group(detail, 'Indirectly affected', indirect, 'indirect');
      if (!n.deps.length && !n.used.length) {
        var p = document.createElement('span'); p.className = 'dep-detail__sum'; p.textContent = 'No link with the other repositories.'; detail.appendChild(p);
      }
      detail.hidden = false;
      if (scroll) n.el.scrollIntoView({ block: 'center', behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
    }
    function go(name) { history.replaceState(null, '', '#repo-' + name); select(name, true); }

    grid.addEventListener('click', function(e) {
      if (e.target.closest('.dep-card__gh')) return; // the GitHub link opens the repository
      var chip = e.target.closest('.dep-chip');
      if (chip) { e.preventDefault(); go(chip.getAttribute('href').slice(6)); return; }
      var card = e.target.closest('.dep-card');
      if (card) card.dataset.repo === current ? (history.replaceState(null, '', location.pathname + location.search), clear()) : go(card.dataset.repo);
    });
    detail.addEventListener('click', function(e) {
      var chip = e.target.closest('.dep-chip');
      if (chip) { e.preventDefault(); go(chip.getAttribute('href').slice(6)); }
    });
    grid.addEventListener('keydown', function(e) {
      var card = e.target.closest('.dep-card');
      if ((e.key === 'Enter' || e.key === ' ') && card && e.target === card) { e.preventDefault(); go(card.dataset.repo); }
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && current && !e.defaultPrevented) { history.replaceState(null, '', location.pathname + location.search); clear(); }
    });

    function update() {
      var q = search.value.trim().toLowerCase(), shown = 0;
      cards.forEach(function(el) {
        var hit = !q || el.dataset.label.toLowerCase().indexOf(q) >= 0;
        el.hidden = !hit;
        if (hit) shown++;
      });
      count.textContent = shown === cards.length ? cards.length + ' repositories' : shown + ' of ' + cards.length;
    }
    search.addEventListener('input', update);
    root.querySelector('.dep-sort').addEventListener('click', function(e) {
      var b = e.target.closest('[data-sort]');
      if (!b) return;
      [].forEach.call(root.querySelectorAll('[data-sort]'), function(o) { o.classList.toggle('active', o === b); });
      var key = b.dataset.sort;
      cards.sort(function(a, c) {
        var A = repos[a.dataset.repo], C = repos[c.dataset.repo];
        var d = key === 'used' ? C.used.length - A.used.length : key === 'deps' ? C.deps.length - A.deps.length : 0;
        return d || byLabel(a.dataset.repo, c.dataset.repo);
      }).forEach(function(el) { grid.appendChild(el); });
    });
    function fromHash() { if (location.hash.indexOf('#repo-') === 0) select(decodeURIComponent(location.hash.slice(6)), true); }
    window.addEventListener('hashchange', fromHash);
    update();
    fromHash();
  })();

  var chartColors = {
    primary: getComputedStyle(document.documentElement).getPropertyValue('--secondary-color').trim() || '#3498db',
    success: getComputedStyle(document.documentElement).getPropertyValue('--success-color').trim() || '#27ae60',
    warning: getComputedStyle(document.documentElement).getPropertyValue('--warning-color').trim() || '#f39c12',
    danger: getComputedStyle(document.documentElement).getPropertyValue('--danger-color').trim() || '#e74c3c',
    info: getComputedStyle(document.documentElement).getPropertyValue('--info').trim() || '#54a0ff',
    accent2: getComputedStyle(document.documentElement).getPropertyValue('--accent2').trim() || '#00d2d3',
    text: getComputedStyle(document.documentElement).getPropertyValue('--text-muted').trim() || '#6c757d',
    cardBg: getComputedStyle(document.documentElement).getPropertyValue('--card-bg').trim() || '#ffffff',
    gridColor: getComputedStyle(document.documentElement).getPropertyValue('--border-color').trim() || '#dee2e6'
  };
  var trendPalette = [chartColors.primary, chartColors.accent2, chartColors.success, chartColors.warning, chartColors.danger];

  function hexToRgb(hex) {
    var r = parseInt(hex.slice(1,3), 16), g = parseInt(hex.slice(3,5), 16), b = parseInt(hex.slice(5,7), 16);
    return r+','+g+','+b;
  }

  new Chart(document.getElementById('commitsChart'), {
    type: 'bar',
    data: {
      labels: chartData.labels,
      datasets: [{
        label: 'Commits',
        data: chartData.activity,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.primary) + ', 0.6)',
        borderColor: chartColors.primary,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { maxTicksLimit: 15, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });

  var repoTrendDates = chartData.trendDates;
  var repoTrendSeries = chartData.trendSeries;
  new Chart(document.getElementById('repoTrendChart'), {
    type: 'line',
    data: {
      labels: repoTrendDates,
      datasets: Object.keys(repoTrendSeries).map(function(label, i) {
        var color = trendPalette[i % trendPalette.length];
        return {
          label: label,
          data: repoTrendSeries[label],
          borderColor: color,
          backgroundColor: 'rgba(' + hexToRgb(color) + ', 0.15)',
          borderWidth: 2,
          pointRadius: 0,
          tension: 0,
          fill: false
        };
      })
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: true, position: 'bottom', labels: { color: chartColors.text, boxWidth: 12 } } },
      scales: {
        x: { ticks: { maxTicksLimit: 15, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });

  new Chart(document.getElementById('repoChart'), {
    type: 'bar',
    data: {
      labels: chartData.repoLabels,
      datasets: [{
        label: 'Commits',
        data: chartData.repoCommits,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.success) + ', 0.6)',
        borderColor: chartColors.success,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { ticks: { font: { size: 10 }, color: chartColors.text }, grid: { display: false } }
      }
    }
  });

  new Chart(document.getElementById('authorChart'), {
    type: 'bar',
    data: {
      labels: chartData.authors,
      datasets: [{
        label: 'Commits',
        data: chartData.authorCommits,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.warning) + ', 0.6)',
        borderColor: chartColors.warning,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { ticks: { font: { size: 10 }, color: chartColors.text }, grid: { display: false } }
      }
    }
  });

  new Chart(document.getElementById('dowChart'), {
    type: 'bar',
    data: {
      labels: chartData.dowLabels,
      datasets: [{
        label: 'Commits',
        data: chartData.dowValues,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.info) + ', 0.6)',
        borderColor: chartColors.info,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });
});

/* Live usage: polled from /server-stats every 30s while the page is visible */
(function () {
    var GB = 1024 * 1024; // kB per GB
    var TOP = 3;
    var expandedHosts = {}; // JVM list toggles, kept across refreshes
    // The numbers and names come from the other acceptance servers: escape them (quotes too, they go into attributes)
    function esc(v) {
        return (v == null ? '' : String(v)).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }
    function num(v) { v = Number(v); return isFinite(v) ? v : 0; }
    function level(pct) { return pct >= 85 ? 'crit' : (pct >= 70 ? 'warn' : ''); }
    function fmt(v, digits) { return num(v).toFixed(digits === undefined ? 1 : digits); }
    function meterRow(icon, label, pct, value, title) {
        var p = Math.max(0, Math.min(100, pct)), l = level(pct);
        return '<div class="server-live__row"' + (title ? ' title="' + esc(title) + '"' : '') + '>'
            + '<span class="server-live__label"><i class="fas ' + icon + ' me-1"></i>' + label + '</span>'
            + '<span class="server-live__value"><span>' + value + '</span><span class="pct ' + l + '">' + Math.round(pct) + '%</span></span>'
            + '<div class="usage-meter"><div class="usage-meter__fill ' + l + '" style="width:' + p + '%"></div></div></div>';
    }
    function toggleLabel(expanded, count) {
        return expanded ? '<i class="fas fa-chevron-up me-1"></i>Show less' : '<i class="fas fa-chevron-down me-1"></i>Show all ' + count;
    }
    function uptime(s) {
        var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600);
        return d > 0 ? d + 'd ' + h + 'h' : h + 'h ' + Math.floor(s % 3600 / 60) + 'm';
    }
    function render(card, st) {
        var box = card.querySelector('.server-live');
        if (!st || st.error) {
            box.innerHTML = '<div class="server-live__footer"><span class="server-live__error"><i class="fas fa-exclamation-triangle me-1"></i>Live usage unavailable</span></div>';
            return;
        }
        var html = '';
        if (st.mem) {
            var memTotal = st.mem.total_kb / GB;
            html += meterRow('fa-memory', 'RAM', st.mem.used_kb / st.mem.total_kb * 100,
                fmt(st.mem.used_kb / GB) + ' / ' + fmt(memTotal) + ' GB', 'Used memory (excluding cache/buffers)');
            var j = st.jvm;
            if (j && j.readable) {
                html += meterRow('fa-layer-group', 'JVMs', j.rss_kb / st.mem.total_kb * 100,
                    fmt(j.rss_kb / GB) + ' GB &middot; ' + num(j.running) + ' running',
                    'Resident memory of running instance JVMs, out of total RAM (Xmx of running: ' + fmt(j.xmx_gb) + ' GB)');
            }
            if (st.mem.swap_total_kb > 0 && st.mem.swap_used_kb > 0) {
                html += meterRow('fa-exchange-alt', 'Swap', st.mem.swap_used_kb / st.mem.swap_total_kb * 100,
                    fmt(st.mem.swap_used_kb / GB) + ' / ' + fmt(st.mem.swap_total_kb / GB) + ' GB');
            }
        }
        if (st.load && st.cpu && st.cpu.threads) {
            html += meterRow('fa-microchip', 'Load', st.load[0] / st.cpu.threads * 100,
                st.load.map(function (l) { return fmt(l, 2); }).join(' &middot; ') + ' / ' + num(st.cpu.threads) + ' thr',
                'Load average 1 / 5 / 15 min, relative to CPU threads');
        }
        if (st.disk) {
            var tb = st.disk.total_b > 1e12, unit = tb ? 1024 * 1024 * 1024 * 1024 : 1024 * 1024 * 1024;
            html += meterRow('fa-hdd', 'Disk', st.disk.used_b / st.disk.total_b * 100,
                fmt(st.disk.used_b / unit, tb ? 2 : 0) + ' / ' + fmt(st.disk.total_b / unit, tb ? 2 : 0) + (tb ? ' TB' : ' GB'), 'ADT data filesystem');
        }
        // Running JVMs, largest first: top 3, the rest behind a toggle
        // ("top"/"name" is the format of servers not yet updated)
        var jvms = st.jvm && st.jvm.readable ? (st.jvm.list || st.jvm.top || []) : [];
        if (jvms.length) {
            var expanded = !!expandedHosts[card.getAttribute('data-host')];
            html += '<ul class="server-live__top' + (expanded ? ' expanded' : '') + '">' + jvms.map(function (t, i) {
                var key = t.key || t.name;
                return '<li' + (i >= TOP ? ' class="extra"' : '') + '><a href="#instance-' + esc(key) + '" data-instance="' + esc(key) + '" title="' + esc((t.label ? t.label + ' \u2014 ' : '') + key) + '">' + esc(t.label || t.name) + '</a>'
                    + '<span title="Process memory (heap, metaspace, threads, native) &middot; configured max heap">' + fmt(num(t.rss_kb) / GB) + ' GB'
                    + (t.xmx_gb ? ' <small>&middot; heap ' + fmt(num(t.xmx_gb)) + '</small>' : '') + '</span></li>';
            }).join('') + '</ul>';
            if (jvms.length > TOP) {
                html += '<button type="button" class="server-live__toggle" data-count="' + jvms.length + '" aria-expanded="' + expanded + '">'
                    + toggleLabel(expanded, jvms.length) + '</button>';
            }
        }
        html += '<div class="server-live__footer">'
            + '<span>' + (st.uptime_s ? 'Up ' + uptime(st.uptime_s) : '') + '</span>'
            + '<span>Updated ' + new Date(st.time * 1000).toLocaleTimeString() + '</span></div>';
        box.innerHTML = html;
    }
    var loading = false; // a slow answer must not pile up requests
    function refresh() {
        if (document.visibilityState === 'hidden' || loading) return;
        loading = true;
        var opts = { cache: 'no-store' };
        if (window.AbortSignal && AbortSignal.timeout) opts.signal = AbortSignal.timeout(20000);
        fetch('/server-stats', opts).then(function (r) {
            if (!r.ok) throw new Error(r.status);
            return r.json();
        }).then(function (stats) {
            document.querySelectorAll('.server-card[data-host]').forEach(function (card) {
                render(card, stats[card.getAttribute('data-host')]);
            });
        }).catch(function () {
            document.querySelectorAll('.server-card[data-host]').forEach(function (card) { render(card, null); });
        }).then(function () { loading = false; });
    }
    document.querySelector('.server-cards').addEventListener('click', function (e) {
        var toggle = e.target.closest('.server-live__toggle');
        if (toggle) {
            // Toggle in place: rebuilding the block would make the page jump
            var card = toggle.closest('.server-card');
            var host = card.getAttribute('data-host');
            var expanded = expandedHosts[host] = !expandedHosts[host];
            card.querySelector('.server-live__top').classList.toggle('expanded', expanded);
            toggle.setAttribute('aria-expanded', expanded);
            toggle.innerHTML = toggleLabel(expanded, toggle.getAttribute('data-count'));
            return;
        }
        // Jump to the instance row in the port registry and highlight it
        var link = e.target.closest('a[data-instance]');
        var row = link && document.getElementById('instance-' + link.getAttribute('data-instance'));
        if (!row) return;
        e.preventDefault();
        if (row.classList.contains('hidden')) {
            var input = document.getElementById('portRegistrySearch');
            input.value = '';
            ['filterStatus', 'filterHost', 'filterDb'].forEach(function (id) { document.getElementById(id).value = ''; });
            input.dispatchEvent(new Event('input'));
        }
        document.querySelectorAll('#portRegistryTable tr.highlight').forEach(function (r) { r.classList.remove('highlight'); });
        row.classList.add('highlight');
        row.scrollIntoView({ behavior: 'smooth', block: 'center' });
    });
    refresh();
    setInterval(refresh, 30000);
    document.addEventListener('visibilitychange', refresh);
})();

(function () {
    var input = document.getElementById('portRegistrySearch');
    var table = document.getElementById('portRegistryTable');
    if (!input || !table) return;
    var selects = {
        status: document.getElementById('filterStatus'),
        host: document.getElementById('filterHost'),
        db: document.getElementById('filterDb')
    };
    var resetBtn = document.getElementById('filterReset');
    function applyFilters() {
        var query = input.value.toLowerCase().trim();
        var visibleCountByGroup = {};
        var filtered = false;
        Object.keys(selects).forEach(function (k) { if (selects[k].value) filtered = true; });
        resetBtn.classList.toggle('d-none', !filtered);
        table.querySelectorAll('tbody > tr:not(.category-row)').forEach(function (row) {
            var match = (!query || row.textContent.toLowerCase().indexOf(query) !== -1)
                && (!selects.status.value || row.getAttribute('data-status') === selects.status.value)
                && (!selects.host.value || row.getAttribute('data-host') === selects.host.value)
                && (!selects.db.value || row.getAttribute('data-db') === selects.db.value);
            row.classList.toggle('hidden', !match);
            if (match) {
                var group = row.getAttribute('data-host-group');
                visibleCountByGroup[group] = (visibleCountByGroup[group] || 0) + 1;
            }
        });
        table.querySelectorAll('tbody > tr.category-row').forEach(function (row) {
            var group = row.getAttribute('data-host-group');
            var visible = visibleCountByGroup[group] || 0;
            row.classList.toggle('hidden', visible === 0);
            var total = row.getAttribute('data-total');
            var countEl = row.querySelector('.category-row__count');
            countEl.textContent = visible !== Number(total)
                ? visible + ' of ' + total + ' instance' + (total == 1 ? '' : 's')
                : total + ' instance' + (total == 1 ? '' : 's');
        });
    }
    input.addEventListener('input', applyFilters);
    Object.keys(selects).forEach(function (k) { selects[k].addEventListener('change', applyFilters); });
    resetBtn.addEventListener('click', function () {
        Object.keys(selects).forEach(function (k) { selects[k].value = ''; });
        applyFilters();
    });
    applyFilters();
})();

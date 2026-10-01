<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("Servers"); ?>
    <style>
        /* ── Server summary cards ───────────────────────────── */
        .server-cards {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }
        .server-card {
            background: var(--bg-surface);
            border: 1px solid var(--border-card);
            border-radius: var(--r-md);
            padding: 1.1rem 1.25rem;
            transition: box-shadow var(--dur-fast), border-color var(--dur-fast), transform var(--dur-fast);
            border-top: 4px solid var(--card-accent, #6c757d);
        }
        .server-card:hover {
            border-color: var(--border-active);
            box-shadow: var(--shadow-card);
            transform: translateY(-2px);
        }
        .server-card__header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: .75rem;
        }
        .server-card__hostname {
            font-size: .78rem;
            color: var(--text-muted);
            font-family: 'Courier New', monospace;
            word-break: break-all;
        }
        .server-card__name {
            font-weight: 700;
            font-size: 1.05rem;
            color: var(--card-accent, #6c757d);
        }
        .server-card__badge {
            display: inline-flex;
            align-items: center;
            gap: .3rem;
            background: color-mix(in srgb, var(--card-accent, #6c757d) 16%, transparent);
            color: var(--card-accent, #6c757d);
            border: 1px solid color-mix(in srgb, var(--card-accent, #6c757d) 35%, transparent);
            border-radius: var(--r-full);
            padding: .2rem .65rem;
            font-size: .8rem;
            font-weight: 600;
            white-space: nowrap;
        }
        .server-card__specs {
            display: grid;
            grid-template-columns: auto 1fr;
            gap: .25rem .6rem;
            font-size: .8rem;
            margin-top: .6rem;
        }
        .server-card__specs dt {
            color: var(--text-muted);
            font-weight: 500;
            white-space: nowrap;
        }
        .server-card__specs dd {
            margin: 0;
            color: var(--bs-body-color);
        }
        .jvm-range {
            display: inline-flex;
            align-items: center;
            gap: .3rem;
            font-size: .82rem;
            font-weight: 500;
        }
        .jvm-range .jvm-min { color: var(--success-color); }
        .jvm-range .jvm-max { color: var(--danger-color); }

        /* ── Live usage meters ──────────────────────────────── */
        .server-live { margin-top: .85rem; display: grid; gap: .55rem; font-size: .78rem; }
        .server-live__row { display: grid; grid-template-columns: 4.2rem 1fr; gap: .15rem .6rem; align-items: center; }
        .server-live__label { color: var(--text-muted); font-weight: 500; white-space: nowrap; grid-row: span 2; }
        .server-live__value { display: flex; justify-content: space-between; gap: .5rem; color: var(--bs-body-color); }
        .server-live__value .pct { font-weight: 700; font-variant-numeric: tabular-nums; }
        .usage-meter { height: 6px; background: var(--bg-field); border-radius: var(--r-full); overflow: hidden; }
        .usage-meter__fill { height: 100%; width: 0; background: var(--success); border-radius: inherit; transition: width var(--dur-fast); }
        .usage-meter__fill.warn { background: var(--warning); }
        .usage-meter__fill.crit { background: var(--danger); }
        .pct.warn { color: var(--warning); }
        .pct.crit { color: var(--danger); }
        .server-live__top { margin: 0; padding: 0; list-style: none; display: grid; gap: .1rem; }
        .server-live__top li { display: flex; justify-content: space-between; gap: .5rem; color: var(--text-secondary); }
        .server-live__top li a { color: inherit; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; text-decoration: none; }
        .server-live__top li a:hover { color: var(--accent); text-decoration: underline; }
        .server-live__top li span { white-space: nowrap; font-variant-numeric: tabular-nums; }
        .server-live__top li span small { color: var(--text-muted); }
        .server-live__toggle { background: none; border: 0; padding: 0; color: var(--accent); font-size: .72rem; cursor: pointer; justify-self: start; }
        .server-live__toggle:hover { text-decoration: underline; }
        .server-live__footer { color: var(--text-muted); font-size: .72rem; display: flex; justify-content: space-between; }
        .server-live__error { color: var(--danger); }

        /* Server accent colours (match color-acceptanceX in style.css) */
        .accent-acc7  { --card-accent: #9b59b6; }
        .accent-acc12 { --card-accent: #f39c12; }
        .accent-acc13 { --card-accent: #1abc9c; }
        .accent-acc14 { --card-accent: #3498db; }
        .accent-acc15 { --card-accent: #9b59b6; }
        .accent-accX  { --card-accent: #6c757d; }

        /* ── Section headers ────────────────────────────────── */
        .section-title {
            display: flex;
            align-items: center;
            gap: .5rem;
            font-size: 1rem;
            font-weight: 700;
            color: var(--primary-color);
            padding-bottom: .4rem;
            border-bottom: 2px solid var(--border-color);
            margin-bottom: 1rem;
        }
        [data-bs-theme="dark"] .section-title {
            color: var(--table-header-text);
        }

        /* ── Port badge (monospace chip) ────────────────────── */
        .port-badge {
            font-family: var(--font-mono);
            font-size: .78rem;
            background: var(--bg-field);
            border: 1px solid var(--border-card);
            border-radius: var(--r-sm);
            padding: .15rem .5rem;
            white-space: nowrap;
            color: var(--text-secondary);
        }

        /* ── Host pill ──────────────────────────────────────── */
        .host-pill {
            display: inline-block;
            padding: .15rem .55rem;
            border-radius: var(--r-full);
            font-size: .78rem;
            font-weight: 600;
            background: var(--bg-field);
            white-space: nowrap;
        }
        .host-pill.acc7  { color: #9b59b6; border: 1px solid #9b59b6; }
        .host-pill.acc12 { color: #f39c12; border: 1px solid #f39c12; }
        .host-pill.acc13 { color: #1abc9c; border: 1px solid #1abc9c; }
        .host-pill.acc14 { color: #3498db; border: 1px solid #3498db; }
        .host-pill.acc15 { color: #9b59b6; border: 1px solid #9b59b6; }
        .host-pill.accX  { color: var(--text-muted); border: 1px solid var(--border-color); }

        /* ── Port registry table ────────────────────────────── */
        /* Bootstrap paints every cell with --bs-table-bg (plain grey in dark
           mode): let the themed table background show through instead */
        #portRegistryTable {
            --bs-table-bg: transparent;
            --bs-table-color: var(--text-primary);
            --bs-table-hover-bg: var(--accent-soft);
            --bs-table-hover-color: var(--text-primary);
            --bs-table-border-color: var(--border-subtle);
        }
        /* Server groups: accent-tinted header and a left accent bar on each row */
        #portRegistryTable tr.category-row > td {
            background: color-mix(in srgb, var(--card-accent) 14%, var(--bg-elevated));
            border-top: 1px solid color-mix(in srgb, var(--card-accent) 35%, transparent);
            border-bottom: 1px solid color-mix(in srgb, var(--card-accent) 35%, transparent);
        }
        #portRegistryTable tbody tr:not(.category-row) > td:first-child {
            border-left: 3px solid color-mix(in srgb, var(--card-accent) 70%, transparent);
        }
        #portRegistryTable thead th {
            position: sticky;
            top: 0;
            z-index: 5;
        }
        /* Compact row content */
        .registry-flags { margin-top: .3rem; display: flex; flex-wrap: wrap; align-items: center; gap: .3rem; }
        .registry-flags:empty { display: none; }
        .addons-chip, .db-chip, .port-chip {
            display: inline-flex; align-items: center; gap: .3rem;
            font-size: .72rem; line-height: 1.4; white-space: nowrap;
            padding: .05rem .45rem; border-radius: var(--r-full);
            background: var(--bg-field); border: 1px solid var(--border-card); color: var(--text-secondary);
        }
        .addons-chip { cursor: help; }
        .port-chips { display: flex; flex-wrap: wrap; gap: .3rem; }
        .port-chip { font-family: var(--font-mono); }
        .port-chip__label { font-family: var(--font-sans); color: var(--text-muted); font-size: .66rem; text-transform: uppercase; letter-spacing: .03em; }
        .port-chip--odd { border-color: color-mix(in srgb, var(--warning) 60%, transparent); color: var(--warning); }
        .port-registry-version {
            display: inline-block;
            max-width: 220px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            vertical-align: bottom;
        }
    </style>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
    <div id="main" role="main">
        <div class="container-fluid">

            <!-- Page Header -->
            <div class="page-header">
                <h1 class="page-header__title">Servers</h1>
                <p class="page-header__subtitle">Acceptance server hardware overview and port registry</p>
            </div>

            <?php
            /* ── Data preparation ──────────────────────────────────── */
            $merged_list = getGlobalAcceptanceInstances();
            $descriptor_arrays = [];
            foreach ($merged_list as $tmp_array) {
                $descriptor_arrays = array_merge($descriptor_arrays, $tmp_array);
            }
            usort($descriptor_arrays, fn($a, $b) => strcmp($a->DEPLOYMENT_HTTP_PORT, $b->DEPLOYMENT_HTTP_PORT));

            $servers_counter = [];
            foreach ($descriptor_arrays as $descriptor_array) {
                $host = $descriptor_array->ACCEPTANCE_HOST;

                if (!isset($servers_counter[$host]['nb']))      $servers_counter[$host]['nb']      = 0;
                if (!isset($servers_counter[$host]['jvm-min'])) $servers_counter[$host]['jvm-min'] = 0;
                if (!isset($servers_counter[$host]['jvm-max'])) $servers_counter[$host]['jvm-max'] = 0;

                $servers_counter[$host]['nb']++;

                if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MIN, 'g')) {
                    $servers_counter[$host]['jvm-min'] += (float)str_replace('g', '', $descriptor_array->DEPLOYMENT_JVM_SIZE_MIN);
                } elseif (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MIN, 'm')) {
                    $servers_counter[$host]['jvm-min'] += (float)str_replace('m', '', $descriptor_array->DEPLOYMENT_JVM_SIZE_MIN) / 1000;
                } else {
                    error_log("The unit of DEPLOYMENT_JVM_SIZE_MIN is not managed ({$descriptor_array->DEPLOYMENT_JVM_SIZE_MIN}) ({$host}:" . componentProductVersion($descriptor_array) . ")");
                }

                if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MAX, 'g')) {
                    $servers_counter[$host]['jvm-max'] += (float)str_replace('g', '', $descriptor_array->DEPLOYMENT_JVM_SIZE_MAX);
                } elseif (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MAX, 'm')) {
                    $servers_counter[$host]['jvm-max'] += (float)str_replace('m', '', $descriptor_array->DEPLOYMENT_JVM_SIZE_MAX) / 1000;
                } else {
                    error_log("The unit of DEPLOYMENT_JVM_SIZE_MAX is not managed ({$descriptor_array->DEPLOYMENT_JVM_SIZE_MAX}) ({$host}:" . componentProductVersion($descriptor_array) . ")");
                }
            }

            /* Hostname → accent CSS class + short label */
            $host_meta = [
                'acceptance12.exoplatform.org' => ['css' => 'acc12', 'short' => 'acceptance12'],
                'acceptance13.exoplatform.org' => ['css' => 'acc13', 'short' => 'acceptance13'],
                'acceptance14.exoplatform.org' => ['css' => 'acc14', 'short' => 'acceptance14'],
                'acceptance15.exoplatform.org' => ['css' => 'acc15', 'short' => 'acceptance15'],
            ];

            /* Static server hardware specs */
            $server_specs = [
                'acceptance12.exoplatform.org' => ['alias' => 'acc02', 'cpu' => 'AMD Ryzen 9 5900X @ 3.7/4.8 GHz', 'cores' => '12 cores / 24 threads'],
                'acceptance13.exoplatform.org' => ['alias' => 'acc03', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads'],
                'acceptance14.exoplatform.org' => ['alias' => 'acc04', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads'],
                'acceptance15.exoplatform.org' => ['alias' => 'acc05', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads'],
            ];
            ?>

            <!-- ══ Section 1 – Server overview cards ══════════════════ -->
            <div class="section-title mt-3">
                <i class="fas fa-server" aria-hidden="true"></i> Acceptance Servers
            </div>
            <div class="server-cards">
                <?php foreach ($server_specs as $hostname => $spec):
                    $meta   = isset($host_meta[$hostname]) ? $host_meta[$hostname] : ['css' => 'accX', 'short' => $hostname];
                    $counts = isset($servers_counter[$hostname]) ? $servers_counter[$hostname] : ['nb' => 0, 'jvm-min' => 0, 'jvm-max' => 0];
                ?>
                <div class="server-card accent-<?= $meta['css'] ?>" data-host="<?= htmlspecialchars($hostname) ?>">
                    <div class="server-card__header">
                        <div>
                            <div class="server-card__name">
                                <i class="fas fa-server me-1"></i><?= htmlspecialchars($spec['alias']) ?>
                            </div>
                            <div class="server-card__hostname"><?= htmlspecialchars($hostname) ?></div>
                        </div>
                        <div class="server-card__badge" title="Deployed instances">
                            <i class="fas fa-cubes"></i><?= (int)$counts['nb'] ?>
                        </div>
                    </div>
                    <dl class="server-card__specs">
                        <dt><i class="fas fa-microchip me-1"></i>CPU</dt>
                        <dd><?= htmlspecialchars($spec['cpu']) ?></dd>

                        <dt><i class="fas fa-th-large me-1"></i>Cores</dt>
                        <dd><?= htmlspecialchars($spec['cores']) ?></dd>

                        <dt><i class="fas fa-layer-group me-1"></i>JVM config</dt>
                        <dd>
                            <span class="jvm-range" title="Sum of configured -Xms → -Xmx">
                                <span class="jvm-min"><?= number_format((float)$counts['jvm-min'], 1) ?> GB</span>
                                <span class="text-muted">→</span>
                                <span class="jvm-max"><?= number_format((float)$counts['jvm-max'], 1) ?> GB</span>
                            </span>
                        </dd>
                    </dl>
                    <div class="server-live" aria-live="polite">
                        <div class="server-live__footer"><span><i class="fas fa-spinner fa-spin me-1"></i>Loading live usage...</span></div>
                    </div>
                </div>
                <?php endforeach; ?>
            </div>
            <script>
                /* Live usage: polled from /server-stats every 30s while the page is visible */
                (function () {
                    var GB = 1024 * 1024; // kB per GB
                    var TOP = 3;
                    var expandedHosts = {}; // JVM list toggles, kept across refreshes
                    var lastStats = null;
                    function esc(v) { var d = document.createElement('div'); d.textContent = v == null ? '' : String(v); return d.innerHTML; }
                    function level(pct) { return pct >= 85 ? 'crit' : (pct >= 70 ? 'warn' : ''); }
                    function fmt(v, digits) { return v.toFixed(digits === undefined ? 1 : digits); }
                    function meterRow(icon, label, pct, value, title) {
                        var p = Math.max(0, Math.min(100, pct)), l = level(pct);
                        return '<div class="server-live__row"' + (title ? ' title="' + esc(title) + '"' : '') + '>'
                            + '<span class="server-live__label"><i class="fas ' + icon + ' me-1"></i>' + label + '</span>'
                            + '<span class="server-live__value"><span>' + value + '</span><span class="pct ' + l + '">' + Math.round(pct) + '%</span></span>'
                            + '<div class="usage-meter"><div class="usage-meter__fill ' + l + '" style="width:' + p + '%"></div></div></div>';
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
                                    fmt(j.rss_kb / GB) + ' GB &middot; ' + j.running + ' running',
                                    'Resident memory of running instance JVMs, out of total RAM (Xmx of running: ' + fmt(j.xmx_gb) + ' GB)');
                            }
                            if (st.mem.swap_total_kb > 0 && st.mem.swap_used_kb > 0) {
                                html += meterRow('fa-exchange-alt', 'Swap', st.mem.swap_used_kb / st.mem.swap_total_kb * 100,
                                    fmt(st.mem.swap_used_kb / GB) + ' / ' + fmt(st.mem.swap_total_kb / GB) + ' GB');
                            }
                        }
                        if (st.load && st.cpu && st.cpu.threads) {
                            html += meterRow('fa-microchip', 'Load', st.load[0] / st.cpu.threads * 100,
                                st.load.map(function (l) { return fmt(l, 2); }).join(' &middot; ') + ' / ' + st.cpu.threads + ' thr',
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
                            var expanded = expandedHosts[card.getAttribute('data-host')];
                            html += '<ul class="server-live__top">' + jvms.slice(0, expanded ? jvms.length : TOP).map(function (t) {
                                var key = t.key || t.name;
                                return '<li><a href="#instance-' + esc(key) + '" data-instance="' + esc(key) + '" title="' + esc(key) + '">' + esc(t.label || t.name) + '</a>'
                                    + '<span title="Process memory (heap, metaspace, threads, native) &middot; configured max heap">' + fmt(t.rss_kb / GB) + ' GB'
                                    + (t.xmx_gb ? ' <small>&middot; heap ' + fmt(t.xmx_gb) + '</small>' : '') + '</span></li>';
                            }).join('') + '</ul>';
                            if (jvms.length > TOP) {
                                html += '<button type="button" class="server-live__toggle" aria-expanded="' + !!expanded + '">'
                                    + (expanded ? '<i class="fas fa-chevron-up me-1"></i>Show less' : '<i class="fas fa-chevron-down me-1"></i>Show all ' + jvms.length) + '</button>';
                            }
                        }
                        html += '<div class="server-live__footer">'
                            + '<span>' + (st.uptime_s ? 'Up ' + uptime(st.uptime_s) : '') + '</span>'
                            + '<span>Updated ' + new Date(st.time * 1000).toLocaleTimeString() + '</span></div>';
                        box.innerHTML = html;
                    }
                    function refresh() {
                        if (document.visibilityState === 'hidden') return;
                        fetch('/server-stats', { cache: 'no-store' }).then(function (r) {
                            if (!r.ok) throw new Error(r.status);
                            return r.json();
                        }).then(function (stats) {
                            lastStats = stats;
                            document.querySelectorAll('.server-card[data-host]').forEach(function (card) {
                                render(card, stats[card.getAttribute('data-host')]);
                            });
                        }).catch(function () {
                            document.querySelectorAll('.server-card[data-host]').forEach(function (card) { render(card, null); });
                        });
                    }
                    document.querySelector('.server-cards').addEventListener('click', function (e) {
                        var toggle = e.target.closest('.server-live__toggle');
                        if (toggle) {
                            var card = toggle.closest('.server-card');
                            var host = card.getAttribute('data-host');
                            expandedHosts[host] = !expandedHosts[host];
                            render(card, lastStats && lastStats[host]);
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
            </script>

            <!-- ══ Section 2 – Deployment port registry ═══════════════ -->
            <div class="section-title">
                <i class="fas fa-network-wired"></i> Deployment Port Registry
            </div>
            <div class="instances-search">
                <i class="fas fa-search instances-search__icon"></i>
                <input type="text" id="portRegistrySearch" class="instances-search__input" placeholder="Filter by instance, version, server...">
            </div>
            <div class="table-responsive mb-5 port-registry-scroll">
                <table class="table table-hover align-middle table-sm" id="portRegistryTable" aria-label="Deployment port registry">
                    <caption class="sr-only">Deployment port registry listing all instances grouped by server, with their assigned ports</caption>
                    <thead>
                        <tr>
                            <th class="col-left">Instance</th>
                            <th class="col-left">Version</th>
                            <th class="col-center">DB</th>
                            <th class="col-center">Prefix</th>
                            <th class="col-center">HTTP</th>
                            <th class="col-left" title="Shown as the suffix after the prefix; highlighted when outside the instance prefix range">Other ports</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php
                        /* Group rows by server host (known hosts first, in the same
                         * order as the summary cards above; any other host last),
                         * so the registry mirrors the "Acceptance Servers" grouping
                         * above instead of an arbitrary port-number-only ordering. */
                        $rows_by_host = [];
                        foreach ($descriptor_arrays as $descriptor_array) {
                            $rows_by_host[$descriptor_array->ACCEPTANCE_HOST][] = $descriptor_array;
                        }
                        $ordered_hosts = array_values(array_intersect(array_keys($host_meta), array_keys($rows_by_host)));
                        foreach (array_keys($rows_by_host) as $h) {
                            if (!in_array($h, $ordered_hosts, true)) {
                                $ordered_hosts[] = $h;
                            }
                        }

                        /* Port chip: shown as its suffix when it follows the instance
                         * prefix convention (e.g. 25622 -> "22" for prefix 256), as the
                         * full number otherwise (highlighted, e.g. a shared Mongo 27017) */
                        $port_chip = function ($label, $ports, $prefix) {
                            $ports = array_values(array_filter((array) $ports, 'strlen'));
                            if (empty($ports)) return '';
                            $standard = true;
                            $short = array_map(function ($port) use ($prefix, &$standard) {
                                if ($prefix !== '' && strpos((string) $port, (string) $prefix) === 0 && strlen($port) === strlen($prefix) + 2) {
                                    return substr($port, -2);
                                }
                                $standard = false;
                                return $port;
                            }, $ports);
                            return '<span class="port-chip' . ($standard ? '' : ' port-chip--odd') . '" title="' . htmlspecialchars($label . ': ' . implode(' / ', $ports) . ($standard ? '' : ' (outside the instance prefix range)')) . '">'
                                . '<span class="port-chip__label">' . htmlspecialchars($label) . '</span>' . htmlspecialchars(implode('/', $short))
                                . '<span class="visually-hidden"> ' . htmlspecialchars(implode(' ', $ports)) . '</span></span>';
                        };

                        foreach ($ordered_hosts as $host):
                            $meta = $host_meta[$host] ?? ['css' => 'accX', 'short' => str_replace('.exoplatform.org', '', $host)];
                        ?>
                        <tr class="category-row accent-<?= htmlspecialchars($meta['css']) ?>" data-host-group="<?= htmlspecialchars($meta['css']) ?>" data-total="<?= count($rows_by_host[$host]) ?>">
                            <td colspan="6">
                                <span class="host-pill <?= htmlspecialchars($meta['css']) ?>"><?= htmlspecialchars($meta['short']) ?></span>
                                <span class="ms-2 category-row__count"><?= count($rows_by_host[$host]) ?> instance<?= count($rows_by_host[$host]) == 1 ? '' : 's' ?></span>
                            </td>
                        </tr>
                        <?php foreach ($rows_by_host[$host] as $descriptor_array):
                            if (preg_match("/([^\-]*)\-(.*\-.*)\-SNAPSHOT/", $descriptor_array->PRODUCT_VERSION, $matches)) {
                                $feature_branch = $matches[2];
                            } else {
                                $feature_branch = "";
                            }
                        ?>
                        <tr class="accent-<?= htmlspecialchars($meta['css']) ?>" id="instance-<?= htmlspecialchars($descriptor_array->INSTANCE_KEY) ?>" data-host-group="<?= htmlspecialchars($meta['css']) ?>">
                            <?php
                            // Add-ons collapsed into a single chip; names stay searchable
                            preg_match_all('/<span[^>]*>([^<]+)<\/span>/', componentAddonsTags($descriptor_array), $addon_matches);
                            $addons = array_values(array_unique(array_filter(array_map('trim', $addon_matches[1]))));
                            $prefix = (string) $descriptor_array->DEPLOYMENT_PORT_PREFIX;
                            ?>
                            <td class="col-left">
                                <div class="d-flex align-items-center gap-2">
                                    <?= componentStatusIcon($descriptor_array); ?>
                                    <?= componentAppServerIcon($descriptor_array); ?>
                                    <span><?= componentProductHtmlLabel($descriptor_array); ?></span>
                                </div>
                                <div class="registry-flags">
                                    <?= componentUpgradeEligibility($descriptor_array); ?>
                                    <?= componentPatchInstallation($descriptor_array); ?>
                                    <?= componentCertbotEnabled($descriptor_array); ?>
                                    <?= componentDevModeEnabled($descriptor_array); ?>
                                    <?= componentStagingModeEnabled($descriptor_array); ?>
                                    <?= componentDebugModeEnabled($descriptor_array); ?>
                                    <?php if (!empty($addons)): ?>
                                    <span class="addons-chip" rel="tooltip" data-bs-html="true" title="<?= htmlspecialchars(implode('<br>', array_map('htmlspecialchars', $addons))) ?>">
                                        <i class="fas fa-puzzle-piece me-1"></i><?= count($addons) ?> add-on<?= count($addons) == 1 ? '' : 's' ?>
                                        <span class="visually-hidden"> <?= htmlspecialchars(implode(' ', $addons)) ?></span>
                                    </span>
                                    <?php endif; ?>
                                    <?= componentLabels($descriptor_array); ?>
                                </div>
                            </td>
                            <td class="col-left">
                                <span class="text-mono small port-registry-version" title="<?= htmlspecialchars(strip_tags(componentProductVersion($descriptor_array))) ?>"><?= componentProductVersion($descriptor_array); ?></span>
                                <?php if (!empty($feature_branch)): ?>
                                    <span class="port-badge d-block mt-1" title="Feature branch"><i class="fas fa-code-branch me-1"></i><?= htmlspecialchars($feature_branch) ?></span>
                                <?php endif; ?>
                            </td>
                            <td class="col-center">
                                <span class="db-chip"><?= htmlspecialchars(str_replace(':', ' ', $descriptor_array->DATABASE)) ?></span>
                            </td>
                            <td class="col-center">
                                <span class="port-badge"><?= htmlspecialchars($prefix) ?>xx</span>
                            </td>
                            <td class="col-center">
                                <span class="port-badge"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_HTTP_PORT) ?></span>
                            </td>
                            <td class="col-left">
                                <div class="port-chips">
                                    <?= $port_chip('JMX', [$descriptor_array->DEPLOYMENT_RMI_REG_PORT, $descriptor_array->DEPLOYMENT_RMI_SRV_PORT], $prefix) ?>
                                    <?= $port_chip('Mongo', $descriptor_array->DEPLOYMENT_CHAT_MONGODB_PORT, $prefix) ?>
                                    <?= $port_chip('ES', $descriptor_array->DEPLOYMENT_ES_HTTP_PORT, $prefix) ?>
                                </div>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
            <script>
                (function () {
                    var input = document.getElementById('portRegistrySearch');
                    var table = document.getElementById('portRegistryTable');
                    if (!input || !table) return;
                    input.addEventListener('input', function () {
                        var query = this.value.toLowerCase().trim();
                        var visibleCountByGroup = {};
                        table.querySelectorAll('tbody > tr:not(.category-row)').forEach(function (row) {
                            var match = !query || row.textContent.toLowerCase().indexOf(query) !== -1;
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
                            countEl.textContent = query && visible !== Number(total)
                                ? visible + ' of ' + total + ' instance' + (total == 1 ? '' : 's')
                                : total + ' instance' + (total == 1 ? '' : 's');
                        });
                    });
                })();
            </script>

        </div><!-- /container-fluid -->
    </div>
</div>
<?php pageFooter(); ?>
</body>
</html>

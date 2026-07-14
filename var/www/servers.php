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

        /* Server accent colours (match color-acceptanceX in style.css) */
        .accent-acc7  { --card-accent: #9b59b6; }
        .accent-acc12 { --card-accent: #f39c12; }
        .accent-acc13 { --card-accent: #1abc9c; }
        .accent-acc14 { --card-accent: #3498db; }
        .accent-acc15 { --card-accent: #9b59b6; }

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
        #portRegistryTable thead th {
            position: sticky;
            top: 0;
            z-index: 5;
        }
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
                'acceptance12.exoplatform.org' => ['alias' => 'acc02', 'ram' => '128 GB', 'cpu' => 'AMD Ryzen 9 5900X @ 3.7/4.8 GHz', 'cores' => '12 cores / 24 threads', 'disks' => '2 × 1.92 TB NVMe'],
                'acceptance13.exoplatform.org' => ['alias' => 'acc03', 'ram' => '128 GB', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads', 'disks' => '2 × 960 GB NVMe'],
                'acceptance14.exoplatform.org' => ['alias' => 'acc04', 'ram' => '128 GB', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads', 'disks' => '2 × 960 GB NVMe'],
                'acceptance15.exoplatform.org' => ['alias' => 'acc05', 'ram' => '128 GB', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads', 'disks' => '2 × 960 GB NVMe'],
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
                <div class="server-card accent-<?= $meta['css'] ?>">
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
                        <dt><i class="fas fa-memory me-1"></i>RAM</dt>
                        <dd><?= htmlspecialchars($spec['ram']) ?></dd>

                        <dt><i class="fas fa-microchip me-1"></i>CPU</dt>
                        <dd><?= htmlspecialchars($spec['cpu']) ?></dd>

                        <dt><i class="fas fa-th-large me-1"></i>Cores</dt>
                        <dd><?= htmlspecialchars($spec['cores']) ?></dd>

                        <dt><i class="fas fa-hdd me-1"></i>Disks</dt>
                        <dd><?= htmlspecialchars($spec['disks']) ?></dd>

                        <dt><i class="fas fa-layer-group me-1"></i>JVM</dt>
                        <dd>
                            <span class="jvm-range">
                                <span class="jvm-min"><?= number_format((float)$counts['jvm-min'], 1) ?> GB</span>
                                <span class="text-muted">→</span>
                                <span class="jvm-max"><?= number_format((float)$counts['jvm-max'], 1) ?> GB</span>
                            </span>
                        </dd>
                    </dl>
                </div>
                <?php endforeach; ?>
            </div>

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
                            <th class="col-center">Bundle</th>
                            <th class="col-center">DB</th>
                            <th class="col-center">Server</th>
                            <th class="col-center">Status</th>
                            <th class="col-center">Prefix</th>
                            <th class="col-center">HTTP</th>
                            <th class="col-center">ES</th>
                            <th class="col-center">Mongo</th>
                            <th class="col-center">AJP</th>
                            <th class="col-center">JMX</th>
                            <th class="col-center">CRaSH</th>
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

                        foreach ($ordered_hosts as $host):
                            $meta = $host_meta[$host] ?? ['css' => 'accX', 'short' => str_replace('.exoplatform.org', '', $host)];
                        ?>
                        <tr class="category-row" data-host-group="<?= htmlspecialchars($meta['css']) ?>" data-total="<?= count($rows_by_host[$host]) ?>">
                            <td colspan="13">
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
                        <tr data-host-group="<?= htmlspecialchars($meta['css']) ?>">
                            <td class="col-left">
                                <div class="d-flex align-items-center gap-1">
                                    <?= componentAppServerIcon($descriptor_array); ?>
                                    <span><?= componentProductHtmlLabel($descriptor_array); ?></span>
                                </div>
                                <div class="mt-1 d-flex flex-wrap gap-1">
                                    <?= componentUpgradeEligibility($descriptor_array); ?>
                                    <?= componentPatchInstallation($descriptor_array); ?>
                                    <?= componentCertbotEnabled($descriptor_array); ?>
                                    <?= componentDevModeEnabled($descriptor_array); ?>
                                    <?= componentStagingModeEnabled($descriptor_array); ?>
                                    <?= componentDebugModeEnabled($descriptor_array); ?>
                                    <?= componentAddonsTags($descriptor_array); ?>
                                    <?= componentLabels($descriptor_array); ?>
                                </div>
                            </td>
                            <td class="col-left">
                                <span class="text-mono small port-registry-version" title="<?= htmlspecialchars(strip_tags(componentProductVersion($descriptor_array))) ?>"><?= componentProductVersion($descriptor_array); ?></span>
                                <?php if (!empty($feature_branch)): ?>
                                    <span class="port-badge d-block mt-1" title="Feature branch"><i class="fas fa-code-branch me-1"></i><?= htmlspecialchars($feature_branch) ?></span>
                                <?php endif; ?>
                            </td>
                            <td class="col-center"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_APPSRV_TYPE) ?></td>
                            <td class="col-center"><?= htmlspecialchars($descriptor_array->DATABASE) ?></td>
                            <td class="col-center">
                                <span class="host-pill <?= $meta['css'] ?>">
                                    <?= htmlspecialchars($meta['short']) ?>
                                </span>
                            </td>
                            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
                            <td class="col-center">
                                <span class="port-badge"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_PORT_PREFIX) ?>xx</span>
                            </td>
                            <td class="col-center">
                                <span class="port-badge"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_HTTP_PORT) ?></span>
                            </td>
                            <td class="col-center">
                                <span class="port-badge"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_ES_HTTP_PORT) ?></span>
                            </td>
                            <td class="col-center">
                                <span class="port-badge"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_CHAT_MONGODB_PORT) ?></span>
                            </td>
                            <td class="col-center">
                                <span class="port-badge"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_AJP_PORT) ?></span>
                            </td>
                            <td class="col-center">
                                <span class="port-badge" title="JMX RMI Reg / Server">
                                    <?= htmlspecialchars($descriptor_array->DEPLOYMENT_RMI_REG_PORT) ?>/<?= htmlspecialchars($descriptor_array->DEPLOYMENT_RMI_SRV_PORT) ?>
                                </span>
                            </td>
                            <td class="col-center">
                                <span class="port-badge"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_CRASH_SSH_PORT) ?></span>
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

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
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 1.1rem 1.25rem;
            box-shadow: 0 2px 6px rgba(0,0,0,.07);
            transition: box-shadow .2s ease, transform .2s ease;
            border-top: 4px solid var(--card-accent, #6c757d);
        }
        .server-card:hover {
            box-shadow: 0 6px 18px rgba(0,0,0,.12);
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
            background: var(--card-accent, #6c757d);
            color: #fff;
            border-radius: 20px;
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
            font-family: 'Courier New', monospace;
            font-size: .78rem;
            background: var(--body-bg);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            padding: .1rem .4rem;
            white-space: nowrap;
            color: var(--bs-body-color);
        }

        /* ── Host pill ──────────────────────────────────────── */
        .host-pill {
            display: inline-block;
            padding: .15rem .55rem;
            border-radius: 20px;
            font-size: .78rem;
            font-weight: 600;
            background: rgba(0,0,0,.05);
            white-space: nowrap;
        }
        [data-bs-theme="dark"] .host-pill {
            background: rgba(255,255,255,.07);
        }
        .host-pill.acc7  { color: #9b59b6; border: 1px solid #9b59b6; }
        .host-pill.acc12 { color: #f39c12; border: 1px solid #f39c12; }
        .host-pill.acc13 { color: #1abc9c; border: 1px solid #1abc9c; }
        .host-pill.acc14 { color: #3498db; border: 1px solid #3498db; }
        .host-pill.acc15 { color: #9b59b6; border: 1px solid #9b59b6; }
        .host-pill.accX  { color: var(--text-muted); border: 1px solid var(--border-color); }
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
            $descriptor_arrays = array();
            foreach ($merged_list as $tmp_array) {
                $descriptor_arrays = array_merge($descriptor_arrays, $tmp_array);
            }
            function cmp($a, $b)
            {
                return strcmp($a->DEPLOYMENT_HTTP_PORT, $b->DEPLOYMENT_HTTP_PORT);
            }
            usort($descriptor_arrays, "cmp");

            $servers_counter = array();
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
            $host_meta = array(
                'acceptance7.exoplatform.org'  => ['css' => 'acc7',  'short' => 'acceptance7'],
                'acceptance12.exoplatform.org' => ['css' => 'acc12', 'short' => 'acceptance12'],
                'acceptance13.exoplatform.org' => ['css' => 'acc13', 'short' => 'acceptance13'],
                'acceptance14.exoplatform.org' => ['css' => 'acc14', 'short' => 'acceptance14'],
                'acceptance15.exoplatform.org' => ['css' => 'acc15', 'short' => 'acceptance15'],
            );

            /* Static server hardware specs */
            $server_specs = array(
                'acceptance7.exoplatform.org'  => ['alias' => 'prd05', 'ram' => '128 GB', 'cpu' => 'Xeon E5-1650 v2 @ 3.50 GHz', 'cores' => '6 cores / 12 threads', 'disks' => '3 × 300 GB SSD'],
                'acceptance12.exoplatform.org' => ['alias' => 'acc02', 'ram' => '128 GB', 'cpu' => 'AMD Ryzen 9 5900X @ 3.7/4.8 GHz', 'cores' => '12 cores / 24 threads', 'disks' => '2 × 1.92 TB NVMe'],
                'acceptance13.exoplatform.org' => ['alias' => 'acc03', 'ram' => '128 GB', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads', 'disks' => '2 × 960 GB NVMe'],
                'acceptance14.exoplatform.org' => ['alias' => 'acc04', 'ram' => '128 GB', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads', 'disks' => '2 × 960 GB NVMe'],
                'acceptance15.exoplatform.org' => ['alias' => 'acc05', 'ram' => '128 GB', 'cpu' => 'Xeon E2388G @ 3.2/4.6 GHz', 'cores' => '8 cores / 16 threads', 'disks' => '2 × 960 GB NVMe'],
            );
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
            <div class="table-responsive mb-5">
                <table class="table table-hover align-middle table-sm" aria-label="Deployment port registry">
                    <caption class="sr-only">Deployment port registry listing all instances with their assigned ports</caption>
                    <thead>
                        <tr>
                            <th class="col-left">Instance</th>
                            <th class="col-center">Version</th>
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
                        <?php foreach ($descriptor_arrays as $descriptor_array):
                            if (preg_match("/([^\-]*)\-(.*\-.*)\-SNAPSHOT/", $descriptor_array->PRODUCT_VERSION, $matches)) {
                                $feature_branch = $matches[2];
                            } elseif (preg_match("/(.*)\-SNAPSHOT/", $descriptor_array->PRODUCT_VERSION, $matches)) {
                                $feature_branch = "";
                            } else {
                                $feature_branch = "";
                            }

                            $host = $descriptor_array->ACCEPTANCE_HOST;
                            $meta = isset($host_meta[$host])
                                ? $host_meta[$host]
                                : ['css' => 'accX', 'short' => str_replace('.exoplatform.org', '', $host)];
                        ?>
                        <tr>
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
                            <td class="col-left"><span class="text-mono small"><?= componentProductVersion($descriptor_array); ?></span></td>
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
                    </tbody>
                </table>
            </div>

        </div><!-- /container-fluid -->
    </div>
</div>
<?php pageFooter(); ?>
</body>
</html>

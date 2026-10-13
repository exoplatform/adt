<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();

$data = getenv('ADT_DATA') ?: '/';

/** Run a command with a short timeout, returns its output lines or null when unavailable */
function healthRun($cmd)
{
  $disabled = array_map('trim', explode(',', (string)ini_get('disable_functions')));
  if (!function_exists('shell_exec') || in_array('shell_exec', $disabled, true)) {
    return null;
  }
  $out = @shell_exec('timeout 5 ' . $cmd . ' 2>/dev/null');
  return $out === null || trim($out) === '' ? null : explode("\n", trim($out));
}

function healthRow($label, $value)
{
  return '<tr><th scope="row" class="w-25">' . htmlspecialchars($label) . '</th><td>' . $value . '</td></tr>';
}

function healthMeter($used, $total)
{
  $pct = $total > 0 ? round(100 * $used / $total) : 0;
  $class = $pct >= 90 ? 'bg-danger' : ($pct >= 75 ? 'bg-warning' : 'bg-success');
  return '<div class="progress" style="min-width:120px" role="progressbar" aria-valuenow="' . $pct . '" aria-valuemin="0" aria-valuemax="100">'
    . '<div class="progress-bar ' . $class . '" style="width:' . $pct . '%">' . $pct . '%</div></div>';
}

// --- host
$uptime = is_readable('/proc/uptime') ? (int)explode(' ', file_get_contents('/proc/uptime'))[0] : null;
$load = function_exists('sys_getloadavg') ? sys_getloadavg() : null;
$mem = [];
if (is_readable('/proc/meminfo')) {
  foreach (explode("\n", file_get_contents('/proc/meminfo')) as $l) {
    if (preg_match('/^(\w+):\s+(\d+) kB/', $l, $m)) {
      $mem[$m[1]] = $m[2] * 1024;
    }
  }
}

// --- filesystems (deduplicated by device)
$paths = array_unique(array_filter([$data, $data . '/var/log', '/tmp']));
$fs = [];
foreach ($paths as $p) {
  if (!is_dir($p)) {
    continue;
  }
  $total = @disk_total_space($p);
  $free = @disk_free_space($p);
  if ($total) {
    $fs[$p] = [$total, $total - $free];
  }
}

// --- directory sizes, only on demand (du can be slow)
$sizes = null;
if (isset($_GET['sizes'])) {
  $sizes = [];
  foreach (['var/log/apache2', 'var/sessions', 'var/audit', 'conf', 'sources', 'downloads', 'datasets'] as $d) {
    $out = is_dir("$data/$d") ? healthRun('du -sk ' . escapeshellarg("$data/$d")) : null;
    $sizes[$d] = $out ? ((int)$out[0]) * 1024 : null;
  }
}

// --- docker
$docker = healthRun("docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.State}}'");

// --- deployments
$descriptors = glob("$data/conf/adt/*") ?: [];
$lastDeploy = 0;
foreach ($descriptors as $f) {
  $lastDeploy = max($lastDeploy, (int)@filemtime($f));
}
$sessionsCount = count(glob(sessionsDir() . '/*.json') ?: []);

// --- cache backends
$cacheBackend = 'none';
if (extension_loaded('apcu') && function_exists('apcu_cache_info')) {
  $info = apcu_cache_info(true);
  $cacheBackend = sprintf('APCu (%d entries, %d hits / %d misses)', $info['num_entries'] ?? 0, $info['num_hits'] ?? 0, $info['num_misses'] ?? 0);
} elseif (extension_loaded('memcache') && !empty($GLOBALS['memcache'])) {
  $cacheBackend = 'Memcache';
}

debugPageBegin('health', 'Debug Health', 'Host, disk, Docker and deployment state', false);
?>
<div class="row g-3">
  <div class="col-lg-6">
    <div class="card h-100">
      <div class="card-header"><i class="fas fa-server me-2"></i>Host</div>
      <div class="card-body">
        <table class="table table-sm mb-0"><tbody>
<?= healthRow('Hostname', htmlspecialchars((string)gethostname())) ?>
<?= healthRow('Uptime', $uptime === null ? 'n/a' : durationLabel($uptime)) ?>
<?= healthRow('Load average', $load ? htmlspecialchars(implode(' / ', array_map(fn($l) => sprintf('%.2f', $l), $load))) : 'n/a') ?>
<?php if (!empty($mem['MemTotal'])) {
  $used = $mem['MemTotal'] - ($mem['MemAvailable'] ?? $mem['MemFree'] ?? 0);
  echo healthRow('Memory', debugBytes($used) . ' / ' . debugBytes($mem['MemTotal']) . healthMeter($used, $mem['MemTotal']));
}
if (!empty($mem['SwapTotal'])) {
  $su = $mem['SwapTotal'] - ($mem['SwapFree'] ?? 0);
  echo healthRow('Swap', debugBytes($su) . ' / ' . debugBytes($mem['SwapTotal']) . healthMeter($su, $mem['SwapTotal']));
} ?>
        </tbody></table>
      </div>
    </div>
  </div>
  <div class="col-lg-6">
    <div class="card h-100">
      <div class="card-header"><i class="fas fa-cogs me-2"></i>Software</div>
      <div class="card-body">
        <table class="table table-sm mb-0"><tbody>
<?= healthRow('Web server', htmlspecialchars($_SERVER['SERVER_SOFTWARE'] ?? 'n/a')) ?>
<?= healthRow('PHP', htmlspecialchars(PHP_VERSION . ' (' . PHP_SAPI . ')')) ?>
<?= healthRow('Cache backend', htmlspecialchars($cacheBackend)) ?>
<?= healthRow('ADT_DATA', '<code>' . htmlspecialchars($data) . '</code>') ?>
<?= healthRow('Time (UTC)', gmdate('Y-m-d H:i:s')) ?>
        </tbody></table>
      </div>
    </div>
  </div>
  <div class="col-lg-6">
    <div class="card h-100">
      <div class="card-header"><i class="fas fa-hdd me-2"></i>Disk</div>
      <div class="card-body">
        <table class="table table-sm"><thead><tr><th>Path</th><th>Used</th><th></th></tr></thead><tbody>
<?php foreach ($fs as $path => [$total, $used]) { ?>
          <tr><td><code><?= htmlspecialchars($path) ?></code></td><td class="text-nowrap"><?= debugBytes($used) ?> / <?= debugBytes($total) ?></td><td><?= healthMeter($used, $total) ?></td></tr>
<?php } ?>
        </tbody></table>
<?php if ($sizes === null) { ?>
        <a class="btn btn-sm btn-outline-primary" href="/debug-health?sizes=1">Compute directory sizes</a>
<?php } else { ?>
        <table class="table table-sm mb-0"><thead><tr><th>Directory (under ADT_DATA)</th><th>Size</th></tr></thead><tbody>
<?php foreach ($sizes as $d => $size) { ?>
          <tr><td><code><?= htmlspecialchars($d) ?></code></td><td><?= $size === null ? 'n/a' : debugBytes($size) ?></td></tr>
<?php } ?>
        </tbody></table>
<?php } ?>
      </div>
    </div>
  </div>
  <div class="col-lg-6">
    <div class="card h-100">
      <div class="card-header"><i class="fas fa-rocket me-2"></i>Deployments</div>
      <div class="card-body">
        <table class="table table-sm mb-0"><tbody>
<?= healthRow('Instance descriptors', (string)count($descriptors)) ?>
<?= healthRow('Last deployment', $lastDeploy ? htmlspecialchars(gmdate('Y-m-d H:i', $lastDeploy)) . ' UTC (' . durationLabel(time() - $lastDeploy) . ' ago)' : 'n/a') ?>
<?= healthRow('Tracked login sessions', (string)$sessionsCount) ?>
        </tbody></table>
      </div>
    </div>
  </div>
  <div class="col-12">
    <div class="card">
      <div class="card-header"><i class="fab fa-docker me-2"></i>Docker containers</div>
      <div class="card-body">
<?php if ($docker === null) { ?>
        <div class="alert alert-secondary mb-0">Docker is not reachable from the web server (no <code>docker</code> binary or no access to the socket).</div>
<?php } else { ?>
        <div class="table-responsive"><table class="table table-sm align-middle mb-0">
          <thead><tr><th>Name</th><th>Image</th><th>Status</th></tr></thead><tbody>
<?php foreach ($docker as $line) {
  [$name, $image, $status, $state] = array_pad(explode("\t", $line), 4, '');
  $badge = $state === 'running' ? 'bg-success' : ($state === 'exited' ? 'bg-danger' : 'bg-secondary'); ?>
          <tr><td><?= htmlspecialchars($name) ?></td><td class="small"><?= htmlspecialchars($image) ?></td><td><span class="badge <?= $badge ?>"><?= htmlspecialchars($status) ?></span></td></tr>
<?php } ?>
        </tbody></table></div>
<?php } ?>
      </div>
    </div>
  </div>
</div>
<?php debugPageEnd(); ?>

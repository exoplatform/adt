<?php
require_once(__DIR__ . '/lib/functions.php');
require_once(__DIR__ . '/lib/functions-ui.php');
checkCaches();

/** Escaped string of a property of an instance object (instances come from json_decode) */
function di(object $instance, string $key): string
{
  $v = $instance->$key ?? '';
  return is_scalar($v) ? (string)$v : '';
}

function h(mixed $s): string
{
  return htmlspecialchars((string)$s);
}

/** Every instance of a category-keyed array, as a flat list */
function flattenInstances(array|object|null $byCategory): array
{
  $flat = [];
  // Array of arrays when it comes from the caches/servers, objects when decoded straight from JSON (dev mode)
  if (is_array($byCategory) || is_object($byCategory)) {
    foreach ($byCategory as $instances) {
      foreach ((array)$instances as $i) {
        if (is_object($i)) {
          $flat[] = $i;
        }
      }
    }
  }
  return $flat;
}

/** Identity of an instance across the getters: its key and the server/host it runs on */
function instanceId(object $i): string
{
  return di($i, 'INSTANCE_KEY') . '|' . di($i, 'ACCEPTANCE_HOST') . '|' . di($i, 'DEPLOYMENT_EXT_HOST');
}

/** Days since a "Ymd.His" deployment date, or null */
function deploymentAgeDays(object $i): ?int
{
  $d = DateTime::createFromFormat('Ymd.His', di($i, 'DEPLOYMENT_DATE'));
  return $d ? (int)$d->diff(new DateTime())->format('%a') : null;
}

function labelsOf(object $i): array
{
  $l = $i->DEPLOYMENT_LABELS ?? [];
  return is_array($l) ? array_map('strval', $l) : [];
}

// The category getters and the rule each one applies on top of the instances of all the servers
$getters = [
  'getGlobalDevInstances'          => 'everything but sales, qa, company, doc, translation and cp',
  'getGlobalQAInstances'           => 'qa',
  'getGlobalQAUserInstances'       => 'qa + user',
  'getGlobalQAAutoInstances'       => 'qa + auto',
  'getGlobalCPInstances'           => 'cp',
  'getGlobalCompanyInstances'      => 'company',
  'getGlobalDocInstances'          => 'doc',
  'getGlobalTranslationInstances'  => 'translation',
  'getGlobalSalesUserInstances'    => 'sales + user',
  'getGlobalSalesDemoInstances'    => 'sales + demo',
  'getGlobalSalesEvalInstances'    => 'sales + eval',
];

// --- data: all the instances, then each getter (timed)
$t = microtime(true);
$all = getGlobalAcceptanceInstances();
$allMs = (microtime(true) - $t) * 1000;
$flat = flattenInstances($all);

$results = [];
$membership = []; // instance id => getter names
foreach ($getters as $getter => $rule) {
  if (!function_exists($getter)) {
    continue;
  }
  $t = microtime(true);
  $byCategory = $getter();
  $ms = (microtime(true) - $t) * 1000;
  $list = flattenInstances($byCategory);
  foreach ($list as $i) {
    $membership[instanceId($i)][] = $getter;
  }
  $results[$getter] = ['rule' => $rule, 'categories' => $byCategory, 'list' => $list, 'ms' => $ms];
}

// --- problems
$problems = [];
$seen = [];
foreach ($flat as $i) {
  $id = instanceId($i);
  $name = di($i, 'INSTANCE_KEY') ?: di($i, 'DEPLOYMENT_EXT_HOST');
  if (isset($seen[$id])) {
    $problems[] = ['warning', $name, 'listed twice (same key and host)'];
  }
  $seen[$id] = true;
  if (di($i, 'DEPLOYMENT_STATUS') === 'Down') {
    $problems[] = ['danger', $name, 'is down'];
  }
  $age = deploymentAgeDays($i);
  if ($age !== null && $age > 30) {
    $problems[] = ['warning', $name, "was last deployed $age days ago"];
  }
  if (di($i, 'ARTIFACT_AGE_CLASS') === 'red') {
    $problems[] = ['warning', $name, 'runs an artifact older than 5 days (' . di($i, 'ARTIFACT_AGE_STRING') . ')'];
  }
  if (di($i, 'DEPLOYMENT_EXT_HOST') === '' || di($i, 'INSTANCE_KEY') === '') {
    $problems[] = ['danger', $name ?: '?', 'has no INSTANCE_KEY or DEPLOYMENT_EXT_HOST'];
  }
  if (empty($membership[$id])) {
    $problems[] = ['info', $name, 'is not returned by any category getter (not shown in any dashboard section)'];
  }
}

// --- instances explorer (filtered)
$q = trim((string)($_GET['q'] ?? ''));
$statusFilter = (string)($_GET['status'] ?? '');
$explorer = array_values(array_filter($flat, function ($i) use ($q, $statusFilter) {
  if ($statusFilter !== '' && di($i, 'DEPLOYMENT_STATUS') !== $statusFilter) {
    return false;
  }
  $hay = di($i, 'INSTANCE_KEY') . ' ' . di($i, 'DEPLOYMENT_EXT_HOST') . ' ' . di($i, 'PRODUCT_VERSION') . ' ' . di($i, 'ACCEPTANCE_HOST') . ' ' . implode(' ', labelsOf($i));
  return $q === '' || stripos($hay, $q) !== false;
}));
usort($explorer, fn($a, $b) => strcmp(di($a, 'DEPLOYMENT_EXT_HOST'), di($b, 'DEPLOYMENT_EXT_HOST')));

// --- servers check, on demand (network calls)
$servers = [];
if (isset($_GET['servers'])) {
  foreach (array_filter(array_map('trim', explode(',', (string)getenv('ACCEPTANCE_SERVERS')))) as $server) {
    $url = rtrim($server, '/') . '/rest/local-instances.php';
    $t = microtime(true);
    $body = @file_get_contents($url, false, stream_context_create(['http' => ['timeout' => 5, 'ignore_errors' => true]]));
    $ms = (microtime(true) - $t) * 1000;
    $code = 0;
    foreach ($http_response_header ?? [] as $hdr) {
      if (preg_match('#^HTTP/\S+\s+(\d{3})#', $hdr, $m)) {
        $code = (int)$m[1];
      }
    }
    $decoded = is_string($body) ? json_decode($body, true) : null;
    $count = is_array($decoded) ? array_sum(array_map('count', $decoded)) : null;
    $servers[] = ['server' => $server, 'code' => $code, 'ms' => $ms, 'count' => $count, 'bytes' => is_string($body) ? strlen($body) : 0];
  }
}

$up = count(array_filter($flat, fn($i) => di($i, 'DEPLOYMENT_STATUS') === 'Up'));
$down = count(array_filter($flat, fn($i) => di($i, 'DEPLOYMENT_STATUS') === 'Down'));
$serverList = array_filter(array_map('trim', explode(',', (string)getenv('ACCEPTANCE_SERVERS'))));
$source = getenv('ADT_DEV_MODE') ? 'local instances (ADT_DEV_MODE)'
  : (cacheGet('all_instances') ? 'fresh cache' : (cacheGet('all_instances_stale') ? 'stale cache' : 'live fetch'));

debugPageBegin('deployment', 'Debug Deployment', 'Instances of all the servers, category getters and what to look at');
?>
<div class="row g-3 mb-4">
  <div class="col-6 col-lg-3"><div class="card h-100"><div class="card-body"><div class="text-muted small">Instances</div><div class="fs-3"><?= count($flat) ?></div><div class="small"><span class="text-success"><?= $up ?> up</span> · <span class="text-danger"><?= $down ?> down</span></div></div></div></div>
  <div class="col-6 col-lg-3"><div class="card h-100"><div class="card-body"><div class="text-muted small">Servers</div><div class="fs-3"><?= count($serverList) ?: 1 ?></div><div class="small"><a href="/debug-deploy?servers=1">Check them now</a></div></div></div></div>
  <div class="col-6 col-lg-3"><div class="card h-100"><div class="card-body"><div class="text-muted small">Source</div><div class="fs-6"><?= h($source) ?></div><div class="small"><?= round($allMs) ?> ms · <a href="/debug-deploy?clearCaches=true">clear caches</a></div></div></div></div>
  <div class="col-6 col-lg-3"><div class="card h-100"><div class="card-body"><div class="text-muted small">To look at</div><div class="fs-3"><?= count($problems) ?></div><div class="small"><a href="#problems">See the list</a></div></div></div></div>
</div>

<?php if ($servers) { ?>
<div class="card mb-4">
  <div class="card-header"><i class="fas fa-network-wired me-2"></i>Servers</div>
  <div class="card-body">
    <table class="table table-hover table-themed table-sm align-middle mb-0">
      <thead><tr><th>Server</th><th>Status</th><th>Time</th><th>Instances</th><th>Size</th></tr></thead>
      <tbody>
<?php foreach ($servers as $s) { $ok = $s['code'] === 200 && $s['count'] !== null; ?>
        <tr>
          <td><code><?= h($s['server']) ?></code></td>
          <td><span class="badge <?= $ok ? 'bg-success' : 'bg-danger' ?>"><?= $s['code'] ?: 'no answer' ?></span></td>
          <td><?= round($s['ms']) ?> ms</td>
          <td><?= $s['count'] === null ? '<span class="text-danger">invalid answer</span>' : $s['count'] ?></td>
          <td><?= debugBytes($s['bytes']) ?></td>
        </tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</div>
<?php } elseif (isset($_GET['servers'])) { ?>
<?= debugAlert('secondary', 'ACCEPTANCE_SERVERS is not set: only this server is used.') ?>
<?php } ?>

<div class="card mb-4" id="problems">
  <div class="card-header"><i class="fas fa-exclamation-triangle me-2"></i>To look at (<?= count($problems) ?>)</div>
  <div class="card-body">
<?php if (!$problems) { ?>
    <div class="alert alert-success mb-0">Nothing to report.</div>
<?php } else { ?>
    <ul class="list-unstyled mb-0">
<?php foreach ($problems as [$level, $name, $text]) { ?>
      <li class="mb-1"><span class="badge bg-<?= $level ?> me-2"><?= h($level) ?></span><strong><?= h($name) ?></strong> <?= h($text) ?></li>
<?php } ?>
    </ul>
<?php } ?>
  </div>
</div>

<div class="card mb-4">
  <div class="card-header"><i class="fas fa-layer-group me-2"></i>Category getters</div>
  <div class="card-body">
    <div class="table-responsive">
    <table class="table table-hover table-themed table-sm align-middle">
      <thead><tr><th>Getter</th><th>Rule</th><th>Categories</th><th>Instances</th><th>Time</th><th></th></tr></thead>
      <tbody>
<?php $n = 0; foreach ($results as $getter => $r) { $n++; ?>
        <tr>
          <td><code><?= h($getter) ?>()</code></td>
          <td class="small"><?= h($r['rule']) ?></td>
          <td><?= is_array($r['categories']) || is_object($r['categories']) ? count((array)$r['categories']) : 0 ?></td>
          <td><?= count($r['list']) ?></td>
          <td><?= round($r['ms']) ?> ms</td>
          <td><?php if ($r['list']) { ?><button type="button" class="btn btn-sm btn-outline-primary" data-bs-toggle="collapse" data-bs-target="#g<?= $n ?>">Details</button><?php } ?></td>
        </tr>
<?php if ($r['list']) { ?>
        <tr class="collapse" id="g<?= $n ?>"><td colspan="6">
<?php foreach ($r['categories'] as $category => $instances) { ?>
          <h6 class="mt-2"><?= h($category) ?> <span class="text-muted">(<?= count((array)$instances) ?>)</span></h6>
          <ul class="list-unstyled ms-3 mb-2">
<?php foreach ((array)$instances as $i) { ?>
            <li><i class="fas fa-cube text-muted me-2"></i><?= h(di($i, 'INSTANCE_DESCRIPTION') ?: di($i, 'INSTANCE_KEY')) ?> <span class="text-muted small"><?= h(di($i, 'DEPLOYMENT_EXT_HOST')) ?></span></li>
<?php } ?>
          </ul>
<?php } ?>
          <?= debug_var_toggle($r['categories']) ?>
        </td></tr>
<?php } ?>
<?php } ?>
      </tbody>
    </table>
    </div>
  </div>
</div>

<div class="card">
  <div class="card-header"><i class="fas fa-cubes me-2"></i>Instance explorer (<?= count($explorer) ?> of <?= count($flat) ?>)</div>
  <div class="card-body">
    <form method="get" class="row g-2 mb-3">
      <div class="col-md-5"><input type="search" name="q" value="<?= h($q) ?>" class="form-control form-control-sm" placeholder="Key, host, version, server or label" aria-label="Filter"></div>
      <div class="col-md-2">
        <select name="status" class="form-select form-select-sm" aria-label="Status">
          <option value="">Any status</option>
          <option value="Up"<?= $statusFilter === 'Up' ? ' selected' : '' ?>>Up</option>
          <option value="Down"<?= $statusFilter === 'Down' ? ' selected' : '' ?>>Down</option>
        </select>
      </div>
      <div class="col-md-3"><button class="btn btn-sm btn-primary" type="submit">Filter</button> <a class="btn btn-sm btn-outline-secondary" href="/debug-deploy">Reset</a></div>
    </form>
    <div class="table-responsive">
    <table class="table table-hover table-themed table-sm align-middle">
      <thead><tr><th>Instance</th><th>Server</th><th>Version</th><th>Status</th><th>Labels</th><th>Artifact</th><th>Deployed</th><th>Listed in</th></tr></thead>
      <tbody>
<?php foreach ($explorer as $i) { $in = $membership[instanceId($i)] ?? []; ?>
        <tr>
          <td><?= h(di($i, 'DEPLOYMENT_EXT_HOST')) ?><div class="small text-muted"><?= h(di($i, 'INSTANCE_KEY')) ?></div></td>
          <td class="small"><?= h(di($i, 'ACCEPTANCE_HOST')) ?></td>
          <td class="small"><?= h(di($i, 'PRODUCT_VERSION')) ?></td>
          <td><?php $st = di($i, 'DEPLOYMENT_STATUS'); ?><span class="badge <?= match ($st) { 'Up' => 'bg-success', 'Down' => 'bg-danger', default => 'bg-secondary' } ?>"><?= h($st ?: '?') ?></span></td>
          <td><?php foreach (labelsOf($i) as $l) { echo '<span class="badge bg-secondary me-1">' . h($l) . '</span>'; } ?></td>
          <td class="small text-nowrap"><?= h(di($i, 'ARTIFACT_AGE_STRING') ?: '-') ?></td>
          <td class="small text-nowrap"><?= h(di($i, 'DEPLOYMENT_AGE_STRING') ?: '-') ?></td>
          <td class="small"><?= $in ? h(implode(', ', array_map(fn($g) => preg_replace('/^getGlobal|Instances$/', '', $g), $in))) : '<span class="text-warning">none</span>' ?></td>
        </tr>
<?php } ?>
<?php if (!$explorer) { ?>
        <tr><td colspan="8" class="text-muted">No instance.</td></tr>
<?php } ?>
      </tbody>
    </table>
    </div>
  </div>
</div>
<?php debugPageEnd(); ?>

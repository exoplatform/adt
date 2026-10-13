<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();

$data = getenv('ADT_DATA');
$confDir = "$data/conf/apache";

/** Mask the values of the sensitive keys of a descriptor */
function maskDescriptor(array $d)
{
  foreach ($d as $k => $v) {
    if (preg_match('/PASS(WORD|PHRASE)?|SECRET|TOKEN|PRIVATE|CREDENTIAL|_KEY$/i', $k) && $k !== 'INSTANCE_KEY' && $v !== '') {
      $d[$k] = '********';
    }
  }
  return $d;
}

$rows = [];
foreach (glob("$data/conf/adt/*") ?: [] as $file) {
  $d = @parse_ini_file($file);
  if (!is_array($d)) {
    continue;
  }
  $host = $d['DEPLOYMENT_EXT_HOST'] ?? basename($file);
  $pidFile = $d['DEPLOYMENT_PID_FILE'] ?? '';
  $pid = ($pidFile !== '' && is_readable($pidFile)) ? trim((string)file_get_contents($pidFile)) : '';
  $up = $pid !== '' && ctype_digit($pid) && is_dir("/proc/$pid");
  $rows[] = [
    'key' => $d['INSTANCE_KEY'] ?? basename($file),
    'host' => $host,
    'product' => trim(($d['PRODUCT_NAME'] ?? '') . ' ' . ($d['PRODUCT_VERSION'] ?? '')),
    'up' => $up,
    'pidKnown' => $pidFile !== '',
    'security' => $d['DEPLOYMENT_APACHE_SECURITY'] ?? '-',
    'https' => ($d['DEPLOYMENT_APACHE_HTTPS_ENABLED'] ?? '') === 'true' || ($d['DEPLOYMENT_APACHE_HTTPSONLY_ENABLED'] ?? '') === 'true',
    'vhost' => file_exists("$confDir/sites-available/$host"),
    'include' => file_exists("$confDir/includes/$host.include"),
    'deployed' => $d['DEPLOYMENT_DATE'] ?? '',
    'descriptor' => maskDescriptor($d),
    'file' => basename($file),
  ];
}
usort($rows, fn($a, $b) => strcmp($a['host'], $b['host']));

$q = trim((string)($_GET['q'] ?? ''));
if ($q !== '') {
  $rows = array_values(array_filter($rows, fn($r) => stripos($r['host'] . ' ' . $r['key'] . ' ' . $r['product'], $q) !== false));
}
$issues = count(array_filter($rows, fn($r) => !$r['vhost'] || !$r['include']));

debugPageBegin('instances', 'Debug Instances', 'Deployment descriptors, status and Apache configuration of each instance');
?>
<div class="card">
  <div class="card-header"><i class="fas fa-cubes me-2"></i>Instances (<?= count($rows) ?>)<?= $issues ? ' <span class="badge bg-warning text-dark">' . $issues . ' with missing Apache config</span>' : '' ?></div>
  <div class="card-body">
    <form method="get" class="mb-3"><input type="search" name="q" value="<?= htmlspecialchars($q) ?>" class="form-control form-control-sm w-auto d-inline-block" placeholder="Filter" aria-label="Filter"> <button class="btn btn-sm btn-primary" type="submit">Filter</button></form>
    <div class="table-responsive">
    <table class="table table-sm align-middle">
      <thead><tr><th>Host</th><th>Product</th><th>Status</th><th>Apache</th><th>Deployed</th><th>Logs</th><th></th></tr></thead>
      <tbody>
<?php foreach ($rows as $i => $r) { ?>
        <tr>
          <td><?= htmlspecialchars($r['host']) ?><div class="small text-muted"><?= htmlspecialchars($r['key']) ?></div></td>
          <td><?= htmlspecialchars($r['product']) ?></td>
          <td><?= !$r['pidKnown'] ? '<span class="badge bg-secondary">unknown</span>' : ($r['up'] ? '<span class="badge bg-success">Up</span>' : '<span class="badge bg-danger">Down</span>') ?></td>
          <td class="small">
            <?= htmlspecialchars($r['security']) ?><?= $r['https'] ? ', https' : '' ?><br>
            vhost <?= $r['vhost'] ? '<i class="fas fa-check text-success"></i>' : '<i class="fas fa-times text-danger"></i>' ?>
            include <?= $r['include'] ? '<i class="fas fa-check text-success"></i>' : '<i class="fas fa-times text-danger"></i>' ?>
          </td>
          <td class="small text-nowrap"><?= htmlspecialchars($r['deployed'] ?: '-') ?></td>
          <td class="small text-nowrap">
            <a href="/debug-logs?file=<?= urlencode($r['host']) ?>-error.log">error</a> ·
            <a href="/debug-logs?file=<?= urlencode($r['host']) ?>-access.log">access</a>
          </td>
          <td><button type="button" class="btn btn-sm btn-outline-primary" data-bs-toggle="collapse" data-bs-target="#d<?= $i ?>">Descriptor</button></td>
        </tr>
        <tr class="collapse" id="d<?= $i ?>"><td colspan="7"><?= debug_var($r['descriptor'], true) ?></td></tr>
<?php } ?>
<?php if (!$rows) { ?>
        <tr><td colspan="7" class="text-muted">No instance descriptor found in <code><?= htmlspecialchars("$data/conf/adt") ?></code>.</td></tr>
<?php } ?>
      </tbody>
    </table>
    </div>
  </div>
</div>
<?php debugPageEnd(); ?>

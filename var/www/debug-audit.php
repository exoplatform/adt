<?php
require_once(__DIR__ . '/lib/functions.php');
require_once(__DIR__ . '/lib/functions-ui.php');
checkCaches();

$filters = [
  'action' => trim((string)($_GET['action'] ?? '')),
  'user' => trim((string)($_GET['user'] ?? '')),
  'q' => trim((string)($_GET['q'] ?? '')),
];
$entries = auditRead(500, $filters);
$all = auditRead(2000);
$actions = array_values(array_unique(array_map(fn($e) => $e['action'] ?? '', $all)));
$users = array_values(array_unique(array_map(fn($e) => $e['user'] ?? '', $all)));
sort($actions);
sort($users);

debugPageBegin('audit', 'Debug Audit', 'Administrative actions done from the dashboard');
?>
<div class="card">
  <div class="card-header"><i class="fas fa-clipboard-list me-2"></i>Audit log (<?= count($entries) ?> shown, latest first)</div>
  <div class="card-body">
    <form method="get" class="row g-2 mb-3">
      <div class="col-md-3">
        <select name="action" class="form-select form-select-sm" aria-label="Action">
          <option value="">All actions</option>
<?php foreach ($actions as $a) { ?>
          <option value="<?= htmlspecialchars($a) ?>"<?= $a === $filters['action'] ? ' selected' : '' ?>><?= htmlspecialchars($a) ?></option>
<?php } ?>
        </select>
      </div>
      <div class="col-md-3">
        <select name="user" class="form-select form-select-sm" aria-label="User">
          <option value="">All users</option>
<?php foreach ($users as $u) { ?>
          <option value="<?= htmlspecialchars($u) ?>"<?= $u === $filters['user'] ? ' selected' : '' ?>><?= htmlspecialchars($u) ?></option>
<?php } ?>
        </select>
      </div>
      <div class="col-md-4"><input type="search" name="q" value="<?= htmlspecialchars($filters['q']) ?>" class="form-control form-control-sm" placeholder="Search" aria-label="Search"></div>
      <div class="col-md-2"><button class="btn btn-sm btn-primary" type="submit">Filter</button> <a class="btn btn-sm btn-outline-secondary" href="/debug-audit">Reset</a></div>
    </form>
    <div class="table-responsive">
    <table class="table table-hover table-themed table-sm align-middle">
      <thead><tr><th>Time (UTC)</th><th>User</th><th>IP</th><th>Action</th><th>Detail</th></tr></thead>
      <tbody>
<?php foreach ($entries as $e) { ?>
        <tr>
          <td class="text-nowrap"><?= gmdate('Y-m-d H:i:s', (int)($e['ts'] ?? 0)) ?></td>
          <td><?= htmlspecialchars($e['user'] ?? '') ?></td>
          <td><?= htmlspecialchars($e['ip'] ?? '') ?></td>
          <td><code><?= htmlspecialchars($e['action'] ?? '') ?></code></td>
          <td class="small"><?= htmlspecialchars(json_encode($e['detail'] ?? [], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)) ?></td>
        </tr>
<?php } ?>
<?php if (!$entries) { ?>
        <tr><td colspan="5" class="text-muted">No entry.</td></tr>
<?php } ?>
      </tbody>
    </table>
    </div>
  </div>
</div>
<?php debugPageEnd(); ?>

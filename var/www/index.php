<?php
/**
 * ADT v2 dashboard - main page.
 * Lists all deployed instances with status, URL, and features.
 */
require_once __DIR__ . '/lib/functions.php';

$instances = getLocalAcceptanceInstances();
$scheme = getAcceptanceScheme();
$host = getAcceptanceHost();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ADT - Acceptance Deployment Tool</title>
<style>
:root { --green: #22c55e; --red: #ef4444; --gray: #6b7280; --blue: #3b82f6; --bg: #0f172a; --card: #1e293b; --text: #e2e8f0; }
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); padding: 2rem; }
h1 { font-size: 1.5rem; margin-bottom: 1rem; }
.summary { display: flex; gap: 1rem; margin-bottom: 2rem; }
.metric { background: var(--card); padding: 1rem 1.5rem; border-radius: 8px; text-align: center; }
.metric .num { font-size: 2rem; font-weight: 700; }
.metric .lbl { font-size: 0.8rem; color: var(--gray); text-transform: uppercase; }
table { width: 100%; border-collapse: collapse; background: var(--card); border-radius: 8px; overflow: hidden; }
th, td { padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid #334155; }
th { background: #334155; font-size: 0.8rem; text-transform: uppercase; color: var(--gray); }
td a { color: var(--blue); text-decoration: none; }
td a:hover { text-decoration: underline; }
.status-running { color: var(--green); font-weight: 600; }
.status-stopped { color: var(--red); }
.status-unknown { color: var(--gray); }
.badge { display: inline-block; padding: 0.15rem 0.5rem; border-radius: 4px; font-size: 0.7rem; background: #334155; margin: 1px; }
.empty { text-align: center; padding: 3rem; color: var(--gray); }
.features { font-size: 0.75rem; color: var(--gray); }
input[type=text] { background: var(--card); border: 1px solid #334155; color: var(--text); padding: 0.5rem 1rem; border-radius: 6px; width: 300px; margin-bottom: 1rem; }
</style>
</head>
<body>
<h1>ADT Dashboard</h1>
<div class="summary">
  <div class="metric"><div class="num"><?= count($instances) ?></div><div class="lbl">Instances</div></div>
  <div class="metric"><div class="num" style="color: var(--green)"><?= count(array_filter($instances, fn($i) => $i['_status'] === 'running')) ?></div><div class="lbl">Running</div></div>
  <div class="metric"><div class="num" style="color: var(--red)"><?= count(array_filter($instances, fn($i) => $i['_status'] === 'stopped')) ?></div><div class="lbl">Stopped</div></div>
</div>
<input type="text" id="search" placeholder="Search instances..." onkeyup="filterTable()">
<?php if (empty($instances)): ?>
  <p class="empty">No deployed instances. Use <code>adt.sh deploy</code> to deploy one.</p>
<?php else: ?>
<table id="instances">
<thead><tr><th>Instance</th><th>Product</th><th>Version</th><th>Status</th><th>DB</th><th>Features</th><th>URL</th></tr></thead>
<tbody>
<?php foreach ($instances as $inst): ?>
  <tr>
    <td><?= htmlspecialchars($inst['INSTANCE_KEY'] ?? '') ?></td>
    <td><?= htmlspecialchars($inst['PRODUCT_NAME'] ?? '') ?></td>
    <td><?= htmlspecialchars($inst['PRODUCT_VERSION'] ?? '') ?></td>
    <td><span class="status-<?= htmlspecialchars($inst['_status'] ?? 'unknown') ?>"><?= htmlspecialchars(ucfirst($inst['_status'] ?? 'unknown')) ?></span></td>
    <td><?= htmlspecialchars(getInstanceDb($inst)) ?></td>
    <td class="features"><?= htmlspecialchars(getInstanceFeatures($inst)) ?></td>
    <td><a href="<?= htmlspecialchars($inst['_url'] ?? '') ?>" target="_blank"><?= htmlspecialchars($inst['DEPLOYMENT_EXT_HOST'] ?? '') ?></a></td>
  </tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>
<script>
function filterTable() {
  const q = document.getElementById('search').value.toLowerCase();
  const rows = document.querySelectorAll('#instances tbody tr');
  rows.forEach(r => { r.style.display = r.textContent.toLowerCase().includes(q) ? '' : 'none'; });
}
</script>
</body>
</html>

<?php
require_once(__DIR__ . '/lib/functions.php');
require_once(__DIR__ . '/lib/functions-ui.php');
checkCaches();

$logDir = getenv('ADT_DATA') . '/var/log/apache2';
// Only files found in the directory can be chosen (no path from the request is ever used)
$files = [];
foreach (glob("$logDir/*.log") ?: [] as $f) {
  if (is_file($f) && is_readable($f)) {
    $files[basename($f)] = filesize($f);
  }
}
ksort($files);
$file = (string)($_GET['file'] ?? '');
if (!isset($files[$file])) {
  // Default: the frontend error log of this vhost, else the first file
  $file = isset($files[($_SERVER['SERVER_NAME'] ?? '') . '-error.log']) ? $_SERVER['SERVER_NAME'] . '-error.log' : (array_key_first($files) ?? '');
}
$lines = in_array((int)($_GET['lines'] ?? 200), [100, 200, 500, 1000, 2000], true) ? (int)($_GET['lines'] ?? 200) : 200;
$q = trim((string)($_GET['q'] ?? ''));
$level = (string)($_GET['level'] ?? '');
$status = (string)($_GET['status'] ?? '');
$refresh = isset($_GET['refresh']);

/** Last lines of a file (reads at most the last 2MB), oldest first */
function logTail(string $path, int $maxBytes = 2097152): array
{
  $size = filesize($path);
  $h = fopen($path, 'rb');
  if (!$h) {
    return [];
  }
  $start = max(0, $size - $maxBytes);
  fseek($h, $start);
  $data = stream_get_contents($h);
  fclose($h);
  $lines = explode("\n", rtrim($data, "\n"));
  if ($start > 0) {
    array_shift($lines); // partial first line
  }
  return $lines;
}

$out = [];
if ($file !== '') {
  foreach (logTail("$logDir/$file") as $line) {
    if ($q !== '' && stripos($line, $q) === false) {
      continue;
    }
    if ($level !== '' && !preg_match('/\[[a-z_0-9]+:' . preg_quote($level, '/') . '\]/', $line)) {
      continue;
    }
    if ($status !== '' && !preg_match('/" ' . preg_quote($status[0], '/') . '\d\d /', $line)) {
      continue;
    }
    $out[] = $line;
  }
  $out = array_slice($out, -$lines);
}
$isError = str_ends_with($file, '-error.log');

debugPageBegin('logs', 'Debug Apache logs', 'Tail of the frontend and instance Apache logs', false);
?>
<div class="card">
  <div class="card-header"><i class="fas fa-file-alt me-2"></i>Apache logs</div>
  <div class="card-body">
    <form method="get" class="row g-2 mb-3" id="logform">
      <div class="col-md-4">
        <select name="file" class="form-select form-select-sm" aria-label="Log file">
<?php foreach ($files as $name => $size) { ?>
          <option value="<?= htmlspecialchars($name) ?>"<?= $name === $file ? ' selected' : '' ?>><?= htmlspecialchars($name) ?> (<?= debugBytes($size) ?>)</option>
<?php } ?>
        </select>
      </div>
      <div class="col-md-2">
        <select name="lines" class="form-select form-select-sm" aria-label="Lines">
<?php foreach ([100, 200, 500, 1000, 2000] as $n) { ?>
          <option value="<?= $n ?>"<?= $n === $lines ? ' selected' : '' ?>>Last <?= $n ?></option>
<?php } ?>
        </select>
      </div>
      <div class="col-md-2">
<?php if ($isError) { ?>
        <select name="level" class="form-select form-select-sm" aria-label="Level">
          <option value="">All levels</option>
<?php foreach (['error', 'warn', 'notice', 'info', 'debug'] as $l) { ?>
          <option value="<?= $l ?>"<?= $l === $level ? ' selected' : '' ?>><?= $l ?></option>
<?php } ?>
        </select>
<?php } else { ?>
        <select name="status" class="form-select form-select-sm" aria-label="Status">
          <option value="">All statuses</option>
<?php foreach (['2xx', '3xx', '4xx', '5xx'] as $s) { ?>
          <option value="<?= $s ?>"<?= $s === $status ? ' selected' : '' ?>><?= $s ?></option>
<?php } ?>
        </select>
<?php } ?>
      </div>
      <div class="col-md-3"><input type="search" name="q" value="<?= htmlspecialchars($q) ?>" class="form-control form-control-sm" placeholder="Contains" aria-label="Contains"></div>
      <div class="col-md-1"><button class="btn btn-sm btn-primary" type="submit">Show</button></div>
      <div class="col-12">
        <div class="form-check form-switch">
          <input class="form-check-input" type="checkbox" role="switch" name="refresh" id="refresh" value="1"<?= $refresh ? ' checked' : '' ?>>
          <label class="form-check-label small" for="refresh">Auto-refresh every 5s</label>
        </div>
      </div>
    </form>
<?php if ($file === '') { ?>
    <div class="alert alert-secondary">No log file found in <code><?= htmlspecialchars($logDir) ?></code>.</div>
<?php } else { ?>
    <p class="small text-muted"><?= count($out) ?> line(s) from <code><?= htmlspecialchars($file) ?></code></p>
    <pre class="debug-dump" style="max-height:65vh;overflow:auto;white-space:pre-wrap;word-break:break-all"><code><?= htmlspecialchars(implode("\n", $out)) ?></code></pre>
<?php } ?>
  </div>
</div>
<script>
  (function () {
    var form = document.getElementById('logform'), box = document.getElementById('refresh');
    form.querySelectorAll('select').forEach(function (s) { s.addEventListener('change', function () { form.submit(); }); });
    box.addEventListener('change', function () { form.submit(); });
    if (box.checked) setTimeout(function () { form.submit(); }, 5000);
    var pre = document.querySelector('pre.debug-dump');
    if (pre) pre.scrollTop = pre.scrollHeight;
  })();
</script>
<?php debugPageEnd(); ?>

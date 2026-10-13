<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();

$data = getenv('ADT_DATA');
$confDir = "$data/conf/apache";

/** Hide the value of the secret directives/variables in a configuration text */
function maskSecrets($text)
{
  // Apache directives holding a secret
  $text = preg_replace('/^(\s*(?:AuthLDAPBindPassword|SessionCryptoPassphrase|SSLCertificateKeyFile|SetEnv\s+\S*(?:PASS\w*|SECRET|TOKEN)\S*))\s+.*$/mi', '$1 ********', $text);
  // KEY=value / KEY "value" style lines
  return preg_replace('/^(\s*\S*(?:PASSWORD|PASSPHRASE|SECRET|TOKEN)\S*\s*[=\s]\s*).+$/mi', '$1********', $text);
}

// Files that can be shown: the rendered Apache includes and vhosts only
$files = [];
foreach (['includes' => "$confDir/includes", 'sites-available' => "$confDir/sites-available", 'conf.d' => "$confDir/conf.d"] as $label => $dir) {
  foreach (glob("$dir/*") ?: [] as $f) {
    if (is_file($f) && is_readable($f)) {
      $files["$label/" . basename($f)] = $f;
    }
  }
}
ksort($files);
$selected = (string)($_GET['file'] ?? '');
if (!isset($files[$selected])) {
  $selected = isset($files['includes/acceptance-frontend.include']) ? 'includes/acceptance-frontend.include' : (array_key_first($files) ?? '');
}
$content = $selected !== '' ? maskSecrets((string)file_get_contents($files[$selected])) : '';

// Environment seen by the web server
$envKeys = ['ADT_DATA', 'ACCEPTANCE_SERVERS', 'ADT_APACHE_VERSION', 'ADT_APACHE_VERSION_MINOR', 'ADT_DEV_MODE',
            'ACCEPTANCE_HOST', 'ACCEPTANCE_SCHEME', 'LDAP_ACCEPTANCE_BIND_DN', 'LDAP_ACCEPTANCE_BIND_PASSWORD',
            'LDAP_ACCEPTANCE_APACHE2_ADMIN_DN', 'ADT_SESSION_PASSPHRASE', 'CROWD_ACCEPTANCE_APP_NAME', 'CROWD_ACCEPTANCE_APP_PASSWORD'];
$env = [];
foreach ($envKeys as $k) {
  $v = getenv($k);
  if ($v !== false) {
    $env[$k] = preg_match('/PASS(WORD|PHRASE)|SECRET|TOKEN/', $k) ? ($v === '' ? '' : '********') : $v;
  }
}
$mods = function_exists('apache_get_modules') ? apache_get_modules() : [];
sort($mods);

debugPageBegin('config', 'Debug Config', 'Rendered Apache configuration and environment (secrets masked)');
?>
<div class="row g-3">
  <div class="col-12">
    <div class="card">
      <div class="card-header"><i class="fas fa-file-code me-2"></i>Rendered Apache configuration</div>
      <div class="card-body">
        <form method="get" class="mb-3">
          <select name="file" class="form-select form-select-sm w-auto d-inline-block" aria-label="File" onchange="this.form.submit()">
<?php foreach ($files as $label => $path) { ?>
            <option value="<?= htmlspecialchars($label) ?>"<?= $label === $selected ? ' selected' : '' ?>><?= htmlspecialchars($label) ?></option>
<?php } ?>
          </select>
        </form>
<?php if ($selected === '') { ?>
        <div class="alert alert-secondary mb-0">No rendered configuration found in <code><?= htmlspecialchars($confDir) ?></code>.</div>
<?php } else { ?>
        <p class="small text-muted"><code><?= htmlspecialchars($files[$selected]) ?></code> &middot; <?= htmlspecialchars(gmdate('Y-m-d H:i', filemtime($files[$selected]))) ?> UTC &middot; <?= debugBytes(filesize($files[$selected])) ?></p>
        <pre class="debug-dump" style="max-height:60vh;overflow:auto"><code><?= htmlspecialchars($content) ?></code></pre>
<?php } ?>
      </div>
    </div>
  </div>
  <div class="col-lg-6">
    <div class="card h-100">
      <div class="card-header"><i class="fas fa-leaf me-2"></i>Environment</div>
      <div class="card-body">
        <table class="table table-themed table-sm mb-0"><tbody>
<?php foreach ($env as $k => $v) { ?>
          <tr><th scope="row"><code><?= htmlspecialchars($k) ?></code></th><td class="text-break"><?= $v === '' ? '<span class="text-muted">empty</span>' : htmlspecialchars($v) ?></td></tr>
<?php } ?>
        </tbody></table>
      </div>
    </div>
  </div>
  <div class="col-lg-6">
    <div class="card h-100">
      <div class="card-header"><i class="fas fa-puzzle-piece me-2"></i>Apache modules (<?= count($mods) ?>)</div>
      <div class="card-body">
<?php if ($mods) { ?>
        <p class="small mb-0"><?php foreach ($mods as $m) { echo '<span class="badge bg-secondary me-1 mb-1">' . htmlspecialchars($m) . '</span>'; } ?></p>
<?php } else { ?>
        <div class="alert alert-secondary mb-0">Module list not available (PHP is not running as an Apache module).</div>
<?php } ?>
      </div>
    </div>
  </div>
</div>
<?php debugPageEnd(); ?>

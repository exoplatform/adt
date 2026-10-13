<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
require_once(dirname(__FILE__) . '/lib/functions-sessions.php');

$notice = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $id = (string)($_POST['id'] ?? '');
  if (!hash_equals(sessionsCsrfToken(), (string)($_POST['token'] ?? ''))) {
    http_response_code(403);
    exit('Invalid token');
  }
  if (($_POST['action'] ?? '') === 'evict-all') {
    $n = evictAllSessions(currentSessionId());
    $notice = ['success', "$n session(s) evicted (yours was kept): those users are sent back to the login page on their next request."];
  } elseif ($id === currentSessionId()) {
    $notice = ['warning', 'You cannot evict your own session (use Logout).'];
  } elseif (evictSession($id)) {
    $notice = ['success', 'Session evicted: the user is sent back to the login page on the next request.'];
  } else {
    $notice = ['danger', 'Session not found.'];
  }
}
$sessions = listSessions();
$current = currentSessionId();
$now = time();
$token = sessionsCsrfToken();
?>
<html lang="en">
<head>
  <?= pageHeader("debug - sessions", false); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
  <div id="wrap">
    <div id="main">
      <div class="page-header">
        <h1 class="page-header__title">Debug Sessions</h1>
        <p class="page-header__subtitle">Connected users, session time and eviction</p>
      </div>
      <div class="container-fluid">
        <div class="row">
          <div class="col-12">
            <?= componentDebugMenu(); ?>
<?php if ($notice) { ?>
            <div class="alert alert-<?= $notice[0] ?>"><?= htmlspecialchars($notice[1]) ?></div>
<?php } ?>
            <div class="card">
              <div class="card-header d-flex justify-content-between align-items-center">
                <span><i class="fas fa-users me-2"></i>Login sessions (<?= count($sessions) ?>)</span>
                <form method="post" class="d-inline" onsubmit="return confirm('Evict all other sessions?');">
                  <input type="hidden" name="action" value="evict-all">
                  <input type="hidden" name="token" value="<?= $token ?>">
                  <button type="submit" class="btn btn-sm btn-danger"><i class="fas fa-users-slash me-1"></i>Evict all</button>
                </form>
              </div>
              <div class="card-body">
                <p class="text-muted small">Only sessions that visited the dashboard since this feature was enabled are listed.
                  Evicting a session rejects its cookie on every path; the user can log in again.</p>
                <div class="table-responsive">
                <table class="table table-sm align-middle">
                  <thead><tr>
                    <th>User</th><th>IP</th><th>Browser</th><th>Connected</th><th>Last seen</th><th>Expires in</th><th></th>
                  </tr></thead>
                  <tbody>
<?php foreach ($sessions as $s) { ?>
                    <tr>
                      <td><?= htmlspecialchars($s['name']) ?> <span class="text-muted">(<?= htmlspecialchars($s['user']) ?>)</span><?= $s['id'] === $current ? ' <span class="badge bg-info">you</span>' : '' ?></td>
                      <td><?= htmlspecialchars($s['ip']) ?></td>
                      <td class="small text-truncate" style="max-width:260px" title="<?= htmlspecialchars($s['ua']) ?>"><?= htmlspecialchars($s['ua']) ?></td>
                      <td><?= durationLabel($now - $s['first_seen']) ?> ago</td>
                      <td><?= durationLabel($now - $s['last_seen']) ?> ago</td>
                      <td><?= durationLabel($s['expiry'] - $now) ?></td>
                      <td>
<?php if (!empty($s['evicted'])) { ?>
                        <span class="badge bg-danger">Evicted</span>
<?php } elseif ($s['id'] === $current) { ?>
                        <button class="btn btn-sm btn-outline-secondary" disabled>Evict</button>
<?php } else { ?>
                        <form method="post" class="d-inline" onsubmit="return confirm('Evict <?= htmlspecialchars(addslashes($s['user']), ENT_QUOTES) ?>?');">
                          <input type="hidden" name="id" value="<?= $s['id'] ?>">
                          <input type="hidden" name="token" value="<?= $token ?>">
                          <button type="submit" class="btn btn-sm btn-outline-danger"><i class="fas fa-user-slash me-1"></i>Evict</button>
                        </form>
<?php } ?>
                      </td>
                    </tr>
<?php } ?>
<?php if (!$sessions) { ?>
                    <tr><td colspan="7" class="text-muted">No tracked session.</td></tr>
<?php } ?>
                  </tbody>
                </table>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
<?php pageFooter(); ?>
</body>
</html>

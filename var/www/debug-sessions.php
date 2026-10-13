<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
require_once(dirname(__FILE__) . '/lib/functions-sessions.php');

$notice = null;
$current = currentSessionId();
$me = strtolower(auditActor());
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $id = (string)($_POST['id'] ?? '');
  $user = trim((string)($_POST['user'] ?? ''));
  if (!hash_equals(sessionsCsrfToken(), (string)($_POST['token'] ?? ''))) {
    http_response_code(403);
    exit('Invalid token');
  }
  switch ($_POST['action'] ?? '') {
    case 'evict-all':
      $n = evictAllSessions($current);
      $notice = ['success', "$n session(s) evicted (yours was kept): those users are sent back to the login page on their next request."];
      break;
    case 'evict-user':
      $n = $user === '' ? 0 : evictUserSessions($user, $current);
      $notice = ['success', "$n session(s) of $user evicted."];
      break;
    case 'block':
      $minutes = in_array((int)($_POST['minutes'] ?? 0), [15, 60, 480, 1440], true) ? (int)$_POST['minutes'] : 60;
      if ($user === '' || strtolower($user) === $me) {
        $notice = ['warning', 'You cannot block yourself.'];
      } else {
        blockUser($user, $minutes, $current);
        $notice = ['success', "$user is blocked for $minutes minute(s): their sessions are evicted and they cannot log in again meanwhile."];
      }
      break;
    case 'unblock':
      $notice = unblockUser((string)($_POST['hash'] ?? '')) ? ['success', 'User unblocked.'] : ['danger', 'Block not found.'];
      break;
    default:
      if ($id === $current) {
        $notice = ['warning', 'You cannot evict your own session (use Logout).'];
      } elseif (evictSession($id)) {
        $notice = ['success', 'Session evicted: the user is sent back to the login page on the next request.'];
      } else {
        $notice = ['danger', 'Session not found.'];
      }
  }
}
$sessions = listSessions();
$blocked = listBlocked();
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
                <span class="form-check form-switch mb-0">
                  <input class="form-check-input" type="checkbox" role="switch" id="autorefresh">
                  <label class="form-check-label small" for="autorefresh">Auto-refresh (10s)</label>
                </span>
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
            <?php
              // Users with at least one live session, with their session count
              $byUser = [];
              foreach ($sessions as $sess) {
                if (empty($sess['evicted'])) {
                  $key = strtolower($sess['user']);
                  $byUser[$key] = $byUser[$key] ?? ['user' => $sess['user'], 'name' => $sess['name'], 'count' => 0];
                  $byUser[$key]['count']++;
                }
              }
              ksort($byUser);
            ?>
            <div class="card mt-4">
              <div class="card-header"><i class="fas fa-user-lock me-2"></i>Users (<?= count($byUser) ?>)</div>
              <div class="card-body">
                <p class="text-muted small">Block evicts every session of the user and refuses their login for the chosen time (web login only, not <code>curl</code> on <code>/downloads</code> and similar Basic-auth paths).</p>
                <div class="table-responsive">
                <table class="table table-sm align-middle">
                  <thead><tr><th>User</th><th>Sessions</th><th></th></tr></thead>
                  <tbody>
<?php foreach ($byUser as $u) { $isMe = strtolower($u['user']) === $me; ?>
                    <tr>
                      <td><?= htmlspecialchars($u['name']) ?> <span class="text-muted">(<?= htmlspecialchars($u['user']) ?>)</span><?= $isMe ? ' <span class="badge bg-info">you</span>' : '' ?></td>
                      <td><?= $u['count'] ?></td>
                      <td class="text-nowrap">
                        <form method="post" class="d-inline" onsubmit="return confirm('Evict all the sessions of <?= htmlspecialchars(addslashes($u['user']), ENT_QUOTES) ?>?');">
                          <input type="hidden" name="action" value="evict-user">
                          <input type="hidden" name="user" value="<?= htmlspecialchars($u['user'], ENT_QUOTES) ?>">
                          <input type="hidden" name="token" value="<?= $token ?>">
                          <button type="submit" class="btn btn-sm btn-outline-danger"<?= $isMe && $u['count'] < 2 ? ' disabled' : '' ?>>Evict user</button>
                        </form>
<?php if (!$isMe) { ?>
                        <form method="post" class="d-inline-flex gap-1 align-items-center" onsubmit="return confirm('Block <?= htmlspecialchars(addslashes($u['user']), ENT_QUOTES) ?>?');">
                          <input type="hidden" name="action" value="block">
                          <input type="hidden" name="user" value="<?= htmlspecialchars($u['user'], ENT_QUOTES) ?>">
                          <input type="hidden" name="token" value="<?= $token ?>">
                          <select name="minutes" class="form-select form-select-sm w-auto" aria-label="Block duration">
                            <option value="15">15 min</option><option value="60" selected>1 hour</option><option value="480">8 hours</option><option value="1440">24 hours</option>
                          </select>
                          <button type="submit" class="btn btn-sm btn-outline-warning"><i class="fas fa-ban me-1"></i>Block</button>
                        </form>
<?php } ?>
                      </td>
                    </tr>
<?php } ?>
<?php if (!$byUser) { ?>
                    <tr><td colspan="3" class="text-muted">No connected user.</td></tr>
<?php } ?>
                  </tbody>
                </table>
                </div>
              </div>
            </div>
<?php if ($blocked) { ?>
            <div class="card mt-4">
              <div class="card-header"><i class="fas fa-ban me-2"></i>Blocked users (<?= count($blocked) ?>)</div>
              <div class="card-body">
                <table class="table table-sm align-middle mb-0">
                  <thead><tr><th>User</th><th>Blocked by</th><th>Remaining</th><th></th></tr></thead>
                  <tbody>
<?php foreach ($blocked as $b) { ?>
                    <tr>
                      <td><?= htmlspecialchars($b['user']) ?></td>
                      <td><?= htmlspecialchars($b['by']) ?></td>
                      <td><?= durationLabel($b['until'] - $now) ?></td>
                      <td>
                        <form method="post" class="d-inline">
                          <input type="hidden" name="action" value="unblock">
                          <input type="hidden" name="hash" value="<?= $b['hash'] ?>">
                          <input type="hidden" name="token" value="<?= $token ?>">
                          <button type="submit" class="btn btn-sm btn-outline-success">Unblock</button>
                        </form>
                      </td>
                    </tr>
<?php } ?>
                  </tbody>
                </table>
              </div>
            </div>
<?php } ?>
          </div>
        </div>
      </div>
    </div>
  </div>
<script>
  (function () {
    var box = document.getElementById('autorefresh'), timer = null;
    function get() { try { return localStorage.getItem('sessionsRefresh') === '1'; } catch (e) { return false; } }
    function set(v) { try { localStorage.setItem('sessionsRefresh', v ? '1' : '0'); } catch (e) {} }
    function apply() {
      clearTimeout(timer);
      // Reload as a plain GET so a pending POST result is never resubmitted
      if (box.checked) timer = setTimeout(function () { location.href = location.pathname; }, 10000);
    }
    box.checked = get();
    box.addEventListener('change', function () { set(box.checked); apply(); });
    apply();
  })();
</script>
<?php pageFooter(); ?>
</body>
</html>

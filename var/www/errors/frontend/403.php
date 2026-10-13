<?php
// 403 error page (ErrorDocument).
// - A session evicted from /debug-sessions is rejected with a 403: send that user back to the login page
//   instead of showing "Access Forbidden".
// - A user blocked from /debug-sessions gets a 403 once logged in: say so, and retry the request as soon as
//   the block has expired (its entry is then dropped from revoked.txt).
require_once(dirname(__FILE__) . '/../../lib/functions-sessions.php');

if (isSessionRevoked()) {
  header('Location: /login?next=' . rawurlencode($_SERVER['REQUEST_URI'] ?? '/'));
  exit;
}

$html = file_get_contents(dirname(__FILE__) . '/403.html');
$user = $_SERVER['REMOTE_USER'] ?? $_SERVER['REDIRECT_REMOTE_USER'] ?? '';
if ($user !== '') {
  $block = userBlock($user); // drops the expired blocks
  $revoked = static fn() => strpos((string)@file_get_contents(sessionsDir() . '/revoked.txt'), userHash($user)) !== false;
  if ($block) {
    $notice = '<p class="sub" role="alert">Your access has been blocked by an administrator until '
      . htmlspecialchars(gmdate('H:i', $block['until'])) . ' UTC.</p>';
    $html = str_replace('<div class="cards">', $notice . '<div class="cards">', $html);
  } elseif ($revoked()) {
    // Stale entry of an expired block: regenerate revoked.txt, then retry once it is gone
    listSessions();
    if (!$revoked()) {
      header('Location: ' . ($_SERVER['REQUEST_URI'] ?? '/'));
      exit;
    }
  }
}
http_response_code(403);
echo $html;

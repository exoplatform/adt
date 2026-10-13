<?php
// 403 error page (ErrorDocument). A session evicted from /debug-sessions is rejected with a 403;
// send that user back to the login page instead of showing "Access Forbidden".
require_once(dirname(__FILE__) . '/../../lib/functions-sessions.php');

if (isSessionRevoked()) {
  $target = $_SERVER['REQUEST_URI'] ?? '/';
  header('Location: /login?next=' . rawurlencode($target));
  exit;
}
http_response_code(403);
readfile(dirname(__FILE__) . '/403.html');

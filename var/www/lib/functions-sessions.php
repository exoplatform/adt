<?php
/**
 * Login session tracking and eviction.
 *
 * Login sessions are stateless encrypted cookies (mod_session_cookie), so Apache keeps no
 * list of them. Each dashboard request records its session here (one JSON file per session,
 * keyed by sha1 of the raw session cookie.
 * Evicting a session adds that same sha1 to revoked.txt, which Apache reads on every
 * request (Require expr + file(), see frontend.include.j2) to reject the cookie.
 * A new login produces a new session value, hence is not affected by an earlier eviction.
 */

/** Directory holding the tracked sessions and revoked.txt */
function sessionsDir()
{
  return getenv('ADT_DATA') . '/var/sessions';
}

/** Raw (still encrypted) value of the session cookie, as Apache sees it, or '' */
function sessionCookieValue()
{
  return preg_match('/(?:^|; ?)adt_session=([^;]+)/', $_SERVER['HTTP_COOKIE'] ?? '', $m) ? $m[1] : '';
}

/** Identifier of the current session (what Apache hashes in its revocation check), or null */
function currentSessionId()
{
  $raw = sessionCookieValue();
  return $raw === '' || ($_SERVER['HTTP_SESSION'] ?? '') === '' ? null : sha1($raw);
}

/** Whether the current request carries an evicted session cookie */
function isSessionRevoked()
{
  $raw = sessionCookieValue();
  $revoked = $raw === '' ? false : @file_get_contents(sessionsDir() . '/revoked.txt');
  return $revoked !== false && strpos($revoked, sha1($raw)) !== false;
}

/** Anti-CSRF token for the eviction form, derived from the (secret) current session */
function sessionsCsrfToken()
{
  return hash_hmac('sha256', 'evict-session', $_SERVER['HTTP_SESSION'] ?? '');
}

/**
 * Record the current request's session (throttled: at most one write every 30s per session).
 * Never fails the page if the directory is not writable.
 */
function trackSession()
{
  $id = currentSessionId();
  $dir = sessionsDir();
  if ($id === null || !is_dir($dir) || !is_writable($dir)) {
    return;
  }
  parse_str($_SERVER['HTTP_SESSION'], $session);
  $expiry = (int)($session['expiry'] ?? 0);
  $user = (string)($session['user'] ?? ($_SERVER['REMOTE_USER'] ?? ''));
  if ($user === '' || $expiry <= 0) {
    return;
  }
  $file = "$dir/$id.json";
  $now = time();
  $rec = is_file($file) ? (json_decode((string)@file_get_contents($file), true) ?: []) : [];
  if (!empty($rec['evicted']) || (($rec['last_seen'] ?? 0) > $now - 30)) {
    return;
  }
  $rec = array_merge([
    'id' => $id,
    'first_seen' => $now,
    'evicted' => false,
  ], $rec, [
    'user' => $user,
    'name' => $_SERVER['AUTHENTICATE_DISPLAYNAME'] ?? $user,
    'ip' => $_SERVER['REMOTE_ADDR'] ?? '',
    'ua' => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 200),
    'expiry' => intdiv($expiry, 1000000),
    'last_seen' => $now,
  ]);
  @file_put_contents($file, json_encode($rec), LOCK_EX);
}

/**
 * Tracked sessions (still valid ones, newest activity first). Expired ones are pruned.
 * Evicted ones are kept, flagged, until their cookie would have expired anyway.
 */
function listSessions()
{
  $dir = sessionsDir();
  $sessions = [];
  $now = time();
  foreach (glob("$dir/*.json") ?: [] as $file) {
    $rec = json_decode((string)@file_get_contents($file), true);
    if (!is_array($rec) || ($rec['expiry'] ?? 0) <= $now) {
      @unlink($file);
      continue;
    }
    $sessions[] = $rec;
  }
  usort($sessions, fn($a, $b) => $b['last_seen'] <=> $a['last_seen']);
  rewriteRevokedList($sessions);
  return $sessions;
}

/** Rebuild revoked.txt (one session id per line) from the evicted, not yet expired sessions */
function rewriteRevokedList(array $sessions)
{
  $ids = [];
  foreach ($sessions as $s) {
    if (!empty($s['evicted'])) {
      $ids[] = $s['id'];
    }
  }
  $content = $ids ? implode("\n", $ids) . "\n" : '';
  $file = sessionsDir() . '/revoked.txt';
  if (!is_file($file) || file_get_contents($file) !== $content) {
    file_put_contents($file, $content, LOCK_EX);
  }
}

/** Evict a tracked session. Returns true if it was found. */
function evictSession($id)
{
  if (!preg_match('/^[0-9a-f]{40}$/', $id)) {
    return false;
  }
  $file = sessionsDir() . "/$id.json";
  if (!is_file($file)) {
    return false;
  }
  $rec = json_decode((string)file_get_contents($file), true);
  if (!is_array($rec)) {
    return false;
  }
  $rec['evicted'] = true;
  $rec['evicted_at'] = time();
  $rec['evicted_by'] = $_SERVER['REMOTE_USER'] ?? '';
  file_put_contents($file, json_encode($rec), LOCK_EX);
  listSessions(); // regenerates revoked.txt
  auditLog('session.evict', ['target' => $rec['user'] ?? '', 'session' => substr($id, 0, 8)]);
  return true;
}

/** Evict every tracked, not yet evicted session except $exceptId. Returns how many were evicted. */
function evictAllSessions($exceptId = null)
{
  $count = 0;
  foreach (listSessions() as $s) {
    if (empty($s['evicted']) && $s['id'] !== $exceptId) {
      $file = sessionsDir() . "/{$s['id']}.json";
      $s['evicted'] = true;
      $s['evicted_at'] = time();
      $s['evicted_by'] = $_SERVER['REMOTE_USER'] ?? '';
      file_put_contents($file, json_encode($s), LOCK_EX);
      $count++;
    }
  }
  listSessions(); // regenerates revoked.txt
  auditLog('session.evict-all', ['count' => $count]);
  return $count;
}

/** "2h 05m" style duration */
function durationLabel($seconds)
{
  $seconds = max(0, (int)$seconds);
  $d = intdiv($seconds, 86400);
  $h = intdiv($seconds % 86400, 3600);
  $m = intdiv($seconds % 3600, 60);
  return $d > 0 ? sprintf('%dd %dh', $d, $h) : sprintf('%dh %02dm', $h, $m);
}

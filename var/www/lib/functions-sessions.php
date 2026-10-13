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
function sessionsDir(): string
{
  return getenv('ADT_DATA') . '/var/sessions';
}

/** Raw (still encrypted) value of the session cookie, as Apache sees it, or '' */
function sessionCookieValue(): string
{
  return preg_match('/(?:^|; ?)adt_session=([^;]+)/', $_SERVER['HTTP_COOKIE'] ?? '', $m) ? $m[1] : '';
}

/** Identifier of the current session (what Apache hashes in its revocation check), or null */
function currentSessionId(): ?string
{
  $raw = sessionCookieValue();
  return $raw === '' || ($_SERVER['HTTP_SESSION'] ?? '') === '' ? null : sha1($raw);
}

/** Whether the current request carries an evicted session cookie */
function isSessionRevoked(): bool
{
  $raw = sessionCookieValue();
  $revoked = $raw === '' ? false : @file_get_contents(sessionsDir() . '/revoked.txt');
  return $revoked !== false && str_contains($revoked, sha1($raw));
}

/** Anti-CSRF token for the eviction form, derived from the (secret) current session */
function sessionsCsrfToken(): string
{
  return hash_hmac('sha256', 'evict-session', $_SERVER['HTTP_SESSION'] ?? '');
}

/**
 * Record the current request's session (throttled: at most one write every 30s per session).
 * Never fails the page if the directory is not writable.
 */
function trackSession(): void
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
function listSessions(): array
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

/**
 * Rebuild revoked.txt from the evicted, not yet expired sessions (sha1 of the session cookie) and the
 * blocked users (sha1 of the lowercased login), one per line. Apache rejects any request matching one.
 */
function rewriteRevokedList(array $sessions): void
{
  $ids = [];
  foreach ($sessions as $s) {
    if (!empty($s['evicted'])) {
      $ids[] = $s['id'];
    }
  }
  foreach (listBlocked() as $b) {
    $ids[] = $b['hash'];
  }
  $content = $ids ? implode("\n", $ids) . "\n" : '';
  $file = sessionsDir() . '/revoked.txt';
  if (!is_file($file) || file_get_contents($file) !== $content) {
    file_put_contents($file, $content, LOCK_EX);
  }
}

/** Evict a tracked session. Returns true if it was found. */
function evictSession(string $id): bool
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

/** Flag as evicted the tracked sessions accepted by $filter, returns how many. Regenerates revoked.txt. */
function evictWhere(callable $filter): int
{
  $count = 0;
  foreach (listSessions() as $s) {
    if (empty($s['evicted']) && $filter($s)) {
      $s['evicted'] = true;
      $s['evicted_at'] = time();
      $s['evicted_by'] = $_SERVER['REMOTE_USER'] ?? '';
      file_put_contents(sessionsDir() . "/{$s['id']}.json", json_encode($s), LOCK_EX);
      $count++;
    }
  }
  listSessions(); // regenerates revoked.txt
  return $count;
}

/** Evict every tracked, not yet evicted session except $exceptId. Returns how many were evicted. */
function evictAllSessions(?string $exceptId = null): int
{
  $count = evictWhere(fn($s) => $s['id'] !== $exceptId);
  auditLog('session.evict-all', ['count' => $count]);
  return $count;
}

/** Evict all the sessions of a user (except $exceptId). Returns how many were evicted. */
function evictUserSessions(string $user, ?string $exceptId = null): int
{
  $count = evictWhere(fn($s) => strcasecmp($s['user'], $user) === 0 && $s['id'] !== $exceptId);
  auditLog('session.evict-user', ['target' => $user, 'count' => $count]);
  return $count;
}

/** Directory of the login blocks (one JSON file per blocked user) */
function blockedDir(): string
{
  return sessionsDir() . '/blocked';
}

/** Key of a user in the blocks and in revoked.txt: Apache computes the same with tolower(REMOTE_USER) */
function userHash(string $user): string
{
  return sha1(strtolower($user));
}

/** Active login blocks, soonest to expire first. Expired ones are removed. */
function listBlocked(): array
{
  $blocks = [];
  foreach (glob(blockedDir() . '/*.json') ?: [] as $file) {
    $rec = json_decode((string)@file_get_contents($file), true);
    if (!is_array($rec) || ($rec['until'] ?? 0) <= time()) {
      @unlink($file);
      continue;
    }
    $blocks[] = $rec;
  }
  usort($blocks, fn($a, $b) => $a['until'] <=> $b['until']);
  return $blocks;
}

/** The active block of a user, or null */
function userBlock(string $user): ?array
{
  foreach (listBlocked() as $b) {
    if ($b['hash'] === userHash($user)) {
      return $b;
    }
  }
  return null;
}

/** Block the login of a user for $minutes and evict their sessions (except $exceptId) */
function blockUser(string $user, int $minutes, ?string $exceptId = null): void
{
  $dir = blockedDir();
  if (!is_dir($dir)) {
    @mkdir($dir, 0777, true);
  }
  $rec = [
    'hash' => userHash($user),
    'user' => $user,
    'until' => time() + max(1, (int)$minutes) * 60,
    'by' => $_SERVER['REMOTE_USER'] ?? '',
    'at' => time(),
  ];
  file_put_contents("$dir/{$rec['hash']}.json", json_encode($rec), LOCK_EX);
  evictWhere(fn($s) => strcasecmp($s['user'], $user) === 0 && $s['id'] !== $exceptId); // also rewrites revoked.txt
  auditLog('user.block', ['target' => $user, 'minutes' => (int)$minutes]);
}

function unblockUser(string $hash): bool
{
  if (!preg_match('/^[0-9a-f]{40}$/', $hash)) {
    return false;
  }
  $file = blockedDir() . "/$hash.json";
  $rec = is_file($file) ? json_decode((string)file_get_contents($file), true) : null;
  if (!is_array($rec)) {
    return false;
  }
  @unlink($file);
  listSessions(); // regenerates revoked.txt
  auditLog('user.unblock', ['target' => $rec['user'] ?? '']);
  return true;
}

/** "2h 05m" style duration */
function durationLabel(int|float $seconds): string
{
  $seconds = max(0, (int)$seconds);
  $d = intdiv($seconds, 86400);
  $h = intdiv($seconds % 86400, 3600);
  $m = intdiv($seconds % 3600, 60);
  return $d > 0 ? sprintf('%dd %dh', $d, $h) : sprintf('%dh %02dm', $h, $m);
}

<?php
/**
 * Audit log of the administrative actions done from the dashboard (JSON lines).
 * Rotated at 5MB (audit.log -> audit.log.1, one generation kept).
 */

function auditDir(): string
{
  return getenv('ADT_DATA') . '/var/audit';
}

/** Login of the user doing the current request */
function auditActor(): string
{
  if (!empty($_SERVER['REMOTE_USER'])) {
    return $_SERVER['REMOTE_USER'];
  }
  parse_str($_SERVER['HTTP_SESSION'] ?? '', $session);
  return (string)($session['user'] ?? '-');
}

/** Append an entry. Never fails the request if the log is not writable. */
function auditLog(string $action, array $detail = []): void
{
  $dir = auditDir();
  if (!is_dir($dir)) {
    @mkdir($dir, 0777, true);
  }
  if (!is_dir($dir) || !is_writable($dir)) {
    return;
  }
  $file = "$dir/audit.log";
  if (is_file($file) && filesize($file) > 5 * 1024 * 1024) {
    @rename($file, "$file.1");
  }
  $line = json_encode([
    'ts' => time(),
    'user' => auditActor(),
    'ip' => $_SERVER['REMOTE_ADDR'] ?? '',
    'action' => $action,
    'detail' => $detail,
  ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
  @file_put_contents($file, $line . "\n", FILE_APPEND | LOCK_EX);
}

/**
 * Latest entries first. $filters: 'action' (prefix match), 'user' (exact), 'q' (substring of the entry).
 */
function auditRead(int $limit = 500, array $filters = []): array
{
  $entries = [];
  foreach (["audit.log", "audit.log.1"] as $name) {
    $file = auditDir() . "/$name";
    $lines = is_file($file) ? (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: []) : [];
    foreach (array_reverse($lines) as $line) {
      $e = json_decode($line, true);
      if (!is_array($e)) {
        continue;
      }
      if (!empty($filters['action']) && !str_starts_with($e['action'] ?? '', $filters['action'])) {
        continue;
      }
      if (!empty($filters['user']) && ($e['user'] ?? '') !== $filters['user']) {
        continue;
      }
      if (!empty($filters['q']) && stripos($line, $filters['q']) === false) {
        continue;
      }
      $entries[] = $e;
      if (count($entries) >= $limit) {
        return $entries;
      }
    }
  }
  return $entries;
}

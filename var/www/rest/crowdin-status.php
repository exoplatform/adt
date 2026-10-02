<?php
/**
 * Latest result of one GitHub Actions workflow, for the Crowdin Healthcheck
 * page. Status badges (GitHub's, and shields.io which wraps them) only count
 * push-triggered runs and are served inconsistently by GitHub's CDN, so the
 * runs are read from the Actions API instead.
 *
 * The API allows 60 requests/hour without a token (5000 with GITHUB_TOKEN),
 * shared with every other page, so:
 * - results are cached server-side for all viewers (CACHE_TTL),
 * - refreshes are conditional (ETag): a 304 doesn't count against the limit,
 * - calls stop while the remaining quota is low, until the limit resets, and
 *   the last known result is served meanwhile.
 * When no result is available at all, "level" is null and the page falls
 * back to the shields.io badge.
 */
require_once(dirname(__FILE__) . '/../lib/functions.php');
header("Content-type: application/json; charset=utf-8");
header("Cache-Control: private, max-age=60");

const CACHE_TTL = 600;          // seconds a result is reused before refreshing
const STALE_TTL = 86400;        // seconds a result is kept as a fallback
const QUOTA_RESERVE = 10;       // requests left untouched for other pages
const LIMITED_KEY = 'github_api_limited_until';

$org = $_GET['org'] ?? '';
$repo = $_GET['repo'] ?? '';
$workflow = $_GET['workflow'] ?? '';
$branch = $_GET['branch'] ?? '';
if (!preg_match('#^[A-Za-z0-9_.-]+$#', $org) || !preg_match('#^[A-Za-z0-9_.-]+$#', $repo)
    || !preg_match('#^[A-Za-z0-9_.-]+\.ya?ml$#', $workflow) || !preg_match('#^[A-Za-z0-9_./-]*$#', $branch)) {
  http_response_code(400);
  echo json_encode(array('level' => null, 'message' => 'invalid parameters'));
  exit;
}

function respond($result) {
  unset($result['etag'], $result['at']);
  echo json_encode($result);
  exit;
}

// Most recent finished run; cancelled/skipped runs say nothing about health
function runToResult($runs) {
  foreach ($runs as $run) {
    if (($run['status'] ?? '') !== 'completed') continue;
    $conclusion = $run['conclusion'] ?? '';
    if (in_array($conclusion, array('cancelled', 'skipped'))) continue;
    $date = substr($run['created_at'] ?? '', 0, 10);
    $suffix = " ({$run['event']}, {$date})";
    if ($conclusion === 'success') return array('level' => 'ok', 'message' => 'passing' . $suffix, 'run_url' => $run['html_url']);
    if (in_array($conclusion, array('failure', 'timed_out', 'startup_failure'))) return array('level' => 'fail', 'message' => 'failing' . $suffix, 'run_url' => $run['html_url']);
    return array('level' => 'warn', 'message' => $conclusion . $suffix, 'run_url' => $run['html_url']);
  }
  return array('level' => 'unknown', 'message' => 'no status');
}

$cache_key = 'crowdin_run_' . md5("{$org}/{$repo}/{$workflow}/{$branch}");
$cached = cacheGet($cache_key) ?: null;
if ($cached && time() - $cached['at'] < CACHE_TTL) respond($cached);

$limited_until = (int) cacheGet(LIMITED_KEY);
if ($limited_until > time()) respond($cached ?: array('level' => null, 'message' => 'GitHub API rate limit reached'));

$token = getenv('GITHUB_TOKEN') ?: '';
$header = "User-Agent: ADT-Crowdin-Health\r\nAccept: application/vnd.github+json\r\n"
  . ($token ? "Authorization: token {$token}\r\n" : "")
  . ($cached && !empty($cached['etag']) ? "If-None-Match: {$cached['etag']}\r\n" : "");
$url = "https://api.github.com/repos/{$org}/{$repo}/actions/workflows/" . rawurlencode($workflow)
  . "/runs?per_page=10&exclude_pull_requests=true" . ($branch ? "&branch=" . rawurlencode($branch) : "");
$opts = array('http' => array('method' => 'GET', 'header' => $header, 'timeout' => 5, 'ignore_errors' => true));
$body = @file_get_contents($url, false, stream_context_create($opts));

$code = 0;
$headers = array();
foreach ($http_response_header ?? array() as $line) {
  if (preg_match('#^HTTP/\S+\s+(\d+)#', $line, $m)) $code = (int) $m[1];
  elseif (strpos($line, ':') !== false) {
    list($name, $value) = explode(':', $line, 2);
    $headers[strtolower(trim($name))] = trim($value);
  }
}

// Back off before the quota is used up (or once it is), until it resets
$remaining = isset($headers['x-ratelimit-remaining']) ? (int) $headers['x-ratelimit-remaining'] : null;
$reset = isset($headers['x-ratelimit-reset']) ? (int) $headers['x-ratelimit-reset'] : time() + 3600;
if (($remaining !== null && $remaining <= QUOTA_RESERVE) || $code === 429
    || ($code === 403 && $remaining === 0)) {
  cacheSet(LIMITED_KEY, $reset, max(60, $reset - time()));
}

if ($code === 304 && $cached) {
  $cached['at'] = time();
  cacheSet($cache_key, $cached, STALE_TTL);
  respond($cached);
}
if ($code === 200 && ($data = json_decode($body, true)) && isset($data['workflow_runs'])) {
  $result = runToResult($data['workflow_runs']);
  $result['etag'] = $headers['etag'] ?? '';
  $result['at'] = time();
  cacheSet($cache_key, $result, STALE_TTL);
  respond($result);
}
if ($code === 404) {
  // Private repo without token access, or workflow missing on GitHub
  $result = array('level' => 'unknown', 'message' => 'not found', 'at' => time());
  cacheSet($cache_key, $result, STALE_TTL);
  respond($result);
}
respond($cached ?: array('level' => null, 'message' => 'GitHub API unavailable'));

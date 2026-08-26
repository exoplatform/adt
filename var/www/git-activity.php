<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();

$days_back = isset($_GET['days']) ? max(1, min(365, intval($_GET['days']))) : 30;
$since = date('Y-m-d', strtotime("-{$days_back} days"));
$projects = getRepositories();
$repo_names = array_keys($projects);
$ignored_authors = array('exo-swf', 'Crowdin Bot', 'eXo CI server', 'eXo');
$github_token = getenv('GITHUB_TOKEN') ?: '';
$github_search_limited = false;

function targetBranchArgs($repoObject) {
  try {
    $repoObject->git("rev-parse --verify origin/develop 2>/dev/null");
    return 'origin/develop';
  } catch (Exception $e) {
    return 'HEAD';
  }
}

function getRepoGithubUrl($repoObject) {
  try {
    $url = trim($repoObject->git('config --get remote.origin.url'));
    // Remotes are inconsistently cloned with/without a trailing ".git" (both
    // "git@github.com:org/repo.git" and "git@github.com:org/repo" exist in
    // the wild here), so treat it as optional rather than requiring it.
    if (preg_match('#github\.com[:/]+([^/]+)/([^/]+?)(?:\.git)?/?$#', $url, $m)) {
      return "https://github.com/{$m[1]}/{$m[2]}";
    }
  } catch (Exception $e) {}
  return null;
}

function isIgnored($name) {
  global $ignored_authors;
  return in_array($name, $ignored_authors);
}

/**
 * Maven groupIds tracked for dependency links - only modules published
 * under these groups can be one of our own repos.
 */
$dependency_link_prefixes = array('io.meeds', 'addon.meeds', 'org.exoplatform', 'addon.exo');

function groupIdMatchesDependencyPrefix($groupId) {
  global $dependency_link_prefixes;
  foreach ($dependency_link_prefixes as $prefix) {
    if ($groupId === $prefix || strpos($groupId, $prefix . '.') === 0) return true;
  }
  return false;
}

/** The bare vendor namespaces themselves (e.g. "io.meeds") are shared by too many repos' parent to ever identify one. */
function groupIdIsGenericPrefix($groupId) {
  global $dependency_link_prefixes;
  return in_array($groupId, $dependency_link_prefixes, true);
}

function getPomXmlAt($repoObject, $ref) {
  try {
    $content = $repoObject->git("show {$ref}:pom.xml");
    return $content !== '' ? $content : null;
  } catch (Exception $e) {
    return null;
  }
}

/**
 * Lightweight regex-based pom.xml reader - deliberately avoids ext-simplexml/
 * ext-dom (not otherwise used anywhere in this codebase, so not guaranteed to
 * be installed) in favor of plain string matching over the well-known,
 * predictable shape of a Maven POM.
 */
function pomExtractTag($xml, $tag) {
  if (preg_match('#<' . preg_quote($tag, '#') . '[^>]*>(.*?)</' . preg_quote($tag, '#') . '>#s', $xml, $m)) {
    return trim($m[1]);
  }
  return '';
}

function pomExtractBlock($xml, $tag) {
  if (preg_match('#<' . preg_quote($tag, '#') . '[^>]*>(.*?)</' . preg_quote($tag, '#') . '>#s', $xml, $m)) {
    return $m[1];
  }
  return null;
}

function parsePomXml($xmlContent) {
  if (empty($xmlContent)) return null;
  return preg_replace('/<!--.*?-->/s', '', $xmlContent);
}

/**
 * The pom's own groupId/artifactId/version sit directly under <project>,
 * right after </parent> and before the first nested block (<properties>,
 * <dependencyManagement>, <build>, ...) - so once the parent block is
 * stripped out, cut the string at the first such block before doing a plain
 * "first match" lookup, otherwise an omitted own <groupId> (inherited from
 * the parent, as is common) would wrongly match some dependency's groupId
 * further down the file instead of falling back to the parent's.
 */
function pomOwnHeaderSegment($xml) {
  $parentBlock = pomExtractBlock($xml, 'parent');
  $ownXml = $parentBlock !== null ? str_replace("<parent>{$parentBlock}</parent>", '', $xml) : $xml;
  $boundaryTags = array('properties', 'dependencyManagement', 'dependencies', 'build',
    'modules', 'profiles', 'scm', 'licenses', 'developers', 'distributionManagement');
  $cutAt = strlen($ownXml);
  foreach ($boundaryTags as $tag) {
    $pos = strpos($ownXml, "<{$tag}>");
    if ($pos !== false && $pos < $cutAt) $cutAt = $pos;
  }
  return array(substr($ownXml, 0, $cutAt), $parentBlock);
}

/** The pom's own groupId:artifactId (groupId falls back to the parent's when omitted). */
function pomOwnCoordinates($xml) {
  list($header, $parentBlock) = pomOwnHeaderSegment($xml);
  $artifactId = pomExtractTag($header, 'artifactId');
  $groupId = pomExtractTag($header, 'groupId');
  if ($groupId === '' && $parentBlock !== null) $groupId = pomExtractTag($parentBlock, 'groupId');
  return $groupId !== '' && $artifactId !== '' ? "{$groupId}:{$artifactId}" : null;
}

/**
 * groupId:artifactId of the modules this pom links "upward" to: its parent
 * and every dependencyManagement entry under the groupIds we track. Not
 * restricted to scope=import/type=pom BOM imports - distribution/packaging
 * repos (e.g. platform-private-distributions) bundle addons as plain
 * scope=provided/type=zip entries instead, and that's just as real a link.
 */
function pomUpperLinks($xml) {
  $links = array();

  $parentBlock = pomExtractBlock($xml, 'parent');
  if ($parentBlock !== null) {
    $groupId = pomExtractTag($parentBlock, 'groupId');
    $artifactId = pomExtractTag($parentBlock, 'artifactId');
    if ($groupId !== '' && $artifactId !== '' && groupIdMatchesDependencyPrefix($groupId)) {
      $links["{$groupId}:{$artifactId}"] = true;
    }
  }

  $depMgmtBlock = pomExtractBlock($xml, 'dependencyManagement');
  $depsBlock = $depMgmtBlock !== null ? pomExtractBlock($depMgmtBlock, 'dependencies') : null;
  if ($depsBlock !== null && preg_match_all('#<dependency>(.*?)</dependency>#s', $depsBlock, $matches)) {
    foreach ($matches[1] as $depBlock) {
      $groupId = pomExtractTag($depBlock, 'groupId');
      $artifactId = pomExtractTag($depBlock, 'artifactId');
      if ($groupId !== '' && $artifactId !== '' && groupIdMatchesDependencyPrefix($groupId)) {
        $links["{$groupId}:{$artifactId}"] = true;
      }
    }
  }

  return array_keys($links);
}

/**
 * Builds the dependency-link graph across all tracked repos: for each repo,
 * which other tracked repos it links to via its pom.xml parent/BOM imports
 * (read from the same base branch used for activity - see targetBranchArgs()).
 * Returns array('links' => repo => [repo...], 'github_url' => repo => url|null).
 */
function getRepoDependencyGraph($projects) {
  $cache_key = 'git_activity_dependency_graph_v2';
  $cached = cacheGet($cache_key);
  if ($cached !== false) return $cached;

  $coordinates = array(); // "groupId:artifactId" => repo
  $group_owners = array(); // groupId => repo, or false once claimed by >1 repo (ambiguous)
  $upper_links = array(); // repo => [ "groupId:artifactId", ... ]
  $github_urls = array(); // repo => url|null

  foreach (array_keys($projects) as $repo) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $github_urls[$repo] = getRepoGithubUrl($repoObject);
      $xml = parsePomXml(getPomXmlAt($repoObject, targetBranchArgs($repoObject)));
      if (!$xml) continue;
      $own = pomOwnCoordinates($xml);
      if ($own) {
        $coordinates[$own] = $repo;
        $ownGroupId = strstr($own, ':', true);
        if (!groupIdIsGenericPrefix($ownGroupId)) {
          $group_owners[$ownGroupId] = array_key_exists($ownGroupId, $group_owners) ? false : $repo;
        }
      }
      $upper_links[$repo] = pomUpperLinks($xml);
    } catch (Exception $e) {}
  }
  $group_owners = array_filter($group_owners, function($v) { return $v !== false; });

  $links = array();
  foreach ($upper_links as $repo => $targets) {
    $resolved = array();
    foreach ($targets as $coord) {
      // A submodule (e.g. "social-component-core") is often referenced instead
      // of the tracked repo's own root artifactId (e.g. "social") - fall back
      // to matching on groupId alone, which still identifies the repo.
      if (isset($coordinates[$coord])) {
        $target = $coordinates[$coord];
      } else {
        $groupId = strstr($coord, ':', true);
        $target = isset($group_owners[$groupId]) ? $group_owners[$groupId] : null;
      }
      if ($target !== null && $target !== $repo) $resolved[$target] = true;
    }
    if (!empty($resolved)) $links[$repo] = array_keys($resolved);
  }

  $result = array('links' => $links, 'github_url' => $github_urls);
  cacheSet($cache_key, $result, 3600);
  return $result;
}

function getGithubUsername($email) {
  if (preg_match('/^(?:\d+\+)?([a-z0-9\-]+)@users\.noreply\.github\.com$/i', trim($email), $m)) {
    return $m[1];
  }
  return null;
}

function getGithubAvatarUrl($username) {
  return $username ? "https://avatars.githubusercontent.com/{$username}?size=48" : null;
}

/**
 * Resolve a commit email to a GitHub username: fast path for the
 * noreply-email convention, falling back to GitHub's user search API
 * (only matches if the author made their commit email public). Results
 * (including "not found") are cached for a day since email->username
 * doesn't change often, and lookups back off for the rest of the request
 * once GitHub's search rate limit is hit.
 */
function resolveGithubUser($email) {
  global $github_token, $github_search_limited;
  $email = trim($email);
  if (empty($email)) return null;

  $username = getGithubUsername($email);
  if ($username) return $username;

  $cache_key = 'github_user_email_' . md5(strtolower($email));
  $cached = cacheGet($cache_key);
  if ($cached !== false) return $cached ?: null;

  if ($github_search_limited) return null;

  $header = "User-Agent: ADT-Git-Activity\r\n" . ($github_token ? "Authorization: token {$github_token}\r\n" : "");
  $opts = array('http' => array('method' => 'GET', 'header' => $header, 'timeout' => 4, 'ignore_errors' => true));
  $response = @file_get_contents("https://api.github.com/search/users?q=" . urlencode($email) . "+in:email", false, stream_context_create($opts));

  $username = null;
  $trust_result = false;
  if ($response !== false) {
    $data = json_decode($response, true);
    if (!empty($data['message']) && stripos($data['message'], 'rate limit') !== false) {
      $github_search_limited = true;
    } elseif (isset($data['items']) && is_array($data['items'])) {
      $trust_result = true;
      if (!empty($data['items'][0]['login'])) $username = $data['items'][0]['login'];
    }
  }

  // Only cache an authoritative answer - a rate limit or transient failure
  // should be retried on the next page load, not locked in as "no avatar" for a day.
  if ($trust_result) {
    cacheSet($cache_key, $username ?: '', 86400);
  }
  return $username;
}

function getGitCommitActivityByDay($repos, $days) {
  $activity = array();
  $since = date('Y-m-d', strtotime("-{$days} days"));
  for ($i = $days; $i >= 0; $i--) {
    $date = date('Y-m-d', strtotime("-{$i} days"));
    $activity[$date] = 0;
  }
  foreach ($repos as $repo) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $branches = targetBranchArgs($repoObject);
      $output = $repoObject->git("log --after=\"{$since}\" --date=short --format='format:%ad|%cn' --no-merges {$branches}");
      if (empty($output)) continue;
      foreach (explode("\n", $output) as $line) {
        $parts = explode('|', $line, 2);
        $date = trim($parts[0]);
        $committer = isset($parts[1]) ? trim($parts[1]) : '';
        if (isset($activity[$date]) && !isIgnored($committer)) $activity[$date]++;
      }
    } catch (Exception $e) {}
  }
  return $activity;
}

function getGitCommitActivityByDayAndRepo($projects, $days, $top_n = 5) {
  $dates = array();
  for ($i = $days; $i >= 0; $i--) {
    $dates[] = date('Y-m-d', strtotime("-{$i} days"));
  }
  $since = $dates[0];
  $daily = array();
  foreach ($projects as $repo => $label) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $branches = targetBranchArgs($repoObject);
      $output = $repoObject->git("log --after=\"{$since}\" --date=short --format='format:%ad|%cn' --no-merges {$branches}");
      if (empty($output)) continue;
      foreach (explode("\n", $output) as $line) {
        $parts = explode('|', $line, 2);
        $date = trim($parts[0]);
        $committer = isset($parts[1]) ? trim($parts[1]) : '';
        if (isIgnored($committer)) continue;
        $daily[$label][$date] = ($daily[$label][$date] ?? 0) + 1;
      }
    } catch (Exception $e) {}
  }
  $totals = array();
  foreach ($daily as $label => $by_date) $totals[$label] = array_sum($by_date);
  arsort($totals);
  $top_labels = array_slice(array_keys($totals), 0, $top_n);
  $series = array();
  foreach ($top_labels as $label) {
    $series[$label] = array_map(function($d) use ($daily, $label) { return $daily[$label][$d] ?? 0; }, $dates);
  }
  return array('dates' => $dates, 'series' => $series);
}

function getGitCommitsByDayOfWeek($activity) {
  $day_names = array('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');
  $totals = array_fill(0, 7, 0);
  foreach ($activity as $date => $count) {
    $totals[date('N', strtotime($date)) - 1] += $count;
  }
  return array_combine($day_names, $totals);
}

function getGitCommitsByRepo($projects, $days) {
  $result = array();
  $since = date('Y-m-d', strtotime("-{$days} days"));
  foreach ($projects as $repo => $label) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $gh_base = getRepoGithubUrl($repoObject);
      $branches = targetBranchArgs($repoObject);
      $output = $repoObject->git("log --after=\"{$since}\" --format=format:%cn --no-merges {$branches}");
      $count = 0;
      if (!empty($output)) {
        foreach (explode("\n", $output) as $c) {
          $c = trim($c);
          if (!empty($c) && !isIgnored($c)) $count++;
        }
      }
      $result[] = array('repo' => $repo, 'label' => $label, 'commits' => $count, 'github_url' => $gh_base);
    } catch (Exception $e) {}
  }
  usort($result, function($a, $b) { return $b['commits'] - $a['commits']; });
  return $result;
}

function getGitCommitsByAuthor($repos, $days) {
  $result = array();
  $since = date('Y-m-d', strtotime("-{$days} days"));
  $author_counts = array();
  $author_emails = array();
  foreach ($repos as $repo) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $branches = targetBranchArgs($repoObject);
      $output = $repoObject->git("log --after=\"{$since}\" --format='format:%an|%ae|%cn' --no-merges {$branches}");
      if (empty($output)) continue;
      foreach (explode("\n", $output) as $line) {
        $parts = explode('|', $line, 3);
        $author = trim($parts[0]);
        $email = isset($parts[1]) ? trim($parts[1]) : '';
        $committer = isset($parts[2]) ? trim($parts[2]) : '';
        if (empty($author) || isIgnored($author) || isIgnored($committer)) continue;
        $author_counts[$author] = ($author_counts[$author] ?? 0) + 1;
        if (empty($author_emails[$author]) && !empty($email)) $author_emails[$author] = $email;
      }
    } catch (Exception $e) {}
  }
  arsort($author_counts);
  foreach (array_slice($author_counts, 0, 30) as $author => $count) {
    $github_user = isset($author_emails[$author]) ? resolveGithubUser($author_emails[$author]) : null;
    $result[] = array(
      'author' => $author,
      'commits' => $count,
      'github_url' => $github_user ? "https://github.com/{$github_user}" : null,
      'avatar_url' => getGithubAvatarUrl($github_user)
    );
  }
  return $result;
}

function getGitRecentCommits($projects, $limit = 50) {
  $all_commits = array();
  $since = date('Y-m-d', strtotime("-90 days"));
  foreach ($projects as $repo => $label) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $gh_base = getRepoGithubUrl($repoObject);
      $branches = targetBranchArgs($repoObject);
      $output = $repoObject->git("log --after=\"{$since}\" --format='format:%H|%an|%ae|%ai|%cn|%s' --no-merges {$branches} -100");
      if (empty($output)) continue;
      foreach (explode("\n", $output) as $line) {
        $parts = explode('|', $line, 6);
        if (count($parts) >= 6) {
          if (isIgnored($parts[1]) || isIgnored($parts[4])) continue;
          $github_user = resolveGithubUser($parts[2]);
          $all_commits[] = array(
            'repo' => $repo,
            'label' => $label,
            'hash' => substr($parts[0], 0, 8),
            'full_hash' => $parts[0],
            'author' => $parts[1],
            'email' => $parts[2],
            'date' => substr($parts[3], 0, 10),
            'message' => $parts[5],
            'github_url' => $gh_base ? "{$gh_base}/commit/{$parts[0]}" : null,
            'repo_url' => $gh_base,
            'author_url' => $github_user ? "https://github.com/{$github_user}" : ($gh_base ? "{$gh_base}/commits?author=" . rawurlencode($parts[2]) : null),
            'avatar_url' => getGithubAvatarUrl($github_user)
          );
        }
      }
    } catch (Exception $e) {}
  }
  usort($all_commits, function($a, $b) { return strcmp($b['date'], $a['date']); });
  return array_slice($all_commits, 0, $limit);
}

function getGitHubPRData($org, $token = '', $days = 30) {
  $cache_key = 'github_pr_' . $org . '_' . $days;
  $cached = null;
  if (extension_loaded('apc') && function_exists('apc_fetch')) {
    $cached = apc_fetch($cache_key);
  } elseif (extension_loaded('apcu') && function_exists('apcu_fetch')) {
    $cached = apcu_fetch($cache_key);
  } elseif (extension_loaded('memcache')) {
    $cached = $GLOBALS['memcache']->get($cache_key);
  }
  if (!empty($cached)) return $cached;

  $since = date('Y-m-d', strtotime("-{$days} days"));
  $result = array('created' => 0, 'merged' => 0);
  $header = "User-Agent: ADT-Git-Activity\r\n" . ($token ? "Authorization: token {$token}\r\n" : "");

  foreach (array('created' => "created:>={$since}", 'merged' => "merged:>={$since}") as $key => $qualifier) {
    $url = "https://api.github.com/search/issues?q=is:pr+org:{$org}+{$qualifier}&per_page=1";
    $opts = array('http' => array('method' => 'GET', 'header' => $header, 'timeout' => 10));
    $response = @file_get_contents($url, false, stream_context_create($opts));
    if ($response === false) continue;
    $data = json_decode($response, true);
    if (isset($data['total_count'])) $result[$key] = (int)$data['total_count'];
  }

  if (extension_loaded('apc') && function_exists('apc_store')) {
    apc_store($cache_key, $result, 300);
  } elseif (extension_loaded('apcu') && function_exists('apcu_store')) {
    apcu_store($cache_key, $result, 300);
  } elseif (extension_loaded('memcache')) {
    $GLOBALS['memcache']->set($cache_key, $result, 0, 300);
  }
  return $result;
}

$bundle = cacheGet("git_activity_bundle_{$days_back}");
if (empty($bundle)) {
  $bundle = array(
    'activity' => getGitCommitActivityByDay($repo_names, $days_back),
    'repo_trend' => getGitCommitActivityByDayAndRepo($projects, $days_back),
    'repo_stats' => getGitCommitsByRepo($projects, $days_back),
    'author_stats' => getGitCommitsByAuthor($repo_names, $days_back),
  );
  cacheSet("git_activity_bundle_{$days_back}", $bundle, 300);
}
$activity = $bundle['activity'];
$repo_trend = $bundle['repo_trend'];
$repo_stats = $bundle['repo_stats'];
$author_stats = $bundle['author_stats'];
$day_of_week = getGitCommitsByDayOfWeek($activity);

$recent_commits = cacheGet('git_activity_recent_commits');
if (empty($recent_commits)) {
  $recent_commits = getGitRecentCommits($projects);
  cacheSet('git_activity_recent_commits', $recent_commits, 300);
}

$total_commits = array_sum($activity);
$active_repos = count(array_filter($repo_stats, function($r) { return $r['commits'] > 0; }));
$total_authors = count($author_stats);

$busiest_day = null;
foreach ($activity as $date => $count) {
  if ($busiest_day === null || $count > $activity[$busiest_day]) $busiest_day = $date;
}
$top_repo = !empty($repo_stats) && $repo_stats[0]['commits'] > 0 ? $repo_stats[0] : null;
$top_author = !empty($author_stats) ? $author_stats[0] : null;

$github_pr_data = array();
$github_orgs = array('meeds-io', 'exoplatform');
foreach ($github_orgs as $org) {
  $github_pr_data[$org] = getGitHubPRData($org, $github_token, $days_back);
}

$dependency_graph = getRepoDependencyGraph($projects);
$dependency_links = $dependency_graph['links'];
$dependency_repo_github_urls = $dependency_graph['github_url'];
// Every tracked repo gets a row (even leaves with no outgoing links) so that
// "Depends on" badges always have a same-page anchor to jump to.
$dependency_table_repos = $projects;
ksort($dependency_table_repos);
?>
<html lang="en">
<head>
  <?= pageHeader("Git Activity"); ?>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
  <style>
    .chart-container { position: relative; height: 250px; width: 100%; }
    .activity-list { font-size: 0.875rem; }
    .commit-msg { max-width: 400px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .metric__value--label { font-size: 1.5rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .link-reset { color: inherit; text-decoration: none; }
    .link-reset:hover { text-decoration: underline; }
    [id^="repo-"] { scroll-margin-top: 1rem; }
    .dependency-badges { display: flex; flex-wrap: wrap; gap: 0.4rem; }
    .dependency-link:hover .badge { background-color: var(--accent) !important; }
    /* Override the generic (static amber) tr.highlight so the jumped-to row follows the active accent theme */
    tr.dependency-row.highlight td { background: var(--accent-soft) !important; border-bottom: 1px solid var(--accent); }
    .avatar-sm { width: 20px; height: 20px; border-radius: 50%; vertical-align: middle; margin-right: 0.4rem; }
    .days-filter { flex-shrink: 0; }
    @media (max-width: 576px) {
      .days-filter { width: 100%; }
      .days-filter .btn { flex: 1 1 0; }
    }
    /* Below 768px the sticky .mobile-bar covers the top of the viewport - give
       jumped-to rows enough clearance to land below it instead of under it. */
    @media (max-width: 768px) {
      [id^="repo-"] { scroll-margin-top: 4rem; }
    }
  </style>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<div id="wrap">
  <div id="main" role="main">
    <div class="container-fluid">

      <div class="d-flex flex-wrap align-items-start justify-content-between gap-2 mb-4">
        <div class="page-header mb-0">
          <h1 class="page-header__title">Git Activity</h1>
          <p class="page-header__subtitle">Commit activity across <?= count($repo_names) ?> repositories over the last <?= $days_back ?> days (base branch <code>develop</code>, excluding merge commits and bot accounts)</p>
        </div>
        <div class="btn-group btn-group-sm days-filter">
          <a href="?days=7" class="btn btn-outline-secondary <?= $days_back == 7 ? 'active' : '' ?>">7d</a>
          <a href="?days=14" class="btn btn-outline-secondary <?= $days_back == 14 ? 'active' : '' ?>">14d</a>
          <a href="?days=30" class="btn btn-outline-secondary <?= $days_back == 30 ? 'active' : '' ?>">30d</a>
          <a href="?days=90" class="btn btn-outline-secondary <?= $days_back == 90 ? 'active' : '' ?>">90d</a>
        </div>
      </div>

      <div class="section-title">
        <i class="fas fa-chart-simple" aria-hidden="true"></i> Overview
      </div>
      <div class="bento mb-2">
        <div class="bento__item bento__item--3" style="--card-accent: var(--accent)">
          <div class="metric">
            <span class="metric__label"><i class="fas fa-code-commit"></i> Commits</span>
            <span class="metric__value"><?= number_format($total_commits) ?></span>
            <span class="metric__change">last <?= $days_back ?> days</span>
          </div>
        </div>
        <div class="bento__item bento__item--3" style="--card-accent: var(--success)">
          <div class="metric">
            <span class="metric__label"><span class="pulse-dot on"></span> Active Repositories</span>
            <span class="metric__value"><?= $active_repos ?> / <?= count($repo_names) ?></span>
            <span class="metric__change">with commits</span>
          </div>
        </div>
        <div class="bento__item bento__item--3" style="--card-accent: var(--info)">
          <div class="metric">
            <span class="metric__label"><i class="fas fa-users"></i> Contributors</span>
            <span class="metric__value"><?= $total_authors ?></span>
            <span class="metric__change">unique authors</span>
          </div>
        </div>
        <div class="bento__item bento__item--3" style="--card-accent: var(--warning)">
          <div class="metric">
            <span class="metric__label"><i class="fas fa-chart-line"></i> Avg Commits / Day</span>
            <span class="metric__value"><?= number_format($days_back > 0 ? round($total_commits / $days_back, 1) : 0) ?></span>
            <span class="metric__change">over <?= $days_back ?> days</span>
          </div>
        </div>
      </div>
      <div class="bento mb-4">
        <div class="bento__item bento__item--4" style="--card-accent: var(--accent2)">
          <div class="metric">
            <span class="metric__label"><i class="fas fa-fire"></i> Busiest Day</span>
            <span class="metric__value metric__value--label"><?= $busiest_day ? htmlspecialchars($busiest_day) : '—' ?></span>
            <span class="metric__change"><?= $busiest_day ? number_format($activity[$busiest_day]) . ' commits' : 'no data' ?></span>
          </div>
        </div>
        <div class="bento__item bento__item--4" style="--card-accent: var(--accent)">
          <div class="metric">
            <span class="metric__label"><i class="fas fa-cube"></i> Most Active Repository</span>
            <span class="metric__value metric__value--label">
              <?php if ($top_repo && $top_repo['github_url']): ?>
              <a href="<?= htmlspecialchars($top_repo['github_url']) ?>" target="_blank" class="link-reset"><?= htmlspecialchars($top_repo['label']) ?></a>
              <?php else: ?>
              <?= $top_repo ? htmlspecialchars($top_repo['label']) : '—' ?>
              <?php endif; ?>
            </span>
            <span class="metric__change"><?= $top_repo ? number_format($top_repo['commits']) . ' commits' : 'no data' ?></span>
          </div>
        </div>
        <div class="bento__item bento__item--4" style="--card-accent: var(--info)">
          <div class="metric">
            <span class="metric__label"><i class="fas fa-trophy"></i> Top Contributor</span>
            <span class="metric__value metric__value--label">
              <?php if ($top_author && $top_author['avatar_url']): ?>
              <img src="<?= htmlspecialchars($top_author['avatar_url']) ?>" class="avatar-sm" alt="">
              <?php endif; ?>
              <?php if ($top_author && $top_author['github_url']): ?>
              <a href="<?= htmlspecialchars($top_author['github_url']) ?>" target="_blank" class="link-reset"><?= htmlspecialchars($top_author['author']) ?></a>
              <?php else: ?>
              <?= $top_author ? htmlspecialchars($top_author['author']) : '—' ?>
              <?php endif; ?>
            </span>
            <span class="metric__change"><?= $top_author ? number_format($top_author['commits']) . ' commits' : 'no data' ?></span>
          </div>
        </div>
      </div>

      <?php if (!empty($github_pr_data)): ?>
      <div class="section-title">
        <i class="fab fa-github" aria-hidden="true"></i> Pull Requests
      </div>
      <div class="bento mb-4">
        <?php foreach ($github_pr_data as $org => $data): ?>
        <div class="bento__item bento__item--6" style="--card-accent: var(--accent2)">
          <div class="d-flex justify-content-between align-items-center mb-2">
            <span class="metric__label"><i class="fab fa-github"></i> <?= htmlspecialchars($org) ?></span>
          </div>
          <div class="row text-center">
            <div class="col-6">
              <span class="metric__value" style="color: var(--success)"><?= number_format($data['created']) ?></span>
              <div class="metric__label mt-1">PRs Created</div>
            </div>
            <div class="col-6">
              <span class="metric__value" style="color: var(--accent)"><?= number_format($data['merged']) ?></span>
              <div class="metric__label mt-1">PRs Merged</div>
            </div>
          </div>
        </div>
        <?php endforeach; ?>
      </div>
      <?php endif; ?>

      <div class="section-title">
        <i class="fas fa-chart-line" aria-hidden="true"></i> Activity Trends
      </div>
      <div class="row g-3 mb-4">
        <div class="col-12">
          <div class="card">
            <div class="card-header">
              <i class="fas fa-chart-bar me-1"></i> Commits per Day
            </div>
            <div class="card-body">
              <div class="chart-container">
                <canvas id="commitsChart"></canvas>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="row g-3 mb-4">
        <div class="col-12">
          <div class="card">
            <div class="card-header">
              <i class="fas fa-code-branch me-1"></i> Repository Activity Trend
              <small class="text-muted ms-2">(top <?= count($repo_trend['series']) ?> repositories)</small>
            </div>
            <div class="card-body">
              <div class="chart-container">
                <canvas id="repoTrendChart"></canvas>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="row g-3 mb-4">
        <div class="col-md-4">
          <div class="card h-100">
            <div class="card-header">
              <i class="fas fa-cube me-1"></i> Commits by Repository
            </div>
            <div class="card-body">
              <div class="chart-container">
                <canvas id="repoChart"></canvas>
              </div>
            </div>
          </div>
        </div>
        <div class="col-md-4">
          <div class="card h-100">
            <div class="card-header">
              <i class="fas fa-users me-1"></i> Top Contributors
            </div>
            <div class="card-body">
              <div class="chart-container">
                <canvas id="authorChart"></canvas>
              </div>
            </div>
          </div>
        </div>
        <div class="col-md-4">
          <div class="card h-100">
            <div class="card-header">
              <i class="fas fa-calendar-week me-1"></i> Commits by Day of Week
            </div>
            <div class="card-body">
              <div class="chart-container">
                <canvas id="dowChart"></canvas>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="section-title">
        <i class="fas fa-diagram-project" aria-hidden="true"></i> Dependency Links
      </div>
      <div class="card mb-4">
        <div class="card-header">
          <i class="fas fa-diagram-project me-1"></i> Repository dependency links
          <small class="text-muted ms-2">(pom.xml parent &amp; imported BOMs on <code>develop</code>)</small>
        </div>
        <div class="card-body p-0">
          <div class="table-responsive">
            <table class="table table-hover table-striped mb-0 activity-list">
              <thead class="table-dark">
                <tr>
                  <th>Repository</th>
                  <th>Depends on</th>
                </tr>
              </thead>
              <tbody>
                <?php if (empty($dependency_table_repos)): ?>
                <tr><td colspan="2" class="text-center text-muted py-3">No dependency links found</td></tr>
                <?php else: ?>
                <?php foreach ($dependency_table_repos as $repo => $label): ?>
                <tr id="repo-<?= htmlspecialchars($repo) ?>">
                  <td>
                    <?php $repo_url = isset($dependency_repo_github_urls[$repo]) ? $dependency_repo_github_urls[$repo] : null; ?>
                    <?php if ($repo_url): ?><a href="<?= htmlspecialchars($repo_url) ?>" target="_blank" class="link-reset" title="Open <?= htmlspecialchars($label) ?> on GitHub"><span class="badge bg-secondary"><?= htmlspecialchars($label) ?></span></a><?php else: ?><span class="badge bg-secondary"><?= htmlspecialchars($label) ?></span><?php endif; ?>
                  </td>
                  <td>
                    <?php
                    $targets = isset($dependency_links[$repo]) ? $dependency_links[$repo] : array();
                    usort($targets, function($a, $b) use ($projects) {
                      return strcasecmp(isset($projects[$a]) ? $projects[$a] : $a, isset($projects[$b]) ? $projects[$b] : $b);
                    });
                    ?>
                    <?php if (empty($targets)): ?>
                    <span class="text-muted">&mdash;</span>
                    <?php else: ?>
                    <div class="dependency-badges">
                    <?php foreach ($targets as $target): ?>
                      <?php $target_label = isset($projects[$target]) ? $projects[$target] : $target; ?>
                      <a href="#repo-<?= htmlspecialchars($target) ?>" class="link-reset dependency-link" title="Jump to <?= htmlspecialchars($target_label) ?>"><span class="badge bg-secondary"><?= htmlspecialchars($target_label) ?></span></a>
                    <?php endforeach; ?>
                    </div>
                    <?php endif; ?>
                  </td>
                </tr>
                <?php endforeach; ?>
                <?php endif; ?>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div class="section-title">
        <i class="fas fa-history" aria-hidden="true"></i> Recent Commits
      </div>
      <div class="card mb-4">
        <div class="card-header">
          <i class="fas fa-history me-1"></i> Last 50 commits
          <small class="text-muted ms-2">(last 90 days — main branches only, no merges)</small>
        </div>
        <div class="card-body p-0">
          <div class="table-responsive">
            <table class="table table-hover table-striped mb-0 activity-list">
              <thead class="table-dark">
                <tr>
                  <th>Date</th>
                  <th>Repository</th>
                  <th>Author</th>
                  <th>Commit</th>
                  <th>Message</th>
                </tr>
              </thead>
              <tbody>
                <?php if (empty($recent_commits)): ?>
                <tr><td colspan="5" class="text-center text-muted py-3">No commits found</td></tr>
                <?php else: ?>
                <?php foreach ($recent_commits as $c): ?>
                <tr>
                  <td class="text-nowrap"><small><?= $c['date'] ?></small></td>
                  <td><?php if ($c['repo_url']): ?><a href="<?= htmlspecialchars($c['repo_url']) ?>" target="_blank" class="link-reset"><span class="badge bg-secondary"><?= $c['label'] ?></span></a><?php else: ?><span class="badge bg-secondary"><?= $c['label'] ?></span><?php endif; ?></td>
                  <td>
                    <?php if ($c['avatar_url']): ?><img src="<?= htmlspecialchars($c['avatar_url']) ?>" class="avatar-sm" alt=""><?php endif; ?>
                    <?php if ($c['author_url']): ?><a href="<?= htmlspecialchars($c['author_url']) ?>" target="_blank" class="link-reset"><?= htmlspecialchars($c['author']) ?></a><?php else: ?><?= htmlspecialchars($c['author']) ?><?php endif; ?>
                  </td>
                  <td><?php if ($c['github_url']): ?><a href="<?= $c['github_url'] ?>" target="_blank"><code><?= $c['hash'] ?></code></a><?php else: ?><code><?= $c['hash'] ?></code><?php endif; ?></td>
                  <td class="commit-msg" rel="tooltip" title="<?= htmlspecialchars($c['message']) ?>"><?= htmlspecialchars(function_exists('mb_strimwidth') ? mb_strimwidth($c['message'], 0, 80, '...') : (strlen($c['message']) > 80 ? substr($c['message'], 0, 77) . '...' : $c['message'])) ?></td>
                </tr>
                <?php endforeach; ?>
                <?php endif; ?>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
<?php pageFooter(); ?>
<script>
$(document).ready(function() {
  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[rel=tooltip]'));
  tooltipTriggerList.map(function(tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl);
  });

  // Highlight the dependency-links row jumped to via a "Depends on" badge
  // or a direct #repo-xxx link, so the target is easy to spot after the scroll.
  function highlightDependencyRow() {
    var current = document.querySelector('.dependency-row.highlight');
    if (current) current.classList.remove('highlight');
    if (location.hash.indexOf('#repo-') !== 0) return;
    var row = document.querySelector(location.hash);
    if (row) row.classList.add('highlight', 'dependency-row');
  }
  highlightDependencyRow();
  window.addEventListener('hashchange', highlightDependencyRow);

  var chartColors = {
    primary: getComputedStyle(document.documentElement).getPropertyValue('--secondary-color').trim() || '#3498db',
    success: getComputedStyle(document.documentElement).getPropertyValue('--success-color').trim() || '#27ae60',
    warning: getComputedStyle(document.documentElement).getPropertyValue('--warning-color').trim() || '#f39c12',
    danger: getComputedStyle(document.documentElement).getPropertyValue('--danger-color').trim() || '#e74c3c',
    info: getComputedStyle(document.documentElement).getPropertyValue('--info').trim() || '#54a0ff',
    accent2: getComputedStyle(document.documentElement).getPropertyValue('--accent2').trim() || '#00d2d3',
    text: getComputedStyle(document.documentElement).getPropertyValue('--text-muted').trim() || '#6c757d',
    cardBg: getComputedStyle(document.documentElement).getPropertyValue('--card-bg').trim() || '#ffffff',
    gridColor: getComputedStyle(document.documentElement).getPropertyValue('--border-color').trim() || '#dee2e6'
  };
  var trendPalette = [chartColors.primary, chartColors.accent2, chartColors.success, chartColors.warning, chartColors.danger];

  function hexToRgb(hex) {
    var r = parseInt(hex.slice(1,3), 16), g = parseInt(hex.slice(3,5), 16), b = parseInt(hex.slice(5,7), 16);
    return r+','+g+','+b;
  }

  new Chart(document.getElementById('commitsChart'), {
    type: 'bar',
    data: {
      labels: <?= json_encode(array_keys($activity)) ?>,
      datasets: [{
        label: 'Commits',
        data: <?= json_encode(array_values($activity)) ?>,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.primary) + ', 0.6)',
        borderColor: chartColors.primary,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { maxTicksLimit: 15, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });

  var repoTrendDates = <?= json_encode($repo_trend['dates']) ?>;
  var repoTrendSeries = <?= json_encode($repo_trend['series']) ?>;
  new Chart(document.getElementById('repoTrendChart'), {
    type: 'line',
    data: {
      labels: repoTrendDates,
      datasets: Object.keys(repoTrendSeries).map(function(label, i) {
        var color = trendPalette[i % trendPalette.length];
        return {
          label: label,
          data: repoTrendSeries[label],
          borderColor: color,
          backgroundColor: 'rgba(' + hexToRgb(color) + ', 0.15)',
          borderWidth: 2,
          pointRadius: 0,
          tension: 0,
          fill: false
        };
      })
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: true, position: 'bottom', labels: { color: chartColors.text, boxWidth: 12 } } },
      scales: {
        x: { ticks: { maxTicksLimit: 15, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });

  new Chart(document.getElementById('repoChart'), {
    type: 'bar',
    data: {
      labels: <?= json_encode(array_map(function($r) { return $r['label']; }, $repo_stats)) ?>,
      datasets: [{
        label: 'Commits',
        data: <?= json_encode(array_map(function($r) { return $r['commits']; }, $repo_stats)) ?>,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.success) + ', 0.6)',
        borderColor: chartColors.success,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { ticks: { font: { size: 10 }, color: chartColors.text }, grid: { display: false } }
      }
    }
  });

  new Chart(document.getElementById('authorChart'), {
    type: 'bar',
    data: {
      labels: <?= json_encode(array_map(function($a) { return $a['author']; }, $author_stats)) ?>,
      datasets: [{
        label: 'Commits',
        data: <?= json_encode(array_map(function($a) { return $a['commits']; }, $author_stats)) ?>,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.warning) + ', 0.6)',
        borderColor: chartColors.warning,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { ticks: { font: { size: 10 }, color: chartColors.text }, grid: { display: false } }
      }
    }
  });

  new Chart(document.getElementById('dowChart'), {
    type: 'bar',
    data: {
      labels: <?= json_encode(array_keys($day_of_week)) ?>,
      datasets: [{
        label: 'Commits',
        data: <?= json_encode(array_values($day_of_week)) ?>,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.info) + ', 0.6)',
        borderColor: chartColors.info,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });
});
</script>
</body>
</html>

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
      $output = $repoObject->git("log --after=\"{$since}\" --date=short --format=format:%ad --all");
      if (empty($output)) continue;
      foreach (explode("\n", $output) as $date) {
        $date = trim($date);
        if (isset($activity[$date])) $activity[$date]++;
      }
    } catch (Exception $e) {}
  }
  return $activity;
}

function getGitCommitsByRepo($projects, $days) {
  $result = array();
  $since = date('Y-m-d', strtotime("-{$days} days"));
  foreach ($projects as $repo => $label) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $output = $repoObject->git("log --after=\"{$since}\" --oneline --all");
      $count = empty($output) ? 0 : count(explode("\n", $output));
      $result[] = array('repo' => $repo, 'label' => $label, 'commits' => $count);
    } catch (Exception $e) {}
  }
  usort($result, function($a, $b) { return $b['commits'] - $a['commits']; });
  return $result;
}

function getGitCommitsByAuthor($repos, $days, $ignored = array()) {
  global $ignored_authors;
  $ignored = array_merge($ignored, $ignored_authors);
  $result = array();
  $since = date('Y-m-d', strtotime("-{$days} days"));
  $author_counts = array();
  foreach ($repos as $repo) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $output = $repoObject->git("log --after=\"{$since}\" --format=format:%an --all");
      if (empty($output)) continue;
      foreach (explode("\n", $output) as $author) {
        $author = trim($author);
        if (empty($author) || in_array($author, $ignored)) continue;
        $author_counts[$author] = ($author_counts[$author] ?? 0) + 1;
      }
    } catch (Exception $e) {}
  }
  arsort($author_counts);
  foreach (array_slice($author_counts, 0, 30) as $author => $count) {
    $result[] = array('author' => $author, 'commits' => $count);
  }
  return $result;
}

function getGitRecentCommits($projects, $ignored = array(), $limit = 50) {
  global $ignored_authors;
  $ignored = array_merge($ignored, $ignored_authors);
  $all_commits = array();
  $since = date('Y-m-d', strtotime("-90 days"));
  foreach ($projects as $repo => $label) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $output = $repoObject->git("log --after=\"{$since}\" --format='format:%H|%an|%ae|%ai|%s' --all -100");
      if (empty($output)) continue;
      foreach (explode("\n", $output) as $line) {
        $parts = explode('|', $line, 5);
        if (count($parts) >= 5) {
          if (in_array($parts[1], $ignored)) continue;
          if (in_array($parts[2], $ignored)) continue;
          $all_commits[] = array(
            'repo' => $repo,
            'label' => $label,
            'hash' => substr($parts[0], 0, 8),
            'author' => $parts[1],
            'email' => $parts[2],
            'date' => substr($parts[3], 0, 10),
            'message' => $parts[4]
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

$activity = getGitCommitActivityByDay($repo_names, $days_back);
$repo_stats = getGitCommitsByRepo($projects, $days_back);
$author_stats = getGitCommitsByAuthor($repo_names, $days_back);
$recent_commits = getGitRecentCommits($projects);

$total_commits = array_sum($activity);
$active_repos = count(array_filter($repo_stats, function($r) { return $r['commits'] > 0; }));
$total_authors = count($author_stats);

$github_token = getenv('GITHUB_TOKEN') ?: '';
$github_pr_data = array();
$github_orgs = array('meeds-io', 'exoplatform');
foreach ($github_orgs as $org) {
  $github_pr_data[$org] = getGitHubPRData($org, $github_token, $days_back);
}
?>
<html lang="en">
<head>
  <?= pageHeader("Git Activity"); ?>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
  <style>
    .stat-card { text-align: center; padding: 1.5rem; border-radius: 0.5rem; }
    .stat-card .stat-value { font-size: 2.5rem; font-weight: 700; }
    .stat-card .stat-label { font-size: 0.9rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); }
    .chart-container { position: relative; height: 250px; width: 100%; }
    .activity-list { font-size: 0.875rem; }
    .commit-msg { max-width: 400px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  </style>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<div id="wrap">
  <div id="main" role="main">
    <div class="container-fluid">
      <div class="alert alert-info d-flex align-items-center">
        <i class="fab fa-github fa-2x me-3" aria-hidden="true"></i>
        <div class="flex-grow-1">
          <h5 class="alert-heading mb-1">Git Activity & Analytics</h5>
          <p class="mb-0">Commit activity across <?= count($repo_names) ?> repositories over the last <?= $days_back ?> days</p>
        </div>
        <div class="ms-3">
          <div class="btn-group btn-group-sm">
            <a href="?days=7" class="btn btn-outline-secondary <?= $days_back == 7 ? 'active' : '' ?>">7d</a>
            <a href="?days=14" class="btn btn-outline-secondary <?= $days_back == 14 ? 'active' : '' ?>">14d</a>
            <a href="?days=30" class="btn btn-outline-secondary <?= $days_back == 30 ? 'active' : '' ?>">30d</a>
            <a href="?days=90" class="btn btn-outline-secondary <?= $days_back == 90 ? 'active' : '' ?>">90d</a>
          </div>
        </div>
      </div>

      <div class="row g-3 mb-4">
        <div class="col-md-3">
          <div class="stat-card card">
            <div class="stat-value text-primary"><?= number_format($total_commits) ?></div>
            <div class="stat-label">Commits</div>
            <small class="text-muted">last <?= $days_back ?> days</small>
          </div>
        </div>
        <div class="col-md-3">
          <div class="stat-card card">
            <div class="stat-value text-success"><?= $active_repos ?> / <?= count($repo_names) ?></div>
            <div class="stat-label">Active Repositories</div>
            <small class="text-muted">with commits</small>
          </div>
        </div>
        <div class="col-md-3">
          <div class="stat-card card">
            <div class="stat-value text-info"><?= $total_authors ?></div>
            <div class="stat-label">Contributors</div>
            <small class="text-muted">unique authors</small>
          </div>
        </div>
        <div class="col-md-3">
          <div class="stat-card card">
            <div class="stat-value text-warning"><?= number_format($days_back > 0 ? round($total_commits / $days_back, 1) : 0) ?></div>
            <div class="stat-label">Avg Commits / Day</div>
            <small class="text-muted">over <?= $days_back ?> days</small>
          </div>
        </div>
      </div>

      <?php if (!empty($github_pr_data)): ?>
      <div class="row g-3 mb-4">
        <?php foreach ($github_pr_data as $org => $data): ?>
        <div class="col-md-6">
          <div class="card">
            <div class="card-header">
              <i class="fab fa-github me-1"></i> Pull Requests — <strong><?= $org ?></strong>
            </div>
            <div class="card-body">
              <div class="row text-center">
                <div class="col-6">
                  <div class="stat-value text-success"><?= number_format($data['created']) ?></div>
                  <div class="stat-label">PRs Created</div>
                </div>
                <div class="col-6">
                  <div class="stat-value text-primary"><?= number_format($data['merged']) ?></div>
                  <div class="stat-label">PRs Merged</div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <?php endforeach; ?>
      </div>
      <?php endif; ?>

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
        <div class="col-md-6">
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
        <div class="col-md-6">
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
      </div>

      <div class="card mb-4">
        <div class="card-header">
          <i class="fas fa-history me-1"></i> Recent Commits
          <small class="text-muted ms-2">(last 90 days, max 50)</small>
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
                  <td><span class="badge bg-secondary"><?= $c['label'] ?></span></td>
                  <td><?= htmlspecialchars($c['author']) ?></td>
                  <td><code><?= $c['hash'] ?></code></td>
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

  var chartColors = {
    primary: getComputedStyle(document.documentElement).getPropertyValue('--secondary-color').trim() || '#3498db',
    success: getComputedStyle(document.documentElement).getPropertyValue('--success-color').trim() || '#27ae60',
    warning: getComputedStyle(document.documentElement).getPropertyValue('--warning-color').trim() || '#f39c12',
    danger: getComputedStyle(document.documentElement).getPropertyValue('--danger-color').trim() || '#e74c3c',
    text: getComputedStyle(document.documentElement).getPropertyValue('--text-muted').trim() || '#6c757d',
    cardBg: getComputedStyle(document.documentElement).getPropertyValue('--card-bg').trim() || '#ffffff',
    gridColor: getComputedStyle(document.documentElement).getPropertyValue('--border-color').trim() || '#dee2e6'
  };

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
});
</script>
</body>
</html>

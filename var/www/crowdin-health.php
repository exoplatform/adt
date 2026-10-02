<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();

$stable_version = '7.2.x';

// Repos known to be private on GitHub. A live API check turned out to be
// unreliable in production (rate limits/token issues made it fail for
// most repos, which - depending on which way the check fails safe - either
// wrongly shows every public repo as "private" or lets a private repo's
// badge attempt render GitHub's "not found" error). A short static list
// is simpler and doesn't depend on network conditions at page-render time.
$private_repos = array('ai', 'platform-private-distributions');

function getRepoGithubOrgAndUrl($repoObject) {
  try {
    $url = $repoObject->git('config --get remote.origin.url');
    if (preg_match("#git@github\.com:(.+)/(.+)\.git#", $url, $m) ||
        preg_match("#https://github\.com/(.+)/(.+)\.git#", $url, $m)) {
      return array('org' => $m[1], 'repo' => $m[2], 'url' => "https://github.com/{$m[1]}/{$m[2]}");
    }
  } catch (Exception $e) {}
  return null;
}

function isPrivateRepo($repo) {
  global $private_repos;
  return in_array($repo, $private_repos);
}

/**
 * shields.io JSON endpoint for the GitHub Actions status of a public repo
 * workflow (CORS enabled), so the page can draw its own status dot instead
 * of embedding a full badge image. Private repos can't be looked up without
 * authentication and get no URL.
 */
function crowdinStatusUrl($org, $repo, $workflow, $branch) {
  $url = "https://img.shields.io/github/actions/workflow/status/{$org}/{$repo}/{$workflow}.json";
  if ($branch) $url .= "?branch=" . rawurlencode($branch);
  return $url;
}

/**
 * Render one status pill (dot + label) linking to the workflow run history.
 * The dot color is filled in by the page script from the status JSON.
 */
function renderCrowdinBadge($m, $workflow, $branch, $query_branch, $label, $alt, $dot_only = false) {
  $text = $dot_only ? '<span class="visually-hidden">' . htmlspecialchars($label) . '</span>' : htmlspecialchars($label);
  $class = 'crowdin-status' . ($dot_only ? ' crowdin-status--dot' : '');
  $run_url = "{$m['github_url']}/actions/workflows/{$workflow}" . ($query_branch ? "?query=branch%3A" . rawurlencode($query_branch) : "");
  if ($m['is_private']) {
    echo '<a href="' . htmlspecialchars($run_url) . '" target="_blank" class="' . $class . '" title="' . htmlspecialchars($alt . ': private repository, status not available') . '">';
    echo '<span class="status-dot is-private" aria-hidden="true"></span>' . $text . '</a>';
    return;
  }
  $status_url = crowdinStatusUrl($m['github_org'], $m['github_repo'], $workflow, $branch);
  echo '<a href="' . htmlspecialchars($run_url) . '" target="_blank" class="' . $class . '" data-status-url="' . htmlspecialchars($status_url) . '" data-title="' . htmlspecialchars($alt) . '" title="' . htmlspecialchars($alt . ': loading...') . '">';
  echo '<span class="status-dot is-loading" aria-hidden="true"></span>' . $text . '</a>';
}

function gitPathExists($repoObject, $ref, $path) {
  try {
    $repoObject->git("cat-file -e {$ref}:{$path} 2>/dev/null");
    return true;
  } catch (Exception $e) {
    return false;
  }
}

function gitRefExists($repoObject, $ref) {
  try {
    $repoObject->git("rev-parse --verify {$ref} 2>/dev/null");
    return true;
  } catch (Exception $e) {
    return false;
  }
}

/**
 * Discover which repos have Crowdin GitHub Actions wired up, and which of
 * develop/stable branches actually exist for each - branch/workflow
 * detection is purely local git, only repo visibility needs a (cached)
 * GitHub API call. Result is cached for an hour since this rarely changes.
 */
function getCrowdinModules($projects, $stable_version) {
  $cache_key = 'crowdin_modules_' . md5($stable_version);
  $modules = cacheGet($cache_key);
  if (!empty($modules)) return $modules;

  $modules = array();
  foreach ($projects as $repo => $label) {
    $path = getenv('ADT_DATA') . "/sources/" . $repo . ".git";
    if (!is_dir($path)) continue;
    try {
      $repoObject = new PHPGit_Repository($path);
      $gh = getRepoGithubOrgAndUrl($repoObject);
      if (!$gh) continue;

      if (!gitPathExists($repoObject, 'origin/develop', '.github/workflows/upload-crowdin-main.yml')) {
        $modules[] = array('repo' => $repo, 'label' => $label, 'has_crowdin' => false);
        continue;
      }

      $has_download = gitPathExists($repoObject, 'origin/develop', '.github/workflows/download-crowdin.yml');

      $is_meeds = stripos($gh['org'], 'meeds-io') !== false;
      $stable_branch = $is_meeds ? "stable/{$stable_version}-exo" : "stable/{$stable_version}";
      $stable_ok = gitRefExists($repoObject, "origin/{$stable_branch}")
        && gitPathExists($repoObject, "origin/{$stable_branch}", '.github/workflows/upload-crowdin-branches.yml');

      $modules[] = array(
        'repo' => $repo,
        'label' => $label,
        'has_crowdin' => true,
        'github_org' => $gh['org'],
        'github_repo' => $gh['repo'],
        'github_url' => $gh['url'],
        'is_private' => isPrivateRepo($repo),
        'has_download' => $has_download,
        'stable_branch' => $stable_ok ? $stable_branch : null,
      );
    } catch (Exception $e) {}
  }
  usort($modules, function($a, $b) { return strcasecmp($a['label'], $b['label']); });
  cacheSet($cache_key, $modules, 3600);
  return $modules;
}

$projects = getRepositories();
$modules = getCrowdinModules($projects, $stable_version);
$active_modules = array_values(array_filter($modules, function($m) { return $m['has_crowdin']; }));
$skipped_modules = array_values(array_filter($modules, function($m) { return !$m['has_crowdin']; }));
?>
<html lang="en">
<head>
  <?= pageHeader("Crowdin Healthcheck", false); ?>
  <script>
    // Cards/Table view, applied before first paint
    if (getPref('crowdin-view', 'cards') === 'table') document.documentElement.classList.add('crowdin-table-view');
  </script>
  <style>
    .project-grid { grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); }
    .crowdin-branch-group + .crowdin-branch-group { margin-top: 0.6rem; }
    .crowdin-branch-group .feature-branch-link { display: block; font-size: 0.78rem; margin-bottom: 0.3rem; }
    .crowdin-branch-row { display: flex; align-items: center; gap: 0.4rem; flex-wrap: wrap; }
    /* Muted without opacity, which would drop the text below WCAG contrast */
    .project-chip--skipped { background: transparent; border-style: dashed; }
    .project-chip--skipped .project-chip-name { color: var(--text-secondary); }
    .link-reset { color: inherit; text-decoration: none; }
    .link-reset:hover { text-decoration: underline; }
    .crowdin-status {
      display: inline-flex; align-items: center; gap: 0.35rem;
      padding: 0.1rem 0.5rem; border: 1px solid var(--border-card); border-radius: var(--r-full);
      background: var(--bg-field); color: var(--text-secondary); font-size: 0.74rem; text-decoration: none;
    }
    .crowdin-status:hover { border-color: var(--accent); color: var(--text-primary); }
    .crowdin-toolbar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 0.5rem 1rem; margin-bottom: 1rem; }
    .crowdin-toolbar__actions { display: flex; flex-wrap: wrap; align-items: center; gap: 0.5rem; }
    @media (max-width: 768px) {
      .crowdin-toolbar__actions { width: 100%; }
      .crowdin-toolbar__actions > .btn-group { flex: 1 1 auto; }
    }
    .crowdin-table { display: none; width: 100%; border-collapse: separate; border-spacing: 0; font-size: 0.82rem;
      border: 1px solid var(--border-card); border-radius: var(--r-md); }
    html.crowdin-table-view .crowdin-table { display: table; }
    html.crowdin-table-view .crowdin-cards { display: none; }
    .crowdin-table th, .crowdin-table td { padding: 0.45rem 0.85rem; border-bottom: 1px solid var(--border-subtle); background: var(--bg-surface); }
    .crowdin-table tbody tr:last-child > * { border-bottom: 0; }
    .crowdin-table tbody th { font-weight: 600; }
    .crowdin-table thead th {
      position: sticky; top: 0; z-index: 2; background: var(--bg-elevated); border-bottom: 1px solid var(--border-card);
      color: var(--text-secondary); font-size: 0.7rem; font-weight: 600; letter-spacing: 0.05em; text-transform: uppercase; white-space: nowrap;
    }
    .crowdin-table thead th:first-child { border-top-left-radius: var(--r-md); }
    .crowdin-table thead th:last-child { border-top-right-radius: var(--r-md); }
    .crowdin-table tbody tr:hover > * { background: color-mix(in srgb, var(--accent) 8%, var(--bg-surface)); }
    .crowdin-table code { font-size: 0.78rem; }
    .crowdin-status--dot { padding: 0.3rem; border-color: transparent; background: none; }
    .crowdin-status--dot .status-dot { width: 11px; height: 11px; }
    .crowdin-table td.cell-nomatch > * { visibility: hidden; }
    .crowdin-summary { display: flex; flex-wrap: wrap; align-items: center; gap: 0.4rem 1.1rem; font-size: 0.82rem; color: var(--text-secondary); }
    .crowdin-summary > span { display: inline-flex; align-items: center; gap: 0.35rem; }
    .crowdin-summary b { color: var(--text-primary); font-variant-numeric: tabular-nums; }
    .status-dot { display: inline-block; width: 9px; height: 9px; border-radius: 50%; flex: 0 0 auto; background: var(--text-muted); }
    .status-dot.ok { background: var(--success); }
    .status-dot.fail { background: var(--danger); }
    .status-dot.warn { background: var(--warning); }
    .status-dot.unknown { background: var(--text-muted); opacity: 0.6; }
    .status-dot.is-private { background: transparent; box-shadow: inset 0 0 0 1.5px var(--text-muted); }
    .status-dot.is-loading { opacity: 0.4; animation: status-dot-pulse 1.2s ease-in-out infinite; }
    @keyframes status-dot-pulse { 50% { opacity: 0.1; } }
    @media (prefers-reduced-motion: reduce) { .status-dot.is-loading { animation: none; } }
  </style>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<div id="wrap">
  <div id="main" role="main">
    <div class="container-fluid">

      <div class="page-header">
        <h1 class="page-header__title">Crowdin Healthcheck</h1>
        <p class="page-header__subtitle">Crowdin upload/download GitHub Action status per module, on <code>develop</code> and its <code>stable/<?= htmlspecialchars($stable_version) ?></code> counterpart (<code>-exo</code> suffix for Meeds-io repositories)</p>
      </div>

      <?php if (!empty($active_modules)): ?>
      <div class="card mb-4">
        <div class="card-header">
          <div class="w-100">
            <div class="d-flex align-items-center flex-wrap">
              <i class="fas fa-language text-success me-2"></i>
              <h2 class="h5 mb-0">Modules with Crowdin integration</h2>
              <span class="badge bg-success ms-2" id="crowdinModulesCount" data-total="<?= count($active_modules) ?>"><?= count($active_modules) ?></span>
            </div>
            <small class="text-muted d-block mt-1">Status dots (green passing, red failing, grey no status) link to the GitHub Actions run history - private repositories show a hollow dot, since their status can't be looked up without authentication</small>
          </div>
        </div>
        <div class="card-body">
          <div class="crowdin-toolbar">
            <div class="crowdin-summary" aria-live="polite">
              <span><span class="status-dot ok"></span><b data-count="ok">0</b> passing</span>
              <span><span class="status-dot fail"></span><b data-count="fail">0</b> failing</span>
              <span data-if="warn"><span class="status-dot warn"></span><b data-count="warn">0</b> warning</span>
              <span data-if="unknown"><span class="status-dot unknown"></span><b data-count="unknown">0</b> no status</span>
              <span data-if="is-private"><span class="status-dot is-private"></span><b data-count="is-private">0</b> private</span>
              <span data-if="is-loading" class="text-muted"><b data-count="is-loading">0</b> loading&hellip;</span>
            </div>
            <div class="crowdin-toolbar__actions filter-bar">
              <button type="button" id="crowdinFailingOnly" class="btn btn-sm btn-outline-secondary" aria-pressed="false" title="Only modules with a failing workflow">
                <i class="fas fa-exclamation-circle me-1"></i>Failing only
              </button>
              <div class="btn-group btn-group-sm" role="group" aria-label="Modules view">
                <button type="button" class="btn btn-outline-secondary" data-view="cards" title="Card view"><i class="fas fa-th-large me-1"></i>Cards</button>
                <button type="button" class="btn btn-outline-secondary" data-view="table" title="Table view"><i class="fas fa-table me-1"></i>Table</button>
              </div>
            </div>
          </div>
          <div id="crowdinNoFailure" class="empty-section d-none">
            <i class="fas fa-check-circle"></i>
            <h3 class="h4">No failing workflow</h3>
          </div>
          <div class="project-grid crowdin-cards">
            <?php foreach ($active_modules as $m): ?>
            <div class="project-chip">
              <div class="project-chip-header">
                <span class="project-chip-name"><i class="fas fa-cube me-1" aria-hidden="true"></i><?= htmlspecialchars($m['label']) ?></span>
              </div>

              <div class="crowdin-branch-group">
                <a href="<?= htmlspecialchars($m['github_url']) ?>/tree/develop" target="_blank" class="feature-branch-link link-reset">develop</a>
                <div class="crowdin-branch-row">
                  <?php renderCrowdinBadge($m, 'upload-crowdin-main.yml', 'develop', 'develop', 'upload', 'Crowdin upload status for develop'); ?>
                  <?php if ($m['has_download']): ?>
                  <?php renderCrowdinBadge($m, 'download-crowdin.yml', null, null, 'download', 'Crowdin download status (scheduled)'); ?>
                  <?php endif; ?>
                </div>
              </div>

              <?php if ($m['stable_branch']): ?>
              <div class="crowdin-branch-group">
                <a href="<?= htmlspecialchars($m['github_url']) ?>/tree/<?= rawurlencode($m['stable_branch']) ?>" target="_blank" class="feature-branch-link link-reset"><?= htmlspecialchars($m['stable_branch']) ?></a>
                <div class="crowdin-branch-row">
                  <?php renderCrowdinBadge($m, 'upload-crowdin-branches.yml', $m['stable_branch'], $m['stable_branch'], 'upload', "Crowdin upload status for {$m['stable_branch']}"); ?>
                </div>
              </div>
              <?php endif; ?>
            </div>
            <?php endforeach; ?>
          </div>

          <!-- Table view -->
          <table class="crowdin-table" aria-label="Crowdin workflow status per module">
            <thead>
              <tr>
                <th scope="col">Module</th>
                <th scope="col">Stable branch</th>
                <th scope="col" class="text-center">Develop upload</th>
                <th scope="col" class="text-center">Develop download</th>
                <th scope="col" class="text-center">Stable upload</th>
              </tr>
            </thead>
            <tbody>
              <?php foreach ($active_modules as $m): ?>
              <tr>
                <th scope="row"><a href="<?= htmlspecialchars($m['github_url']) ?>" target="_blank" class="link-reset"><i class="fas fa-cube me-1 text-muted" aria-hidden="true"></i><?= htmlspecialchars($m['label']) ?></a></th>
                <td><?php if ($m['stable_branch']): ?><a href="<?= htmlspecialchars($m['github_url']) ?>/tree/<?= rawurlencode($m['stable_branch']) ?>" target="_blank" class="link-reset"><code><?= htmlspecialchars($m['stable_branch']) ?></code></a><?php else: ?><span class="text-muted">&mdash;</span><?php endif; ?></td>
                <td class="text-center"><?php renderCrowdinBadge($m, 'upload-crowdin-main.yml', 'develop', 'develop', 'develop upload', 'Crowdin upload status for develop', true); ?></td>
                <td class="text-center"><?php if ($m['has_download']): ?><?php renderCrowdinBadge($m, 'download-crowdin.yml', null, null, 'develop download', 'Crowdin download status (scheduled)', true); ?><?php else: ?><span class="text-muted">&mdash;</span><?php endif; ?></td>
                <td class="text-center"><?php if ($m['stable_branch']): ?><?php renderCrowdinBadge($m, 'upload-crowdin-branches.yml', $m['stable_branch'], $m['stable_branch'], 'stable upload', "Crowdin upload status for {$m['stable_branch']}", true); ?><?php else: ?><span class="text-muted">&mdash;</span><?php endif; ?></td>
              </tr>
              <?php endforeach; ?>
            </tbody>
          </table>
        </div>
      </div>
      <?php elseif (empty($skipped_modules)): ?>
      <div class="empty-section">
        <i class="fas fa-language"></i>
        <h2 class="h4">No modules found</h2>
        <p class="text-muted">No mirrored repositories were found under <code>ADT_DATA</code>.</p>
      </div>
      <?php endif; ?>

      <?php if (!empty($skipped_modules)): ?>
      <div class="card mb-4">
        <div class="card-header">
          <div class="w-100">
            <div class="d-flex align-items-center flex-wrap">
              <i class="fas fa-minus-circle text-muted me-2"></i>
              <h2 class="h5 mb-0">Modules without a Crowdin action</h2>
              <span class="badge bg-secondary ms-2"><?= count($skipped_modules) ?></span>
            </div>
            <small class="text-muted d-block mt-1">No Crowdin workflow on <code>develop</code> - skipped</small>
          </div>
        </div>
        <div class="card-body">
          <div class="project-grid">
            <?php foreach ($skipped_modules as $m): ?>
            <div class="project-chip project-chip--skipped">
              <div class="project-chip-header">
                <span class="project-chip-name"><i class="fas fa-cube me-1" aria-hidden="true"></i><?= htmlspecialchars($m['label']) ?></span>
              </div>
              <span class="badge bg-secondary">skipped</span>
            </div>
            <?php endforeach; ?>
          </div>
        </div>
      </div>
      <?php endif; ?>

    </div>
  </div>
</div>
<?php pageFooter(); ?>
<script>
// Fill the status dots from the shields.io JSON endpoint, a few requests at
// a time. Its first lookup for a repo/workflow/branch can time out while it
// cold-fetches from GitHub but is cached and fast right after: retry once.
(function () {
  // Each status is shown in both views: fetch every URL once, update all its links
  var byUrl = {};
  document.querySelectorAll('.crowdin-status[data-status-url]').forEach(function (link) {
    var url = link.getAttribute('data-status-url');
    (byUrl[url] = byUrl[url] || []).push(link);
  });
  var links = Object.keys(byUrl).map(function (url) { return byUrl[url]; });
  var CONCURRENCY = 6;
  function level(status) {
    var color = (status.color || '').toLowerCase(), message = (status.message || '').toLowerCase();
    if (message === 'passing') return 'ok';
    if (message === 'failing') return 'fail';
    // e.g. "repo or workflow not found" (red) or "no status": not a build failure
    if (/not found|no status|invalid|inaccessible/.test(message)) return 'unknown';
    if (color === 'brightgreen' || color === 'green') return 'ok';
    if (color === 'red' || color === 'critical') return 'fail';
    if (color === 'yellow' || color === 'orange' || color === 'important') return 'warn';
    return 'unknown';
  }
  function show(group, cls, message) {
    group.forEach(function (link) {
      link.querySelector('.status-dot').className = 'status-dot ' + cls;
      link.title = link.getAttribute('data-title') + ': ' + message;
    });
    update();
  }

  // Summary counts and "Failing only" filter (saved per browser)
  var grid = document.querySelector('.crowdin-cards');
  var table = document.querySelector('.crowdin-table');
  var failingBtn = document.getElementById('crowdinFailingOnly');
  var failingOnly = getPref('crowdin-failing-only', '0') === '1';
  function update() {
    if (!grid) return;
    var counts = {};
    grid.querySelectorAll('.crowdin-status .status-dot').forEach(function (dot) {
      var cls = dot.className.replace('status-dot', '').trim();
      counts[cls] = (counts[cls] || 0) + 1;
    });
    document.querySelectorAll('.crowdin-summary [data-count]').forEach(function (b) {
      b.textContent = counts[b.getAttribute('data-count')] || 0;
    });
    document.querySelectorAll('.crowdin-summary [data-if]').forEach(function (el) {
      el.classList.toggle('d-none', !counts[el.getAttribute('data-if')]);
    });
    failingBtn.classList.toggle('active', failingOnly);
    failingBtn.setAttribute('aria-pressed', failingOnly ? 'true' : 'false');
    var visible = 0, chips = grid.querySelectorAll('.project-chip');
    chips.forEach(function (chip) {
      var failing = 0;
      chip.querySelectorAll('.crowdin-status').forEach(function (pill) {
        var isFail = !!pill.querySelector('.status-dot.fail');
        if (isFail) failing++;
        pill.classList.toggle('d-none', failingOnly && !isFail);
      });
      chip.querySelectorAll('.crowdin-branch-group').forEach(function (group) {
        group.classList.toggle('d-none', failingOnly && !group.querySelector('.crowdin-status:not(.d-none)'));
      });
      var show = !failingOnly || failing > 0;
      chip.classList.toggle('d-none', !show);
      if (show) visible++;
    });
    // Table rows: same rule, non-failing cells blanked
    table.querySelectorAll('tbody tr').forEach(function (row) {
      var failing = 0;
      row.querySelectorAll('td').forEach(function (cell) {
        var isFail = !!cell.querySelector('.status-dot.fail');
        if (isFail) failing++;
        cell.classList.toggle('cell-nomatch', failingOnly && !isFail && cell.querySelector('.crowdin-status'));
      });
      row.classList.toggle('d-none', failingOnly && !failing);
    });
    var badge = document.getElementById('crowdinModulesCount');
    badge.textContent = visible == chips.length ? chips.length : visible + ' / ' + chips.length;
    var loading = counts['is-loading'] || 0;
    document.getElementById('crowdinNoFailure').classList.toggle('d-none', !(failingOnly && visible === 0 && !loading));
  }
  // Cards/Table view switch, saved per browser
  var viewBtns = document.querySelectorAll('.crowdin-toolbar [data-view]');
  function applyView(view) {
    document.documentElement.classList.toggle('crowdin-table-view', view === 'table');
    viewBtns.forEach(function (b) {
      var on = b.getAttribute('data-view') === view;
      b.classList.toggle('active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  }
  viewBtns.forEach(function (b) {
    b.addEventListener('click', function () {
      setPref('crowdin-view', this.getAttribute('data-view'));
      applyView(this.getAttribute('data-view'));
    });
  });
  applyView(getPref('crowdin-view', 'cards'));
  if (failingBtn) {
    failingBtn.addEventListener('click', function () {
      failingOnly = !failingOnly;
      setPref('crowdin-failing-only', failingOnly ? '1' : '0');
      update();
    });
  }
  update();
  function load(link, retried) {
    return fetch(link[0].getAttribute('data-status-url')).then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.json();
    }).then(function (status) {
      show(link, level(status), status.message || 'unknown');
    }).catch(function () {
      if (!retried) return new Promise(function (res) { setTimeout(res, 3000); }).then(function () { return load(link, true); });
      show(link, 'unknown', 'status unavailable');
    });
  }
  function next() {
    var link = links.shift();
    if (link) return load(link, false).then(next);
  }
  for (var i = 0; i < CONCURRENCY; i++) next();
})();
</script>
</body>
</html>

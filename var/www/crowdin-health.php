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
 * A live shields.io badge proxying the real GitHub Actions status for a
 * public repo. shields.io supports a short custom &label=, unlike GitHub's
 * own badge.svg (which ignores label overrides and renders at its full
 * workflow-name width - and has shown rate-limit/hang issues under load).
 * Only used for public repos; private ones use privateBadgeUrl() since
 * shields.io's public endpoint can't authenticate and always reports
 * "not found" for a repo it can't see.
 */
function crowdinBadgeUrl($org, $repo, $workflow, $branch, $label) {
  $url = "https://img.shields.io/github/actions/workflow/status/{$org}/{$repo}/{$workflow}?label=" . rawurlencode($label);
  if ($branch) $url .= "&branch=" . rawurlencode($branch);
  return $url;
}

/**
 * A static shields.io badge - not tied to any repo/API call, just a fixed
 * label/message/color image - so it renders identically for private repos
 * with none of the auth/CORS problems a live status lookup would have.
 */
function privateBadgeUrl($label) {
  // shields.io static badge syntax: segments are hyphen-separated, so a
  // literal "-" in label text must be escaped as "--" first.
  $escaped = str_replace('-', '--', $label);
  return "https://img.shields.io/badge/" . rawurlencode($escaped) . "-private-lightgrey";
}

/**
 * Render one badge link. For a known-private repo, skip the live <img>
 * entirely and show a static "private" badge instead. loading="lazy" on
 * the live badges keeps a page with many modules from firing 100+
 * simultaneous cross-origin image requests at once - badges below the
 * fold only request once scrolled into view. Live badges also get an
 * onerror retry (see crowdinBadgeRetry): shields.io's first-ever lookup
 * for a repo/workflow/branch combo can time out while it cold-fetches
 * from GitHub, but it's cached and fast right after - a retry a few
 * seconds later usually just works.
 */
function renderCrowdinBadge($m, $workflow, $branch, $query_branch, $label, $alt) {
  $run_url = "{$m['github_url']}/actions/workflows/{$workflow}" . ($query_branch ? "?query=branch%3A" . rawurlencode($query_branch) : "");
  $src = $m['is_private']
    ? privateBadgeUrl($label)
    : crowdinBadgeUrl($m['github_org'], $m['github_repo'], $workflow, $branch, $label);
  echo '<a href="' . htmlspecialchars($run_url) . '" target="_blank" rel="tooltip" title="' . htmlspecialchars($alt) . '">';
  echo '<img src="' . htmlspecialchars($src) . '" class="ci-badge" loading="lazy" alt="' . htmlspecialchars($alt) . '"' . ($m['is_private'] ? '' : ' onerror="crowdinBadgeRetry(this)"') . '>';
  echo '</a>';
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
  <style>
    .project-grid { grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); }
    .crowdin-branch-group + .crowdin-branch-group { margin-top: 0.6rem; }
    .crowdin-branch-group .feature-branch-link { display: block; font-size: 0.78rem; margin-bottom: 0.3rem; }
    .crowdin-branch-row { display: flex; align-items: center; gap: 0.4rem; flex-wrap: wrap; }
    .project-chip--skipped { opacity: 0.6; }
    .link-reset { color: inherit; text-decoration: none; }
    .link-reset:hover { text-decoration: underline; }
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
              <h5 class="mb-0">Modules with Crowdin integration</h5>
              <span class="badge bg-success ms-2"><?= count($active_modules) ?></span>
            </div>
            <small class="text-muted d-block mt-1">Badges link to the corresponding GitHub Actions run history - private repositories show a "private" badge instead, since their status can't be looked up without authentication</small>
          </div>
        </div>
        <div class="card-body">
          <div class="project-grid">
            <?php foreach ($active_modules as $m): ?>
            <div class="project-chip">
              <div class="project-chip-header">
                <i class="fas fa-cube me-1" aria-hidden="true"></i>
                <?= htmlspecialchars($m['label']) ?>
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
        </div>
      </div>
      <?php elseif (empty($skipped_modules)): ?>
      <div class="empty-section">
        <i class="fas fa-language"></i>
        <h4>No modules found</h4>
        <p class="text-muted">No mirrored repositories were found under <code>ADT_DATA</code>.</p>
      </div>
      <?php endif; ?>

      <?php if (!empty($skipped_modules)): ?>
      <div class="card mb-4">
        <div class="card-header">
          <div class="w-100">
            <div class="d-flex align-items-center flex-wrap">
              <i class="fas fa-minus-circle text-muted me-2"></i>
              <h5 class="mb-0">Modules without a Crowdin action</h5>
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
                <i class="fas fa-cube me-1" aria-hidden="true"></i>
                <?= htmlspecialchars($m['label']) ?>
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
// shields.io's first-ever lookup for a given repo/workflow/branch combo can
// time out while it cold-fetches status from GitHub, but is fast right after
// once cached on its end. Retry once after a few seconds; if it still fails,
// fall back to a plain link instead of leaving a broken image icon.
function crowdinBadgeRetry(img) {
  var attempts = parseInt(img.dataset.retries || '0', 10);
  if (attempts < 1) {
    img.dataset.retries = attempts + 1;
    setTimeout(function() {
      var src = img.src;
      img.src = '';
      img.src = src;
    }, 3000);
  } else {
    var span = document.createElement('span');
    span.className = 'badge bg-secondary';
    span.textContent = 'view on GitHub';
    img.replaceWith(span);
  }
}
</script>
</body>
</html>

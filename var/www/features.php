<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("features"); ?>
    <script type="text/javascript">
        // Handle hash-based navigation to highlight feature cards
        // (tooltip init is already handled globally by pageFooter())
        document.addEventListener('DOMContentLoaded', function () {
            if (window.location.hash.length > 1) {
                var name = decodeURIComponent(window.location.hash.substring(1));
                var anchor = document.querySelector('a[name="' + CSS.escape(name) + '"]');
                if (anchor) anchor.closest('.feature-card').classList.add('highlight');
            }
        });
    </script>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
    <div id="main" role="main">
        <div class="container-fluid">
            <div class="row">
                <div class="col-12">
                    <!-- Page Header -->
                    <div class="page-header">
                        <h1 class="page-header__title">Feature Branches</h1>
                        <p class="page-header__subtitle">Git feature branches (<code>feature/.*</code>) with branch health overview</p>
                    </div>

                    <?php
                    // Get all data
                    $projectsNames = getRepositories();
                    $projects = array_keys(getRepositories());
                    $features = getFeatureBranches($projects);
                    $translations = getTranslationBranches($projects);
                    $meedsProjectsNames = getMeedsRepositories();
                    $meedsProjects = array_keys($meedsProjectsNames);
                    $baseBranches = getBaseBranches($meedsProjects);
                    
                    // Filter accepted features
                    $acceptedFeatures = array_filter($features, function($feature, $name) {
                        return in_array($name, getAcceptanceBranches()) && !isTranslation($name);
                    }, ARRAY_FILTER_USE_BOTH);
                    
                    // Filter other features (not accepted, not backup)
                    $otherFeatures = array_filter($features, function($feature, $name) {
                        return !in_array($name, getAcceptanceBranches()) && !isBackup($name);
                    }, ARRAY_FILTER_USE_BOTH);
                    ?>

                    <!-- Feature Branches deployed on acceptance -->
                    <?php if (!empty($acceptedFeatures)): ?>
                    <div class="card mb-4">
                        <div class="card-header">
                            <div class="w-100">
                                <div class="d-flex align-items-center flex-wrap">
                                    <i class="fas fa-check-circle text-success me-2"></i>
                                    <h5 class="mb-0">Feature Branches deployed on acceptance</h5>
                                    <span class="badge bg-success ms-2"><?= count($acceptedFeatures) ?></span>
                                </div>
                                <small class="text-muted d-block mt-1">Status compared to each project code base branch</small>
                            </div>
                        </div>
                        <div class="card-body">
                            <?php foreach ($acceptedFeatures as $feature => $FBProjects): ?>
                            <?php $featureSlug = str_replace(["/", "."], "-", $feature); ?>
                            <div class="feature-card card mb-3" id="feature-<?= htmlspecialchars($featureSlug) ?>">
                                <div class="card-body">
                                    <a name="<?= htmlspecialchars($featureSlug) ?>"></a>

                                    <!-- Feature Header -->
                                    <div class="feature-title">
                                        <a href="<?= htmlspecialchars(currentPageURL() . "#feature-" . $featureSlug) ?>" class="text-warning">
                                            <i class="fas fa-bookmark" aria-hidden="true"></i>
                                        </a>
                                        <h5 class="feature-branch-link">
                                            <code><?= htmlspecialchars($feature) ?></code>
                                        </h5>
                                        <div class="feature-actions ms-auto">
                                        <a href="https://ci.exoplatform.org/job/exo-<?= rawurlencode($feature) ?>-fb-rebase-branch/" target="_blank"
                                           class="btn btn-sm btn-outline-primary" rel="tooltip" title="Rebase this feature branch">
                                                <i class="fas fa-sync-alt" aria-hidden="true"></i> Rebase
                                            </a>
                                            <img src="https://ci.exoplatform.org/buildStatus/icon?job=exo-<?= rawurlencode($feature) ?>-fb-rebase-branch"
                                                 class="ci-badge" alt="Rebase build status for <?= htmlspecialchars($feature) ?>">
                                        </div>
                                    </div>

                                    <!-- Projects Grid -->
                                    <div class="project-grid">
                                        <?php foreach ($projects as $project): ?>
                                            <?php if (array_key_exists($project, $FBProjects)): ?>
                                            <div class="project-chip">
                                                <div class="project-chip-header">
                                                    <i class="fas fa-cube me-1" aria-hidden="true"></i>
                                                    <?= htmlspecialchars($projectsNames[$project]) ?>
                                                </div>
                                                <div class="text-center">
                                                    <?= componentFeatureRepoBrancheStatus($FBProjects[$project]); ?>
                                                </div>
                                                <div class="text-center mt-2">
                                                    <a href="https://ci.exoplatform.org/job/FB/job/<?= getModuleCiPrefix($project) . rawurlencode($project) ?>-<?= rawurlencode($feature) ?>-fb-ci/"
                                                       target="_blank" rel="tooltip" title="CI Job for <?= htmlspecialchars($projectsNames[$project]) ?>">
                                                         <img src="https://ci.exoplatform.org/buildStatus/icon?job=fb/<?= getModuleCiPrefix($project) . rawurlencode($project) ?>-<?= rawurlencode($feature) ?>-fb-ci"
                                                              class="ci-badge" alt="CI build status for <?= htmlspecialchars($projectsNames[$project]) ?>">
                                                    </a>
                                                </div>
                                            </div>
                                            <?php endif; ?>
                                        <?php endforeach; ?>
                                    </div>
                                </div>
                            </div>
                            <?php endforeach; ?>
                        </div>
                    </div>
                    <?php endif; ?>

                    <!-- Others branches -->
                    <?php if (!empty($otherFeatures)): ?>
                    <div class="card mb-4">
                        <div class="card-header">
                            <div class="w-100">
                                <div class="d-flex align-items-center flex-wrap">
                                    <i class="fas fa-exclamation-triangle text-warning me-2"></i>
                                    <h5 class="mb-0">Other branches</h5>
                                    <span class="badge bg-warning ms-2"><?= count($otherFeatures) ?></span>
                                </div>
                                <small class="text-danger d-block mt-1">
                                    <i class="fas fa-broom me-1"></i>
                                    ARE YOU SURE YOU DON'T NEED TO DO SOME BRANCH CLEANUP?
                                </small>
                            </div>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <?php foreach ($otherFeatures as $feature => $FBProjects): ?>
                                <div class="col-md-6 col-lg-4 mb-3">
                                    <div class="feature-card card h-100">
                                        <div class="card-body">
                                            <div class="feature-title">
                                                <a href="<?= htmlspecialchars(currentPageURL() . "#" . str_replace(["/", "."], "-", $feature)) ?>" class="text-warning">
                                                    <i class="fas fa-bookmark" aria-hidden="true"></i>
                                                </a>
                                                <code class="small"><?= htmlspecialchars($feature) ?></code>
                                            </div>
                                            <div class="mt-2">
                                                <?php
                                                $projectCount = count($FBProjects);
                                                $firstProjects = array_slice($FBProjects, 0, 3, true);
                                                ?>
                                                <span class="badge bg-info me-2"><?= $projectCount ?> project(s)</span>
                                                <?php if ($projectCount > 0): ?>
                                                    <small class="text-muted">
                                                        <?= htmlspecialchars(implode(', ', array_map(function($p) use ($projectsNames) {
                                                            return $projectsNames[$p];
                                                        }, array_keys($firstProjects)))) ?>
                                                        <?= $projectCount > 3 ? '...' : '' ?>
                                                    </small>
                                                <?php endif; ?>
                                            </div>
                                            <?php if (!empty($FBProjects)): ?>
                                            <div class="mt-2 d-flex gap-2 flex-wrap">
                                                <?php foreach (array_slice($FBProjects, 0, 2) as $project => $data): ?>
                                                    <span class="badge bg-light text-dark">
                                                        <?= componentFeatureRepoBrancheStatus($data) ?>
                                                    </span>
                                                <?php endforeach; ?>
                                                <?php if (count($FBProjects) > 2): ?>
                                                    <span class="badge bg-secondary">+<?= count($FBProjects) - 2 ?> more</span>
                                                <?php endif; ?>
                                            </div>
                                            <?php endif; ?>
                                        </div>
                                    </div>
                                </div>
                                <?php endforeach; ?>
                            </div>
                        </div>
                    </div>
                    <?php endif; ?>
                    <!-- Empty state -->
                    <?php if (empty($acceptedFeatures) && empty($otherFeatures) && empty($baseBranches)): ?>
                    <div class="empty-section">
                        <i class="fas fa-code-branch"></i>
                        <h4>No branches found</h4>
                        <p class="text-muted">There are currently no feature branches to display.</p>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </div>
        <!-- /container -->
    </div>
</div>
<?php pageFooter(); ?>
</body>
</html>
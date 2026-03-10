<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader("features"); ?>
    <script type="text/javascript">
        $(document).ready(function () {
            $(".feature-card").on("click", function (event) {
                if (!$(event.target).closest('a').length) {
                    $(".feature-card").removeClass('highlight');
                    $(this).addClass('highlight');
                }
            });
            
            if (window.location.hash.length > 0) {
                $trSelector = "a[name=" + window.location.hash.substring(1, window.location.hash.length) + "]";
                $($trSelector).closest('.feature-card').addClass('highlight');
            }
            
            // Initialize Bootstrap tooltips
            var tooltipTriggerList = [].slice.call(document.querySelectorAll('[rel=tooltip]'));
            tooltipTriggerList.map(function(tooltipTriggerEl) {
                return new bootstrap.Tooltip(tooltipTriggerEl);
            });
        });
    </script>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
    <div id="main">
        <div class="container-fluid">
            <div class="row">
                <div class="col-12">
                    <div class="alert alert-info d-flex align-items-center">
                        <i class="fas fa-code-branch fa-2x me-3"></i>
                        <div>
                            <h5 class="alert-heading mb-1">Feature Branches Overview</h5>
                            <p class="mb-0">This page summarizes all Git feature branches (<code>feature/.*</code>) and provides an overview of branches health.</p>
                        </div>
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
                            <div class="d-flex align-items-center">
                                <i class="fas fa-check-circle text-success me-2"></i>
                                <h5 class="mb-0">Feature Branches deployed on acceptance</h5>
                                <span class="badge bg-success ms-2"><?= count($acceptedFeatures) ?></span>
                            </div>
                            <small class="text-muted d-block mt-1">Status compared to each project code base branch</small>
                        </div>
                        <div class="card-body">
                            <?php foreach ($acceptedFeatures as $feature => $FBProjects): ?>
                            <div class="feature-card card mb-3" id="feature-<?= str_replace(array("/", "."), "-", $feature) ?>">
                                <div class="card-body">
                                    <a name="<?= str_replace(array("/", "."), "-", $feature) ?>"></a>
                                    
                                    <!-- Feature Header -->
                                    <div class="feature-title">
                                        <a href="<?= currentPageURL() . "#feature-" . str_replace(array("/", "."), "-", $feature) ?>" class="text-warning">
                                            <i class="fas fa-bookmark"></i>
                                        </a>
                                        <h5 class="feature-branch-link">
                                            <code><?= $feature ?></code>
                                        </h5>
                                        <div class="feature-actions ms-auto">
                                            <a href="https://ci.exoplatform.org/job/exo-<?= $feature ?>-fb-rebase-branch/" target="_blank" 
                                               class="btn btn-sm btn-outline-primary" rel="tooltip" title="Rebase this feature branch">
                                                <i class="fas fa-sync-alt"></i> Rebase
                                            </a>
                                            <img src="https://ci.exoplatform.org/buildStatus/icon?job=exo-<?= $feature ?>-fb-rebase-branch" 
                                                 class="ci-badge" alt="Build Status">
                                        </div>
                                    </div>
                                    
                                    <!-- Projects Grid -->
                                    <div class="project-grid">
                                        <?php foreach ($projects as $project): ?>
                                            <?php if (array_key_exists($project, $FBProjects)): ?>
                                            <div class="project-chip">
                                                <div class="project-chip-header">
                                                    <i class="fas fa-cube me-1"></i>
                                                    <?= $projectsNames[$project] ?>
                                                </div>
                                                <div class="text-center">
                                                    <?= componentFeatureRepoBrancheStatus($FBProjects[$project]); ?>
                                                </div>
                                                <div class="text-center mt-2">
                                                    <a href="https://ci.exoplatform.org/job/FB/job/<?= getModuleCiPrefix($project) ?><?= $project ?>-<?= $feature ?>-fb-ci/" 
                                                       target="_blank" rel="tooltip" title="CI Job">
                                                        <img src="https://ci.exoplatform.org/buildStatus/icon?job=fb/<?= getModuleCiPrefix($project) ?><?= $project ?>-<?= $feature ?>-fb-ci" 
                                                             class="ci-badge" alt="CI Status">
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
                    <div class="card mb-4 border-warning">
                        <div class="card-header bg-warning bg-opacity-10">
                            <div class="d-flex align-items-center">
                                <i class="fas fa-exclamation-triangle text-warning me-2"></i>
                                <h5 class="mb-0">Other branches</h5>
                                <span class="badge bg-warning ms-2"><?= count($otherFeatures) ?></span>
                            </div>
                            <small class="text-danger d-block mt-1">
                                <i class="fas fa-broom me-1"></i>
                                ARE YOU SURE YOU DON'T NEED TO DO SOME BRANCH CLEANUP?
                            </small>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <?php foreach ($otherFeatures as $feature => $FBProjects): ?>
                                <div class="col-md-6 col-lg-4 mb-3">
                                    <div class="feature-card card h-100">
                                        <div class="card-body">
                                            <div class="feature-title">
                                                <a href="<?= currentPageURL() . "#" . str_replace(array("/", "."), "-", $feature) ?>" class="text-warning">
                                                    <i class="fas fa-bookmark"></i>
                                                </a>
                                                <code class="small"><?= $feature ?></code>
                                            </div>
                                            <div class="mt-2">
                                                <?php 
                                                $projectCount = count($FBProjects);
                                                $firstProjects = array_slice($FBProjects, 0, 3, true);
                                                ?>
                                                <span class="badge bg-info me-2"><?= $projectCount ?> project(s)</span>
                                                <?php if ($projectCount > 0): ?>
                                                    <small class="text-muted">
                                                        <?= implode(', ', array_map(function($p) use ($projectsNames) { 
                                                            return $projectsNames[$p]; 
                                                        }, array_keys($firstProjects))) ?>
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

                    <!-- Meeds-io Development Branches -->
                    <?php if (!empty($baseBranches)): ?>
                    <div class="card mb-4">
                        <div class="card-header">
                            <div class="d-flex align-items-center">
                                <i class="fab fa-meetup text-success me-2"></i>
                                <h5 class="mb-0">Meeds-io Development Branches</h5>
                                <span class="badge bg-success ms-2"><?= count($baseBranches) ?></span>
                            </div>
                            <small class="text-muted d-block mt-1">Status compared to each project code base branch</small>
                        </div>
                        <div class="card-body">
                            <?php foreach ($baseBranches as $baseBranch => $BaseProjects): 
                                $ciView = getBaseBranchView($baseBranch);
                                $rebaseJobName = getRebaseJobName($baseBranch);
                                $cherryCompare = isCherryCompare($baseBranch);
                            ?>
                            <div class="feature-card card mb-3" id="branch-<?= str_replace(array("/", "."), "-", $baseBranch) ?>">
                                <div class="card-body">
                                    <div class="feature-title">
                                        <a href="<?= currentPageURL() . "#branch-" . str_replace(array("/", "."), "-", $baseBranch) ?>" class="text-warning">
                                            <i class="fas fa-bookmark"></i>
                                        </a>
                                        <h5 class="mb-0"><?= $baseBranch ?></h5>
                                        <div class="feature-actions ms-auto">
                                            <a href="https://ci.exoplatform.org/job/<?= $rebaseJobName ?>" target="_blank" 
                                               class="btn btn-sm btn-outline-primary" rel="tooltip" title="Rebase branch">
                                                <i class="fas fa-sync-alt"></i> Rebase
                                            </a>
                                            <img src="https://ci.exoplatform.org/buildStatus/icon?job=<?= $rebaseJobName ?>" 
                                                 class="ci-badge" alt="Build Status">
                                        </div>
                                    </div>
                                    
                                    <div class="project-grid">
                                        <?php foreach ($meedsProjects as $project): ?>
                                            <?php if (array_key_exists($project, $BaseProjects)): ?>
                                            <div class="project-chip">
                                                <div class="project-chip-header">
                                                    <i class="fas fa-cube me-1"></i>
                                                    <?= $meedsProjectsNames[$project] ?>
                                                </div>
                                                <div class="text-center">
                                                    <?= componentFeatureRepoBrancheStatus($BaseProjects[$project], $cherryCompare); ?>
                                                </div>
                                                <div class="text-center mt-2">
                                                    <a href="https://ci.exoplatform.org/job/<?= $ciView ?>/job/<?= getModuleCiPrefix($project) ?><?= $project ?>-<?= $baseBranch ?>-ci/" 
                                                       target="_blank" rel="tooltip" title="CI Job">
                                                        <img src="https://ci.exoplatform.org/buildStatus/icon?job=<?= $ciView ?>/<?= getModuleCiPrefix($project) ?><?= $project ?>-<?= $baseBranch ?>-ci" 
                                                             class="ci-badge" alt="CI Status">
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
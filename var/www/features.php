<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';
checkCaches();

$projectsNames = getRepositories();
$projects = array_keys($projectsNames);
$features = getFeatureBranches($projects);
$translations = getTranslationBranches($projects);
$baseBranches = getBaseBranches(array_keys(getMeedsRepositories()));
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader("Feature Branches"); ?>
    <script>
        $(document).ready(function() {
            $("tr").on("click", function(event) {
                $(this).addClass('table-active').siblings().removeClass('table-active');
            });
            
            if (window.location.hash.length > 0) {
                const trSelector = "a[name=" + window.location.hash.substring(1) + "]";
                $(trSelector).parents('tr').addClass('table-active').siblings().removeClass('table-active');
            }
        });
    </script>
</head>
<body>
    <?php pageTracker(); ?>
    <?php pageNavigation(); ?>
    
    <div id="wrap">
        <div id="main">
            <div class="container-fluid">
                <div class="row">
                    <div class="col-12">
                        <div class="card mb-4">
                            <div class="card-body">
                                <h1 class="h4 mb-4">Feature Branches Overview</h1>
                                <p>This page summarizes all Git feature branches (<code>feature/.*</code>) and provides an overview of branch health.</p>
                                
                                <h2 class="h5 mt-5 mb-3">Feature Branches <u>deployed on acceptance</u> <small class="text-muted">(status compared to each project code base branch)</small></h2>
                                <div class="table-responsive">
                                    <table class="table table-hover table-header-rotated">
                                        <thead>
                                            <tr>
                                                <th class="text-start"><div><span>feature/.*</span></div></th>
                                                <?php foreach ($projects as $project): ?>
                                                    <th class="rotate-45"><div><span><?= htmlspecialchars($projectsNames[$project]) ?></span></div></th>
                                                <?php endforeach; ?>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php foreach ($features as $feature => $FBProjects): ?>
                                                <?php if (in_array($feature, getAcceptanceBranches()) && !isTranslation($feature)): ?>
                                                    <tr>
                                                        <td>
                                                            <a name="<?= htmlspecialchars(str_replace(['/', '.'], '-', $feature)) ?>"></a>
                                                            <a href="<?= htmlspecialchars(currentPageURL() . "#" . str_replace(['/', '.'], '-', $feature)) ?>">
                                                                <i class="fas fa-bookmark me-1"></i>
                                                            </a>
                                                            <?= htmlspecialchars($feature) ?>
                                                            <div class="mt-2">
                                                                <a href="https://ci.exoplatform.org/job/exo-<?= htmlspecialchars($feature) ?>-fb-rebase-branch/" 
                                                                   target="_blank" 
                                                                   class="text-decoration-none" 
                                                                   title="Rebase FB">
                                                                    <i class="fas fa-sync-alt me-1"></i>
                                                                </a>
                                                                <img src="https://ci.exoplatform.org/buildStatus/icon?job=exo-<?= htmlspecialchars($feature) ?>-fb-rebase-branch" 
                                                                     style="height:15px; width: 85px;" 
                                                                     alt="Build status">
                                                            </div>
                                                        </td>
                                                        <?php foreach ($projects as $project): ?>
                                                            <td class="text-center">
                                                                <?php if (array_key_exists($project, $FBProjects)): ?>
                                                                    <?= componentFeatureRepoBrancheStatus($FBProjects[$project]) ?>
                                                                    <a href="https://ci.exoplatform.org/job/FB/job/<?= htmlspecialchars(getModuleCiPrefix($project)) ?><?= htmlspecialchars($project) ?>-<?= htmlspecialchars($feature) ?>-fb-ci/" 
                                                                       target="_blank" 
                                                                       title="Continuous integration job">
                                                                        <img src="https://ci.exoplatform.org/buildStatus/icon?job=fb/<?= htmlspecialchars(getModuleCiPrefix($project)) ?><?= htmlspecialchars($project) ?>-<?= htmlspecialchars($feature) ?>-fb-ci" 
                                                                             alt="CI status">
                                                                    </a>
                                                                <?php endif; ?>
                                                            </td>
                                                        <?php endforeach; ?>
                                                    </tr>
                                                <?php endif; ?>
                                            <?php endforeach; ?>
                                        </tbody>
                                    </table>
                                </div>
                                
                                <h2 class="h5 mt-5 mb-3">Meeds-io Development Branches <small class="text-muted">(status compared to each project code base branch)</small></h2>
                                <div class="table-responsive">
                                    <table class="table table-hover table-header-rotated">
                                        <thead>
                                            <tr>
                                                <th class="text-start"><div><span>base branch</span></div></th>
                                                <?php foreach (array_keys(getMeedsRepositories()) as $project): ?>
                                                    <th class="rotate-45"><div><span><?= htmlspecialchars(getMeedsRepositories()[$project]) ?></span></div></th>
                                                <?php endforeach; ?>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php foreach ($baseBranches as $baseBranch => $BaseProjects): 
                                                $ciView = getBaseBranchView($baseBranch);
                                                $rebaseJobName = getRebaseJobName($baseBranch);
                                                $cherryCompare = isCherryCompare($baseBranch);
                                            ?>
                                                <tr>
                                                    <td>
                                                        <a name="<?= htmlspecialchars(str_replace(['/', '.'], '-', $baseBranch)) ?>"></a>
                                                        <a href="<?= htmlspecialchars(currentPageURL() . "#" . str_replace(['/', '.'], '-', $baseBranch)) ?>">
                                                            <i class="fas fa-bookmark me-1"></i>
                                                        </a>
                                                        <?= htmlspecialchars($baseBranch) ?>
                                                        <div class="mt-2">
                                                            <a href="https://ci.exoplatform.org/job/<?= htmlspecialchars($rebaseJobName) ?>" 
                                                               target="_blank" 
                                                               class="text-decoration-none" 
                                                               title="Rebase FB">
                                                                <i class="fas fa-sync-alt me-1"></i>
                                                            </a>
                                                            <img src="https://ci.exoplatform.org/buildStatus/icon?job=<?= htmlspecialchars($rebaseJobName) ?>" 
                                                                 style="height:15px; width: 85px;" 
                                                                 alt="Build status">
                                                        </div>
                                                    </td>
                                                    <?php foreach (array_keys(getMeedsRepositories()) as $project): ?>
                                                        <td class="text-center">
                                                            <?php if (array_key_exists($project, $BaseProjects)): ?>
                                                                <?= componentFeatureRepoBrancheStatus($BaseProjects[$project], $cherryCompare) ?>
                                                                <a href="https://ci.exoplatform.org/job/<?= htmlspecialchars($ciView) ?>/job/<?= htmlspecialchars(getModuleCiPrefix($project)) ?><?= htmlspecialchars($project) ?>-<?= htmlspecialchars($baseBranch) ?>-ci/" 
                                                                   target="_blank" 
                                                                   title="Continuous integration job">
                                                                    <img src="https://ci.exoplatform.org/buildStatus/icon?job=<?= htmlspecialchars($ciView) ?>/<?= htmlspecialchars(getModuleCiPrefix($project)) ?><?= htmlspecialchars($project) ?>-<?= htmlspecialchars($baseBranch) ?>-ci" 
                                                                         alt="CI status">
                                                                </a>
                                                            <?php endif; ?>
                                                        </td>
                                                    <?php endforeach; ?>
                                                </tr>
                                            <?php endforeach; ?>
                                        </tbody>
                                    </table>
                                </div>
                                
                                <h2 class="h5 mt-5 mb-3">Other branches <small class="text-muted">ARE YOU SURE YOU DON'T NEED TO DO SOME BRANCH CLEANUP?</small></h2>
                                <div class="table-responsive">
                                    <table class="table table-hover table-header-rotated">
                                        <thead>
                                            <tr>
                                                <th class="text-start">feature/????</th>
                                                <?php foreach ($projects as $project): ?>
                                                    <th class="rotate-45"><div><span><?= htmlspecialchars($projectsNames[$project]) ?></span></div></th>
                                                <?php endforeach; ?>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php foreach ($features as $feature => $FBProjects): ?>
                                                <?php if (!in_array($feature, getAcceptanceBranches()) && !isBackup($feature)): ?>
                                                    <tr>
                                                        <td>
                                                            <a name="<?= htmlspecialchars(str_replace(['/', '.'], '-', $feature)) ?>"></a>
                                                            <a href="<?= htmlspecialchars(currentPageURL() . "#" . str_replace(['/', '.'], '-', $feature)) ?>">
                                                                <i class="fas fa-bookmark me-1"></i>
                                                            </a>
                                                            <?= htmlspecialchars($feature) ?>
                                                        </td>
                                                        <?php foreach ($projects as $project): ?>
                                                            <td class="text-center">
                                                                <?php if (array_key_exists($project, $FBProjects)): ?>
                                                                    <?= componentFeatureRepoBrancheStatus($FBProjects[$project]) ?>
                                                                <?php endif; ?>
                                                            </td>
                                                        <?php endforeach; ?>
                                                    </tr>
                                                <?php endif; ?>
                                            <?php endforeach; ?>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <?php pageFooter(); ?>
</body>
</html>
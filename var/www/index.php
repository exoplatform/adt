<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();

// Compute stats for bento grid
$all_merged = getGlobalAcceptanceInstances();
$total_instances = 0;
$running = 0;
$stopped = 0;
foreach ($all_merged as $branch => $instances) {
    foreach ($instances as $inst) {
        $total_instances++;
        if ($inst->DEPLOYMENT_STATUS == "Up") $running++;
        else $stopped++;
    }
}
$translation_instances = getGlobalTranslationInstances();
$translation_count = 0;
if (isDeploymentInCategoryArray($translation_instances)) {
    foreach ($translation_instances as $arr) {
        $translation_count += count($arr);
    }
}
$dev_instances = getGlobalDevInstances();
$dev_count = 0;
foreach ($dev_instances as $arr) {
    $dev_count += count($arr);
}
?>
<html lang="en">
<head>
    <?= pageHeader(); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
<div id="main" role="main">

    <!-- Page Header -->
    <div class="page-header">
        <h1 class="page-header__title">Dashboard</h1>
        <p class="page-header__subtitle">Acceptance test deployment instances</p>
    </div>

    <!-- Bento Metric Grid -->
    <div class="bento">
        <div class="bento__item bento__item--3" style="--card-accent: var(--accent)">
            <div class="metric">
                <span class="metric__label"><i class="fas fa-server"></i> Total Instances</span>
                <span class="metric__value"><?= $total_instances ?></span>
            </div>
        </div>
        <div class="bento__item bento__item--3" style="--card-accent: var(--success)">
            <div class="metric">
                <span class="metric__label"><span class="pulse-dot on"></span> Running</span>
                <span class="metric__value"><?= $running ?></span>
                <?php if ($running > 0): ?>
                <span class="metric__change up"><?= round(($running / max($total_instances, 1)) * 100) ?>% active</span>
                <?php endif; ?>
            </div>
        </div>
        <div class="bento__item bento__item--3" style="--card-accent: var(--danger)">
            <div class="metric">
                <span class="metric__label"><span class="pulse-dot off"></span> Stopped</span>
                <span class="metric__value"><?= $stopped ?></span>
            </div>
        </div>
        <div class="bento__item bento__item--3" style="--card-accent: var(--accent2)">
            <div class="metric">
                <span class="metric__label"><i class="fas fa-code-branch"></i> Dev Branches</span>
                <span class="metric__value"><?= $dev_count ?></span>
                <span class="metric__change"><?= count($dev_instances) ?> active</span>
            </div>
        </div>
    </div>
    <!-- Search -->
    <div class="instances-search">
        <i class="fas fa-search instances-search__icon"></i>
        <input type="text" id="instanceSearch" class="instances-search__input" placeholder="Search by name, version, or branch...">
    </div>

    <!-- Translation Instances -->
    <?php if (isDeploymentInCategoryArray($translation_instances)): ?>
    <div class="instances-section">
        <div class="instances-section__header">
            <i class="fas fa-globe" aria-hidden="true"></i> Translation deployments
        </div>
        <div class="instance-grid">
            <?php foreach ($translation_instances as $plf_branch => $descriptor_arrays):
                foreach ($descriptor_arrays as $inst):
                    echo renderInstanceCard($inst, [
                        'rich_name' => true,
                        'meta_download_first' => true,
                        'actions_top' => componentEditNoteIcon($inst),
                        'show_built_age' => true,
                        'badges' => [],
                    ]);
                endforeach;
            endforeach; ?>
        </div>
    </div>
    <?php endif; ?>

    <!-- Dev Instances -->
    <?php foreach ($dev_instances as $plf_branch => $descriptor_arrays): ?>
    <div class="instances-section">
        <div class="instances-section__header">
            <i class="fas fa-code-branch"></i> <?= buildTableTitleDev($plf_branch) ?>
        </div>
        <div class="instance-grid">
            <?php foreach ($descriptor_arrays as $inst):
                echo renderInstanceCard($inst, [
                    'rich_name' => true,
                    'meta_download_first' => true,
                    'actions_top' => componentSpecificationIcon($inst) . (!isInstanceFeatureBranch($inst) ? componentEditNoteIcon($inst) : ''),
                    'show_built_age' => true,
                    'feature_label' => true,
                    'fb_badges' => true,
                    'labels' => true,
                ]);
            endforeach; ?>
        </div>
    </div>
    <?php endforeach; ?>

    <!-- Info cards -->
    <?= componentAccessInfoCards(); ?>

<!-- /container -->
</div>
</div>
<?php pageFooter(); ?>
</body>
</html>

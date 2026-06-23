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
                foreach ($descriptor_arrays as $inst): ?>
            <div class="instance-card">
                <div class="instance-card__top">
                    <div class="instance-card__status">
                        <?php if ($inst->DEPLOYMENT_STATUS == "Up"): ?>
                            <span class="pulse-dot on" title="Running" aria-label="Status: Up"></span>
                        <?php else: ?>
                            <span class="pulse-dot off" title="Stopped" aria-label="Status: Down"></span>
                        <?php endif; ?>
                    </div>
                    <div class="instance-card__info">
                        <div class="instance-card__name">
                            <?= componentProductInfoIcon($inst); ?>
                            <?php
                            $label = componentVisibilityIcon($inst, empty($inst->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'success');
                            $label .= ' ' . componentAppServerIcon($inst);
                            $label .= ' ' . componentProductHtmlLabel($inst);
                            echo componentProductOpenLink($inst, $label);
                            ?>
                        </div>
                        <div class="instance-card__meta">
                            <?= componentDownloadIcon($inst); ?>
                            <?= componentProductVersion($inst); ?>
                        </div>
                    </div>
                    <div class="instance-card__actions-top">
                        <?= componentEditNoteIcon($inst) ?>
                    </div>
                </div>
                <div class="instance-card__details">
                    <?= componentDatabaseIcon($inst) ?>
                    <div class="instance-card__ages">
                        <span class="<?= $inst->ARTIFACT_AGE_CLASS ?>" title="Time since artifact was built"><i class="fas fa-calendar-alt me-1"></i>built <?= $inst->ARTIFACT_AGE_STRING ?></span>
                        <span title="Time since instance was deployed"><i class="fas fa-clock me-1"></i>deployed <?= $inst->DEPLOYMENT_AGE_STRING ?></span>
                    </div>
                </div>
                <div class="instance-card__actions">
                    <?= componentDeploymentActions($inst); ?>
                </div>
            </div>
            <?php endforeach; endforeach; ?>
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
            <?php foreach ($descriptor_arrays as $inst): ?>
            <div class="instance-card">
                <div class="instance-card__top">
                    <div class="instance-card__status">
                        <?php if ($inst->DEPLOYMENT_STATUS == "Up"): ?>
                            <span class="pulse-dot on" title="Running" aria-label="Status: Up"></span>
                        <?php else: ?>
                            <span class="pulse-dot off" title="Stopped" aria-label="Status: Down"></span>
                        <?php endif; ?>
                    </div>
                    <div class="instance-card__info">
                        <div class="instance-card__name">
                            <?= componentProductInfoIcon($inst); ?>
                            <?php
                            $label = componentVisibilityIcon($inst, empty($inst->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'success');
                            $label .= ' ' . componentAppServerIcon($inst);
                            $label .= ' ' . componentProductHtmlLabel($inst);
                            echo componentProductOpenLink($inst, $label);
                            ?>
                        </div>
                        <div class="instance-card__meta">
                            <?= componentDownloadIcon($inst); ?>
                            <?= componentProductVersion($inst); ?>
                        </div>
                    </div>
                    <div class="instance-card__actions-top">
                        <?= componentSpecificationIcon($inst) ?>
                        <?php if (!isInstanceFeatureBranch($inst)) echo componentEditNoteIcon($inst); ?>
                    </div>
                </div>
                <div class="instance-card__details">
                    <?= componentDatabaseIcon($inst) ?>
                    <?php if (isInstanceFeatureBranch($inst)): ?>
                        <span class="instance-card__feature">
                            <?= componentFBScmLabel($inst) ?>
                        </span>
                    <?php endif; ?>
                    <div class="instance-card__ages">
                        <span class="<?= $inst->ARTIFACT_AGE_CLASS ?>" title="Time since artifact was built"><i class="fas fa-calendar-alt me-1"></i>built <?= $inst->ARTIFACT_AGE_STRING ?></span>
                        <span title="Time since instance was deployed"><i class="fas fa-clock me-1"></i>deployed <?= $inst->DEPLOYMENT_AGE_STRING ?></span>
                    </div>
                </div>
                <?php if (isInstanceFeatureBranch($inst)): ?>
                <div class="instance-card__badges">
                    <?= componentFBStatusLabel($inst) ?>
                    <?= componentFBIssueLabel($inst) ?>
                    <?= componentFBEditIcon($inst) ?>
                    <?= componentFBDeployIcon($inst) ?>
                </div>
                <?php endif; ?>
                <div class="instance-card__badges">
                    <?= componentUpgradeEligibility($inst); ?>
                    <?= componentPatchInstallation($inst); ?>
                    <?= componentCertbotEnabled($inst); ?>
                    <?= componentDevModeEnabled($inst); ?>
                    <?= componentStagingModeEnabled($inst); ?>
                    <?= componentDebugModeEnabled($inst); ?>
                    <?= componentAddonsTags($inst); ?>
                    <?= componentLabels($inst); ?>
                </div>
                <div class="instance-card__actions">
                    <?= componentDeploymentActions($inst); ?>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
    </div>
    <?php endforeach; ?>

    <!-- Info cards -->
    <div class="row g-3 mt-3">
        <div class="col-md-4">
            <div class="card h-100">
                <div class="card-header">
                    <i class="fas fa-plug me-2"></i>JMX Access
                </div>
                <div class="card-body">
                    <p class="card-text opacity-60">Each instance can be accessed using JMX with the URL linked to the monitoring icon. Credentials are available on CI Build.</p>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <div class="card h-100">
                <div class="card-header">
                    <i class="fas fa-key me-2"></i>Keycloak Access
                </div>
                <div class="card-body">
                    <p class="card-text opacity-60">Each deployed Keycloak can be accessed using the Keycloak icon:</p>
                    <div class="mt-2 p-3 rounded code-bg">
                        <code class="d-block">root / password</code>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <div class="card h-100">
                <div class="card-header">
                    <i class="fas fa-address-book me-2"></i>LDAP Access
                </div>
                <div class="card-body">
                    <p class="card-text opacity-60">Each LDAP deployment can be accessed with:</p>
                    <div class="mt-2 p-3 rounded code-bg">
                        <code class="d-block">Base DN: dc=exoplatform,dc=com</code>
                        <code class="d-block mt-1">User DN: cn=admin,dc=exoplatform,dc=com</code>
                        <code class="d-block mt-1">password: exo</code>
                    </div>
                </div>
            </div>
        </div>
    </div>

<!-- /container -->
</div>
</div>
<?php pageFooter(); ?>
</body>
</html>

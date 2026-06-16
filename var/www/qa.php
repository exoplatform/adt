<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("QA environments"); ?>
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
<div class="page-header">
    <h1 class="page-header__title">QA Environments</h1>
    <p class="page-header__subtitle">Instances deployed for <strong>eXo QA Team members</strong> usage only</p>
</div>
<div class="instances-search">
    <i class="fas fa-search instances-search__icon"></i>
    <input type="text" id="instanceSearch" class="instances-search__input" placeholder="Filter instances...">
</div>
<?php
$qa_instances=getGlobalQAUserInstances();
if (isDeploymentInCategoryArray($qa_instances)) {
?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-tag"></i> QA User Environments
    </div>
    <div class="instance-grid">
  <?php
  foreach ($qa_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $inst) {
        ?>
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
                        <?= componentProductOpenLink($inst); ?>
                    </div>
                    <div class="instance-card__meta">
                        <?= componentProductVersion($inst); ?>
                        <?= componentDownloadIcon($inst); ?>
                    </div>
                </div>
                <div class="instance-card__actions-top">
                    <?php
                    if(isset($inst->DEPLOYMENT_BUILD_URL)) {
                        echo '<a href="'.$inst->DEPLOYMENT_BUILD_URL.'/build?delay=0sec" target="_blank" rel="tooltip" title="Restart or reset data"><i class="fas fa-sync-alt"></i></a>';
                    } else {
                        echo '<a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-'.$inst->BASE_VERSION.'-'.$inst->INSTANCE_ID.'-acc/build?delay=0sec" target="_blank" rel="tooltip" title="Restart or reset data"><i class="fas fa-sync-alt"></i></a>';
                    }
                    ?>
                </div>
            </div>
            <div class="instance-card__details">
                <?= componentDatabaseIcon($inst) ?>
                <div class="instance-card__ages">
                    <span><i class="fas fa-clock me-1"></i>deployed <?= $inst->DEPLOYMENT_AGE_STRING ?></span>
                </div>
            </div>
            <div class="instance-card__badges">
                <?= componentUpgradeEligibility($inst); ?>
                <?= componentCertbotEnabled($inst); ?>
                <?= componentDevModeEnabled($inst); ?>
                <?= componentStagingModeEnabled($inst); ?>
                <?= componentDebugModeEnabled($inst); ?>
                <?= componentAddonsTags($inst); ?>
            </div>
            <div class="instance-card__actions">
                <?= componentDeploymentActions($inst) ?>
            </div>
        </div>
        <?php
    }
  }
  ?>
    </div>
  </div>
  <?php
} else {
  echo '<div class="alert alert-warning"><i class="fas fa-exclamation-triangle me-2"></i>Nothing yet ;-)</div>';
}
?>
  <div class="alert alert-warning mt-4">
    <i class="fas fa-robot me-2"></i>
    These instances are deployed for <strong>Automatic QA Tests</strong> usage only (<strong>NOT FOR MANUAL TESTS</strong>).
  </div>
<?php
$qa_auto_instances=getGlobalQAAutoInstances();
if (isDeploymentInCategoryArray($qa_auto_instances)) {
?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-robot"></i> Automatic QA Environments
    </div>
    <div class="instance-grid">
  <?php
  foreach ($qa_auto_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $inst) {
        ?>
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
                        <?= componentProductOpenLink($inst); ?>
                    </div>
                    <div class="instance-card__meta">
                        <?= componentProductVersion($inst); ?>
                        <?= componentDownloadIcon($inst); ?>
                    </div>
                </div>
                <div class="instance-card__actions-top">
                    <?php
                    if(isset($inst->DEPLOYMENT_BUILD_URL)) {
                        echo '<a href="'.$inst->DEPLOYMENT_BUILD_URL.'/build?delay=0sec" target="_blank" rel="tooltip" title="Restart or reset data"><i class="fas fa-sync-alt"></i></a>';
                    } else {
                        echo '<a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-'.$inst->BASE_VERSION.'-'.$inst->INSTANCE_ID.'-acc/build?delay=0sec" target="_blank" rel="tooltip" title="Restart or reset data"><i class="fas fa-sync-alt"></i></a>';
                    }
                    ?>
                </div>
            </div>
            <div class="instance-card__details">
                <?= componentDatabaseIcon($inst) ?>
                <div class="instance-card__ages">
                    <span><i class="fas fa-clock me-1"></i>deployed <?= $inst->DEPLOYMENT_AGE_STRING ?></span>
                </div>
            </div>
            <div class="instance-card__badges">
                <?= componentUpgradeEligibility($inst); ?>
                <?= componentPatchInstallation($inst); ?>
                <?= componentCertbotEnabled($inst); ?>
                <?= componentDevModeEnabled($inst); ?>
                <?= componentStagingModeEnabled($inst); ?>
                <?= componentDebugModeEnabled($inst); ?>
                <?= componentAddonsTags($inst); ?>
            </div>
            <div class="instance-card__actions">
                <?= componentDeploymentActions($inst) ?>
            </div>
        </div>
        <?php
    }
  }
  ?>
    </div>
  </div>
  <?php
} else {
  echo '<div class="alert alert-warning"><i class="fas fa-exclamation-triangle me-2"></i>Nothing yet ;-)</div>';
}
?>
  
  <!-- Info cards with synchronized design -->
  <div class="row mt-4">
    <div class="col-md-4">
      <div class="card h-100">
        <div class="card-header">
          <i class="fas fa-plug me-2"></i>JMX Access
        </div>
        <div class="card-body">
          <p class="card-text">Each instance can be accessed using JMX with the URL linked to the monitoring icon. Credentials can be found on CI Build.</p>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card h-100">
        <div class="card-header">
          <i class="fas fa-key me-2"></i>Keycloak Access
        </div>
        <div class="card-body">
          <p class="card-text">Each deployed Keycloak can be accessed using the Keycloak icon with credentials:</p>
          <div class="mt-2 p-2 rounded code-bg">
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
          <p class="card-text">Each LDAP deployed can be accessed with:</p>
          <div class="mt-2 p-2 rounded code-bg">
            <code class="d-block">Base DN: dc=exoplatform,dc=com</code>
            <code class="d-block mt-1">User DN: cn=admin,dc=exoplatform,dc=com</code>
            <code class="d-block mt-1">password: exo</code>
          </div>
        </div>
      </div>
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
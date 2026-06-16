<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("Customer projects"); ?>
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
    <h1 class="page-header__title">Customer Projects</h1>
    <p class="page-header__subtitle">Instances deployed for <strong>Customer Projects</strong> development team usage only</p>
</div>
<div class="instances-search">
    <i class="fas fa-search instances-search__icon"></i>
    <input type="text" id="instanceSearch" class="instances-search__input" placeholder="Filter instances...">
</div>
<?php
$cp_instances=getGlobalCPInstances();
if (isDeploymentInCategoryArray($cp_instances)) {
?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-briefcase"></i> Customer Projects Integration
    </div>
    <div class="instance-grid">
  <?php
  foreach ($cp_instances as $plf_branch => $descriptor_arrays) {
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
                        echo '<a href="https://ci.exoplatform.org/job/platform-enterprise-'.$inst->PLF_BRANCH.'-'.$inst->INSTANCE_ID.'-deploy-acc/build?delay=0sec" target="_blank" rel="tooltip" title="Restart or reset data"><i class="fas fa-sync-alt"></i></a>';
                    }
                    ?>
                    <?= componentEditNoteIcon($inst) ?>
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
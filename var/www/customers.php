<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader("Customer projects"); ?>
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
<div class="alert alert-info">
    <i class="fas fa-users me-2"></i>
    These instances are deployed for <strong>Customer Projects</strong> development Team deployment usage only.
</div>
<?php
// List all Customer Project environments
$cp_instances=getGlobalCPInstances();
if (isDeploymentInCategoryArray($cp_instances)) {
  ?>
  <div class="table-responsive">
  <table class="table table-hover">
    <thead>
    <tr>
      <th class="col-center">Status</th>
      <th class="col-center">Name</th>
      <th class="col-center">Version</th>
      <th class="col-center" colspan="3">Characteristics</th>
    </tr>
    </thead>
    <tbody>
      <tr>
        <td colspan="15" class="category-row"><i class="fas fa-briefcase me-2"></i><?= "Customer Projects integration environments"; ?></td>
      </tr>
<?php
  foreach ($cp_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $descriptor_array) {
        ?>
        <tr>
            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
            <td>
              <div class="d-flex align-items-center">
                <div>
                  <?= componentProductOpenLink($descriptor_array); ?>
                  <br/><?= componentUpgradeEligibility($descriptor_array); ?>
                  <?= componentPatchInstallation($descriptor_array); ?>
                  <?= componentCertbotEnabled($descriptor_array); ?>
                  <?= componentDevModeEnabled($descriptor_array); ?>
                  <?= componentStagingModeEnabled($descriptor_array); ?>
                  <?= componentDebugModeEnabled($descriptor_array); ?>
                  <?= componentAddonsTags($descriptor_array); ?>
                </div>
                <span class="ms-auto">
                <?php 
                if(isset($descriptor_array->DEPLOYMENT_BUILD_URL)) {
                  ?>
                  <a href="<?=$descriptor_array->DEPLOYMENT_BUILD_URL ?>/build?delay=0sec" target="_blank" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Restart your instance or reset your instance's data">
                    <i class="fas fa-sync-alt"></i>
                  </a>
                  <?php 
                } else { 
                  ?>
                  <a href="https://ci.exoplatform.org/job/platform-enterprise-<?= $descriptor_array->PLF_BRANCH ?>-<?= $descriptor_array->INSTANCE_ID ?>-deploy-acc/build?delay=0sec" target="_blank" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Restart your instance or reset your instance's data">
                    <i class="fas fa-sync-alt"></i>
                  </a>
                  <?php 
                }
                ?>
                <?= componentEditNoteIcon($descriptor_array) ?>
                </span>
              </div>
            </td>
            <td class="col-center">
                <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
                <?= componentProductVersion($descriptor_array); ?>&nbsp;
                <?= componentDownloadIcon($descriptor_array); ?>
            </td>
            <td class="col-right"><i class="fas fa-clock me-1"></i>deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
            <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
            <td class="col-left"><?= componentDeploymentActions($descriptor_array) ?></td>
        </tr>
    <?php
    }
  }
}
?>
    </tbody>
</table>
</div>

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
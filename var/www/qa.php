<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader("QA environments"); ?>
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
    <i class="fas fa-flask me-2"></i>
    These instances are deployed for <strong>eXo QA Team members</strong> usage only.
</div>
<?php
$qa_instances=getGlobalQAUserInstances();
if (isDeploymentInCategoryArray($qa_instances)) {
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
  <?php
  foreach ($qa_instances as $plf_branch => $descriptor_arrays) {
    ?>
    <tr>
        <td colspan="15" class="category-row"><i class="fas fa-tag me-2"></i><?= "Platform " . $plf_branch . " QA environments"; ?></td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
        ?>
        <tr>
            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
            <td>
                <div class="d-flex align-items-center">
                    <div>
                        <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
                        <?= componentProductOpenLink($descriptor_array); ?>
                        <br/><?= componentUpgradeEligibility($descriptor_array); ?>
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
                      <?php 
                    } else { 
                      ?>
                      <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-<?= $descriptor_array->BASE_VERSION ?>-<?= $descriptor_array->INSTANCE_ID ?>-acc/build?delay=0sec" target="_blank" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Restart your instance or reset your instance's data">
                      <?php 
                    }
                    ?>
                      <i class="fas fa-sync-alt"></i>
                    </a>
                    </span>
                </div>
            </td>
            <td class="col-center">
                <?= componentDownloadIcon($descriptor_array); ?>&nbsp;
                <?= componentProductVersion($descriptor_array); ?>
            </td>
            <td class="col-right"><i class="fas fa-clock me-1"></i>deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
            <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
            <td class="col-left"><?= componentDeploymentActions($descriptor_array) ?></td>
        </tr>
        <?php
    }
  }
  ?>
    </tbody>
  </table>
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
  <?php
  foreach ($qa_auto_instances as $plf_branch => $descriptor_arrays) {
    ?>
    <tr>
        <td colspan="15" class="category-row"><i class="fas fa-robot me-2"></i><?= "Platform " . $plf_branch . " Automatic QA environments"; ?></td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
        ?>
        <tr>
            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
            <td>
                <div class="d-flex align-items-center">
                    <div>
                        <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
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
                      <?php 
                    } else { 
                      ?>
                      <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-<?= $descriptor_array->BASE_VERSION ?>-<?= $descriptor_array->INSTANCE_ID ?>-acc/build?delay=0sec" target="_blank" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Restart your instance or reset your instance's data">
                      <?php 
                    }
                    ?>
                      <i class="fas fa-sync-alt"></i>
                    </a>
                    </span>
                </div>
            </td>
            <td class="col-center">
                <?= componentDownloadIcon($descriptor_array); ?>&nbsp;
                <?= componentProductVersion($descriptor_array); ?>
            </td>
            <td class="col-right"><i class="fas fa-clock me-1"></i>deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
            <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
            <td class="col-left"><?= componentDeploymentActions($descriptor_array) ?></td>
        </tr>
        <?php
    }
  }
  ?>
    </tbody>
  </table>
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
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
<div class="row-fluid">
<div class="span12">
<p>These instances are deployed for <strong>Customer Projects</strong> development Team deployment usage only.</p>
<?php
// List all Customer Project environments
$cp_instances=getGlobalCPInstances();
if (isDeploymentInCategoryArray($cp_instances)) {
  ?>
  <table class="table table-bordered table-hover">
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
        <td colspan="15" class="category-row"><i class="icon-briefcase"></i> - <?= "Customer Projects integration environments"; ?></td>
      </tr>
<?php
  foreach ($cp_instances as $plf_branch => $descriptor_arrays) {
    ?>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
        ?>
        <tr>
            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
            <td>
              <?= componentProductOpenLink($descriptor_array); ?>
              <br/><?= componentUpgradeEligibility($descriptor_array); ?>
              <?= componentPatchInstallation($descriptor_array); ?>
              <?= componentCertbotEnabled($descriptor_array); ?>
              <?= componentDevModeEnabled($descriptor_array); ?>
              <?= componentStagingModeEnabled($descriptor_array); ?>
              <?= componentDebugModeEnabled($descriptor_array); ?>
              <?= componentAddonsTags($descriptor_array); ?>
              <span class="pull-right">
              <?php 
                if(isset($descriptor_array->DEPLOYMENT_BUILD_URL)) {
                  ?>
                  <a href="<?=$descriptor_array->DEPLOYMENT_BUILD_URL ?>/build?delay=0sec" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's data">
                  <?php 
                } else { 
                  ?>
                  <a href="https://ci.exoplatform.org/job/platform-enterprise-<?= $descriptor_array->PLF_BRANCH ?>-<?= $descriptor_array->INSTANCE_ID ?>-deploy-acc/build?delay=0sec" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's data">
                  <?php 
                }
                ?>
              <?= componentEditNoteIcon($descriptor_array) ?>
              </span>
            </td>
            <td class="col-center">
                <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
                <?= componentProductVersion($descriptor_array); ?>&nbsp;
                <?= componentDownloadIcon($descriptor_array); ?>
            </td>
            <td class="col-right">deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
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
<p>Each instance can be accessed using JMX with the URL linked to the monitoring icon and its credentials can be found on CI Build.
</p>
<p>Each deployed Keycloak can be accessed using the Keycloak icon and these credentials :
    <strong><code>root</code></strong> / <strong><code>password</code></strong>
</p>
<p>Each Ldap deployed can be accessed using the URL linked to the ldap url icon and these parameters :
    <strong><code>Base DN:dc=exoplatform,dc=com</code></strong> / <strong><code>User DN:cn=admin,dc=exoplatform,dc=com</code></strong> / <strong><code>password:exo</code></strong>
</p>
</div>
</div>
</div>
<!-- /container -->
</div>
</div>
<?php pageFooter(); ?>
</body>
</html>

<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader("Sales environments"); ?>
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
<p>These instances are deployed for <strong>eXo Sales Team</strong> usage only.</p>
<?php
// List all Sales personal environments
$sales_user_instances=getGlobalSalesUserInstances();
if (isDeploymentInCategoryArray($sales_user_instances)) {
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
        <td colspan="15" class="category-row"><i class="icon-user"></i> - <?= "Platform personal environments for Sales people"; ?></td>
    </tr>
  <?php
  foreach ($sales_user_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $descriptor_array) {
        ?>
        <tr>
            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
            <td>
              <?= componentProductOpenLink($descriptor_array, "", true); ?>
              <span class="pull-right">
                <?php 
                if(isset($descriptor_array->DEPLOYMENT_BUILD_URL)) {
                  ?>
                  <a href="<?=$descriptor_array->DEPLOYMENT_BUILD_URL ?>/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <?php 
                } else { 
                  ?>
                  <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-trial-<?= $descriptor_array->BASE_VERSION ?>-<?= $descriptor_array->INSTANCE_ID ?>-deploy-acc/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <?php 
                }
                ?>
                  <i class="icon-refresh"></i>&nbsp;(restart or reset data)&nbsp;
                </a> - 
                <?= componentEditNoteIcon($descriptor_array) ?>
              </span>
              <br/><?= componentAddonsTags($descriptor_array); ?>
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
    <p>These instances are deployed for <strong>eXo Demo</strong> purpose usage only.</p>
<?php
// List all Sales lead demo environments
$sales_demo_instances=getGlobalSalesDemoInstances();
if (isDeploymentInCategoryArray($sales_demo_instances)) {
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
      <td colspan="15" class="category-row"><i class="icon-briefcase"></i> - <?= "Platform demo environments for Leads"; ?></td>
    </tr>
  <?php
  foreach ($sales_demo_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $descriptor_array) {
    ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
        <td>
          <?= componentProductOpenLink($descriptor_array, "", true); ?>
          <span class="pull-right">
          <?php 
                if(isset($descriptor_array->DEPLOYMENT_BUILD_URL)) {
                  ?>
                  <a href="<?=$descriptor_array->DEPLOYMENT_BUILD_URL ?>/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <?php 
                } else { 
                  ?>
                  <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-trial-<?= $descriptor_array->BASE_VERSION ?>-<?= $descriptor_array->INSTANCE_ID ?>-deploy-acc/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <?php 
                }
                ?>
              <i class="icon-refresh"></i>&nbsp;(restart or reset data)&nbsp;
            </a> - 
            <?= componentEditNoteIcon($descriptor_array) ?>
          </span>
          <br/><?= componentAddonsTags($descriptor_array); ?>
        </td>
        <td class="col-center">
          <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
          <?= componentProductVersion($descriptor_array); ?>&nbsp;
          <?= componentDownloadIcon($descriptor_array); ?>
        </td>
        <td class="col-right">deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
        <td class="col-left"><?= componentDeploymentActions($descriptor_array); ?></td>
      </tr>
    <?php
    }
  }
}
?>
    </tbody>
</table>
    <p>These instances are deployed for <strong>Evaluation by Leads</strong> purpose usage only.</p>
<?php
// List all Sales lead evaluation environments
$sales_eval_instances=getGlobalSalesEvalInstances();
if (isDeploymentInCategoryArray($sales_eval_instances)) {
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
      <td colspan="15" class="category-row"><i class="icon-briefcase"></i> - <?= "Platform evaluation environments for Leads"; ?></td>
    </tr>
  <?php
  foreach ($sales_eval_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $descriptor_array) {
    ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
        <td>
          <?= componentProductOpenLink($descriptor_array, "", true); ?>
          <span class="pull-right">
            <?= componentEditNoteIcon($descriptor_array) ?>
          </span>
          <br/><?= componentAddonsTags($descriptor_array); ?>
        </td>
        <td class="col-center">
          <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
          <?= componentProductVersion($descriptor_array); ?>&nbsp;
          <?= componentDownloadIcon($descriptor_array); ?>
        </td>
        <td class="col-right">deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
        <td class="col-left"><?= componentDeploymentActions($descriptor_array); ?></td>
      </tr>
    <?php
    }
  }
}
?>
    </tbody>
</table>

<!-- footer -->
<p>Each instance can be accessed using JMX with the URL linked to the monitoring icon and these credentials :
    <strong><code>acceptanceMonitor</code></strong> / <strong><code>monitorAcceptance!</code></strong>
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

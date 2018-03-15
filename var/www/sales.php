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
  <?php
  foreach ($sales_user_instances as $plf_branch => $descriptor_arrays) {
    ?>
    <tr>
        <td colspan="15" class="category-row"><i class="icon-user"></i> - <?= "Platform " . $plf_branch . " demo environments for Sales people"; ?></td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
        ?>
        <tr>
            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
            <td>
              <?= componentProductOpenLink($descriptor_array); ?>
              <br/><?= componentAddonsTags($descriptor_array); ?>
              <span class="pull-right">
                <a href="https://ci.exoplatform.org/job/platform-enterprise-trial-<?= $descriptor_array->PLF_BRANCH ?>-<?= $descriptor_array->INSTANCE_ID ?>-deploy-acc/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <i class="icon-refresh"></i>&nbsp;(restart or reset data)&nbsp;
                </a> - 
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
    <p>These instances are deployed for <strong>Lead demo / evaluation</strong> purpose usage only.</p>
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
  <?php
  foreach ($sales_demo_instances as $plf_branch => $descriptor_arrays) {
  ?>
    <tr>
      <td colspan="15" class="category-row"><i class="icon-briefcase"></i> - <?= "Platform " . $plf_branch . " demo / evaluation environments for Leads"; ?></td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
    ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
        <td>
          <?= componentProductOpenLink($descriptor_array); ?>
          <br/><?= componentAddonsTags($descriptor_array); ?>
          <span class="pull-right">
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
        <td class="col-left"><?= componentDeploymentActions($descriptor_array); ?></td>
      </tr>
    <?php
    }
  }
}
?>
    </tbody>
</table>
<p>Each instance can be accessed using JMX with the URL linked to the monitoring icon and these credentials :
    <strong><code>acceptanceMonitor</code></strong> / <strong><code>monitorAcceptance!</code></strong>
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

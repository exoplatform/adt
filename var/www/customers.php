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
              <span class="pull-right">
                <a href="https://ci.exoplatform.org/job/platform-enterprise-<?= $descriptor_array->PLF_BRANCH ?>-<?= $descriptor_array->INSTANCE_ID ?>-deploy-acc/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
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

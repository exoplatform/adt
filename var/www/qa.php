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
<div class="row-fluid">
<div class="span12">
<p>These instances are deployed <strong>eXo QA Team</strong> usage only.</p>
<?php
$qa_instance=getGlobalQAInstances();
if (is_array($qa_instance) && count($qa_instance)>0) {
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
  foreach ($qa_instance as $plf_branch => $descriptor_arrays) {
    ?>
    <tr>
        <td colspan="15" class="category-row"><?= "Platform " . $plf_branch . " QA environments"; ?></td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
        ?>
        <tr>
            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
            <td>
                <?= componentProductOpenLink($descriptor_array); ?>
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
  ?>
    </tbody>
  </table>
  <p>Each instance can be accessed using JMX with the URL linked to the monitoring icon and these credentials :
    <strong><code>acceptanceMonitor</code></strong> / <strong><code>monitorAcceptance!</code></strong>
  </p>
  <?php
} else {
  echo '<p>Nothing yet ;-)</p>';
}
?>

</div>
</div>
</div>
<!-- /container -->
</div>
</div>
<?php pageFooter(); ?>
</body>
</html>

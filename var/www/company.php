<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader("Company environments"); ?>
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
<ul>
  <li>eXo Website :
    <a href="https://www-dev.exoplatform.com/" target="_blank">(development) www-dev.exoplatform.com/</a>
    - <a href="https://www-preprod.exoplatform.com/" target="_blank">(pre-production) www-preprod.exoplatform.com/</a>
  </li>
  <li>eXo Blog :
    <a href="https://blog-dev.exoplatform.com/" target="_blank">(development) blog-dev.exoplatform.com/</a>
    - <a href="https://blog-preprod.exoplatform.com/" target="_blank">(pre-production) www-preprod.exoplatform.com/blog/</a>
  </li>
</ul>
<?php
$company_instances=getGlobalCompanyInstances();
if (is_array($company_instances) && count($company_instances)>0) {
  ?>
  <table class="table table-bordered table-hover">
    <thead>
    <tr>
      <th class="col-center">Status</th>
      <th class="col-center">Name</th>
      <th class="col-center">Version</th>
      <th class="col-center" colspan="4">Characteristics</th>
    </tr>
    </thead>
    <tbody>
  <?php
  foreach (getGlobalCompanyInstances() as $plf_branch => $descriptor_arrays) {
    ?>
    <tr>
      <td colspan="15" class="category-row"><?= "Company developments : " . $plf_branch; ?></td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
      ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
        <td>
          <?= componentProductInfoIcon($descriptor_array) ?>&nbsp;
          <?= componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'green'); ?>&nbsp;
          <?= componentProductOpenLink($descriptor_array, "", true) ?>
          <span class="pull-right">
            <?= componentEditNoteIcon($descriptor_array) ?>
          </span>

        </td>
        <td class="col-center">
          <?= componentDownloadIcon($descriptor_array); ?>
          &nbsp;
          <?= componentProductVersion($descriptor_array); ?>
        </td>
        <td class="col-right <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>">built <?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
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

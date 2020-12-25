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
<p>These instances are deployed for <strong>eXo QA Team members</strong> usage only.</p>
<?php
$qa_instances=getGlobalQAUserInstances();
if (isDeploymentInCategoryArray($qa_instances)) {
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
  foreach ($qa_instances as $plf_branch => $descriptor_arrays) {
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
                <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
                <?= componentProductOpenLink($descriptor_array); ?>
                <span class="pull-right">
                <?php 
                if(isset($descriptor_array->DEPLOYMENT_BUILD_URL)) {
                  ?>
                  <a href="<?=$descriptor_array->DEPLOYMENT_BUILD_URL ?>/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <?php 
                } else { 
                  ?>
                  <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-<?= $descriptor_array->BASE_VERSION ?>-<?= $descriptor_array->INSTANCE_ID ?>-acc/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <?php 
                }
                ?>
                  <i class="icon-refresh"></i>
                </a>
                </span>
                <br/><?= componentUpgradeEligibility($descriptor_array); ?>
                <?= componentAddonsTags($descriptor_array); ?>
            </td>
            <td class="col-center">
                <?= componentDownloadIcon($descriptor_array); ?>&nbsp;
                <?= componentProductVersion($descriptor_array); ?>
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
  <?php
} else {
  echo '<p>Nothing yet ;-)</p>';
}
?>
  <p>These instances are deployed for <strong>Automatic QA Tests</strong> usage only (<strong>NOT FOR MANUAL TESTS</strong>).</p>
<?php
$qa_auto_instances=getGlobalQAAutoInstances();
if (isDeploymentInCategoryArray($qa_auto_instances)) {
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
  foreach ($qa_auto_instances as $plf_branch => $descriptor_arrays) {
    ?>
    <tr>
        <td colspan="15" class="category-row"><?= "Platform " . $plf_branch . " Automatic QA environments"; ?></td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
        ?>
        <tr>
            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
            <td>
                <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
                <?= componentProductOpenLink($descriptor_array); ?>
                <span class="pull-right">
                <?php 
                if(isset($descriptor_array->DEPLOYMENT_BUILD_URL)) {
                  ?>
                  <a href="<?=$descriptor_array->DEPLOYMENT_BUILD_URL ?>/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <?php 
                } else { 
                  ?>
                  <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-<?= $descriptor_array->BASE_VERSION ?>-<?= $descriptor_array->INSTANCE_ID ?>-acc/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's datas">
                  <?php 
                }
                ?>
                  <i class="icon-refresh"></i>
                </a>
                </span>
                <br/><?= componentUpgradeEligibility($descriptor_array); ?>
                <?= componentAddonsTags($descriptor_array); ?>
            </td>
            <td class="col-center">
                <?= componentDownloadIcon($descriptor_array); ?>&nbsp;
                <?= componentProductVersion($descriptor_array); ?>
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
  <?php
} else {
  echo '<p>Nothing yet ;-)</p>';
}
?>
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

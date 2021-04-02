<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
<?= pageHeader(); ?>
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
<p>These instances are deployed to be used for acceptance tests.</p>
<table class="table table-bordered table-hover">
<thead>
<tr>
    <th class="col-center">S</th>
    <th class="col-center">Name</th>
    <th class="col-center">Version</th>
    <th class="col-center">Database</th>
    <th class="col-center" colspan="4">Feature Branch</th>
    <th class="col-center">Built</th>
    <th class="col-center">Deployed</th>
    <th class="col-center">&nbsp;</th>
</tr>
</thead>
<tbody>
<tr>
  <td colspan="15" class="category-row"><i class="icon-globe"></i> - Translation deployments</td>
</tr>
<?php
$translation_instances = getGlobalTranslationInstances();
if (isDeploymentInCategoryArray($translation_instances)) {
  foreach ($translation_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $descriptor_array) {?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($descriptor_array) ?></td>
        <td>
          <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
          <?php
          $product_deployment_url_label=componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'green');
          $product_deployment_url_label.='&nbsp;'.componentAppServerIcon($descriptor_array);
          $product_deployment_url_label.='&nbsp;'.componentProductHtmlLabel($descriptor_array);
          print componentProductOpenLink($descriptor_array, $product_deployment_url_label);
          ?>
          <span class="pull-right">
          <?= componentEditNoteIcon($descriptor_array) ?>
      </span>
        </td>
        <td class="col-left"><?= componentDownloadIcon($descriptor_array); ?>&nbsp;<?= componentProductVersion($descriptor_array); ?></td>
        <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
        <td class="col-center" colspan="4"></td>
        <td class="col-right <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
        <td class="col-right"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-left"><?= componentDeploymentActions($descriptor_array); ?></td>
      </tr>
    <?php }
  }
}
?>
<!--<tr>
  <td colspan="15" class="category-row"><i class="icon-book"></i> - Documentation deployments</td>
</tr>-->
<?php
$doc_instances = getGlobalDocInstances();
if (isDeploymentInCategoryArray($doc_instances)) {
  foreach ($doc_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $descriptor_array) {?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($descriptor_array) ?></td>
        <td>
          <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
          <?php
          $product_deployment_url_label=componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'green');
          $product_deployment_url_label.='&nbsp;'.componentAppServerIcon($descriptor_array);
          $product_deployment_url_label.='&nbsp;'.componentProductHtmlLabel($descriptor_array);
          print componentProductOpenLink($descriptor_array, $product_deployment_url_label);
          ?>
          <span class="pull-right">
          <?= componentEditNoteIcon($descriptor_array) ?>
      </span>
        </td>
        <td class="col-left"><?= componentDownloadIcon($descriptor_array); ?>&nbsp;<?= componentProductVersion($descriptor_array); ?></td>
        <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
        <td class="col-center" colspan="4"></td>
        <td class="col-right <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
        <td class="col-right"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-left"><?= componentDeploymentActions($descriptor_array); ?></td>
      </tr>
    <?php }
  }
}
?>
<?php
$dev_instances = getGlobalDevInstances();
foreach ($dev_instances as $plf_branch => $descriptor_arrays) {
  ?>
  <tr>
    <td colspan="15" class="category-row"><?= buildTableTitleDev($plf_branch) ?></td>
  </tr>
  <?php foreach ($descriptor_arrays as $descriptor_array) { ?>
    <tr>
      <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
      <td>
        <?= componentProductInfoIcon($descriptor_array); ?>&nbsp;
        <?php
        $product_deployment_url_label=componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'green');
        $product_deployment_url_label.='&nbsp;'.componentAppServerIcon($descriptor_array);
        $product_deployment_url_label.='&nbsp;'.componentProductHtmlLabel($descriptor_array);
        print componentProductOpenLink($descriptor_array, $product_deployment_url_label);
        ?>
        <span class="pull-right">
          <?= componentSpecificationIcon($descriptor_array) ?>
          <?php
            // add edit note option icon if not a feature branch
            if (!isInstanceFeatureBranch($descriptor_array)) {
              print componentEditNoteIcon($descriptor_array);
            } else {
              if(isset($descriptor_array->DEPLOYMENT_BUILD_URL)) {
                ?>
                <a href="<?=$descriptor_array->DEPLOYMENT_BUILD_URL ?>/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's data">
                <?php 
              } else { 
                ?>
                <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-<?= $descriptor_array->BASE_VERSION ?>-<?= $descriptor_array->INSTANCE_ID ?>-acc/build" target="_blank" rel="tooltip" title="Restart your instance or reset your instance's data">
                <?php 
              }
            }
          ?>
        </span>
        <br/><?= componentUpgradeEligibility($descriptor_array); ?>
        <?= componentDevModeEnabled($descriptor_array); ?>
        <?= componentDebugModeEnabled($descriptor_array); ?>
        <?= componentAddonsTags($descriptor_array); ?>
        <br/><?= componentLabels($descriptor_array); ?>
      </td>
      <td class="col-left"><?= componentDownloadIcon($descriptor_array); ?>&nbsp;<?= componentProductVersion($descriptor_array); ?></td>
      <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
      <?php if (isInstanceFeatureBranch($descriptor_array)) { ?>
        <td class="col-center"><?= componentFBStatusLabel($descriptor_array) ?></td>
        <td class="col-center"><?= componentFBScmLabel($descriptor_array) ?></td>
        <td class="col-center"><?= componentFBIssueLabel($descriptor_array) ?></td>
        <td class="col-center"><?= componentFBEditIcon($descriptor_array) ?></td>
      <?php } else { ?>
        <td class="col-center" colspan="4"></td>
      <?php } ?>
      <td class="col-right <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
      <td class="col-right"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
      <td class="col-left"><?= componentDeploymentActions($descriptor_array); ?></td>
    </tr>
  <?php
  }
}
?>
</tbody>
</table>
<p>
  Each instance can be accessed using JMX with the URL linked to the monitoring icon and these credentials :
  <strong><code>acceptanceMonitor</code></strong> / <strong><code>monitorAcceptance!</code></strong>
</p>
<p>Each deployed Keycloak can be accessed using the Keycloak icon and these credentials :
  <strong><code>root</code></strong> / <strong><code>password</code></strong>
</p>
<p>Each deployed CloudBeaver can be accessed using the CloudBeaver icon and these credentials :
  <strong><code>acceptance</code></strong> / <strong><code>acceptance@123!</code></strong>
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

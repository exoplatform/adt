<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("QA environments"); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
<div id="main" role="main">
<div class="container-fluid">
<div class="row">
<div class="col-12">
<div class="page-header">
    <h1 class="page-header__title">QA Environments</h1>
    <p class="page-header__subtitle">Instances deployed for <strong>eXo QA Team members</strong> usage only</p>
</div>
<div class="instances-search">
    <i class="fas fa-search instances-search__icon"></i>
    <input type="text" id="instanceSearch" class="instances-search__input" placeholder="Filter instances...">
</div>
<?php
$qa_instances=getGlobalQAUserInstances();
if (isDeploymentInCategoryArray($qa_instances)) {
?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-tag"></i> QA User Environments
    </div>
    <div class="instance-grid">
  <?php
  foreach ($qa_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $inst) {
      echo renderInstanceCard($inst, [
        'actions_top' => componentBuildRestartLink($inst, 'https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-'.$inst->BASE_VERSION.'-'.$inst->INSTANCE_ID.'-acc/build?delay=0sec'),
        'badges' => ['upgrade', 'certbot', 'dev', 'staging', 'debug', 'addons'],
      ]);
    }
  }
  ?>
    </div>
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
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-robot"></i> Automatic QA Environments
    </div>
    <div class="instance-grid">
  <?php
  foreach ($qa_auto_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $inst) {
      echo renderInstanceCard($inst, [
        'actions_top' => componentBuildRestartLink($inst, 'https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-'.$inst->BASE_VERSION.'-'.$inst->INSTANCE_ID.'-acc/build?delay=0sec'),
        'badges' => ['upgrade', 'patch', 'certbot', 'dev', 'staging', 'debug', 'addons'],
      ]);
    }
  }
  ?>
    </div>
  </div>
  <?php
} else {
  echo '<div class="alert alert-warning"><i class="fas fa-exclamation-triangle me-2"></i>Nothing yet ;-)</div>';
}
?>

  <!-- Info cards with synchronized design -->
  <?= componentAccessInfoCards(); ?>

</div>
</div>
</div>
<!-- /container -->
</div>
</div>
<?php pageFooter(); ?>
</body>
</html>
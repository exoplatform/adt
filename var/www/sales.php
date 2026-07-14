<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("Sales environments"); ?>
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
    <h1 class="page-header__title">Sales Environments</h1>
    <p class="page-header__subtitle">Instances deployed for <strong>eXo Sales Team</strong> usage only</p>
</div>
<div class="instances-search">
    <i class="fas fa-search instances-search__icon"></i>
    <input type="text" id="instanceSearch" class="instances-search__input" placeholder="Filter instances...">
</div>
<?php
$sales_user_instances=getGlobalSalesUserInstances();
if (isDeploymentInCategoryArray($sales_user_instances)) {
?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-user"></i> Personal Sales Environments
    </div>
    <div class="instance-grid">
  <?php
  foreach ($sales_user_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $inst) {
      echo renderInstanceCard($inst, [
        'enforce_ssl' => true,
        'actions_top' => componentBuildRestartLink($inst, 'https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-trial-'.$inst->BASE_VERSION.'-'.$inst->INSTANCE_ID.'-deploy-acc/build?delay=0sec')
          . componentEditNoteIcon($inst),
        'badges' => ['upgrade', 'patch', 'certbot', 'dev', 'staging', 'debug', 'addons'],
      ]);
    }
  }
  ?>
    </div>
  </div>
  <?php
}
?>

  <div class="alert alert-info">
    <i class="fas fa-chart-pie me-2"></i>
    These instances are deployed for <strong>eXo Demo</strong> purpose usage only.
  </div>
<?php
$sales_demo_instances=getGlobalSalesDemoInstances();
if (isDeploymentInCategoryArray($sales_demo_instances)) {
?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-briefcase"></i> Demo Environments for Leads
    </div>
    <div class="instance-grid">
  <?php
  foreach ($sales_demo_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $inst) {
      echo renderInstanceCard($inst, [
        'enforce_ssl' => true,
        'actions_top' => componentBuildRestartLink($inst, 'https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-trial-'.$inst->BASE_VERSION.'-'.$inst->INSTANCE_ID.'-deploy-acc/build?delay=0sec')
          . componentEditNoteIcon($inst),
        'badges' => ['upgrade', 'patch', 'dev', 'staging', 'debug', 'addons'],
      ]);
    }
  }
  ?>
    </div>
  </div>
  <?php
}
?>

  <div class="alert alert-info">
    <i class="fas fa-chart-bar me-2"></i>
    These instances are deployed for <strong>Evaluation by Leads</strong> purpose usage only.
  </div>
<?php
$sales_eval_instances=getGlobalSalesEvalInstances();
if (isDeploymentInCategoryArray($sales_eval_instances)) {
?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-chart-line"></i> Evaluation Environments for Leads
    </div>
    <div class="instance-grid">
  <?php
  foreach ($sales_eval_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $inst) {
      echo renderInstanceCard($inst, [
        'enforce_ssl' => true,
        'actions_top' => componentEditNoteIcon($inst),
        'badges' => ['upgrade', 'patch', 'dev', 'staging', 'debug', 'addons'],
      ]);
    }
  }
  ?>
    </div>
  </div>
  <?php
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
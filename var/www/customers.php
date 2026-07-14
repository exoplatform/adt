<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("Customer projects"); ?>
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
    <h1 class="page-header__title">Customer Projects</h1>
    <p class="page-header__subtitle">Instances deployed for <strong>Customer Projects</strong> development team usage only</p>
</div>
<div class="instances-search">
    <i class="fas fa-search instances-search__icon"></i>
    <input type="text" id="instanceSearch" class="instances-search__input" placeholder="Filter instances...">
</div>
<?php
$cp_instances=getGlobalCPInstances();
if (isDeploymentInCategoryArray($cp_instances)) {
?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-briefcase"></i> Customer Projects Integration
    </div>
    <div class="instance-grid">
  <?php
  foreach ($cp_instances as $plf_branch => $descriptor_arrays) {
    foreach ($descriptor_arrays as $inst) {
      echo renderInstanceCard($inst, [
        'actions_top' => componentBuildRestartLink($inst, 'https://ci.exoplatform.org/job/platform-enterprise-'.$inst->PLF_BRANCH.'-'.$inst->INSTANCE_ID.'-deploy-acc/build?delay=0sec')
          . componentEditNoteIcon($inst),
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
<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("Company environments"); ?>
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
    <h1 class="page-header__title">Company</h1>
    <p class="page-header__subtitle">Internal company environments and deployments</p>
</div>

<!-- Company links -->
<ul class="list-unstyled company-links-list p-3 rounded">
  <li class="mb-2">
    <i class="fas fa-globe me-2" style="color:var(--accent)"></i>eXo Website :
    <a href="https://www-dev.exoplatform.com/" target="_blank" class="badge text-decoration-none" style="background:var(--success);color:#000">dev</a>
    <span class="mx-1">·</span>
    <a href="https://www-preprod.exoplatform.com/" target="_blank" class="badge text-decoration-none" style="background:var(--warning);color:#000">preprod</a>
  </li>
  <li class="mb-2">
    <i class="fas fa-users me-2" style="color:var(--accent)"></i>eXo Tribe :
    <a href="https://community-dev.exoplatform.com/" target="_blank" class="badge text-decoration-none" style="background:var(--success);color:#000">dev</a>
    <span class="mx-1">·</span>
    <a href="https://community-preprod.exoplatform.com/" target="_blank" class="badge text-decoration-none" style="background:var(--warning);color:#000">preprod</a>
  </li>
  <li class="mb-2">
    <i class="fas fa-blog me-2" style="color:var(--accent)"></i>eXo Blog :
    <a href="https://blog-dev.exoplatform.com/" target="_blank" class="badge text-decoration-none" style="background:var(--success);color:#000">dev</a>
    <span class="mx-1">·</span>
    <a href="https://blog-preprod.exoplatform.com/blog/" target="_blank" class="badge text-decoration-none" style="background:var(--warning);color:#000">preprod</a>
  </li>
</ul>

<div class="instances-search">
    <i class="fas fa-search instances-search__icon"></i>
    <input type="text" id="instanceSearch" class="instances-search__input" placeholder="Filter instances...">
</div>
<?php
$company_instances=getGlobalCompanyInstances();
if (isDeploymentInCategoryArray($company_instances)) {
  foreach ($company_instances as $plf_branch => $descriptor_arrays) {
  ?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-code-branch"></i> Company developments: <?= htmlspecialchars($plf_branch) ?>
    </div>
    <div class="instance-grid">
    <?php
    foreach ($descriptor_arrays as $inst) {
      echo renderInstanceCard($inst, [
          'visibility_icon' => empty($inst->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'success',
          'enforce_ssl' => true,
          'actions_top' => componentEditNoteIcon($inst),
          'show_built_age' => true,
          'badges' => ['upgrade', 'patch', 'certbot', 'dev', 'staging', 'debug'],
          'badges_addon_style' => false,
      ]);
    }
    ?>
    </div>
  </div>
  <?php
  }
} else {
  echo '<div class="alert alert-warning"><i class="fas fa-exclamation-triangle me-2"></i>Nothing yet ;-)</div>';
}
?>
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
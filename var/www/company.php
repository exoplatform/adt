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
  foreach (getGlobalCompanyInstances() as $plf_branch => $descriptor_arrays) {
  ?>
  <div class="instances-section">
    <div class="instances-section__header">
        <i class="fas fa-code-branch"></i> Company developments: <?= $plf_branch ?>
    </div>
    <div class="instance-grid">
    <?php
    foreach ($descriptor_arrays as $inst) {
      ?>
      <div class="instance-card">
          <div class="instance-card__top">
              <div class="instance-card__status">
                  <?php if ($inst->DEPLOYMENT_STATUS == "Up"): ?>
                      <span class="pulse-dot on" title="Running" aria-label="Status: Up"></span>
                  <?php else: ?>
                      <span class="pulse-dot off" title="Stopped" aria-label="Status: Down"></span>
                  <?php endif; ?>
              </div>
              <div class="instance-card__info">
                  <div class="instance-card__name">
                      <?= componentProductInfoIcon($inst); ?>
                      <?= componentVisibilityIcon($inst, empty($inst->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'success'); ?>
                      <?= componentProductOpenLink($inst, "", true) ?>
                  </div>
                  <div class="instance-card__meta">
                      <?= componentProductVersion($inst); ?>
                      <?= componentDownloadIcon($inst); ?>
                  </div>
              </div>
              <div class="instance-card__actions-top">
                  <?= componentEditNoteIcon($inst) ?>
              </div>
          </div>
          <div class="instance-card__details">
              <?= componentDatabaseIcon($inst) ?>
              <div class="instance-card__ages">
                  <span class="<?= $inst->ARTIFACT_AGE_CLASS ?>" title="Time since artifact was built"><i class="fas fa-calendar-alt me-1"></i>built <?= $inst->ARTIFACT_AGE_STRING ?></span>
                  <span title="Time since instance was deployed"><i class="fas fa-clock me-1"></i>deployed <?= $inst->DEPLOYMENT_AGE_STRING ?></span>
              </div>
          </div>
          <div class="instance-card__badges">
              <?= componentUpgradeEligibility($inst, false); ?>
              <?= componentPatchInstallation($inst, false); ?>
              <?= componentCertbotEnabled($inst, false); ?>
              <?= componentDevModeEnabled($inst, false); ?>
              <?= componentStagingModeEnabled($inst, false); ?>
              <?= componentDebugModeEnabled($inst, false); ?>
          </div>
          <div class="instance-card__actions">
              <?= componentDeploymentActions($inst) ?>
          </div>
      </div>
      <?php
    }
    ?>
    </div>
  </div>
  <?php
  }
}
?>
  <div class="row mt-4">
    <div class="col-md-4">
      <div class="card">
        <div class="card-header">
          <i class="fas fa-plug me-2"></i>JMX Access
        </div>
        <div class="card-body">
          <p class="mb-0">Each instance can be accessed using JMX with the URL linked to the monitoring icon. Credentials can be found on CI Build.</p>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card">
        <div class="card-header">
          <i class="fas fa-key me-2"></i>Keycloak Access
        </div>
        <div class="card-body">
          <p class="mb-0">Each deployed Keycloak can be accessed using the Keycloak icon with credentials:</p>
          <code class="d-block mt-2 p-2 rounded code-bg">root / password</code>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card">
        <div class="card-header">
          <i class="fas fa-address-book me-2"></i>LDAP Access
        </div>
        <div class="card-body">
          <p class="mb-0">Each LDAP deployed can be accessed with:</p>
          <code class="d-block mt-2 p-2 rounded code-bg">Base DN: dc=exoplatform,dc=com</code>
          <code class="d-block mt-1 p-2 rounded code-bg">User DN: cn=admin,dc=exoplatform,dc=com</code>
          <code class="d-block mt-1 p-2 rounded code-bg">password: exo</code>
        </div>
      </div>
    </div>
  </div>
</div>
</div>
<!-- /container -->
</div>
</div>
<?php pageFooter(); ?>
</body>
</html>
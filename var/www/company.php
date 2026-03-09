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
<div class="row">
<div class="col-12">
<div class="alert alert-info">
    <i class="fas fa-building me-2"></i>
    Company environments and deployments
</div>

<!-- Company links list with proper dark mode support via CSS class -->
<ul class="list-unstyled company-links-list p-3 rounded">
  <li class="mb-2">
    <i class="fas fa-globe text-primary me-2"></i>eXo Website :
    <a href="https://www-dev.exoplatform.com/" target="_blank" class="badge bg-info text-decoration-none">(development) www-dev.exoplatform.com</a>
    <span class="mx-1">-</span>
    <a href="https://www-preprod.exoplatform.com/" target="_blank" class="badge bg-warning text-decoration-none">(pre-production) www-preprod.exoplatform.com</a>
  </li>
  <li class="mb-2">
    <i class="fas fa-users text-primary me-2"></i>eXo Tribe :
    <a href="https://community-dev.exoplatform.com/" target="_blank" class="badge bg-info text-decoration-none">(development) community-dev.exoplatform.com</a>
    <span class="mx-1">-</span>
    <a href="https://community-preprod.exoplatform.com/" target="_blank" class="badge bg-warning text-decoration-none">(pre-production) community-preprod.exoplatform.com</a>
  </li>
  <li class="mb-2">
    <i class="fas fa-blog text-primary me-2"></i>eXo Blog :
    <a href="https://blog-dev.exoplatform.com/" target="_blank" class="badge bg-info text-decoration-none">(development) blog-dev.exoplatform.com/</a>
    <span class="mx-1">-</span>
    <a href="https://blog-preprod.exoplatform.com/blog/" target="_blank" class="badge bg-warning text-decoration-none">(pre-production) www-preprod.exoplatform.com/blog/</a>
  </li>
</ul>

<?php
$company_instances=getGlobalCompanyInstances();
if (isDeploymentInCategoryArray($company_instances)) {
  ?>
  <div class="table-responsive">
  <table class="table table-hover">
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
      <td colspan="15" class="category-row"><i class="fas fa-code-branch me-2"></i><?= "Company developments : " . $plf_branch; ?></td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
      ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
        <td>
          <div class="d-flex align-items-center">
            <?= componentProductInfoIcon($descriptor_array) ?>&nbsp;
            <div class="ms-1">
              <?= componentUpgradeEligibility($descriptor_array, false); ?>
              <?= componentPatchInstallation($descriptor_array, false); ?>
              <?= componentCertbotEnabled($descriptor_array, false); ?>
              <?= componentDevModeEnabled($descriptor_array, false); ?>
              <?= componentStagingModeEnabled($descriptor_array, false); ?>
              <?= componentDebugModeEnabled($descriptor_array, false); ?>
              <?= componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'success'); ?>&nbsp;
              <?= componentProductOpenLink($descriptor_array, "", true) ?>
            </div>
            <span class="ms-auto">
              <?= componentEditNoteIcon($descriptor_array) ?>
            </span>
          </div>
        </td>
        <td class="col-center">
          <?= componentDownloadIcon($descriptor_array); ?>
          &nbsp;
          <?= componentProductVersion($descriptor_array); ?>
        </td>
        <td class="col-right <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><i class="fas fa-calendar-alt me-1"></i>built <?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
        <td class="col-right"><i class="fas fa-clock me-1"></i>deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
        <td class="col-left"><?= componentDeploymentActions($descriptor_array) ?></td>
      </tr>
      <?php
    }
  }
  ?>
    </tbody>
  </table>
  </div>
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
  <?php
} else {
  echo '<div class="alert alert-warning"><i class="fas fa-exclamation-triangle me-2"></i>Nothing yet ;-)</div>';
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
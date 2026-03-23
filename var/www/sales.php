<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader("Sales environments"); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>

<div class="alert alert-info">
    <i class="fas fa-chart-line me-2"></i>
    These instances are deployed for <strong>eXo Sales Team</strong> usage only.
</div>

<?php
$sales_user_instances = getGlobalSalesUserInstances();
if (isDeploymentInCategoryArray($sales_user_instances)):
?>
<div class="inst-table-wrap mb-4">
  <table class="inst-table">
    <thead>
      <tr>
        <th class="col-center" style="width:36px">S</th>
        <th>Name</th>
        <th class="col-center">Version</th>
        <th class="col-right">Deployed</th>
        <th class="col-center">Database</th>
        <th class="col-left">Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr><td colspan="6" class="category-row"><i class="fas fa-user me-2"></i>Platform personal environments for Sales people</td></tr>
      <?php foreach ($sales_user_instances as $plf_branch => $descriptor_arrays):
        foreach ($descriptor_arrays as $d): ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($d) ?></td>
        <td>
          <div class="d-flex align-items-center gap-2">
            <div>
              <?= componentProductOpenLink($d, "", true) ?>
              <div class="mt-1">
                <?= componentUpgradeEligibility($d) ?>
                <?= componentPatchInstallation($d) ?>
                <?= componentCertbotEnabled($d) ?>
                <?= componentDevModeEnabled($d) ?>
                <?= componentStagingModeEnabled($d) ?>
                <?= componentDebugModeEnabled($d) ?>
                <?= componentAddonsTags($d) ?>
              </div>
            </div>
            <span class="ms-auto d-flex gap-1">
              <a href="<?= isset($d->DEPLOYMENT_BUILD_URL)
                ? $d->DEPLOYMENT_BUILD_URL . '/build?delay=0sec'
                : 'https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-trial-' . $d->BASE_VERSION . '-' . $d->INSTANCE_ID . '-deploy-acc/build?delay=0sec' ?>"
                target="_blank" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Restart / reset instance">
                <i class="fas fa-sync-alt"></i>
              </a>
              <?= componentEditNoteIcon($d) ?>
            </span>
          </div>
        </td>
        <td class="col-center">
          <?= componentProductInfoIcon($d) ?>&nbsp;<?= componentProductVersion($d) ?>&nbsp;<?= componentDownloadIcon($d) ?>
        </td>
        <td class="col-right"><i class="fas fa-clock me-1"></i><?= $d->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-center"><?= componentDatabaseIcon($d) ?></td>
        <td class="col-left"><?= componentDeploymentActions($d) ?></td>
      </tr>
      <?php endforeach; endforeach; ?>
    </tbody>
  </table>
</div>
<?php endif; ?>

<div class="alert alert-info">
    <i class="fas fa-chart-pie me-2"></i>
    These instances are deployed for <strong>eXo Demo</strong> purpose usage only.
</div>

<?php
$sales_demo_instances = getGlobalSalesDemoInstances();
if (isDeploymentInCategoryArray($sales_demo_instances)):
?>
<div class="inst-table-wrap mb-4">
  <table class="inst-table">
    <thead>
      <tr>
        <th class="col-center" style="width:36px">S</th>
        <th>Name</th>
        <th class="col-center">Version</th>
        <th class="col-right">Deployed</th>
        <th class="col-center">Database</th>
        <th class="col-left">Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr><td colspan="6" class="category-row"><i class="fas fa-briefcase me-2"></i>Platform demo environments for Leads</td></tr>
      <?php foreach ($sales_demo_instances as $plf_branch => $descriptor_arrays):
        foreach ($descriptor_arrays as $d): ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($d) ?></td>
        <td>
          <div class="d-flex align-items-center gap-2">
            <div>
              <?= componentProductOpenLink($d, "", true) ?>
              <div class="mt-1">
                <?= componentUpgradeEligibility($d) ?>
                <?= componentPatchInstallation($d) ?>
                <?= componentDevModeEnabled($d) ?>
                <?= componentStagingModeEnabled($d) ?>
                <?= componentDebugModeEnabled($d) ?>
                <?= componentAddonsTags($d) ?>
              </div>
            </div>
            <span class="ms-auto d-flex gap-1">
              <a href="<?= isset($d->DEPLOYMENT_BUILD_URL)
                ? $d->DEPLOYMENT_BUILD_URL . '/build?delay=0sec'
                : 'https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-trial-' . $d->BASE_VERSION . '-' . $d->INSTANCE_ID . '-deploy-acc/build?delay=0sec' ?>"
                target="_blank" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Restart / reset instance">
                <i class="fas fa-sync-alt"></i>
              </a>
              <?= componentEditNoteIcon($d) ?>
            </span>
          </div>
        </td>
        <td class="col-center">
          <?= componentProductInfoIcon($d) ?>&nbsp;<?= componentProductVersion($d) ?>&nbsp;<?= componentDownloadIcon($d) ?>
        </td>
        <td class="col-right"><i class="fas fa-clock me-1"></i><?= $d->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-center"><?= componentDatabaseIcon($d) ?></td>
        <td class="col-left"><?= componentDeploymentActions($d) ?></td>
      </tr>
      <?php endforeach; endforeach; ?>
    </tbody>
  </table>
</div>
<?php endif; ?>

<div class="alert alert-info">
    <i class="fas fa-chart-bar me-2"></i>
    These instances are deployed for <strong>Evaluation by Leads</strong> purpose usage only.
</div>

<?php
$sales_eval_instances = getGlobalSalesEvalInstances();
if (isDeploymentInCategoryArray($sales_eval_instances)):
?>
<div class="inst-table-wrap mb-4">
  <table class="inst-table">
    <thead>
      <tr>
        <th class="col-center" style="width:36px">S</th>
        <th>Name</th>
        <th class="col-center">Version</th>
        <th class="col-right">Deployed</th>
        <th class="col-center">Database</th>
        <th class="col-left">Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr><td colspan="6" class="category-row"><i class="fas fa-chart-line me-2"></i>Platform evaluation environments for Leads</td></tr>
      <?php foreach ($sales_eval_instances as $plf_branch => $descriptor_arrays):
        foreach ($descriptor_arrays as $d): ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($d) ?></td>
        <td>
          <div class="d-flex align-items-center gap-2">
            <div>
              <?= componentProductOpenLink($d, "", true) ?>
              <div class="mt-1">
                <?= componentUpgradeEligibility($d) ?>
                <?= componentPatchInstallation($d) ?>
                <?= componentDevModeEnabled($d) ?>
                <?= componentStagingModeEnabled($d) ?>
                <?= componentDebugModeEnabled($d) ?>
                <?= componentAddonsTags($d) ?>
              </div>
            </div>
            <span class="ms-auto">
              <?= componentEditNoteIcon($d) ?>
            </span>
          </div>
        </td>
        <td class="col-center">
          <?= componentProductInfoIcon($d) ?>&nbsp;<?= componentProductVersion($d) ?>&nbsp;<?= componentDownloadIcon($d) ?>
        </td>
        <td class="col-right"><i class="fas fa-clock me-1"></i><?= $d->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-center"><?= componentDatabaseIcon($d) ?></td>
        <td class="col-left"><?= componentDeploymentActions($d) ?></td>
      </tr>
      <?php endforeach; endforeach; ?>
    </tbody>
  </table>
</div>
<?php endif; ?>

<div class="info-grid mt-4">
    <div class="info-card">
        <div class="info-card-header"><i class="fas fa-plug"></i>JMX Access</div>
        <div class="info-card-body">Each instance can be accessed using JMX with the URL linked to the monitoring icon. Credentials can be found on CI Build.</div>
    </div>
    <div class="info-card">
        <div class="info-card-header"><i class="fas fa-key"></i>Keycloak Access</div>
        <div class="info-card-body">
            Each deployed Keycloak can be accessed using the Keycloak icon with credentials:
            <div class="code-block"><span>root / password</span></div>
        </div>
    </div>
    <div class="info-card">
        <div class="info-card-header"><i class="fas fa-address-book"></i>LDAP Access</div>
        <div class="info-card-body">
            Each LDAP deployed can be accessed with:
            <div class="code-block">
                <span>Base DN: dc=exoplatform,dc=com</span>
                <span>User DN: cn=admin,dc=exoplatform,dc=com</span>
                <span>password: exo</span>
            </div>
        </div>
    </div>
</div>

<?php pageFooter(); ?>
</body>
</html>

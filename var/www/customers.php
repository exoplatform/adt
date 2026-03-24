<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader("Customer projects"); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>

<div class="alert alert-info">
    <i class="fas fa-users me-2"></i>
    These instances are deployed for <strong>Customer Projects</strong> development Team deployment usage only.
</div>

<?php
$cp_instances = getGlobalCPInstances();
if (isDeploymentInCategoryArray($cp_instances)):
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
      <tr>
        <td colspan="6" class="category-row">
          <span class="group-type-tag type-cp me-2">CP</span>
          Customer Projects integration environments
        </td>
      </tr>
      <?php foreach ($cp_instances as $plf_branch => $descriptor_arrays):
        foreach ($descriptor_arrays as $d): ?>
      <tr>
        <td class="col-center"><?= componentStatusIcon($d) ?></td>
        <td>
          <div class="d-flex align-items-center gap-2">
            <div class="min-w-0">
              <?= componentProductOpenLink($d) ?>
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
            <span class="ms-auto flex-shrink-0 d-flex gap-1">
              <?php if (isset($d->DEPLOYMENT_BUILD_URL)): ?>
              <a href="<?= $d->DEPLOYMENT_BUILD_URL ?>/build?delay=0sec" target="_blank"
                 class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Restart / reset">
                <i class="fas fa-sync-alt"></i>
              </a>
              <?php else: ?>
              <a href="https://ci.exoplatform.org/job/platform-enterprise-<?= $d->PLF_BRANCH ?>-<?= $d->INSTANCE_ID ?>-deploy-acc/build?delay=0sec"
                 target="_blank" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Restart / reset">
                <i class="fas fa-sync-alt"></i>
              </a>
              <?php endif; ?>
              <?= componentEditNoteIcon($d) ?>
            </span>
          </div>
          <div class="mobile-meta">
            <span class="version-mono"><?= componentProductVersion($d) ?></span>
            <?= componentDatabaseIcon($d) ?>
            <span class="mobile-time-item"><i class="fas fa-clock"></i><?= $d->DEPLOYMENT_AGE_STRING ?></span>
          </div>
        </td>
        <td class="col-center inst-version-cell"><?= componentProductInfoIcon($d) ?>&nbsp;<?= componentProductVersion($d) ?>&nbsp;<?= componentDownloadIcon($d) ?></td>
        <td class="col-right inst-deployed-cell"><i class="fas fa-clock me-1"></i><?= $d->DEPLOYMENT_AGE_STRING ?></td>
        <td class="col-center inst-db-cell"><?= componentDatabaseIcon($d) ?></td>
        <td class="col-left inst-actions-cell"><?= componentDeploymentActions($d) ?></td>
      </tr>
      <?php endforeach; endforeach; ?>
    </tbody>
  </table>
</div>
<?php else: ?>
<div class="alert alert-warning"><i class="fas fa-exclamation-triangle me-2"></i>Nothing yet ;-)</div>
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

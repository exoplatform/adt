<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';
checkCaches();

$sales_user_instances = getGlobalSalesUserInstances();
$sales_demo_instances = getGlobalSalesDemoInstances();
$sales_eval_instances = getGlobalSalesEvalInstances();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader("Sales Environments"); ?>
</head>
<body>
    <?php pageTracker(); ?>
    <?php pageNavigation(); ?>
    
    <div id="wrap">
        <div id="main">
            <div class="container-fluid">
                <div class="row">
                    <div class="col-12">
                        <div class="card mb-4">
                            <div class="card-body">
                                <h1 class="h4 mb-4">Sales Team Environments</h1>
                                <p class="lead">These instances are deployed for <strong>eXo Sales Team</strong> usage only.</p>
                                
                                <?php if (isDeploymentInCategoryArray($sales_user_instances)): ?>
                                    <h2 class="h5 mt-4 mb-3"><i class="fas fa-user me-2"></i>Personal Environments</h2>
                                    <div class="table-responsive">
                                        <table class="table table-bordered table-hover">
                                            <thead class="table-light">
                                                <tr>
                                                    <th class="text-center">Status</th>
                                                    <th class="text-center">Name</th>
                                                    <th class="text-center">Version</th>
                                                    <th class="text-center" colspan="3">Characteristics</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                <?php foreach ($sales_user_instances as $plf_branch => $descriptor_arrays): ?>
                                                    <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                        <tr>
                                                            <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                            <td>
                                                                <?= componentProductOpenLink($descriptor_array, "", true) ?>
                                                                <span class="float-end">
                                                                    <?php if (isset($descriptor_array->DEPLOYMENT_BUILD_URL)): ?>
                                                                        <a href="<?= $descriptor_array->DEPLOYMENT_BUILD_URL ?>/build?delay=0sec" 
                                                                           target="_blank" 
                                                                           title="Restart your instance or reset your instance's data" 
                                                                           data-bs-toggle="tooltip" 
                                                                           class="me-2">
                                                                            <i class="fas fa-sync-alt me-1"></i>Restart/Reset
                                                                        </a>
                                                                    <?php else: ?>
                                                                        <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-trial-<?= htmlspecialchars($descriptor_array->BASE_VERSION) ?>-<?= htmlspecialchars($descriptor_array->INSTANCE_ID) ?>-deploy-acc/build?delay=0sec" 
                                                                           target="_blank" 
                                                                           title="Restart your instance or reset your instance's data" 
                                                                           data-bs-toggle="tooltip" 
                                                                           class="me-2">
                                                                            <i class="fas fa-sync-alt me-1"></i>Restart/Reset
                                                                        </a>
                                                                    <?php endif; ?>
                                                                    <?= componentEditNoteIcon($descriptor_array) ?>
                                                                </span>
                                                                <div class="mt-2">
                                                                    <?= componentUpgradeEligibility($descriptor_array) ?>
                                                                    <?= componentPatchInstallation($descriptor_array) ?>
                                                                    <?= componentDevModeEnabled($descriptor_array) ?>
                                                                    <?= componentStagingModeEnabled($descriptor_array) ?>
                                                                    <?= componentDebugModeEnabled($descriptor_array) ?>
                                                                    <?= componentAddonsTags($descriptor_array) ?>
                                                                </div>
                                                            </td>
                                                            <td class="text-center">
                                                                <?= componentProductInfoIcon($descriptor_array) ?>
                                                                <?= componentProductVersion($descriptor_array) ?>
                                                                <?= componentDownloadIcon($descriptor_array) ?>
                                                            </td>
                                                            <td class="text-end">deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                                                            <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                                            <td class="text-start"><?= componentDeploymentActions($descriptor_array) ?></td>
                                                        </tr>
                                                    <?php endforeach; ?>
                                                <?php endforeach; ?>
                                            </tbody>
                                        </table>
                                    </div>
                                <?php endif; ?>
                                
                                <?php if (isDeploymentInCategoryArray($sales_demo_instances)): ?>
                                    <h2 class="h5 mt-5 mb-3"><i class="fas fa-briefcase me-2"></i>Demo Environments</h2>
                                    <p>These instances are deployed for <strong>eXo Demo</strong> purpose usage only.</p>
                                    <div class="table-responsive">
                                        <table class="table table-bordered table-hover">
                                            <thead class="table-light">
                                                <tr>
                                                    <th class="text-center">Status</th>
                                                    <th class="text-center">Name</th>
                                                    <th class="text-center">Version</th>
                                                    <th class="text-center" colspan="3">Characteristics</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                <?php foreach ($sales_demo_instances as $plf_branch => $descriptor_arrays): ?>
                                                    <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                        <tr>
                                                            <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                            <td>
                                                                <?= componentProductOpenLink($descriptor_array, "", true) ?>
                                                                <span class="float-end">
                                                                    <?php if (isset($descriptor_array->DEPLOYMENT_BUILD_URL)): ?>
                                                                        <a href="<?= $descriptor_array->DEPLOYMENT_BUILD_URL ?>/build?delay=0sec" 
                                                                           target="_blank" 
                                                                           title="Restart your instance or reset your instance's data" 
                                                                           data-bs-toggle="tooltip" 
                                                                           class="me-2">
                                                                            <i class="fas fa-sync-alt me-1"></i>Restart/Reset
                                                                        </a>
                                                                    <?php else: ?>
                                                                        <a href="https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-trial-<?= htmlspecialchars($descriptor_array->BASE_VERSION) ?>-<?= htmlspecialchars($descriptor_array->INSTANCE_ID) ?>-deploy-acc/build?delay=0sec" 
                                                                           target="_blank" 
                                                                           title="Restart your instance or reset your instance's data" 
                                                                           data-bs-toggle="tooltip" 
                                                                           class="me-2">
                                                                            <i class="fas fa-sync-alt me-1"></i>Restart/Reset
                                                                        </a>
                                                                    <?php endif; ?>
                                                                    <?= componentEditNoteIcon($descriptor_array) ?>
                                                                </span>
                                                                <div class="mt-2">
                                                                    <?= componentUpgradeEligibility($descriptor_array) ?>
                                                                    <?= componentPatchInstallation($descriptor_array) ?>
                                                                    <?= componentDevModeEnabled($descriptor_array) ?>
                                                                    <?= componentStagingModeEnabled($descriptor_array) ?>
                                                                    <?= componentDebugModeEnabled($descriptor_array) ?>
                                                                    <?= componentAddonsTags($descriptor_array) ?>
                                                                </div>
                                                            </td>
                                                            <td class="text-center">
                                                                <?= componentProductInfoIcon($descriptor_array) ?>
                                                                <?= componentProductVersion($descriptor_array) ?>
                                                                <?= componentDownloadIcon($descriptor_array) ?>
                                                            </td>
                                                            <td class="text-end">deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                                                            <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                                            <td class="text-start"><?= componentDeploymentActions($descriptor_array) ?></td>
                                                        </tr>
                                                    <?php endforeach; ?>
                                                <?php endforeach; ?>
                                            </tbody>
                                        </table>
                                    </div>
                                <?php endif; ?>
                                
                                <?php if (isDeploymentInCategoryArray($sales_eval_instances)): ?>
                                    <h2 class="h5 mt-5 mb-3"><i class="fas fa-briefcase me-2"></i>Evaluation Environments</h2>
                                    <p>These instances are deployed for <strong>Evaluation by Leads</strong> purpose usage only.</p>
                                    <div class="table-responsive">
                                        <table class="table table-bordered table-hover">
                                            <thead class="table-light">
                                                <tr>
                                                    <th class="text-center">Status</th>
                                                    <th class="text-center">Name</th>
                                                    <th class="text-center">Version</th>
                                                    <th class="text-center" colspan="3">Characteristics</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                <?php foreach ($sales_eval_instances as $plf_branch => $descriptor_arrays): ?>
                                                    <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                        <tr>
                                                            <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                            <td>
                                                                <?= componentProductOpenLink($descriptor_array, "", true) ?>
                                                                <span class="float-end">
                                                                    <?= componentEditNoteIcon($descriptor_array) ?>
                                                                </span>
                                                                <div class="mt-2">
                                                                    <?= componentUpgradeEligibility($descriptor_array) ?>
                                                                    <?= componentPatchInstallation($descriptor_array) ?>
                                                                    <?= componentDevModeEnabled($descriptor_array) ?>
                                                                    <?= componentStagingModeEnabled($descriptor_array) ?>
                                                                    <?= componentDebugModeEnabled($descriptor_array) ?>
                                                                    <?= componentAddonsTags($descriptor_array) ?>
                                                                </div>
                                                            </td>
                                                            <td class="text-center">
                                                                <?= componentProductInfoIcon($descriptor_array) ?>
                                                                <?= componentProductVersion($descriptor_array) ?>
                                                                <?= componentDownloadIcon($descriptor_array) ?>
                                                            </td>
                                                            <td class="text-end">deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                                                            <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                                            <td class="text-start"><?= componentDeploymentActions($descriptor_array) ?></td>
                                                        </tr>
                                                    <?php endforeach; ?>
                                                <?php endforeach; ?>
                                            </tbody>
                                        </table>
                                    </div>
                                <?php endif; ?>
                                
                                <div class="alert alert-info mt-4">
                                    <h5 class="alert-heading">Access Information</h5>
                                    <ul class="mb-0">
                                        <li>Each instance can be accessed using JMX with the URL linked to the monitoring icon and its credentials can be found on CI Build.</li>
                                        <li>Each deployed Keycloak can be accessed using the Keycloak icon with these credentials: 
                                            <strong><code>root</code></strong> / <strong><code>password</code></strong>
                                        </li>
                                        <li>Each LDAP deployed can be accessed using the URL linked to the LDAP URL icon with these parameters:
                                            <strong><code>Base DN:dc=exoplatform,dc=com</code></strong> / 
                                            <strong><code>User DN:cn=admin,dc=exoplatform,dc=com</code></strong> / 
                                            <strong><code>password:exo</code></strong>
                                        </li>
                                    </ul>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <?php pageFooter(); ?>
</body>
</html>
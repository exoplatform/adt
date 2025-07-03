<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';
checkCaches();

$qa_instances = getGlobalQAUserInstances();
$qa_auto_instances = getGlobalQAAutoInstances();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader("QA Environments"); ?>
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
                                <h1 class="h4 mb-4">QA Team Environments</h1>
                                <p class="lead">These instances are deployed for <strong>eXo QA Team members</strong> usage only.</p>
                                
                                <?php if (isDeploymentInCategoryArray($qa_instances)): ?>
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
                                                <?php foreach ($qa_instances as $plf_branch => $descriptor_arrays): ?>
                                                    <tr>
                                                        <td colspan="15" class="category-row">
                                                            Platform <?= htmlspecialchars($plf_branch) ?> QA environments
                                                        </td>
                                                    </tr>
                                                    <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                        <tr>
                                                            <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                            <td>
                                                                <?= componentProductInfoIcon($descriptor_array) ?>
                                                                <?= componentProductOpenLink($descriptor_array) ?>
                                                                <span class="float-end">
                                                                    <a href="<?= htmlspecialchars($descriptor_array->DEPLOYMENT_BUILD_URL ?? 'https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-' . $descriptor_array->BASE_VERSION . '-' . $descriptor_array->INSTANCE_ID . '-acc') ?>/build?delay=0sec" 
                                                                       target="_blank" 
                                                                       class="text-decoration-none" 
                                                                       title="Restart your instance or reset your instance's data">
                                                                        <i class="fas fa-sync-alt"></i>
                                                                    </a>
                                                                </span>
                                                                <div class="mt-2">
                                                                    <?= componentUpgradeEligibility($descriptor_array) ?>
                                                                    <?= componentDevModeEnabled($descriptor_array) ?>
                                                                    <?= componentStagingModeEnabled($descriptor_array) ?>
                                                                    <?= componentDebugModeEnabled($descriptor_array) ?>
                                                                    <?= componentAddonsTags($descriptor_array) ?>
                                                                </div>
                                                            </td>
                                                            <td class="text-center">
                                                                <?= componentDownloadIcon($descriptor_array) ?>
                                                                <?= componentProductVersion($descriptor_array) ?>
                                                            </td>
                                                            <td class="text-end">deployed <?= htmlspecialchars($descriptor_array->DEPLOYMENT_AGE_STRING) ?></td>
                                                            <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                                            <td class="text-start"><?= componentDeploymentActions($descriptor_array) ?></td>
                                                        </tr>
                                                    <?php endforeach; ?>
                                                <?php endforeach; ?>
                                            </tbody>
                                        </table>
                                    </div>
                                <?php else: ?>
                                    <div class="alert alert-info">Nothing yet ;-)</div>
                                <?php endif; ?>
                                
                                <h2 class="h5 mt-5 mb-3">Automatic QA Test Environments</h2>
                                <p class="lead">These instances are deployed for <strong>Automatic QA Tests</strong> usage only (<strong>NOT FOR MANUAL TESTS</strong>).</p>
                                
                                <?php if (isDeploymentInCategoryArray($qa_auto_instances)): ?>
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
                                                <?php foreach ($qa_auto_instances as $plf_branch => $descriptor_arrays): ?>
                                                    <tr>
                                                        <td colspan="15" class="category-row">
                                                            Platform <?= htmlspecialchars($plf_branch) ?> Automatic QA environments
                                                        </td>
                                                    </tr>
                                                    <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                        <tr>
                                                            <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                            <td>
                                                                <?= componentProductInfoIcon($descriptor_array) ?>
                                                                <?= componentProductOpenLink($descriptor_array) ?>
                                                                <span class="float-end">
                                                                    <a href="<?= htmlspecialchars($descriptor_array->DEPLOYMENT_BUILD_URL ?? 'https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/platform-enterprise-' . $descriptor_array->BASE_VERSION . '-' . $descriptor_array->INSTANCE_ID . '-acc') ?>/build?delay=0sec" 
                                                                       target="_blank" 
                                                                       class="text-decoration-none" 
                                                                       title="Restart your instance or reset your instance's data">
                                                                        <i class="fas fa-sync-alt"></i>
                                                                    </a>
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
                                                                <?= componentDownloadIcon($descriptor_array) ?>
                                                                <?= componentProductVersion($descriptor_array) ?>
                                                            </td>
                                                            <td class="text-end">deployed <?= htmlspecialchars($descriptor_array->DEPLOYMENT_AGE_STRING) ?></td>
                                                            <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                                            <td class="text-start"><?= componentDeploymentActions($descriptor_array) ?></td>
                                                        </tr>
                                                    <?php endforeach; ?>
                                                <?php endforeach; ?>
                                            </tbody>
                                        </table>
                                    </div>
                                <?php else: ?>
                                    <div class="alert alert-info">Nothing yet ;-)</div>
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
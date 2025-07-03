<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';
checkCaches();

$company_instances = getGlobalCompanyInstances();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader("Company Environments"); ?>
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
                                <h1 class="h4 mb-4">Company Environments</h1>
                                
                                <ul class="list-unstyled mb-4">
                                    <li class="mb-2">
                                        <strong>eXo Website:</strong>
                                        <a href="https://www-dev.exoplatform.com/" target="_blank" class="ms-2">www-dev.exoplatform.com</a>
                                        <span class="mx-2">-</span>
                                        <a href="https://www-preprod.exoplatform.com/" target="_blank">www-preprod.exoplatform.com</a>
                                    </li>
                                    <li class="mb-2">
                                        <strong>eXo Tribe:</strong>
                                        <a href="https://community-dev.exoplatform.com/" target="_blank" class="ms-2">community-dev.exoplatform.com</a>
                                        <span class="mx-2">-</span>
                                        <a href="https://community-preprod.exoplatform.com/" target="_blank">community-preprod.exoplatform.com</a>
                                    </li>
                                    <li>
                                        <strong>eXo Blog:</strong>
                                        <a href="https://blog-dev.exoplatform.com/" target="_blank" class="ms-2">blog-dev.exoplatform.com</a>
                                        <span class="mx-2">-</span>
                                        <a href="https://blog-preprod.exoplatform.com/blog/" target="_blank">blog-preprod.exoplatform.com</a>
                                    </li>
                                </ul>
                                
                                <?php if (isDeploymentInCategoryArray($company_instances)): ?>
                                    <div class="table-responsive">
                                        <table class="table table-bordered table-hover">
                                            <thead class="table-light">
                                                <tr>
                                                    <th class="text-center">Status</th>
                                                    <th class="text-center">Name</th>
                                                    <th class="text-center">Version</th>
                                                    <th class="text-center" colspan="4">Characteristics</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                <?php foreach ($company_instances as $plf_branch => $descriptor_arrays): ?>
                                                    <tr>
                                                        <td colspan="15" class="category-row">
                                                            Company developments: <?= htmlspecialchars($plf_branch) ?>
                                                        </td>
                                                    </tr>
                                                    <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                        <tr>
                                                            <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                            <td>
                                                                <?= componentProductInfoIcon($descriptor_array) ?>
                                                                <?= componentUpgradeEligibility($descriptor_array, false) ?>
                                                                <?= componentPatchInstallation($descriptor_array, false) ?>
                                                                <?= componentDevModeEnabled($descriptor_array, false) ?>
                                                                <?= componentStagingModeEnabled($descriptor_array, false) ?>
                                                                <?= componentDebugModeEnabled($descriptor_array, false) ?>
                                                                <?= componentVisibilityIcon(
                                                                    $descriptor_array, 
                                                                    empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'text-success'
                                                                ) ?>
                                                                <?= componentProductOpenLink($descriptor_array, "", true) ?>
                                                                <span class="float-end">
                                                                    <?= componentEditNoteIcon($descriptor_array) ?>
                                                                </span>
                                                            </td>
                                                            <td class="text-center">
                                                                <?= componentDownloadIcon($descriptor_array) ?>
                                                                <?= componentProductVersion($descriptor_array) ?>
                                                            </td>
                                                            <td class="text-end <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>">
                                                                built <?= $descriptor_array->ARTIFACT_AGE_STRING ?>
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
                                <?php else: ?>
                                    <div class="alert alert-info">Nothing yet ;-)</div>
                                <?php endif; ?>
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
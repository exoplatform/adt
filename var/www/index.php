<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';
checkCaches();

$translation_instances = getGlobalTranslationInstances();
$doc_instances = getGlobalDocInstances();
$dev_instances = getGlobalDevInstances();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader(); ?>
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
                                <h1 class="h4 mb-4">Acceptance Test Instances</h1>
                                <p class="lead">These instances are deployed to be used for acceptance tests.</p>
                                
                                <div class="table-responsive">
                                    <table class="table table-bordered table-hover">
                                        <thead class="table-light">
                                            <tr>
                                                <th class="text-center">Status</th>
                                                <th class="text-center">Name</th>
                                                <th class="text-center">Version</th>
                                                <th class="text-center">Database</th>
                                                <th class="text-center" colspan="4">Feature Branch</th>
                                                <th class="text-center">Built</th>
                                                <th class="text-center">Deployed</th>
                                                <th class="text-center">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php if (isDeploymentInCategoryArray($translation_instances)): ?>
                                                <tr>
                                                    <td colspan="15" class="category-row">
                                                        <i class="fas fa-globe me-2"></i>Translation deployments
                                                    </td>
                                                </tr>
                                                <?php foreach ($translation_instances as $plf_branch => $descriptor_arrays): ?>
                                                    <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                        <tr>
                                                            <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                            <td>
                                                                <?= componentProductInfoIcon($descriptor_array) ?>
                                                                <?= componentVisibilityIcon(
                                                                    $descriptor_array, 
                                                                    empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'text-success'
                                                                ) ?>
                                                                <?= componentAppServerIcon($descriptor_array) ?>
                                                                <?= componentProductOpenLink($descriptor_array, componentProductHtmlLabel($descriptor_array)) ?>
                                                                <span class="float-end">
                                                                    <?= componentEditNoteIcon($descriptor_array) ?>
                                                                </span>
                                                            </td>
                                                            <td class="text-start">
                                                                <?= componentDownloadIcon($descriptor_array) ?>
                                                                <?= componentProductVersion($descriptor_array) ?>
                                                            </td>
                                                            <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                                            <td class="text-center" colspan="4"></td>
                                                            <td class="text-end <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>">
                                                                <?= $descriptor_array->ARTIFACT_AGE_STRING ?>
                                                            </td>
                                                            <td class="text-end"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                                                            <td class="text-start"><?= componentDeploymentActions($descriptor_array) ?></td>
                                                        </tr>
                                                    <?php endforeach; ?>
                                                <?php endforeach; ?>
                                            <?php endif; ?>

                                            <?php if (isDeploymentInCategoryArray($doc_instances)): ?>
                                                <tr>
                                                    <td colspan="15" class="category-row">
                                                        <i class="fas fa-book me-2"></i>Documentation deployments
                                                    </td>
                                                </tr>
                                                <?php foreach ($doc_instances as $plf_branch => $descriptor_arrays): ?>
                                                    <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                        <tr>
                                                            <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                            <td>
                                                                <?= componentProductInfoIcon($descriptor_array) ?>
                                                                <?= componentVisibilityIcon(
                                                                    $descriptor_array, 
                                                                    empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'text-success'
                                                                ) ?>
                                                                <?= componentAppServerIcon($descriptor_array) ?>
                                                                <?= componentProductOpenLink($descriptor_array, componentProductHtmlLabel($descriptor_array)) ?>
                                                                <span class="float-end">
                                                                    <?= componentEditNoteIcon($descriptor_array) ?>
                                                                </span>
                                                            </td>
                                                            <td class="text-start">
                                                                <?= componentDownloadIcon($descriptor_array) ?>
                                                                <?= componentProductVersion($descriptor_array) ?>
                                                            </td>
                                                            <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                                            <td class="text-center" colspan="4"></td>
                                                            <td class="text-end <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>">
                                                                <?= $descriptor_array->ARTIFACT_AGE_STRING ?>
                                                            </td>
                                                            <td class="text-end"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                                                            <td class="text-start"><?= componentDeploymentActions($descriptor_array) ?></td>
                                                        </tr>
                                                    <?php endforeach; ?>
                                                <?php endforeach; ?>
                                            <?php endif; ?>

                                            <?php foreach ($dev_instances as $plf_branch => $descriptor_arrays): ?>
                                                <tr>
                                                    <td colspan="15" class="category-row">
                                                        <?= buildTableTitleDev($plf_branch) ?>
                                                    </td>
                                                </tr>
                                                <?php foreach ($descriptor_arrays as $descriptor_array): ?>
                                                    <tr>
                                                        <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                        <td>
                                                            <?= componentProductInfoIcon($descriptor_array) ?>
                                                            <?= componentVisibilityIcon(
                                                                $descriptor_array, 
                                                                empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'text-success'
                                                            ) ?>
                                                            <?= componentAppServerIcon($descriptor_array) ?>
                                                            <?= componentProductOpenLink($descriptor_array, componentProductHtmlLabel($descriptor_array)) ?>
                                                            <span class="float-end">
                                                                <?= componentSpecificationIcon($descriptor_array) ?>
                                                                <?php if (!isInstanceFeatureBranch($descriptor_array)): ?>
                                                                    <?= componentEditNoteIcon($descriptor_array) ?>
                                                                <?php endif; ?>
                                                            </span>
                                                            <div class="mt-2">
                                                                <?= componentUpgradeEligibility($descriptor_array) ?>
                                                                <?= componentPatchInstallation($descriptor_array) ?>
                                                                <?= componentDevModeEnabled($descriptor_array) ?>
                                                                <?= componentStagingModeEnabled($descriptor_array) ?>
                                                                <?= componentDebugModeEnabled($descriptor_array) ?>
                                                                <?= componentAddonsTags($descriptor_array) ?>
                                                            </div>
                                                            <div class="mt-2">
                                                                <?= componentLabels($descriptor_array) ?>
                                                            </div>
                                                        </td>
                                                        <td class="text-start">
                                                            <?= componentDownloadIcon($descriptor_array) ?>
                                                            <?= componentProductVersion($descriptor_array) ?>
                                                        </td>
                                                        <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                                        <?php if (isInstanceFeatureBranch($descriptor_array)): ?>
                                                            <td class="text-center"><?= componentFBStatusLabel($descriptor_array) ?></td>
                                                            <td class="text-center"><?= componentFBScmLabel($descriptor_array) ?></td>
                                                            <td class="text-center"><?= componentFBIssueLabel($descriptor_array) ?></td>
                                                            <td class="text-center">
                                                                <?= componentFBEditIcon($descriptor_array) ?>
                                                                <?= componentFBDeployIcon($descriptor_array) ?>
                                                            </td>
                                                        <?php else: ?>
                                                            <td class="text-center" colspan="4"></td>
                                                        <?php endif; ?>
                                                        <td class="text-end <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>">
                                                            <?= $descriptor_array->ARTIFACT_AGE_STRING ?>
                                                        </td>
                                                        <td class="text-end"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
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
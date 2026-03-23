<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader(); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
    <div class="alert alert-info">
        <i class="fas fa-flask me-2"></i>
        These instances are deployed to be used for acceptance tests.
    </div>

    <div class="inst-group">
    <div class="inst-table-wrap">
    <table class="inst-table">
            <thead>
                <tr>
                    <th class="col-center">S</th>
                    <th class="col-center">Name</th>
                    <th class="col-center">Version</th>
                    <th class="col-center">Database</th>
                    <th class="col-center" colspan="4">Feature Branch</th>
                    <th class="col-center">Built</th>
                    <th class="col-center">Deployed</th>
                    <th class="col-center">Actions</th>
                </tr>
            </thead>
            <tbody>
<tr><td colspan="15" class="category-row"><span class="group-type-tag type-trans me-2">Trans</span>Translation Deployments</td></tr>
                <?php
                $translation_instances = getGlobalTranslationInstances();
                if (isDeploymentInCategoryArray($translation_instances)) {
                    foreach ($translation_instances as $plf_branch => $descriptor_arrays) {
                        foreach ($descriptor_arrays as $descriptor_array) { ?>
                            <tr>
                                <td class="col-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                <td>
                                    <div class="d-flex align-items-center">
                                        <?= componentProductInfoIcon($descriptor_array); ?>
                                        <div class="ms-2">
                                            <?php
                                            $product_deployment_url_label = componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'success');
                                            $product_deployment_url_label .= ' ' . componentAppServerIcon($descriptor_array);
                                            $product_deployment_url_label .= ' ' . componentProductHtmlLabel($descriptor_array);
                                            echo componentProductOpenLink($descriptor_array, $product_deployment_url_label);
                                            ?>
                                        </div>
                                        <div class="ms-auto">
                                            <?= componentEditNoteIcon($descriptor_array) ?>
                                        </div>
                                    </div>
                                    <div class="mobile-meta">
                                        <span class="version-mono"><?= componentProductVersion($descriptor_array); ?></span>
                                        <?= componentDatabaseIcon($descriptor_array) ?>
                                        <span class="mobile-time-item"><i class="fas fa-clock"></i><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></span>
                                    </div>
                                </td>
                                <td class="col-left">
                                    <?= componentDownloadIcon($descriptor_array); ?>
                                    <?= componentProductVersion($descriptor_array); ?>
                                </td>
                                <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                                <td class="col-center" colspan="4"></td>
                                <td class="col-right <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><i class="fas fa-calendar-alt me-1"></i><?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
                                <td class="col-right"><i class="fas fa-clock me-1"></i><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                                <td class="col-left"><?= componentDeploymentActions($descriptor_array); ?></td>
                            </tr>
                        <?php }
                    }
                }
                ?>

                <?php
                $dev_instances = getGlobalDevInstances();
                foreach ($dev_instances as $plf_branch => $descriptor_arrays) {
                ?>
                    <tr>
                        <td colspan="15" class="category-row"><?= buildTableTitleDev($plf_branch) ?></td>
                    </tr>
                    <?php foreach ($descriptor_arrays as $descriptor_array) { ?>
                        <tr>
                            <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
                            <td>
                                <div class="d-flex align-items-center">
                                    <?= componentProductInfoIcon($descriptor_array); ?>
                                    <div class="ms-2">
                                        <?php
                                        $product_deployment_url_label = componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'success');
                                        $product_deployment_url_label .= ' ' . componentAppServerIcon($descriptor_array);
                                        $product_deployment_url_label .= ' ' . componentProductHtmlLabel($descriptor_array);
                                        echo componentProductOpenLink($descriptor_array, $product_deployment_url_label);
                                        ?>
                                    </div>
                                    <div class="ms-auto">
                                        <?= componentSpecificationIcon($descriptor_array) ?>
                                        <?php
                                        if (!isInstanceFeatureBranch($descriptor_array)) {
                                            echo componentEditNoteIcon($descriptor_array);
                                        }
                                        ?>
                                    </div>
                                </div>
                                <div class="mt-2">
                                    <?= componentUpgradeEligibility($descriptor_array); ?>
                                    <?= componentPatchInstallation($descriptor_array); ?>
                                    <?= componentCertbotEnabled($descriptor_array); ?>
                                    <?= componentDevModeEnabled($descriptor_array); ?>
                                    <?= componentStagingModeEnabled($descriptor_array); ?>
                                    <?= componentDebugModeEnabled($descriptor_array); ?>
                                    <?= componentAddonsTags($descriptor_array); ?>
                                    <?= componentLabels($descriptor_array); ?>
                                </div>
                                <div class="mobile-meta">
                                    <span class="version-mono"><?= componentProductVersion($descriptor_array); ?></span>
                                    <?= componentDatabaseIcon($descriptor_array) ?>
                                    <?php if (isInstanceFeatureBranch($descriptor_array)): ?>
                                        <?= componentFBStatusLabel($descriptor_array) ?>
                                        <?= componentFBScmLabel($descriptor_array) ?>
                                    <?php endif; ?>
                                    <span class="mobile-time-item"><i class="fas fa-clock"></i><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></span>
                                </div>
                            </td>
                            <td class="col-left">
                                <?= componentDownloadIcon($descriptor_array); ?>
                                <?= componentProductVersion($descriptor_array); ?>
                            </td>
                            <td class="col-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                            <?php if (isInstanceFeatureBranch($descriptor_array)) { ?>
                                <td class="col-center"><?= componentFBStatusLabel($descriptor_array) ?></td>
                                <td class="col-center"><?= componentFBScmLabel($descriptor_array) ?></td>
                                <td class="col-center"><?= componentFBIssueLabel($descriptor_array) ?></td>
                                <td class="col-center">
                                    <?= componentFBEditIcon($descriptor_array) ?>
                                    <?= componentFBDeployIcon($descriptor_array) ?>
                                </td>
                            <?php } else { ?>
                                <td class="col-center" colspan="4"></td>
                            <?php } ?>
                            <td class="col-right <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><i class="fas fa-calendar-alt me-1"></i><?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
                            <td class="col-right"><i class="fas fa-clock me-1"></i><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                            <td class="col-left"><?= componentDeploymentActions($descriptor_array); ?></td>
                        </tr>
                    <?php
                    }
                }
                ?>
            </tbody>
    </table>
    </div>
    </div>

    <div class="info-grid">
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
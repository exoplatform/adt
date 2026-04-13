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
<!-- Main ================================================== -->
<div id="wrap">
<div id="main">
<div class="container-fluid">
<div class="row">
<div class="col-12">

    <!-- Filter bar -->
    <div class="filter-bar">
      <input type="text" id="instanceFilter" placeholder="Search instances…" autocomplete="off">
      <button class="filter-pill active" data-filter="all"><i class="fas fa-th-list"></i> All</button>
      <button class="filter-pill" data-filter="up"><i class="fas fa-circle text-success" style="font-size:.6em"></i> Up</button>
      <button class="filter-pill" data-filter="down"><i class="fas fa-circle text-danger" style="font-size:.6em"></i> Down</button>
      <div class="instance-count" id="instanceCount">– / –</div>
    </div>

    <div class="table-wrap">
    <div class="table-responsive">
        <table class="table table-hover" id="instanceTable">
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
                <tr>
                    <td colspan="15" class="category-row">
                        <i class="fas fa-globe me-2"></i>Translation deployments
                    </td>
                </tr>
                <?php
                $translation_instances = getGlobalTranslationInstances();
                if (isDeploymentInCategoryArray($translation_instances)) {
                    foreach ($translation_instances as $plf_branch => $descriptor_arrays) {
                        foreach ($descriptor_arrays as $descriptor_array) { ?>
                            <tr class="instance-row">
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
                        <tr class="instance-row">
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
                                        // add edit note option icon if not a feature branch
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
    </div><!-- /table-wrap -->

    <!-- Info cards -->
    <div class="info-cards-row">
        <div class="card">
            <div class="card-header"><i class="fas fa-chart-line me-2"></i>JMX Access</div>
            <div class="card-body">
                Access any instance via JMX using the monitoring icon link. Credentials are available on the CI Build page.
            </div>
        </div>
        <div class="card">
            <div class="card-header"><i class="fas fa-key me-2"></i>Keycloak</div>
            <div class="card-body">
                Access deployed Keycloak instances via the key icon.
                <div class="code-bg mt-2">
                    <code>root / password</code>
                </div>
            </div>
        </div>
        <div class="card">
            <div class="card-header"><i class="fas fa-address-book me-2"></i>LDAP</div>
            <div class="card-body">
                <div class="code-bg">
                    <code>Base DN: dc=exoplatform,dc=com</code>
                    <code>User: cn=admin,dc=exoplatform,dc=com</code>
                    <code>pwd: exo</code>
                </div>
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
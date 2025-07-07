<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
<?= pageHeader(); ?>
</head>
<body class="modern-ui">
<?php pageTracker(); ?>
<?php pageNavigation(); ?>

<!-- Main Content ================================================== -->
<main class="container-fluid py-4">
  <div class="row">
    <div class="col-12">
      <div class="card shadow-sm mb-4">
        <div class="card-header bg-primary text-white">
          <h5 class="mb-0">Acceptance Testing Instances</h5>
        </div>
        <div class="card-body">
          <p class="text-muted">These instances are deployed for acceptance tests and quality assurance.</p>
          
          <div class="table-responsive">
            <table class="table table-hover table-striped align-middle">
              <thead class="table-light">
                <tr>
                  <th class="text-center" style="width: 40px">Status</th>
                  <th class="text-center">Instance</th>
                  <th class="text-center">Version</th>
                  <th class="text-center">Database</th>
                  <th class="text-center" colspan="4">Feature Branch</th>
                  <th class="text-center">Built</th>
                  <th class="text-center">Deployed</th>
                  <th class="text-center">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td colspan="15" class="bg-dark text-warning fw-bold"><i class="fas fa-globe me-2"></i>Translation Deployments</td>
                </tr>
                <?php
                $translation_instances = getGlobalTranslationInstances();
                if (isDeploymentInCategoryArray($translation_instances)) {
                  foreach ($translation_instances as $plf_branch => $descriptor_arrays) {
                    foreach ($descriptor_arrays as $descriptor_array) {?>
                      <tr>
                        <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                        <td>
                          <?= componentProductInfoIcon($descriptor_array); ?>
                          <?php
                          $product_deployment_url_label=componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'text-success');
                          $product_deployment_url_label.=' '.componentAppServerIcon($descriptor_array);
                          $product_deployment_url_label.=' '.componentProductHtmlLabel($descriptor_array);
                          print componentProductOpenLink($descriptor_array, $product_deployment_url_label);
                          ?>
                          <div class="float-end">
                          <?= componentEditNoteIcon($descriptor_array) ?>
                          </div>
                        </td>
                        <td><?= componentDownloadIcon($descriptor_array); ?> <?= componentProductVersion($descriptor_array); ?></td>
                        <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                        <td class="text-center" colspan="4"></td>
                        <td class="text-end <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
                        <td class="text-end"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                        <td><?= componentDeploymentActions($descriptor_array); ?></td>
                      </tr>
                    <?php }
                  }
                }
                ?>
                
                <?php
                $doc_instances = getGlobalDocInstances();
                if (isDeploymentInCategoryArray($doc_instances)) {
                  foreach ($doc_instances as $plf_branch => $descriptor_arrays) {
                    foreach ($descriptor_arrays as $descriptor_array) {?>
                      <tr>
                        <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                        <td>
                          <?= componentProductInfoIcon($descriptor_array); ?>
                          <?php
                          $product_deployment_url_label=componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'text-success');
                          $product_deployment_url_label.=' '.componentAppServerIcon($descriptor_array);
                          $product_deployment_url_label.=' '.componentProductHtmlLabel($descriptor_array);
                          print componentProductOpenLink($descriptor_array, $product_deployment_url_label);
                          ?>
                          <div class="float-end">
                          <?= componentEditNoteIcon($descriptor_array) ?>
                          </div>
                        </td>
                        <td><?= componentDownloadIcon($descriptor_array); ?> <?= componentProductVersion($descriptor_array); ?></td>
                        <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                        <td class="text-center" colspan="4"></td>
                        <td class="text-end <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
                        <td class="text-end"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                        <td><?= componentDeploymentActions($descriptor_array); ?></td>
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
                    <td colspan="15" class="bg-dark text-warning fw-bold"><?= buildTableTitleDev($plf_branch) ?></td>
                  </tr>
                  <?php foreach ($descriptor_arrays as $descriptor_array) { ?>
                    <tr>
                      <td class="text-center"><?= componentStatusIcon($descriptor_array); ?></td>
                      <td>
                        <?= componentProductInfoIcon($descriptor_array); ?>
                        <?php
                        $product_deployment_url_label=componentVisibilityIcon($descriptor_array, empty($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'text-success');
                        $product_deployment_url_label.=' '.componentAppServerIcon($descriptor_array);
                        $product_deployment_url_label.=' '.componentProductHtmlLabel($descriptor_array);
                        print componentProductOpenLink($descriptor_array, $product_deployment_url_label);
                        ?>
                        <div class="float-end">
                          <?= componentSpecificationIcon($descriptor_array) ?>
                          <?php
                            // add edit note option icon if not a feature branch
                            if (!isInstanceFeatureBranch($descriptor_array)) {
                              print componentEditNoteIcon($descriptor_array);
                            }
                          ?>
                        </div>
                        <div class="mt-2">
                          <?= componentUpgradeEligibility($descriptor_array); ?>
                          <?= componentPatchInstallation($descriptor_array); ?>
                          <?= componentCertbotEnabled($descriptor_array); ?>
                          <?= componentDevModeEnabled($descriptor_array); ?>
                          <?= componentStagingModeEnabled($descriptor_array); ?>
                          <?= componentDebugModeEnabled($descriptor_array); ?>
                          <?= componentAddonsTags($descriptor_array); ?>
                        </div>
                        <div class="mt-1"><?= componentLabels($descriptor_array); ?></div>
                      </td>
                      <td><?= componentDownloadIcon($descriptor_array); ?> <?= componentProductVersion($descriptor_array); ?></td>
                      <td class="text-center"><?= componentDatabaseIcon($descriptor_array) ?></td>
                      <?php if (isInstanceFeatureBranch($descriptor_array)) { ?>
                        <td class="text-center"><?= componentFBStatusLabel($descriptor_array) ?></td>
                        <td class="text-center"><?= componentFBScmLabel($descriptor_array) ?></td>
                        <td class="text-center"><?= componentFBIssueLabel($descriptor_array) ?></td>
                        <td class="text-center"><?= componentFBEditIcon($descriptor_array) ?><?= componentFBDeployIcon($descriptor_array) ?></td>
                      <?php } else { ?>
                        <td class="text-center" colspan="4"></td>
                      <?php } ?>
                      <td class="text-end <?= $descriptor_array->ARTIFACT_AGE_CLASS ?>"><?= $descriptor_array->ARTIFACT_AGE_STRING ?></td>
                      <td class="text-end"><?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
                      <td><?= componentDeploymentActions($descriptor_array); ?></td>
                    </tr>
                  <?php
                  }
                }
                ?>
              </tbody>
            </table>
          </div>
          
          <div class="alert alert-info mt-4">
            <h6><i class="fas fa-info-circle me-2"></i>Access Information</h6>
            <ul class="mb-0">
              <li>Each instance can be accessed using JMX with the URL linked to the monitoring icon and its credentials can be found on CI Build.</li>
              <li>Each deployed Keycloak can be accessed using the Keycloak icon with credentials: <code>root</code> / <code>password</code></li>
              <li>Each LDAP deployment can be accessed using the LDAP URL icon with parameters:
                <ul>
                  <li><strong>Base DN:</strong> <code>dc=exoplatform,dc=com</code></li>
                  <li><strong>User DN:</strong> <code>cn=admin,dc=exoplatform,dc=com</code></li>
                  <li><strong>Password:</strong> <code>exo</code></li>
                </ul>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </div>
</main>

<?php pageFooter(); ?>
</body>
</html>
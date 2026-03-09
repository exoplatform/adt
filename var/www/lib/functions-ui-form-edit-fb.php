<?php

/**
 * Get the markup to edit the notes of a particular deployment
 *
 * @param $descriptor_array a deployment descriptor
 *
 * @return array html markup
 */
function getFormEditFeatureBranch($descriptor_array)
{
  ob_start();
?>
  <div class="modal fade bigModal" id="edit-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>" tabindex="-1" aria-labelledby="label-<?= $descriptor_array->INSTANCE_KEY ?>" aria-hidden="true">
    <div class="modal-dialog modal-lg">
      <div class="modal-content">
        <form method="POST" action="<?= $descriptor_array->ACCEPTANCE_SCHEME ?>://<?= $descriptor_array->ACCEPTANCE_HOST ?>:<?= $descriptor_array->ACCEPTANCE_PORT ?>/editFeature.php">
          <div class="modal-header">
            <h5 class="modal-title" id="label-<?= $descriptor_array->INSTANCE_KEY ?>">
              <i class="fas fa-code-branch me-2"></i>Edit Feature Branch
            </h5>
            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <input type="hidden" name="from" value="<?= currentPageURL() ?>">
            <input type="hidden" name="key" value="<?= $descriptor_array->INSTANCE_KEY ?>">

            <div class="card mb-3">
              <div class="card-body">
                <div class="row mb-2">
                  <div class="col-3 fw-bold">Product</div>
                  <div class="col-9">
                    <?php
                    if (empty($descriptor_array->INSTANCE_DESCRIPTION))
                      echo $descriptor_array->PRODUCT_NAME;
                    else
                      echo $descriptor_array->PRODUCT_DESCRIPTION;
                    if (!empty($descriptor_array->INSTANCE_ID))
                      echo " (" . $descriptor_array->INSTANCE_ID . ")";
                    ?>
                  </div>
                </div>
                <div class="row mb-2">
                  <div class="col-3 fw-bold">Version</div>
                  <div class="col-9"><?= $descriptor_array->BASE_VERSION ?></div>
                </div>
                <div class="row mb-2">
                  <div class="col-3 fw-bold">Feature Branch</div>
                  <div class="col-9"><?= $descriptor_array->BRANCH_NAME ?></div>
                </div>
              </div>
            </div>

            <div class="mb-3">
              <label for="description" class="form-label fw-bold">Description</label>
              <input type="text" class="form-control" id="description" name="description"
                placeholder="Description" value="<?= htmlspecialchars($descriptor_array->BRANCH_DESC ?? '') ?>">
              <div class="form-text">Short description of the feature branch</div>
            </div>

            <div class="mb-3">
              <label for="specifications" class="form-label fw-bold">Specifications link</label>
              <input type="url" class="form-control" id="specifications" name="specifications"
                placeholder="Url" value="<?= htmlspecialchars($descriptor_array->SPECIFICATIONS_LINK ?? '') ?>">
              <div class="form-text">eXo intranet URL of specifications</div>
            </div>

            <div class="row">
              <div class="col-md-4 mb-3">
                <label for="issue" class="form-label fw-bold">Issue key</label>
                <input type="text" class="form-control" id="issue" name="issue"
                  placeholder="XXX-nnnn" value="<?= htmlspecialchars($descriptor_array->ISSUE_NUM ?? '') ?>">
                <div class="form-text">Issue key where testers can give a feedback.</div>
              </div>

              <div class="col-md-4 mb-3">
                <label for="status" class="form-label fw-bold">Status</label>
                <select class="form-select" id="status" name="status">
                  <option value="Implementing" <?php if (($descriptor_array->ACCEPTANCE_STATE ?? '') === "Implementing") echo "selected"; ?>>Implementing</option>
                  <option value="Engineering Review" <?php if (($descriptor_array->ACCEPTANCE_STATE ?? '') === "Engineering Review") echo "selected"; ?>>Engineering Review</option>
                  <option value="QA Review" <?php if (($descriptor_array->ACCEPTANCE_STATE ?? '') === "QA Review") echo "selected"; ?>>QA Review</option>
                  <option value="QA In Progress" <?php if (($descriptor_array->ACCEPTANCE_STATE ?? '') === "QA In Progress") echo "selected"; ?>>QA In Progress</option>
                  <option value="QA Rejected" <?php if (($descriptor_array->ACCEPTANCE_STATE ?? '') === "QA Rejected") echo "selected"; ?>>QA Rejected</option>
                  <option value="Validated" <?php if (($descriptor_array->ACCEPTANCE_STATE ?? '') === "Validated") echo "selected"; ?>>Validated</option>
                  <option value="Merged" <?php if (($descriptor_array->ACCEPTANCE_STATE ?? '') === "Merged") echo "selected"; ?>>Merged</option>
                </select>
                <div class="form-text">Current status of the feature branch</div>
              </div>

              <div class="col-md-4 mb-3">
                <label for="branch" class="form-label fw-bold">Git branch</label>
                <select class="form-select" id="branch" name="branch">
                  <option value="UNSET">=== Undefined ===</option>
                  <?php
                  // List all projects
                  $features = getFeatureBranches(array_keys(getRepositories()));
                  foreach ($features as $feature => $FBProjects) {
                    $selected = (!empty($descriptor_array->SCM_BRANCH) && $descriptor_array->SCM_BRANCH === $feature) ? 'selected' : '';
                  ?>
                      <option value="<?= htmlspecialchars($feature) ?>" <?= $selected ?>><?= htmlspecialchars($feature) ?></option>
                  <?php
                  }
                  ?>
                </select>
                <div class="form-text">Git branch hosting this development</div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
            <button type="submit" class="btn btn-primary">Save changes</button>
          </div>
        </form>
      </div>
    </div>
  </div>
<?php
  return ob_get_clean();
}
?>
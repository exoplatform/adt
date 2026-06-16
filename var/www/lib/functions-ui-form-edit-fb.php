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
  <div class="modal fade" id="edit-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title"><i class="fas fa-code-branch me-2"></i>Edit Feature Branch</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <form method="POST" action="<?= $descriptor_array->ACCEPTANCE_SCHEME ?>://<?= $descriptor_array->ACCEPTANCE_HOST ?>:<?= $descriptor_array->ACCEPTANCE_PORT ?>/editFeature.php">
          <div class="modal-body">
            <input type="hidden" name="from" value="<?= currentPageURL() ?>">
            <input type="hidden" name="key" value="<?= $descriptor_array->INSTANCE_KEY ?>">

            <div class="bg-field rounded-3 p-3 mb-3">
              <div class="row mb-1">
                <div class="col-3 text-muted small fw-semibold">Product</div>
                <div class="col-9">
                  <?= htmlspecialchars($descriptor_array->INSTANCE_DESCRIPTION ?: $descriptor_array->PRODUCT_NAME) ?>
                  <?php if (!empty($descriptor_array->INSTANCE_ID)) echo " (" . htmlspecialchars($descriptor_array->INSTANCE_ID) . ")"; ?>
                </div>
              </div>
              <div class="row mb-1">
                <div class="col-3 text-muted small fw-semibold">Version</div>
                <div class="col-9"><?= htmlspecialchars($descriptor_array->BASE_VERSION) ?></div>
              </div>
              <div class="row">
                <div class="col-3 text-muted small fw-semibold">Branch</div>
                <div class="col-9 font-mono"><?= htmlspecialchars($descriptor_array->BRANCH_NAME) ?></div>
              </div>
            </div>

            <div class="mb-3">
              <label for="description" class="form-label fw-semibold small text-muted">DESCRIPTION</label>
              <input type="text" class="form-control" id="description" name="description"
                placeholder="Short description" value="<?= htmlspecialchars($descriptor_array->BRANCH_DESC ?? '') ?>">
            </div>

            <div class="mb-3">
              <label for="specifications" class="form-label fw-semibold small text-muted">SPECIFICATIONS LINK</label>
              <input type="url" class="form-control" id="specifications" name="specifications"
                placeholder="https://..." value="<?= htmlspecialchars($descriptor_array->SPECIFICATIONS_LINK ?? '') ?>">
            </div>

            <div class="row">
              <div class="col-md-4 mb-3">
                <label for="issue" class="form-label fw-semibold small text-muted">ISSUE KEY</label>
                <input type="text" class="form-control" id="issue" name="issue"
                  placeholder="XXX-nnnn" value="<?= htmlspecialchars($descriptor_array->ISSUE_NUM ?? '') ?>">
              </div>
              <div class="col-md-4 mb-3">
                <label for="status" class="form-label fw-semibold small text-muted">STATUS</label>
                <select class="form-select" id="status" name="status">
                  <option value="Implementing" <?= (($descriptor_array->ACCEPTANCE_STATE ?? '') === "Implementing") ? "selected" : "" ?>>Implementing</option>
                  <option value="Engineering Review" <?= (($descriptor_array->ACCEPTANCE_STATE ?? '') === "Engineering Review") ? "selected" : "" ?>>Engineering Review</option>
                  <option value="QA Review" <?= (($descriptor_array->ACCEPTANCE_STATE ?? '') === "QA Review") ? "selected" : "" ?>>QA Review</option>
                  <option value="QA In Progress" <?= (($descriptor_array->ACCEPTANCE_STATE ?? '') === "QA In Progress") ? "selected" : "" ?>>QA In Progress</option>
                  <option value="QA Rejected" <?= (($descriptor_array->ACCEPTANCE_STATE ?? '') === "QA Rejected") ? "selected" : "" ?>>QA Rejected</option>
                  <option value="Validated" <?= (($descriptor_array->ACCEPTANCE_STATE ?? '') === "Validated") ? "selected" : "" ?>>Validated</option>
                  <option value="Merged" <?= (($descriptor_array->ACCEPTANCE_STATE ?? '') === "Merged") ? "selected" : "" ?>>Merged</option>
                </select>
              </div>
              <div class="col-md-4 mb-3">
                <label for="branch" class="form-label fw-semibold small text-muted">GIT BRANCH</label>
                <select class="form-select" id="branch" name="branch">
                  <option value="UNSET">=== Undefined ===</option>
                  <?php
                  $features = getFeatureBranches(array_keys(getRepositories()));
                  foreach ($features as $feature => $FBProjects) {
                    $selected = (!empty($descriptor_array->SCM_BRANCH) && $descriptor_array->SCM_BRANCH === $feature) ? 'selected' : '';
                  ?>
                    <option value="<?= htmlspecialchars($feature) ?>" <?= $selected ?>><?= htmlspecialchars($feature) ?></option>
                  <?php } ?>
                </select>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </form>
      </div>
    </div>
  </div>
<?php
  return ob_get_clean();
}
?>

<?php

/**
 * Get the markup to edit the notes of a particular deployment
 *
 * @param $descriptor_array a deployment descriptor
 *
 * @return array html markup
 */
function getFormEditNote($descriptor_array)
{
  ob_start();
?>
  <div class="modal fade" id="edit-note-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title"><i class="fas fa-pencil-alt me-2"></i>Edit Instance Note</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <form method="POST" action="<?= $descriptor_array->ACCEPTANCE_SCHEME ?>://<?= $descriptor_array->ACCEPTANCE_HOST ?>:<?= $descriptor_array->ACCEPTANCE_PORT ?>/editInstance.php">
          <div class="modal-body">
            <input type="hidden" name="from" value="<?= currentPageURL() ?>">
            <input type="hidden" name="key" value="<?= $descriptor_array->INSTANCE_KEY ?>">

            <div class="bg-field rounded-3 p-3 mb-3">
              <div class="row mb-1">
                <div class="col-4 text-muted small fw-semibold">Product</div>
                <div class="col-8"><?= componentProductHtmlLabel($descriptor_array, true); ?></div>
              </div>
              <div class="row">
                <div class="col-4 text-muted small fw-semibold">Version</div>
                <div class="col-8"><?= componentProductVersion($descriptor_array) ?></div>
              </div>
            </div>

            <div class="mb-0">
              <label for="note" class="form-label fw-semibold small text-muted">NOTE</label>
              <input type="text" class="form-control" id="note" name="note" placeholder="Add a note about this instance" value="<?= htmlspecialchars($descriptor_array->INSTANCE_NOTE ?? '') ?>" autofocus>
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

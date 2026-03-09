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
  <div class="modal fade bigModal" id="edit-note-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>" tabindex="-1" aria-labelledby="label-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>" aria-hidden="true">
    <div class="modal-dialog">
      <div class="modal-content">
        <form method="POST" action="<?= $descriptor_array->ACCEPTANCE_SCHEME ?>://<?= $descriptor_array->ACCEPTANCE_HOST ?>:<?= $descriptor_array->ACCEPTANCE_PORT ?>/editInstance.php">
          <div class="modal-header">
            <h5 class="modal-title" id="label-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>">
              <i class="fas fa-pencil-alt me-2"></i>Edit Instance Note
            </h5>
            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <input type="hidden" name="from" value="<?= currentPageURL() ?>">
            <input type="hidden" name="key" value="<?= $descriptor_array->INSTANCE_KEY ?>">

            <div class="card mb-3">
              <div class="card-body">
                <div class="row mb-2">
                  <div class="col-4 fw-bold">Product</div>
                  <div class="col-8"><?= componentProductHtmlLabel($descriptor_array, true); ?></div>
                </div>
                <div class="row mb-2">
                  <div class="col-4 fw-bold">Version</div>
                  <div class="col-8"><?= componentProductVersion($descriptor_array) ?></div>
                </div>
              </div>
            </div>

            <div class="mb-3">
              <label for="note" class="form-label fw-bold">Note</label>
              <input type="text" class="form-control" id="note" name="note" placeholder="Add a note" value="<?= htmlspecialchars($descriptor_array->INSTANCE_NOTE ?? '') ?>">
              <div class="form-text">Short note about this instance</div>
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
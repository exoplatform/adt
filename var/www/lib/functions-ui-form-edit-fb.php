<?php

/**
 * Get the markup to edit the notes of a particular deployment
 *
 * @param $descriptor_array a deployment descriptor
 *
 * @return array html markup
 */
function getFormEditFeatureBranch ($descriptor_array) {
  ob_start()
  ?>
  <form class="form" style="display: inline"
        action="<?= $descriptor_array->ACCEPTANCE_SCHEME ?>://<?= $descriptor_array->ACCEPTANCE_HOST ?>:<?= $descriptor_array->ACCEPTANCE_PORT ?>/editFeature.php"
        method="POST">
    <div class="modal bigModal hide fade"
         id="edit-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>" tabindex="-1"
         role="dialog" aria-labelledby="label-<?= $descriptor_array->INSTANCE_KEY ?>"
         aria-hidden="true">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
        <h3 id="label-<?= $descriptor_array->INSTANCE_KEY ?>">Edit Feature Branch</h3>
      </div>
      <div class="modal-body">
        <input type="hidden" name="from" value="<?= currentPageURL() ?>">
        <input type="hidden" name="key" value="<?= $descriptor_array->INSTANCE_KEY ?>">

        <div class="row-fluid">
          <div class="span4"><strong>Product</strong></div>
          <div
            class="span8"><?php if (empty($descriptor_array->INSTANCE_DESCRIPTION)) echo $descriptor_array->PRODUCT_NAME; else echo $descriptor_array->PRODUCT_DESCRIPTION; ?><?php if (!empty($descriptor_array->INSTANCE_ID)) echo " (" . $descriptor_array->INSTANCE_ID . ")"; ?></div>
        </div>
        <div class="row-fluid">
          <div class="span4"><strong>Version</strong></div>
          <div class="span8"><?= $descriptor_array->BASE_VERSION ?></div>
        </div>
        <div class="row-fluid">
          <div class="span4"><strong>Feature Branch</strong></div>
          <div class="span8"><?= $descriptor_array->BRANCH_NAME ?></div>
        </div>
        <hr/>
        <div class="row-fluid">
          <div class="span12">
            <div class="control-group">
              <label class="control-label"
                     for="description"><strong>Description</strong></label>

              <div class="controls">
                <input class="input-large" type="text" id="description" name="description"
                       placeholder="Description"
                       value="<?= $descriptor_array->BRANCH_DESC ?>">
                <span class="help-block">Short description of the feature branch</span>
              </div>
            </div>
          </div>
        </div>
        <div class="row-fluid">
          <div class="span12">
            <div class="control-group">
              <label class="control-label" for="specifications"><strong>Specifications
                  link</strong></label>

              <div class="controls">
                <input class="input-xxlarge" type="url" id="specifications"
                       name="specifications" placeholder="Url"
                       value="<?= $descriptor_array->SPECIFICATIONS_LINK ?>">
                <span class="help-block">eXo intranet URL of specifications</span>
              </div>
            </div>
          </div>
        </div>
        <div class="row-fluid">
          <div class="span4">
            <div class="control-group">
              <label class="control-label" for="issue"><strong>Issue key</strong></label>

              <div class="controls">
                <input class="input-medium" type="text" id="issue" name="issue"
                       placeholder="XXX-nnnn" value="<?= $descriptor_array->ISSUE_NUM ?>">
                <span class="help-block">Issue key where testers can give a feedback.</span>
              </div>
            </div>
          </div>
          <div class="span4">
            <div class="control-group">
              <label class="control-label" for="status"><strong>Status</strong></label>

              <div class="controls" id="status">
                <select name="status">
                  <option <?php if ($descriptor_array->ACCEPTANCE_STATE === "Implementing") {
                    echo "selected";
                  } ?>>Implementing
                  </option>
                  <option <?php if ($descriptor_array->ACCEPTANCE_STATE === "Engineering Review") {
                    echo "selected";
                  } ?>>Engineering Review
                  </option>
                  <option <?php if ($descriptor_array->ACCEPTANCE_STATE === "QA Review") {
                    echo "selected";
                  } ?>>QA Review
                  </option>
                  <option <?php if ($descriptor_array->ACCEPTANCE_STATE === "QA In Progress") {
                    echo "selected";
                  } ?>>QA In Progress
                  </option>
                  <option <?php if ($descriptor_array->ACCEPTANCE_STATE === "QA Rejected") {
                    echo "selected";
                  } ?>>QA Rejected
                  </option>
                  <option <?php if ($descriptor_array->ACCEPTANCE_STATE === "Validated") {
                    echo "selected";
                  } ?>>Validated
                  </option>
                  <option <?php if ($descriptor_array->ACCEPTANCE_STATE === "Merged") {
                    echo "selected";
                  } ?>>Merged
                  </option>
                </select>
                <span class="help-block">Current status of the feature branch</span>
              </div>
            </div>
          </div>
          <div class="span4">
            <div class="control-group">
              <label class="control-label" for="branch"><strong>Git branch</strong></label>

              <div class="controls" id="branch">
                <select name="branch">
                  <option value="UNSET">=== Undefined ===</option>
                  <?php
                  //List all projects
                  $features = getFeatureBranches(array_keys(getRepositories()));
                  foreach ($features as $feature => $FBProjects) {
                    if ((!empty($descriptor_array->SCM_BRANCH) && $descriptor_array->SCM_BRANCH === $feature) || !in_array($feature, getFeatureBranches($features))) {
                      ?>
                      <option <?php if (!empty($descriptor_array->SCM_BRANCH) && $descriptor_array->SCM_BRANCH === $feature) {
                        echo "selected";
                      } ?>><?= $feature ?>
                      </option>
                      <?php
                    }
                  }
                  ?>
                </select>
                <span class="help-block">Git branch hosting this development</span>
              </div>
            </div>
          </div>
        </div>

      </div>
      <div class="modal-footer">
        <button class="btn" data-dismiss="modal" aria-hidden="true">Close</button>
        <button class="btn btn-primary">Save changes</button>
      </div>
    </div>
  </form>





  <form class="form" action="<?= $descriptor_array->ACCEPTANCE_SCHEME ?>://<?= $descriptor_array->ACCEPTANCE_HOST ?>:<?= $descriptor_array->ACCEPTANCE_PORT ?>/editInstance.php" method="POST">
    <div class="modal bigModal hide fade" id="edit-note-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>" tabindex="-1" role="dialog" aria-labelledby="label-<?= str_replace(".", "_", $descriptor_array->INSTANCE_KEY) ?>" aria-hidden="true">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
        <h3 id="label-<?= $descriptor_array->INSTANCE_KEY ?>">Edit Instance Note</h3>
      </div>
      <div class="modal-body">
        <input type="hidden" name="from" value="<?= currentPageURL() ?>">
        <input type="hidden" name="key" value="<?= $descriptor_array->INSTANCE_KEY ?>">

        <div class="row-fluid">
          <div class="span4"><strong>Product</strong></div>
          <div class="span8"><?= componentProductHtmlLabel($descriptor_array, true); ?></div>
        </div>
        <div class="row-fluid">
          <div class="span4"><strong>Version</strong></div>
          <div class="span8"><?= componentProductVersion($descriptor_array) ?></div>
        </div>
        <hr/>
        <div class="row-fluid">
          <div class="span12">
            <div class="control-group">
              <label class="control-label" for="description"><strong>Note</strong></label>
              <div class="controls">
                <input class="input-xxlarge" type="text" id="note" name="note" placeholder="Add a note" value="<?= ( empty($descriptor_array->INSTANCE_NOTE) ? "" : $descriptor_array->INSTANCE_NOTE ) ?>">
                <span class="help-block">Short note about this instance</span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn" data-dismiss="modal" aria-hidden="true">Close</button>
        <button class="btn btn-primary">Save changes</button>
      </div>
    </div>
  </form>
  <?php
    return ob_get_clean();
}
?>

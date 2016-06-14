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
                <div class="span8"><?php if (empty($descriptor_array->PRODUCT_DESCRIPTION)) echo $descriptor_array->PRODUCT_NAME; else echo $descriptor_array->PRODUCT_DESCRIPTION;?><?php if (!empty($descriptor_array->INSTANCE_ID)) echo " (" .$descriptor_array->INSTANCE_ID.")"; ?></div>
            </div>
            <div class="row-fluid">
                <div class="span4"><strong>Version</strong></div>
                <div class="span8"><?=$descriptor_array->BASE_VERSION?></div>
            </div>
            <hr/>
            <div class="row-fluid">
                <div class="span12">
                    <div class="control-group">
                        <label class="control-label" for="description"><strong>Note</strong></label>
                        <div class="controls">
                            <input class="input-xxlarge" type="text" id="note" name="note" placeholder="Add a note" value="<?= $descriptor_array->INSTANCE_NOTE ?>">
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

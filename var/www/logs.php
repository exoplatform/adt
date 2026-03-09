<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
$file_path = $_GET['file'];
$log_type = $_GET['type'];
checkCaches();
?>
<html>
<head>
<?= pageHeader("log visualization"); ?>
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
                    <?php
                        // Read file only if the type of file is ok.
                        if (isAuthorizedToReadFile($log_type, $file_path) == true){
                    ?>
                        <div class="card mb-4">
                            <div class="card-header">
                                <i class="fas fa-download me-2 text-success"></i>Download
                            </div>
                            <div class="card-body">
                                <p class="mb-0">Download file (<?php printf(human_filesize(filesize($file_path),0)); ?>) : 
                                    <a href="./logsDownload.php?type=<?=$log_type?>&file=<?=$file_path?>" target="_blank" class="btn btn-primary btn-sm">
                                        <i class="fas fa-download me-2"></i><?=$file_path?>
                                    </a>
                                </p>
                            </div>
                        </div>
                        <hr/>
                    <?php
                            if (isFileTooLargeToBeViewed($file_path)){
                                printf("<div class='alert alert-danger'><i class='fas fa-exclamation-triangle me-2'></i><strong>This file is too large to be viewed. Please download it.</strong></div>");
                            } else {
                                printf("<div class='code'><pre class='mb-0'>");
                                $data = file_get_contents($file_path);
                                echo htmlspecialchars($data, ENT_NOQUOTES, 'UTF-8');
                                printf("</pre></div>");
                            }
                        } else {
                            printf("<div class='alert alert-danger'><i class='fas fa-ban me-2'></i><strong>Not authorized to read this file.</strong></div>");
                        }
                   ?>
                </div>
            </div>
        </div>
        <!-- /container -->
    </div>
</div>
<?php pageFooter(); ?>
</body>
</html>
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
            <div class="row-fluid">
                <div class="span12">
                    <?php
                        // Read file only if the type of file is ok.
                        if (isAuthorizedToReadFile($log_type, $file_path) == true){
                    ?>
                        <div class="instructions">
                          Download file (<?php printf(human_filesize(filesize($file_path),0)); ?>) : <a target="_blank" href="./logsDownload.php?type=instance&file=<?=$file_path?>"><?=$file_path?></a>
                        </div>
                        <hr/>
                    <?php
                            if (isFileTooLargeToBeViewed($file_path)){
                                printf("<span style=\"color:red\"><strong>This file is too large to be viewed. Please download it.</strong></span>");
                            } else {
                                printf("<pre>");
                                $data = file_get_contents($file_path);
                                echo htmlspecialchars($data, ENT_NOQUOTES, 'UTF-8');
                                printf("</pre>");
                            }
                        } else {
                            printf("<span style=\"color:red\"><strong>Not authorized to read this file.</strong></span>");
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

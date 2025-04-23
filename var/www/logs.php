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
    <style>
        #log-output {
            background-color: #f8f8f8;
            border: 1px solid #ccc;
            padding: 10px;
            height: 600px;
            overflow-y: scroll;
            white-space: pre-wrap;
            font-family: monospace;
        }
    </style>
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
                            Download file (<?= human_filesize(filesize($file_path), 0); ?>) :
                            <a target="_blank" href="./logsDownload.php?type=<?= $log_type ?>&file=<?= $file_path ?>"><?= $file_path ?></a>
                        </div>
                        <hr/>
                        <?php
                        if (isFileTooLargeToBeViewed($file_path)){
                            echo "<span style=\"color:red\"><strong>This file is too large to be viewed. Please download it.</strong></span>";
                        } else {
                            ?>
                            <pre id="log-output">Loading logs...</pre>
                            <script>
                                let offset = 0;
                                const file = "<?= htmlspecialchars($file_path, ENT_QUOTES) ?>";
                                const type = "<?= htmlspecialchars($log_type, ENT_QUOTES) ?>";

                                function fetchLogs() {
                                    fetch(`logStream.php?file=${encodeURIComponent(file)}&type=${encodeURIComponent(type)}&offset=${offset}`)
                                        .then(response => response.json())
                                        .then(data => {
                                            const pre = document.getElementById('log-output');
                                            if (data.error) {
                                                pre.innerText += "\n[ERROR] " + data.error;
                                                return;
                                            }
                                            offset = data.offset;
                                            if (data.content) {
                                                pre.innerHTML += data.content;
                                                pre.scrollTop = pre.scrollHeight;
                                            }
                                        })
                                        .catch(err => {
                                            console.error("Log stream error:", err);
                                        });
                                }

                                setInterval(fetchLogs, 2000); // Poll every 2 seconds
                            </script>
                            <?php
                        }
                    } else {
                        echo "<span style=\"color:red\"><strong>Not authorized to read this file.</strong></span>";
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

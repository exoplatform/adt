<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
$file_path = $_GET['file'];
$log_type = $_GET['type'];
checkCaches();
?>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <title>Acceptance Live Instances</title>
    <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico"/>
    <link href="//netdna.bootstrapcdn.com/bootswatch/2.3.0/spacelab/bootstrap.min.css" rel="stylesheet">
    <link href="//netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css" rel="stylesheet">
    <link href="./style.css" media="screen" rel="stylesheet" type="text/css"/>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js" type="text/javascript"></script>
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js" type="text/javascript"></script>
    <script type="text/javascript">

        var _gaq = _gaq || [];
        _gaq.push(['_setAccount', 'UA-1292368-28']);
        _gaq.push(['_trackPageview']);

        (function () {
            var ga = document.createElement('script');
            ga.type = 'text/javascript';
            ga.async = true;
            ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
            var s = document.getElementsByTagName('script')[0];
            s.parentNode.insertBefore(ga, s);
        })();

    </script>
</head>
<body>
<!-- navbar ================================================== -->
<div class="navbar navbar-fixed-top">
    <div class="navbar-inner">
        <div class="container-fluid">
            <a class="brand" href="/"><?=$_SERVER['SERVER_NAME'] ?></a>
            <ul class="nav">
                <li><a href="/">Home</a></li>
                <li><a href="/features.php">Features</a></li>
                <li><a href="/servers.php">Servers</a></li>
            </ul>
        </div>
    </div>
</div>
<!-- /navbar -->
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
                                set_time_limit(0);
                                $file = @fopen($file_path,"rb");
                                while(!feof($file))
                                {
                                  print(@fread($file, 1024*8));
                                  ob_flush();
                                  flush();
                                }
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
<!-- Footer ================================================== -->
<div id="footer">Copyright © 2000-2016. All rights Reserved, eXo Platform SAS.</div>
</body>
</html>

<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/PHPGit/Repository.php');
?>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <meta http-equiv="refresh" content="120">
    <title>Acceptance Live Instances</title>
    <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico"/>
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.2.2/css/bootstrap-combined.min.css" type="text/css" rel="stylesheet" media="all">
    <link href="//netdna.bootstrapcdn.com/bootswatch/2.1.1/spacelab/bootstrap.min.css" type="text/css" rel="stylesheet" media="all">
    <link href="./style.css" media="screen" rel="stylesheet" type="text/css"/>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.3/jquery.min.js" type="text/javascript"></script>
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.2.2/js/bootstrap.min.js" type="text/javascript"></script>
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
            <a class="brand" href="#"><?=$_SERVER['SERVER_NAME'] ?></a>
            <ul class="nav">
                <li><a href="/">Home</a></li>
                <li class="active"><a href="/features.php">Features</a></li>
                <li><a href="/infos.php">Servers list</a></li>
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
                    function getDirectoryList($directory)
                    {
                        // create an array to hold directory list
                        $results = array();
                        // create a handler for the directory
                        $handler = opendir($directory);
                        // open directory and walk through the filenames
                        while ($file = readdir($handler)) {
                            // if file isn't this directory or its parent, add it to the results
                            if ($file != "." && $file != "..") {
                                $results[] = $file;
                            }
                        }
                        // tidy up: close the handler
                        closedir($handler);
                        // done!
                        return $results;
                    }
                    //List all repos
                    $repos = getDirectoryList($_SERVER['ADT_DATA'] . "/sources/");
                    ?>

                    <table class="table table-striped table-bordered table-hover">
                        <thead>
                        <tr>
                            <?php
                            foreach ($repos as $repoDirName) {
                                ?>
                                <th class="col-center"><?=$repoDirName?></th>
                            <?php
                            }
                            ?>
                        </tr>
                        </thead>
                        <tbody>
                        <tr>
                            <?php
                            foreach ($repos as $repoDirName) {
                                $repoObject = new PHPGit_Repository($_SERVER['ADT_DATA'] . "/sources/" . $repoDirName);
                                $branches = array_filter(preg_replace('/[\s\*]/', '', explode("\n", $repoObject->git('branch -r --list */feature/*'))));
                                ?>
                                <td>
                                    <?php
                                    foreach ($branches as $branch) {
                                        echo $branch . "<br/>";
                                    }
                                    ?>
                                </td>
                            <?php
                            }
                            ?>
                        </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        <!-- /container -->
    </div>
</div>
<!-- Footer ================================================== -->
<div id="footer">Copyright © 2000-2013. All rights Reserved, eXo Platform SAS.</div>
</body>
</html>

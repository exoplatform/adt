<!DOCTYPE html>
<?php
$file = $_GET['file'];
$num_latest = 30; //the number of errors to show in the "Last Few Errors" section
?>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <title>Acceptance Live Instances</title>
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.2.2/css/bootstrap-combined.min.css" type="text/css" rel="stylesheet" media="all">
    <link href="//netdna.bootstrapcdn.com/bootswatch/2.1.1/spacelab/bootstrap.min.css" type="text/css" rel="stylesheet" media="all">
    <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico"/>
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
                    <div class="instructions">File :
                        <?=$file?>
                    </div>
                    <?php
                    function mysort($a, $b)
                    {
                        if ($a[0] == $b[0]) {
                            return 0;
                        }
                        return ($a[0] > $b[0]) ? -1 : 1;
                    }

                    $handle = @fopen($file, "r");
                    if ($handle) {
                        $linenumber = 0;
                        while (!feof($handle)) {
                            $line = fgets($handle, 4096); //get line

                            if (empty($_GET['f']) || stristr($line, $_GET['f'])) {
                                //stores the last few errors reported
                                $latest[] = $line;
                                if (sizeof($latest) > 1 + $num_latest) array_shift($latest);

                                $linenumber = $linenumber + 1;

                                //figures out severity of error
                                $severity = 1;
                                // Tomcat/eXo warnings
                                if (strstr($line, "WARNING") !== FALSE) $severity = 2;
                                if (strstr($line, "WARN") !== FALSE) $severity = 2;
                                // Tomcat/eXo errors
                                if (strstr($line, "ERROR") !== FALSE) $severity = 3;
                                if (strstr($line, "SEVERE") !== FALSE) $severity = 3;
                                // Apache warnings 40x
                                if (preg_match("/^(\S+) (\S+) (\S+) \[([^:]+):(\d+:\d+:\d+) ([^\]]+)\] \"(\S+) (.*?) (\S+)\" 40[0-9] (\S+) (\".*?\") (\".*?\")$/", $line) > 0) $severity = 2;
                                // Apache errors 50x
                                if (preg_match("/^(\S+) (\S+) (\S+) \[([^:]+):(\d+:\d+:\d+) ([^\]]+)\] \"(\S+) (.*?) (\S+)\" 50[0-9] (\S+) (\".*?\") (\".*?\")$/", $line) > 0) $severity = 3;

                                $line = ereg_replace("[0-9]*-[a-zA-Z]*-[0-9]* [0-9]*:[0-9]*:[0-9]*", "", $line); //gets rid of timestamp
                                $line = str_replace("INFO: ", "", $line);
                                $line = str_replace("WARNING: ", "", $line);
                                $line = str_replace("ERROR: ", "", $line);
                                $line = str_replace("SEVERE: ", "", $line);
                                $line = str_replace("[INFO] ", "", $line);
                                $line = str_replace("[WARNING] ", "", $line);
                                $line = str_replace("[WARN] ", "", $line);
                                $line = str_replace("[ERROR] ", "", $line);

                                $hash = md5($line); //make a unique id for this error


                                if (!empty($line)) {
                                    if (empty($res[$severity][$hash])) { //stuff this error into an array or increment counter for existing error
                                        $res[$severity][$hash][0] = 1;
                                        $res[$severity][$hash][1] = $line;
                                        $res[$severity][$hash][2] = "<a href='logs.php?file=" . urlencode($file) . "#" . $linenumber . "'>" . $linenumber . "</a>";
                                        $res[$severity][$hash][3] = $file;
                                    } else {
                                        $res[$severity][$hash][0]++; //repeat error, so increment the existsing value
                                        $res[$severity][$hash][2] .= " <a href='logs.php?file=" . urlencode($file) . "#" . $linenumber . "'>" . $linenumber . "</a>";
                                    }
                                }
                            }
                        }
                        fclose($handle);

                        asort($res); //sort errors

                        if (!empty($num_latest)) {
                            echo "<div class='latest'><b>Last Few</b><br />";
                            if (!empty($latest) && is_array($latest)) {
                                foreach ($latest as $error) {
                                    echo "<p>" . $error . "</p>";
                                }
                            } else {
                                echo "none<br />";
                            }
                            echo "</div><br />";
                        }
                        ?>
                        <b>Key:</b> The first number is the frequency count (bigger number=worse error). This is followed by the error. The numbers at the ends are the line numbers at which the errors have occurred in your file. <br/>
                        <?php
                        echo "<div class='errors'><b>Errors</b><br />";
                        if (!empty($res[3]) && is_array($res[3])) {
                            usort($res[3], "mysort");
                            foreach ($res[3] as $error) {
                                echo "<p><b>" . $error[0] . "</b> " . $error[1] . " " . $error[2] . "</p>";
                            }
                        } else {
                            echo "none<br />";
                        }
                        echo "</div><br />";

                        echo "<div class='warnings'><b>Warnings</b><br />";
                        if (!empty($res[2]) && is_array($res[2])) {
                            usort($res[2], "mysort");
                            foreach ($res[2] as $error) {
                                echo "<p><b>" . $error[0] . "</b> " . $error[1] . " " . $error[2] . "</p>";
                            }
                        } else {
                            echo "none<br />";
                        }
                        echo "</div><br />";

                    } else {
                        echo "Couldn't read error file.";
                    }
                    ?>
                    <br/>
                    <br/>
            <pre class="linenums">
              <?php
                readfile($_GET['file']);
                ?>
            </pre>
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

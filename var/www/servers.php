<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
checkCaches();
?>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <meta http-equiv="refresh" content="120">
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
                <li class="active"><a href="/servers.php">Servers</a></li>
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
                    <table class="table table-striped table-bordered table-hover">
                        <thead>
                        <tr>
                            <th class="col-center" colspan="3">Product</th>
                            <th class="col-center" colspan="2">Deployment</th>
                            <th class="col-center" colspan="5">Ports</th>
                        </tr>
                        <tr>
                            <th class="col-center">Name</th>
                            <th class="col-center">Snapshot Version</th>
                            <th class="col-center">Feature Branch</th>
                            <th class="col-center">Server</th>
                            <th class="col-center">Status</th>
                            <th class="col-center">HTTP</th>
                            <th class="col-center">AJP</th>
                            <th class="col-center">Shutdown</th>
                            <th class="col-center">JMX RMI Registration</th>
                            <th class="col-center">JMX RMI Server</th>
                        </tr>
                        </thead>
                        <tbody>
                        <?php
                        $merged_list = getGlobalAcceptanceInstances();
                        $descriptor_arrays = array();
                        foreach ($merged_list as $tmp_array) {
                            $descriptor_arrays = array_merge($descriptor_arrays, $tmp_array);
                        }
                        function cmp($a, $b)
                        {
                            return strcmp($a->DEPLOYMENT_HTTP_PORT, $b->DEPLOYMENT_HTTP_PORT);
                        }
                        usort($descriptor_arrays, "cmp");
                        foreach ($descriptor_arrays as $descriptor_array) {
                            if ($descriptor_array->DEPLOYMENT_STATUS == "Up")
                                $status = "<img width=\"16\" height=\"16\" src=\"/images/green_ball.png\" alt=\"Up\"  class=\"left\"/>&nbsp;Up";
                            else
                                $status = "<img width=\"16\" height=\"16\" src=\"/images/red_ball.png\" alt=\"Down\"  class=\"left\"/>&nbsp;Down !";
                            $matches = array();
                            if (preg_match("/([^\-]*)\-(.*\-.*)\-SNAPSHOT/", $descriptor_array->PRODUCT_VERSION, $matches)) {
                                $base_version = $matches[1];
                                $feature_branch = $matches[2];
                            } elseif (preg_match("/(.*)\-SNAPSHOT/", $descriptor_array->PRODUCT_VERSION, $matches)) {
                                $base_version = $matches[1];
                                $feature_branch = "";
                            } else {
                                $base_version = $descriptor_array->PRODUCT_VERSION;
                                $feature_branch = "";
                            }
                            ?>
                            <tr>
                                <td><?php if (empty($descriptor_array->PRODUCT_DESCRIPTION)) echo $descriptor_array->PRODUCT_NAME; else echo $descriptor_array->PRODUCT_DESCRIPTION;?></td>
                                <td class="col-center"><?=$base_version?></td>
                                <td class="col-center"><?=$feature_branch?></td>
                                <?php
                                if ($descriptor_array->ACCEPTANCE_SERVER === "acceptance.exoplatform.org") {
                                    $host_html_color = "blue";
                                } else if ($descriptor_array->ACCEPTANCE_SERVER === "acceptance2.exoplatform.org") {
                                    $host_html_color = "green";
                                } else if ($descriptor_array->ACCEPTANCE_SERVER === "acceptance3.exoplatform.org") {
                                    $host_html_color = "orange";
                                } else {
                                    $host_html_color = "purple";
                                }
                                ?>
                                <td style="font-weight:bold;" class='col-center <?=$host_html_color?>'><?=$descriptor_array->ACCEPTANCE_SERVER?></td>
                                <td><?= $status ?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_HTTP_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_AJP_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_SHUTDOWN_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_RMI_REG_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_RMI_SRV_PORT?></td>
                            </tr>
                        <?php
                        }
                        ?>
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

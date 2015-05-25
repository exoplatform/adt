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
                            <th class="col-center" colspan="4">Product</th>
                            <th class="col-center" colspan="3">Deployment</th>
                            <th class="col-center" colspan="6">Ports</th>
                        </tr>
                        <tr>
                            <th class="col-center">Name</th>
                            <th class="col-center">Version</th>
                            <th class="col-center">Feature Branch</th>
                            <th class="col-center">Bundle</th>
                            <th class="col-center">Database</th>
                            <th class="col-center">Server</th>
                            <th class="col-center">Status</th>
                            <th class="col-center">Prefix</th>
                            <th class="col-center">HTTP</th>
                            <th class="col-center">AJP</th>
                            <th class="col-center">JMX RMI Registration</th>
                            <th class="col-center">JMX RMI Server</th>
                            <th class="col-center">CRaSH SSH</th>
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

                        $servers_counter = array();
                        foreach ($descriptor_arrays as $descriptor_array) {
                            // Compute the number of deployed instances per acceptance server
                            $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['nb']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['nb']+1;
                            // Compute the minimum amount of JVM size allocated per acceptance server
                            if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MIN,'g')) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']+str_replace('g','',$descriptor_array->DEPLOYMENT_JVM_SIZE_MIN);
                            } else if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MIN,'m')) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']+(str_replace('m','',$descriptor_array->DEPLOYMENT_JVM_SIZE_MIN)/1000);
                            } else {
                              throw new Exception("The unit of the DEPLOYMENT_JVM_SIZE_MIN is not manage (".$descriptor_array->DEPLOYMENT_JVM_SIZE_MIN.")");
                            }

                            // Compute the maximum amount of JVM size allocated per acceptance server
                            if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MAX,'g')) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']+str_replace('g','',$descriptor_array->DEPLOYMENT_JVM_SIZE_MAX);
                            } else if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MAX,'m')) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']+(str_replace('m','',$descriptor_array->DEPLOYMENT_JVM_SIZE_MAX)/1000);
                            } else {
                              throw new Exception("The unit of the DEPLOYMENT_JVM_SIZE_MAX is not manage (".$descriptor_array->DEPLOYMENT_JVM_SIZE_MAX.")");
                            }

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
                                <td><img src="/images/<?=$descriptor_array->DEPLOYMENT_APPSRV_TYPE?>.png" width="16" height="16" alt="<?=$descriptor_array->DEPLOYMENT_APPSRV_TYPE?> bundle" class="icon"/> <?php if (empty($descriptor_array->PRODUCT_DESCRIPTION)) echo $descriptor_array->PRODUCT_NAME; else echo $descriptor_array->PRODUCT_DESCRIPTION;?></td>
                                <td class="col-left"><?=$descriptor_array->PRODUCT_VERSION?></td>
                                <td class="col-right"><?=$feature_branch?></td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_APPSRV_TYPE?></td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_DATABASE_TYPE?></td>
                                <?php
                                if ($descriptor_array->ACCEPTANCE_HOST === "acceptance3.exoplatform.org") {
                                    $host_html_color = "color-acceptance3";
                                } else if ($descriptor_array->ACCEPTANCE_HOST === "acceptance4.exoplatform.org") {
                                    $host_html_color = "color-acceptance4";
                                } else if ($descriptor_array->ACCEPTANCE_HOST === "acceptance5.exoplatform.org") {
                                    $host_html_color = "color-acceptance5";
                                } else if ($descriptor_array->ACCEPTANCE_HOST === "acceptance6.exoplatform.org") {
                                    $host_html_color = "color-acceptance6";
                                } else {
                                    $host_html_color = "color-acceptanceX";
                                }
                                ?>
                                <td style="font-weight:bold;" class='col-right <?=$host_html_color?>'><?=$descriptor_array->ACCEPTANCE_HOST?></td>
                                <td class="col-left"><?= $status ?></td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_PORT_PREFIX?>xx</td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_HTTP_PORT?></td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_AJP_PORT?></td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_RMI_REG_PORT?></td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_RMI_SRV_PORT?></td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_CRASH_SSH_PORT?></td>
                            </tr>
                        <?php
                        }
                        ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        <div class="container-fluid">
          <div class="row-fluid">
            <div class="span12">
              <table class="table table-striped table-bordered table-hover">
                <thead>
                  <tr>
                    <th class="col-center">hostname</th>
                    <th class="col-center">server name</th>
                    <th class="col-center">deployment<br />count</th>
                    <th class="col-center">JVM size<br />allocated</th>
                    <th class="col-center">characteristics</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="col-center">acceptance3.exoplatform.org</td>
                    <td class="col-center">prj02</td>
                    <td class="col-center"><?=$servers_counter["acceptance3.exoplatform.org"]['nb']?></td>
                    <td class="col-center"><?=$servers_counter["acceptance3.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance3.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 64GB <br /> CPU = Xeon E5-1620 0 3.60GHz (4 cores + hyperthreading = 8 threads) <br /> Disks = 2 x 2TB (sda = ST2000DM001-9YN164 / sdb = ST2000DM001-9YN164)</td>
                  </tr>
                  <tr>
                    <td class="col-center">acceptance4.exoplatform.org</td>
                    <td class="col-center">prd02</td>
                    <td class="col-center"><?=$servers_counter["acceptance4.exoplatform.org"]['nb']?></td>
                    <td class="col-center"><?=$servers_counter["acceptance4.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance4.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 24GB <br /> CPU = Xeon W3530 2.80GHz (4 cores + hyperthreading = 8 threads) <br /> Disks = 2 x 2TB (sda = Hitachi HDS723020BLE640 / sdb = Hitachi HDS723020BLE640)</td>
                  </tr>
                  <tr>
                    <td class="col-center">acceptance5.exoplatform.org</td>
                    <td class="col-center">prj03</td>
                    <td class="col-center"><?=$servers_counter["acceptance5.exoplatform.org"]['nb']?></td>
                    <td class="col-center"><?=$servers_counter["acceptance5.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance5.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 128GB <br /> CPU = Xeon W3530 2.80GHz (6 cores + hyperthreading = 12 threads) <br /> Disks = 2 x 2TB (sda = HGST HUS724020ALA640 / sdb = HGST HUS724020ALA640)</td>
                  </tr>
                  <tr>
                    <td class="col-center">acceptance6.exoplatform.org</td>
                    <td class="col-center">prd03</td>
                    <td class="col-center"><?=$servers_counter["acceptance6.exoplatform.org"]['nb']?></td>
                    <td class="col-center"><?=$servers_counter["acceptance6.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance6.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 128GB <br /> CPU = Xeon E5-1650 v2 @ 3.50GHz (6 cores + hyperthreading = 12 threads) <br /> Disks = 2 x 2TB (sda = HGST HUS724020ALA640 / sdb = HGST HUS724020ALA640)</td>
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
<div id="footer">Copyright © 2000-2015. All rights Reserved, eXo Platform SAS.</div>
</body>
</html>

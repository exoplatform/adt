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
                <li class="active"><a href="/sales.php">Sales</a></li>
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
<p>These instances are deployed eXo Sales team usage only.</p>
<table class="table table-bordered table-hover">
<thead>
<tr>
    <th class="col-center">Status</th>
    <th class="col-center">Name</th>
    <th class="col-center">Version</th>
    <th class="col-center" colspan="3">Characteristics</th>
</tr>
</thead>
<tbody>
<?php
$all_instances = getGlobalSalesInstances();
foreach ($all_instances as $plf_branch => $descriptor_arrays) {
    ?>
    <tr>
        <td colspan="15" style="background-color: #363636; color: #FBAD18; letter-spacing:2px">
            <?php
            echo "Platform " . $plf_branch . " demo environment for Sales";
            ?>
        </td>
    </tr>
    <?php
    foreach ($descriptor_arrays as $descriptor_array) {
        if ($descriptor_array->DEPLOYMENT_STATUS == "Up")
            $status = "<img width=\"16\" height=\"16\" src=\"/images/green_ball.png\" alt=\"Up\"  class=\"left icon\"/>";
        else
            $status = "<img width=\"16\" height=\"16\" src=\"/images/red_ball.png\" alt=\"Down\"  class=\"left icon\"/>";
        ?>
        <tr>
            <td class="col-center"><?= $status ?></td>
            <td>
                <?php
                $product_html_label = "-UNSET-";
                if (empty($descriptor_array->PRODUCT_DESCRIPTION)) {
                    $product_html_label = $descriptor_array->PRODUCT_NAME;
                } else {
                    $product_html_label = $descriptor_array->PRODUCT_DESCRIPTION;
                }
                if (!empty($descriptor_array->INSTANCE_ID)) {
                    $product_html_label = $product_html_label . " (" . $descriptor_array->INSTANCE_ID . ")";
                }
                if (!empty($descriptor_array->BRANCH_DESC)) {
                    $product_html_label = "<span class=\"muted\">" . $product_html_label . "</span>&nbsp;&nbsp;-&nbsp&nbsp&nbsp" . $descriptor_array->BRANCH_DESC;
                }
                if (!empty($descriptor_array->INSTANCE_NOTE)) {
                    $product_html_label = "<span class=\"muted\">" . $product_html_label . "</span>&nbsp;&nbsp;-&nbsp&nbsp&nbsp" . $descriptor_array->INSTANCE_NOTE;
                }

                $product_deployment_url = "-UNSET-";
                if ($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) {
                    $product_deployment_url = "http://" . $descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS;
                    $product_deployment_url_icon_color = "green";
                } else {
                    $product_deployment_url = $descriptor_array->DEPLOYMENT_URL;
                    $product_deployment_url_icon_color = "";
                }

                $product_html_popover = "<strong>Product:</strong> " . $product_html_label . "<br/>";
                $product_html_popover = $product_html_popover . "<strong>Version:</strong> " . $descriptor_array->PRODUCT_VERSION . "<br/>";
                $product_html_popover = $product_html_popover . "<strong>Packaging:</strong> " . $descriptor_array->DEPLOYMENT_APPSRV_TYPE . " <img src=\"/images/" . $descriptor_array->DEPLOYMENT_APPSRV_TYPE . ".png\" width=\"16\" height=\"16\" alt=\"" . $descriptor_array->DEPLOYMENT_APPSRV_TYPE . " bundle\" class=\"icon\"/> <br/>";
                $product_html_popover = $product_html_popover . "<strong>Database:</strong> " . $descriptor_array->DATABASE . "<br/>";
                $product_html_popover = $product_html_popover . "<strong>Visibility:</strong> " . $descriptor_array->DEPLOYMENT_APACHE_SECURITY;
                if ($descriptor_array->DEPLOYMENT_APACHE_SECURITY === "public") {
                    $product_deployment_url_icon_type = "icon-globe";
                } else if ($descriptor_array->DEPLOYMENT_APACHE_SECURITY === "private") {
                    $product_deployment_url_icon_type = "icon-lock";
                } else {
                    // should never occurs
                    $product_deployment_url_icon_type = "icon-question-sign";
                }
                $product_html_popover = $product_html_popover . " <i class=\"" . $product_deployment_url_icon_type . "\"></i>";
                $product_html_popover = $product_html_popover . "<br/><strong>HTTPS available:</strong> " . ($descriptor_array->DEPLOYMENT_APACHE_HTTPS_ENABLED ? "yes" : "no");
                //SWF-3125: Use Apache version to know if WebSocket can be enabled.
                $product_html_popover = $product_html_popover . "<br/><strong>WebSocket available:</strong> " . ((strcmp($descriptor_array->ACCEPTANCE_APACHE_VERSION_MINOR, "2.4") == 0 && $descriptor_array->DEPLOYMENT_APACHE_WEBSOCKET_ENABLED) ? "yes" : "no");
                $product_html_popover = $product_html_popover . "<br/><strong>Deployed extensions:</strong> " . $descriptor_array->DEPLOYMENT_EXTENSIONS;
                $product_html_popover = $product_html_popover . "<br/><strong>Deployed add-ons:</strong> " . $descriptor_array->DEPLOYMENT_ADDONS;
                $product_html_popover = $product_html_popover . "<br/><strong>Virtual Host:</strong> " . preg_replace("/https?:\/\/(.*)/", "$1", $descriptor_array->DEPLOYMENT_URL);
                if ($descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS) {
                    $product_html_popover = $product_html_popover . "<br/><strong>Virtual Host Alias:</strong> " . $descriptor_array->DEPLOYMENT_APACHE_VHOST_ALIAS;
                }
                if ($descriptor_array->DEPLOYMENT_INFO) {
                    $product_html_popover = $product_html_popover . "<hr/><strong>Info:</strong> " . $descriptor_array->DEPLOYMENT_INFO;
                }
                $product_html_popover = $product_html_popover . "<br/>";
                $product_html_popover = htmlentities($product_html_popover);
                ?>
                <a href="<?= $product_deployment_url ?>" target="_blank" title="Open the instance in a new window">
                    <?= $product_html_label ?>
                </a>
                <?php if ($descriptor_array->DEPLOYMENT_APACHE_HTTPS_ENABLED) { ?>
                    &nbsp;(<a rel="tooltip" title="HTTPS link available" href="<?= preg_replace("/http:(.*)/", "https:$1", $product_deployment_url) ?>" target="_blank">&nbsp;<img src="/images/ssl.png" width="16" height="16" alt="SSL" class="icon"/></a>)
                <?php } ?>
                <a class="pull-right" href="https://ci.exoplatform.org/job/platform-enterprise-trial-<?= $descriptor_array->PLF_BRANCH ?>-<?= $descriptor_array->INSTANCE_ID ?>-deploy-acc/build" target="_blank">
                    <i class="icon-refresh"></i>&nbsp;(restart or reset data)&nbsp;
                </a>
            </td>
            <td class="col-center">
                <a rel="popover" data-content="<?= $product_html_popover ?>" data-html="true"><i class="icon-info-sign"></i></a>
                &nbsp;<?= $descriptor_array->BASE_VERSION ?>
                <span style="font-size: small" class="muted">
                    <?= substr_replace($descriptor_array->ARTIFACT_TIMESTAMP, "", 0, strlen($descriptor_array->BASE_VERSION)) ?>
                </span>
                <a href="<?= $descriptor_array->ARTIFACT_DL_URL ?>" rel="popover" title="Download artifact from Acceptance"
                   data-content="<strong>GroupId:</strong> <?= $descriptor_array->ARTIFACT_GROUPID ?><br/>
                   <strong>ArtifactId:</strong> <?= $descriptor_array->ARTIFACT_ARTIFACTID ?><br/>
                   <strong>Version/Timestamp:</strong> <?= $descriptor_array->ARTIFACT_TIMESTAMP ?>"
                   data-html="true">
                    <i class="icon-download-alt"></i>
                </a>
            </td>
            <td class="col-right">deployed <?= $descriptor_array->DEPLOYMENT_AGE_STRING ?></td>
            <td class="col-center">
                <?php if (stripos($descriptor_array->DATABASE, 'mysql') !== false) {
                    $database_icon = "mysql";
                } else if (stripos($descriptor_array->DATABASE, 'postgres') !== false) {
                    $database_icon = "postgresql";
                } else if (stripos($descriptor_array->DATABASE, 'oracle') !== false) {
                    $database_icon = "oracle";
                } else if (stripos($descriptor_array->DATABASE, 'sqlserver') !== false) {
                    $database_icon = "sqlserver";
                } else {
                    $database_icon = "none";
                }
                if ($database_icon != "none") { ?>
                    <img src="/images/<?= $database_icon ?>.png" witdh="8" height="8" alt="<?= $database_icon ?>">
                    <?php
                } ?>
                <?= ( empty($descriptor_array->DEPLOYMENT_DATABASE_VERSION) ? "-NC-" : $descriptor_array->DEPLOYMENT_DATABASE_VERSION ) ?>
            </td>
            <td class="col-center">
                <a href="<?= $descriptor_array->DEPLOYMENT_LOG_APPSRV_URL ?>" rel="tooltip" title="Instance logs" target="_blank">
                    <img src="/images/<?= $descriptor_array->DEPLOYMENT_APPSRV_TYPE ?>.png" width="16" height="16" alt="instance logs" class="icon"/>
                </a> |
                <a href="<?= $descriptor_array->DEPLOYMENT_LOG_APACHE_URL ?>" rel="tooltip" title="apache logs" target="_blank">
                    <img src="/images/apache.png" width="16" height="16" alt="apache logs" class="icon"/>
                </a> |
                <a href="<?= $descriptor_array->DEPLOYMENT_AWSTATS_URL ?>" rel="tooltip" title="Usage statistics" target="_blank">
                    <img src="/images/server_chart.png" alt="<?= $descriptor_array->DEPLOYMENT_URL ?> usage statistics" width="16" height="16" class="icon"/>
                </a>
            </td>
        </tr>
    <?php
    }
    next($all_instances);
}
?>
</tbody>
</table>
<p>Each instance can be accessed using JMX with the URL linked to the monitoring icon and these credentials : <strong><code>acceptanceMonitor</code></strong> / <strong><code>monitorAcceptance!</code></strong></p>

<p><a href="/stats/awstats.pl?config=<?= $_SERVER['SERVER_NAME'] ?>" title="http://<?= $_SERVER['SERVER_NAME'] ?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="Statistics" width="16" height="16" class="left icon"/>http://<?=$_SERVER['SERVER_NAME'] ?> usage statistics</a></p>
</div>
</div>
</div>
<!-- /container -->
</div>
</div>
<!-- Footer ================================================== -->
<div id="footer">Copyright © 2000-2016. All rights Reserved, eXo Platform SAS.</div>
<script type="text/javascript">
    $(document).ready(function () {
        $('body').tooltip({ selector: '[rel=tooltip]'});
        $('body').popover({ selector: '[rel=popover]', trigger: 'hover'});
    });
</script>

</body>
</html>

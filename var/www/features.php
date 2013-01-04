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
            <a class="brand" href="/"><?=$_SERVER['SERVER_NAME'] ?></a>
            <ul class="nav">
                <li><a href="/">Home</a></li>
                <li class="active"><a href="/features.php">Features</a></li>
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
                    <p>This page summarizes all Git feature branches (<code>feature/*</code>) and their status compared to each project <code>master</code> branch.</p>

                    <h3>Branches deployed on acceptance</h3>
                    <?php
                    //List all projects
                    $projects = getProjects();
                    $features = getFeatureBranches();
                    ?>
                    <table class="table table-bordered table-hover">
                        <thead>
                        <tr>
                            <th class="col-center">Branch feature/*</th>
                            <?php foreach ($projects as $project) { ?>
                                <th class="col-center"><?=$project?></th>
                            <?php } ?>
                        </tr>
                        </thead>
                        <tbody>
                        <?php
                        foreach ($features as $feature => $FBProjects) {
                            if (in_array($feature, getAcceptanceBranches())) {
                                ?>
                                <tr>
                                    <td><a name="<?=str_replace(array("/", "."), "-", $feature)?>"/><a href="<?=currentPageURL() . "#" . str_replace(array("/", "."), "-", $feature)?>"><i class="icon-bookmark"></i></a>&nbsp;<?=$feature?></td>
                                    <?php foreach ($projects as $project) { ?>
                                        <td class="col-center">
                                            <?php if (array_key_exists($project, $FBProjects)) { ?>
                                                <a href="<?=$FBProjects[$project]['http_url']?>" target="_blank" title="Repository URL"><?php if ($FBProjects[$project]['behind_commits'] > 0) { ?><span class="label label-important"><?= $FBProjects[$project]['behind_commits'] ?> behind</span><?php } else { ?><?= $FBProjects[$project]['behind_commits'] ?> behind<?php }?>&nbsp;<?php if ($FBProjects[$project]['ahead_commits'] > 0) { ?><span class="label label-info"><?= $FBProjects[$project]['ahead_commits'] ?> ahead</span><?php } else { ?><?= $FBProjects[$project]['ahead_commits'] ?> ahead<?php }?></a>
                                            <?php }?>
                                        </td>
                                    <?php } ?>
                                </tr>
                            <?php
                            }
                        } ?>
                        </tbody>
                    </table>
                    <h3>Others branches</h3>
                    <table class="table table-bordered table-hover">
                        <thead>
                        <tr>
                            <th class="col-center">Branch feature/*</th>
                            <?php foreach ($projects as $project) { ?>
                                <th class="col-center"><?=$project?></th>
                            <?php } ?>
                        </tr>
                        </thead>
                        <tbody>
                        <?php
                        foreach ($features as $feature => $FBProjects) {
                            if (!in_array($feature, getAcceptanceBranches())) {
                                ?>
                                <tr>
                                    <td><a name="<?=str_replace(array("/", "."), "-", $feature)?>"/><a href="<?=currentPageURL() . "#" . str_replace(array("/", "."), "-", $feature)?>"><i class="icon-bookmark"></i></a>&nbsp;<?=$feature?></td>
                                    <?php foreach ($projects as $project) { ?>
                                        <td class="col-center">
                                            <?php if (array_key_exists($project, $FBProjects)) { ?>
                                                <a href="<?=$FBProjects[$project]['http_url']?>" target="_blank" title="Repository URL"><?php if ($FBProjects[$project]['behind_commits'] > 0) { ?><span class="label label-important"><?= $FBProjects[$project]['behind_commits'] ?> behind</span><?php } else { ?><?= $FBProjects[$project]['behind_commits'] ?> behind<?php }?>&nbsp;<?php if ($FBProjects[$project]['ahead_commits'] > 0) { ?><span class="label label-info"><?= $FBProjects[$project]['ahead_commits'] ?> ahead</span><?php } else { ?><?= $FBProjects[$project]['ahead_commits'] ?> ahead<?php }?></a>
                                            <?php }?>
                                        </td>
                                    <?php } ?>
                                </tr>
                            <?php
                            }
                        } ?>
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

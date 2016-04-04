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

        $(document).ready(function () {
            var ga = document.createElement('script');
            ga.type = 'text/javascript';
            ga.async = true;
            ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
            var s = document.getElementsByTagName('script')[0];
            s.parentNode.insertBefore(ga, s);
            $("tr").on("click", function (event) {
                $(this).addClass('highlight').siblings().removeClass('highlight');
            });
            if (window.location.hash.length > 0) {
                $trSelector = "a[name=" + window.location.hash.substring(1, window.location.hash.length) + "]";
                $($trSelector).parents('tr').addClass('highlight').siblings().removeClass('highlight');
            }
        });
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
                    <p>This page summarizes all Git feature branches (<code>feature/.*</code>) and try to give an overview of branches health.</p>

                    <h3>Feature Branches deployed on acceptance <span class="subtitle">(status compared to each project <code>develop</code> branch.)</span></h3>
                    <?php
                    //List all projects
                    $projectsNames = getRepositories();
                    $projects = array_keys(getRepositories());
                    $features = getFeatureBranches($projects);
                    $translations = getTranslationBranches($projects);
                    ?>
                    <table class="table table-bordered table-hover">
                        <thead>
                        <tr>
                            <th class="col-center">Branch feature/.*</th>
                            <?php foreach ($projects as $project) { ?>
                                <th class="col-center"><?=$projectsNames[$project]?></th>
                            <?php } ?>
                        </tr>
                        </thead>
                        <tbody>
                        <?php
                        foreach ($features as $feature => $FBProjects) {
                            if (in_array($feature, getAcceptanceBranches()) && ! isTranslation ($feature)) {
                                ?>
                                <tr>
                                    <td><a name="<?=str_replace(array("/", "."), "-", $feature)?>"/><a href="<?=currentPageURL() . "#" . str_replace(array("/", "."), "-", $feature)?>"><i class="icon-bookmark"></i></a>&nbsp;<?=$feature?></td>
                                    <?php foreach ($projects as $project) { ?>
                                        <td class="col-center">
                                            <?php if (array_key_exists($project, $FBProjects)) { ?>
                                              <a href="<?=$FBProjects[$project]['http_url']?>" target="_blank" title="Sources"><span rel="tooltip" title="<?=$FBProjects[$project]['behind_commits']?> commits on the base branch that do not exist on this branch [behind]"><?php if ($FBProjects[$project]['behind_commits'] > 0) { ?><span class="label label-important"><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down icon-white"></i></span><?php } else { ?><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down"></i><?php }?></span>&nbsp;<span rel="tooltip" title="<?=$FBProjects[$project]['ahead_commits']?> commits on this branch that do not exist on the base branch [ahead]"><?php if ($FBProjects[$project]['ahead_commits'] > 0) { ?><span class="label label-info"><i class="icon-arrow-up icon-white"></i> <?= $FBProjects[$project]['ahead_commits'] ?></span><?php } else { ?><i class="icon-arrow-up"></i> <?= $FBProjects[$project]['ahead_commits'] ?><?php }?></span></a><br/>
                                              <a href='https://ci.exoplatform.org/job/<?=$project?>-<?=$feature?>-fb-ci/' target="_blank" title="CI" rel="tooltip" title="Continuous integration job"><img src='https://ci.exoplatform.org/buildStatus/icon?job=<?=$project?>-<?=$feature?>-fb-ci'></a>
                                            <?php }?>
                                        </td>
                                    <?php } ?>
                                </tr>
                            <?php
                            }
                        } ?>
                        </tbody>
                    </table>
                    <h3>Translation Branches deployed on acceptance <span class="subtitle">(status compared to each project <code>develop</code> branch.)</span></h3>
                    <table class="table table-bordered table-hover">
                        <thead>
                        <tr>
                            <th class="col-center">Branch integration/[^/]*translation.*</th>
                            <?php foreach ($projects as $project) { ?>
                                <th class="col-center"><?=$projectsNames[$project]?></th>
                            <?php } ?>
                        </tr>
                        </thead>
                        <tbody>
                        <?php
                        foreach ($translations as $translation => $FBProjects) { ?>
                            <tr>
                                <td><a name="<?=str_replace(array("/", "."), "-", $translation)?>"/><a href="<?=currentPageURL() . "#" . str_replace(array("/", "."), "-", $translation)?>"><i class="icon-bookmark"></i></a>&nbsp;<?=$translation?>
                                <a href='https://ci.exoplatform.org/job/platform-integration-<?=$translation?>-ci/' class="pull-right" target="_blank" title="CI" rel="tooltip" title="Continuous integration job"><img src='https://ci.exoplatform.org/buildStatus/icon?job=platform-integration-<?=$translation?>-ci'></a></td>
                                <?php foreach ($projects as $project) { ?>
                                    <td class="col-center">
                                        <?php if (array_key_exists($project, $FBProjects)) { ?>
                                          <a href="<?=$FBProjects[$project]['http_url']?>" target="_blank" title="Sources"><span rel="tooltip" title="<?=$FBProjects[$project]['behind_commits']?> commits on the base branch that do not exist on this branch [behind]"><?php if ($FBProjects[$project]['behind_commits'] > 0) { ?><span class="label label-important"><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down icon-white"></i></span><?php } else { ?><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down"></i><?php }?></span>&nbsp;<span rel="tooltip" title="<?=$FBProjects[$project]['ahead_commits']?> commits on this branch that do not exist on the base branch [ahead]"><?php if ($FBProjects[$project]['ahead_commits'] > 0) { ?><span class="label label-info"><i class="icon-arrow-up icon-white"></i> <?= $FBProjects[$project]['ahead_commits'] ?></span><?php } else { ?><i class="icon-arrow-up"></i> <?= $FBProjects[$project]['ahead_commits'] ?><?php }?></span></a>
                                        <?php }?>
                                    </td>
                                <?php } ?>
                            </tr>
                        <?php } ?>
                        </tbody>
                    </table>
                    <h3>Others branches ... <span class="subtitle">(status compared to each project <code>develop</code> branch.)</span><br/>ARE YOU SURE YOU DON'T NEED TO DO SOME BRANCH CLEANUP ? </h3>
                    <table class="table table-bordered table-hover">
                        <thead>
                        <tr>
                            <th class="col-center">Branch feature/????</th>
                            <?php foreach ($projects as $project) { ?>
                                <th class="col-center"><?=$projectsNames[$project]?></th>
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
                                                <a href="<?=$FBProjects[$project]['http_url']?>" target="_blank" title="GitHub" ><span rel="tooltip" title="<?=$FBProjects[$project]['behind_commits']?> commits on the base branch that do not exist on this branch [behind]"><?php if ($FBProjects[$project]['behind_commits'] > 0) { ?><span class="label label-important"><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down icon-white"></i></span><?php } else { ?><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down"></i><?php }?></span>&nbsp;<span rel="tooltip" title="<?=$FBProjects[$project]['ahead_commits']?> commits on this branch that do not exist on the base branch [ahead]"><?php if ($FBProjects[$project]['ahead_commits'] > 0) { ?><span class="label label-info"><i class="icon-arrow-up icon-white"></i> <?= $FBProjects[$project]['ahead_commits'] ?></span><?php } else { ?><i class="icon-arrow-up"></i> <?= $FBProjects[$project]['ahead_commits'] ?><?php }?></span></a>
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
<div id="footer">Copyright © 2000-2016. All rights Reserved, eXo Platform SAS.</div>
<script type="text/javascript">
    $(document).ready(function () {
        $('body').tooltip({ selector: '[rel=tooltip]'});
    });
</script>
</body>
</html>

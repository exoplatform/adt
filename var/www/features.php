<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/PHPGit/Repository.php');
require_once(dirname(__FILE__) . '/lib/functions.php');
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
        var shiftWindow = function () {
            scrollBy(0, -50)
        };
        if (location.hash) shiftWindow();
        window.addEventListener("hashchange", shiftWindow);
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
                    <?php
                    $dataDirectory = getenv('ADT_DATA');
                    // Default projects order
                    $i = 0;
                    $project["commons"] = $i++;
                    $project["ecms"] = $i++;
                    $project["social"] = $i++;
                    $project["forum"] = $i++;
                    $project["wiki"] = $i++;
                    $project["calendar"] = $i++;
                    $project["integration"] = $i++;
                    $project["platform"] = $i++;
                    $project["platform-tomcat-standalone"] = $i++;
                    //List all repos
                    $repos = getGitDirectoriesList($dataDirectory . "/sources/");
                    usort($repos, "sortProjects");
                    $features = array();
                    foreach ($repos as $repoDirName) {
                        $repoObject = new PHPGit_Repository($dataDirectory . "/sources/" . $repoDirName);
                        $branches = array_filter(preg_replace('/.*\/feature\//', '', array_filter(explode("\n", $repoObject->git('branch -r')), 'isFeature')));
                        foreach ($branches as $branch) {
                            $fetch_url = $repoObject->git('config --get remote.origin.url');
                            if (preg_match("/git:\/\/github\.com\/(.*)\/(.*)\.git/", $fetch_url, $matches)) {
                                $github_org = $matches[1];
                                $github_repo = $matches[2];
                            }
                            $features[$branch][$repoDirName]['http_url'] = "https://github.com/" . $github_org . "/" . $github_repo . "/tree/feature/" . $branch;
                            $behind_commits_logs = $repoObject->git("log origin/feature/" . $branch . "..origin/master --oneline");
                            if (empty($behind_commits_logs))
                                $features[$branch][$repoDirName]['behind_commits'] = 0;
                            else
                                $features[$branch][$repoDirName]['behind_commits'] = count(explode("\n", $behind_commits_logs));
                            $ahead_commits_logs = $repoObject->git("log origin/master..origin/feature/" . $branch . " --oneline");
                            if (empty($ahead_commits_logs))
                                $features[$branch][$repoDirName]['ahead_commits'] = 0;
                            else
                                $features[$branch][$repoDirName]['ahead_commits'] = count(explode("\n", $ahead_commits_logs));
                        }
                    }
                    uksort($features, 'strcasecmp');
                    ?>
                    <table class="table table-bordered table-hover">
                        <thead>
                        <tr>
                            <th class="col-center">Branch feature/*</th>
                            <?php foreach ($repos as $repoDirName) { ?>
                                <th class="col-center"><?=substr($repoDirName, 0, -4)?></th>
                            <?php } ?>
                        </tr>
                        </thead>
                        <tbody>
                        <?php foreach ($features as $feature => $projects) { ?>
                            <tr>
                                <td><a name="<?=str_replace(array("/", "."), "-", $feature)?>"/><a href="<?=currentPageURL() . "#" . str_replace(array("/", "."), "-", $feature)?>"><i class="icon-bookmark"></i></a>&nbsp;<?=$feature?></td>
                                <?php foreach ($repos as $repoDirName) { ?>
                                    <td class="col-center">
                                        <?php if (array_key_exists($repoDirName, $projects)) { ?>
                                            <a href="<?=$projects[$repoDirName]['http_url']?>" target="_blank" title="Repository URL"><?php if ($projects[$repoDirName]['behind_commits'] > 0) { ?><span class="label label-important"><?= $projects[$repoDirName]['behind_commits'] ?> behind</span><?php } else { ?><?= $projects[$repoDirName]['behind_commits'] ?> behind<?php }?>&nbsp;<?php if ($projects[$repoDirName]['ahead_commits'] > 0) { ?><span class="label label-info"><?= $projects[$repoDirName]['ahead_commits'] ?> ahead</span><?php } else { ?><?= $projects[$repoDirName]['ahead_commits'] ?> ahead<?php }?></a>
                                        <?php }?>
                                    </td>
                                <?php } ?>
                            </tr>
                        <?php } ?>
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

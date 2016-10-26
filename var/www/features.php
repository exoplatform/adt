<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader("features"); ?>
    <script type="text/javascript">
        $(document).ready(function () {
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
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
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
                                              <a href="<?=$FBProjects[$project]['http_url_behind']?>" target="_blank" title="[behind]"><span rel="tooltip" title="<?=$FBProjects[$project]['behind_commits']?> commits on the base branch that do not exist on this branch [behind]"><?php if ($FBProjects[$project]['behind_commits'] > 0) { ?><span class="label label-important"><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down icon-white"></i></span><?php } else { ?><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down"></i><?php }?>
                                              </span><a>
                                              &nbsp;
                                              <a href="<?=$FBProjects[$project]['http_url_ahead']?>" target="_blank" title="[ahead]"><span rel="tooltip" title="<?=$FBProjects[$project]['ahead_commits']?> commits on this branch that do not exist on the base branch [ahead]"><?php if ($FBProjects[$project]['ahead_commits'] > 0) { ?><span class="label label-info"><i class="icon-arrow-up icon-white"></i> <?= $FBProjects[$project]['ahead_commits'] ?></span><?php } else { ?><i class="icon-arrow-up"></i> <?= $FBProjects[$project]['ahead_commits'] ?><?php }?></span></a><br/>
                                              <a href='https://ci.exoplatform.org/job/FB/job/<?=$project?>-<?=$feature?>-fb-ci/' target="_blank" title="CI" rel="tooltip" title="Continuous integration job"><img src='https://ci.exoplatform.org/buildStatus/icon?job=fb/<?=$project?>-<?=$feature?>-fb-ci'></a>
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
                                          <a href="<?=$FBProjects[$project]['http_url_behind']?>" target="_blank" title="[behind]"><span rel="tooltip" title="<?=$FBProjects[$project]['behind_commits']?> commits on the base branch that do not exist on this branch [behind]"><?php if ($FBProjects[$project]['behind_commits'] > 0) { ?><span class="label label-important"><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down icon-white"></i></span><?php } else { ?><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down"></i><?php }?>
                                          </span><a>
                                          &nbsp;
                                          <a href="<?=$FBProjects[$project]['http_url_ahead']?>" target="_blank" title="[ahead]"><span rel="tooltip" title="<?=$FBProjects[$project]['ahead_commits']?> commits on this branch that do not exist on the base branch [ahead]"><?php if ($FBProjects[$project]['ahead_commits'] > 0) { ?><span class="label label-info"><i class="icon-arrow-up icon-white"></i> <?= $FBProjects[$project]['ahead_commits'] ?></span><?php } else { ?><i class="icon-arrow-up"></i> <?= $FBProjects[$project]['ahead_commits'] ?><?php }?></span></a>
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
                                              <a href="<?=$FBProjects[$project]['http_url_behind']?>" target="_blank" title="[behind]"><span rel="tooltip" title="<?=$FBProjects[$project]['behind_commits']?> commits on the base branch that do not exist on this branch [behind]"><?php if ($FBProjects[$project]['behind_commits'] > 0) { ?><span class="label label-important"><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down icon-white"></i></span><?php } else { ?><?= $FBProjects[$project]['behind_commits'] ?> <i class="icon-arrow-down"></i><?php }?>
                                              </span><a>
                                              &nbsp;
                                              <a href="<?=$FBProjects[$project]['http_url_ahead']?>" target="_blank" title="[ahead]"><span rel="tooltip" title="<?=$FBProjects[$project]['ahead_commits']?> commits on this branch that do not exist on the base branch [ahead]"><?php if ($FBProjects[$project]['ahead_commits'] > 0) { ?><span class="label label-info"><i class="icon-arrow-up icon-white"></i> <?= $FBProjects[$project]['ahead_commits'] ?></span><?php } else { ?><i class="icon-arrow-up"></i> <?= $FBProjects[$project]['ahead_commits'] ?><?php }?></span></a>
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
<?php pageFooter(); ?>
</body>
</html>

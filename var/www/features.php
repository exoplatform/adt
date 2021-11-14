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

                    <h3>Feature Branches <u>deployed on acceptance</u> <span class="subtitle">(status compared to each project <code>develop</code> branch.)</span></h3>
                    <!--<?php
                    //List all projects
                    $projectsNames = getRepositories();
                    $projects = array_keys(getRepositories());
                    $features = getFeatureBranches($projects);
                    $translations = getTranslationBranches($projects);
                    ?>
                    <table class="table table-hover table-header-rotated">
                        <thead>
                        <tr>
                            <th class="col-left"><div><span>feature/.*</span></div></th>
                            <?php foreach ($projects as $project) { ?>
                                <th class="col-center rotate-45"><div><span><?=$projectsNames[$project]?></span></div></th>
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
                                                <?= componentFeatureRepoBrancheStatus($FBProjects[$project]);?>
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
                    <table class="table table-hover table-header-rotated">
                        <thead>
                        <tr>
                            <th class="col-left">integration/.*translation.*</th>
                            <?php foreach ($projects as $project) { ?>
                                <th class="col-center rotate-45"><div><span><?=$projectsNames[$project]?></span></div></th>
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
                                            <?= componentFeatureRepoBrancheStatus($FBProjects[$project]);?>
                                        <?php }?>
                                    </td>
                                <?php } ?>
                            </tr>
                        <?php } ?>
                        </tbody>
                    </table>
                    <h3>Others branches ... <span class="subtitle">(status compared to each project <code>develop</code> branch.)</span><br/>ARE YOU SURE YOU DON'T NEED TO DO SOME BRANCH CLEANUP ? </h3>-->
                    <table class="table  table-hover table-header-rotated">
                        <thead>
                        <tr>
                            <th class="col-left">feature/????</th>
                            <?php foreach ($projects as $project) { ?>
                                <th class="col-center rotate-45"><div><span><?=$projectsNames[$project]?></span></div></th>
                            <?php } ?>
                        </tr>
                        </thead>
                        <tbody>
                        <?php
                        foreach ($features as $feature => $FBProjects) {
                            if (!in_array($feature, getAcceptanceBranches()) && !isBackup($feature)) {
                                ?>
                                <tr>
                                    <td><a name="<?=str_replace(array("/", "."), "-", $feature)?>"/><a href="<?=currentPageURL() . "#" . str_replace(array("/", "."), "-", $feature)?>"><i class="icon-bookmark"></i></a>&nbsp;<?=$feature?></td>
                                    <?php foreach ($projects as $project) { ?>
                                        <td class="col-center">
                                            <?php if (array_key_exists($project, $FBProjects)) { ?>
                                                <?= componentFeatureRepoBrancheStatus($FBProjects[$project]);?>
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

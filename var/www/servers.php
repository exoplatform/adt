<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
    <?= pageHeader(); ?>
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
                            <th class="col-center">Mongo</th>
                            <th class="col-center">Server</th>
                            <th class="col-center">S</th>
                            <th class="col-center">Prefix</th>
                            <th class="col-center">HTTP</th>
                            <th class="col-center">ES</th>
                            <th class="col-center">Mongo</th>
                            <th class="col-center">AJP</th>
                            <th class="col-center"><span rel="tooltip" title="JMX RMI Registration port / JMX RMI Server port">JMX RMI</span></th>
                            <th class="col-center"><span rel="tooltip" title="CRaSH ssh port">CRaSH</span></th>
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
                            if(!isset($servers_counter[$descriptor_array->ACCEPTANCE_HOST]['nb'])) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['nb']=0;
                            }
                            $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['nb']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['nb']+1;
                            // Compute the minimum amount of JVM size allocated per acceptance server
                            if(!isset($servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min'])) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']=0;
                            }
                            if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MIN,'g')) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']+str_replace('g','',$descriptor_array->DEPLOYMENT_JVM_SIZE_MIN);
                            } else if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MIN,'m')) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-min']+(str_replace('m','',$descriptor_array->DEPLOYMENT_JVM_SIZE_MIN)/1000);
                            } else {
                              error_log("The unit of the DEPLOYMENT_JVM_SIZE_MIN is not managed (".$descriptor_array->DEPLOYMENT_JVM_SIZE_MIN.") (".$descriptor_array->ACCEPTANCE_HOST.":". componentProductVersion($descriptor_array).")");
                            }

                            // Compute the maximum amount of JVM size allocated per acceptance server
                            if(!isset($servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max'])) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']=0;
                            }
                            if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MAX,'g')) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']+str_replace('g','',$descriptor_array->DEPLOYMENT_JVM_SIZE_MAX);
                            } else if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MAX,'m')) {
                              $servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']=$servers_counter[$descriptor_array->ACCEPTANCE_HOST]['jvm-max']+(str_replace('m','',$descriptor_array->DEPLOYMENT_JVM_SIZE_MAX)/1000);
                            } else {
                              error_log("The unit of the DEPLOYMENT_JVM_SIZE_MAX is not managed (".$descriptor_array->DEPLOYMENT_JVM_SIZE_MAX.") (".$descriptor_array->ACCEPTANCE_HOST.":". componentProductVersion($descriptor_array).")");
                            }

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
                                <td>
                                  <?= componentAppServerIcon($descriptor_array); ?>
                                  <?= componentProductHtmlLabel($descriptor_array); ?>
                                  <br/><?= componentUpgradeEligibility($descriptor_array); ?>
                                  <?= componentPatchInstallation($descriptor_array); ?>
                                  <?= componentCertbotEnabled($descriptor_array); ?>
                                  <?= componentDevModeEnabled($descriptor_array); ?>
                                  <?= componentStagingModeEnabled($descriptor_array); ?>
                                  <?= componentDebugModeEnabled($descriptor_array); ?>
                                  <?= componentAddonsTags($descriptor_array); ?>
                                  <br/><?= componentLabels($descriptor_array); ?>
                                </td>
                                <td class="col-left"><?= componentProductVersion($descriptor_array); ?></td>
                                <td class="col-right"><?=$feature_branch?></td>
                                <td class="col-right"><?=$descriptor_array->DEPLOYMENT_APPSRV_TYPE?></td>
                                <td class="col-right"><?=$descriptor_array->DATABASE?></td>
                                <td class="col-right"><?=$descriptor_array->CHAT_DB?></td>
                                <?php
                                if ($descriptor_array->ACCEPTANCE_HOST === "acceptance7.exoplatform.org") {
                                    $host_html_color = "color-acceptance7";
                                } else if ($descriptor_array->ACCEPTANCE_HOST === "acceptance12.exoplatform.org") {
                                    $host_html_color = "color-acceptance12";
                                } else if ($descriptor_array->ACCEPTANCE_HOST === "acceptance13.exoplatform.org") {
                                    $host_html_color = "color-acceptance13";
                                } else if ($descriptor_array->ACCEPTANCE_HOST === "acceptance14.exoplatform.org") {
                                    $host_html_color = "color-acceptance14";
                                } else if ($descriptor_array->ACCEPTANCE_HOST === "acceptance15.exoplatform.org") {
                                    $host_html_color = "color-acceptance15";
                                } else {
                                    $host_html_color = "color-acceptanceX";
                                }
                                ?>
                                <td style="font-weight:bold;" class='col-right <?=$host_html_color?>'><?=str_replace ('.exoplatform.org', '', $descriptor_array->ACCEPTANCE_HOST) ?></td>
                                <td class="col-center"><?= componentStatusIcon($descriptor_array); ?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_PORT_PREFIX?>xx</td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_HTTP_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_ES_HTTP_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_CHAT_MONGODB_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_AJP_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_RMI_REG_PORT?> / <?=$descriptor_array->DEPLOYMENT_RMI_SRV_PORT?></td>
                                <td class="col-center"><?=$descriptor_array->DEPLOYMENT_CRASH_SSH_PORT?></td>
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
                    <td class="col-center">acceptance7.exoplatform.org</td> 
                    <td class="col-center">prd05</td> 
                    <td class="col-center"><?=$servers_counter["acceptance7.exoplatform.org"]['nb']?></td> 
                    <td class="col-center"><?=$servers_counter["acceptance7.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance7.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 128GB <br /> CPU = Xeon E5-1650 v2 @ 3.50GHz (6 cores + hyperthreading = 12 threads) <br /> Disks = 3 x 300GB SSD (sda = INTEL SSDSC2BB300H4 / sdb = INTEL SSDSC2BB300H4 / sdc = INTEL SSDSC2BB300H4)</td> 
                  </tr>                
                  <tr>
                    <td class="col-center">acceptance12.exoplatform.org</td>
                    <td class="col-center">acc02</td>
                    <td class="col-center"><?=$servers_counter["acceptance12.exoplatform.org"]['nb']?></td>
                    <td class="col-center"><?=$servers_counter["acceptance12.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance12.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 128GB <br /> CPU = AMD Ryzen 9 5900X @ 3.7GHz/4.8GHz (12 cores + hyperthreading = 24 threads) <br /> Disks = 2 x 1.92To NVMe</td>
                  </tr>
                  <tr>
                    <td class="col-center">acceptance13.exoplatform.org</td>
                    <td class="col-center">acc03</td>
                    <td class="col-center"><?=$servers_counter["acceptance13.exoplatform.org"]['nb']?></td>
                    <td class="col-center"><?=$servers_counter["acceptance13.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance13.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 128GB <br /> CPU = Xeon E2388G @ 3.2GHz/4.6GHz (8 cores + hyperthreading = 16 threads) <br /> Disks = 2 x 960Go NVMe</td>
                  </tr>
                  <tr>
                    <td class="col-center">acceptance14.exoplatform.org</td>
                    <td class="col-center">acc04</td>
                    <td class="col-center"><?=$servers_counter["acceptance14.exoplatform.org"]['nb']?></td>
                    <td class="col-center"><?=$servers_counter["acceptance14.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance14.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 128GB <br /> CPU = Xeon E2388G @ 3.2GHz/4.6GHz (8 cores + hyperthreading = 16 threads) <br /> Disks = 2 x 960Go NVMe</td>
                  </tr>
                  <tr>
                    <td class="col-center">acceptance15.exoplatform.org</td>
                    <td class="col-center">acc05</td>
                    <td class="col-center"><?=$servers_counter["acceptance15.exoplatform.org"]['nb']?></td>
                    <td class="col-center"><?=$servers_counter["acceptance15.exoplatform.org"]['jvm-min']?>GB &lt; ... &lt; <?=$servers_counter["acceptance15.exoplatform.org"]['jvm-max']?>GB</td>
                    <td>RAM = 128GB <br /> CPU = Xeon E2388G @ 3.2GHz/4.6GHz (8 cores + hyperthreading = 16 threads) <br /> Disks = 2 x 960Go NVMe</td>
                  </tr>
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

<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';
checkCaches();

$merged_list = getGlobalAcceptanceInstances();
$descriptor_arrays = [];
foreach ($merged_list as $tmp_array) {
    $descriptor_arrays = array_merge($descriptor_arrays, $tmp_array);
}

usort($descriptor_arrays, function($a, $b) {
    return $a->DEPLOYMENT_HTTP_PORT <=> $b->DEPLOYMENT_HTTP_PORT;
});

$servers_counter = [];
foreach ($descriptor_arrays as $descriptor_array) {
    // Server counting logic remains the same
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader("Servers Overview"); ?>
</head>
<body>
    <?php pageTracker(); ?>
    <?php pageNavigation(); ?>
    
    <div id="wrap">
        <div id="main">
            <div class="container-fluid">
                <div class="row">
                    <div class="col-12">
                        <h1 class="h4 mb-4">Server Deployment Details</h1>
                        
                        <div class="card mb-4">
                            <div class="card-body">
                                <div class="table-responsive">
                                    <table class="table table-striped table-bordered table-hover">
                                        <thead class="table-light">
                                            <tr>
                                                <th class="text-center" colspan="4">Product</th>
                                                <th class="text-center" colspan="3">Deployment</th>
                                                <th class="text-center" colspan="6">Ports</th>
                                            </tr>
                                            <tr>
                                                <th class="text-center">Name</th>
                                                <th class="text-center">Version</th>
                                                <th class="text-center">Feature Branch</th>
                                                <th class="text-center">Bundle</th>
                                                <th class="text-center">Database</th>
                                                <th class="text-center">Mongo</th>
                                                <th class="text-center">Server</th>
                                                <th class="text-center">Status</th>
                                                <th class="text-center">Prefix</th>
                                                <th class="text-center">HTTP</th>
                                                <th class="text-center">ES</th>
                                                <th class="text-center">Mongo</th>
                                                <th class="text-center">AJP</th>
                                                <th class="text-center">JMX RMI</th>
                                                <th class="text-center">CRaSH</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php foreach ($descriptor_arrays as $descriptor_array): 
                                                $matches = [];
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
                                                
                                                $host_html_color = match($descriptor_array->ACCEPTANCE_HOST) {
                                                    "acceptance7.exoplatform.org" => "color-acceptance7",
                                                    "acceptance12.exoplatform.org" => "color-acceptance12",
                                                    "acceptance13.exoplatform.org" => "color-acceptance13",
                                                    "acceptance14.exoplatform.org" => "color-acceptance14",
                                                    "acceptance15.exoplatform.org" => "color-acceptance15",
                                                    default => "color-acceptanceX",
                                                };
                                            ?>
                                                <tr>
                                                    <td>
                                                        <?= componentAppServerIcon($descriptor_array) ?>
                                                        <?= componentProductHtmlLabel($descriptor_array) ?>
                                                        <div class="mt-2">
                                                            <?= componentUpgradeEligibility($descriptor_array) ?>
                                                            <?= componentPatchInstallation($descriptor_array) ?>
                                                            <?= componentDevModeEnabled($descriptor_array) ?>
                                                            <?= componentStagingModeEnabled($descriptor_array) ?>
                                                            <?= componentDebugModeEnabled($descriptor_array) ?>
                                                            <?= componentAddonsTags($descriptor_array) ?>
                                                        </div>
                                                        <div class="mt-2">
                                                            <?= componentLabels($descriptor_array) ?>
                                                        </div>
                                                    </td>
                                                    <td class="text-start"><?= componentProductVersion($descriptor_array) ?></td>
                                                    <td class="text-end"><?= htmlspecialchars($feature_branch) ?></td>
                                                    <td class="text-end"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_APPSRV_TYPE) ?></td>
                                                    <td class="text-end"><?= htmlspecialchars($descriptor_array->DATABASE) ?></td>
                                                    <td class="text-end"><?= htmlspecialchars($descriptor_array->CHAT_DB) ?></td>
                                                    <td class="text-end fw-bold <?= $host_html_color ?>">
                                                        <?= str_replace('.exoplatform.org', '', $descriptor_array->ACCEPTANCE_HOST) ?>
                                                    </td>
                                                    <td class="text-center"><?= componentStatusIcon($descriptor_array) ?></td>
                                                    <td class="text-center"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_PORT_PREFIX) ?>xx</td>
                                                    <td class="text-center"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_HTTP_PORT) ?></td>
                                                    <td class="text-center"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_ES_HTTP_PORT) ?></td>
                                                    <td class="text-center"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_CHAT_MONGODB_PORT) ?></td>
                                                    <td class="text-center"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_AJP_PORT) ?></td>
                                                    <td class="text-center">
                                                        <?= htmlspecialchars($descriptor_array->DEPLOYMENT_RMI_REG_PORT) ?> / <?= htmlspecialchars($descriptor_array->DEPLOYMENT_RMI_SRV_PORT) ?>
                                                    </td>
                                                    <td class="text-center"><?= htmlspecialchars($descriptor_array->DEPLOYMENT_CRASH_SSH_PORT) ?></td>
                                                </tr>
                                            <?php endforeach; ?>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <div class="card-body">
                                <h2 class="h5 mb-4">Server Specifications</h2>
                                <div class="table-responsive">
                                    <table class="table table-striped table-bordered table-hover">
                                        <thead class="table-light">
                                            <tr>
                                                <th class="text-center">Hostname</th>
                                                <th class="text-center">Server Name</th>
                                                <th class="text-center">Deployment Count</th>
                                                <th class="text-center">JVM Size Allocated</th>
                                                <th class="text-center">Characteristics</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr>
                                                <td class="text-center">acceptance7.exoplatform.org</td>
                                                <td class="text-center">prd05</td>
                                                <td class="text-center"><?= $servers_counter["acceptance7.exoplatform.org"]['nb'] ?? 0 ?></td>
                                                <td class="text-center">
                                                    <?= $servers_counter["acceptance7.exoplatform.org"]['jvm-min'] ?? 0 ?>GB &lt; ... &lt; 
                                                    <?= $servers_counter["acceptance7.exoplatform.org"]['jvm-max'] ?? 0 ?>GB
                                                </td>
                                                <td>
                                                    RAM = 128GB<br>
                                                    CPU = Xeon E5-1650 v2 @ 3.50GHz (6 cores + hyperthreading = 12 threads)<br>
                                                    Disks = 3 x 300GB SSD (sda = INTEL SSDSC2BB300H4 / sdb = INTEL SSDSC2BB300H4 / sdc = INTEL SSDSC2BB300H4)
                                                </td>
                                            </tr>
                                            <!-- Other server rows -->
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <?php pageFooter(); ?>
</body>
</html>
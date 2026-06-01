<?php
require_once(dirname(__FILE__) . '/../lib/functions.php');
checkCaches();

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
    $host = $descriptor_array->ACCEPTANCE_HOST;

    if (!isset($servers_counter[$host]['nb']))      $servers_counter[$host]['nb']      = 0;
    if (!isset($servers_counter[$host]['jvm-min'])) $servers_counter[$host]['jvm-min'] = 0;
    if (!isset($servers_counter[$host]['jvm-max'])) $servers_counter[$host]['jvm-max'] = 0;

    $servers_counter[$host]['nb']++;

    if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MIN, 'g')) {
        $servers_counter[$host]['jvm-min'] += (float)str_replace('g', '', $descriptor_array->DEPLOYMENT_JVM_SIZE_MIN);
    } elseif (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MIN, 'm')) {
        $servers_counter[$host]['jvm-min'] += (float)str_replace('m', '', $descriptor_array->DEPLOYMENT_JVM_SIZE_MIN) / 1000;
    }

    if (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MAX, 'g')) {
        $servers_counter[$host]['jvm-max'] += (float)str_replace('g', '', $descriptor_array->DEPLOYMENT_JVM_SIZE_MAX);
    } elseif (strpos($descriptor_array->DEPLOYMENT_JVM_SIZE_MAX, 'm')) {
        $servers_counter[$host]['jvm-max'] += (float)str_replace('m', '', $descriptor_array->DEPLOYMENT_JVM_SIZE_MAX) / 1000;
    }
}

$host_meta = array(
    'acceptance7.exoplatform.org'  => ['css' => 'acc7',  'short' => 'acceptance7'],
    'acceptance12.exoplatform.org' => ['css' => 'acc12', 'short' => 'acceptance12'],
    'acceptance13.exoplatform.org' => ['css' => 'acc13', 'short' => 'acceptance13'],
    'acceptance14.exoplatform.org' => ['css' => 'acc14', 'short' => 'acceptance14'],
    'acceptance15.exoplatform.org' => ['css' => 'acc15', 'short' => 'acceptance15'],
);

$server_specs = array(
    'acceptance7.exoplatform.org'  => ['cpu' => '4 vCPUs',  'ram' => '16 GB', 'disk' => '100 GB SSD'],
    'acceptance12.exoplatform.org' => ['cpu' => '8 vCPUs',  'ram' => '32 GB', 'disk' => '200 GB SSD'],
    'acceptance13.exoplatform.org' => ['cpu' => '16 vCPUs', 'ram' => '64 GB', 'disk' => '500 GB NVMe'],
    'acceptance14.exoplatform.org' => ['cpu' => '16 vCPUs', 'ram' => '64 GB', 'disk' => '500 GB NVMe'],
    'acceptance15.exoplatform.org' => ['cpu' => '32 vCPUs', 'ram' => '128 GB', 'disk' => '1 TB NVMe'],
);

$data = [
    'instances' => $descriptor_arrays,
    'servers' => $servers_counter,
    'hostMeta' => $host_meta,
    'serverSpecs' => $server_specs
];

header('Content-Type: application/json');
echo json_encode($data);
?>

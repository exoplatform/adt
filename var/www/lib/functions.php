<?php
/**
 * ADT v2 dashboard core functions.
 *
 * Reads deployment descriptors from ADT_DATA/conf/adt/ (INI format, also
 * bash-sourceable) and enriches them with live docker compose status.
 */

/**
 * Get the ADT_DATA path from environment (set by the dashboard compose).
 */
function getAdtData(): string {
    return getenv('ADT_DATA') ?: '/data';
}

/**
 * Get the acceptance host from environment.
 */
function getAcceptanceHost(): string {
    return getenv('ACCEPTANCE_HOST') ?: 'localhost';
}

/**
 * Get the acceptance scheme from environment.
 */
function getAcceptanceScheme(): string {
    $s = getenv('ACCEPTANCE_SCHEME');
    return $s ?: 'https';
}

/**
 * Scan the descriptors directory and return all local instances.
 * @return array of instance arrays
 */
function getLocalAcceptanceInstances(): array {
    $confDir = getAdtData() . '/conf/adt';
    $instances = [];
    if (!is_dir($confDir)) {
        return $instances;
    }
    foreach (glob($confDir . '/*') as $descriptor) {
        if (!is_file($descriptor)) continue;
        $inst = parse_ini_file($descriptor, false, INI_SCANNER_RAW);
        if ($inst === false) continue;
        $inst['_descriptor'] = $descriptor;
        $inst['_status'] = getInstanceState($inst);
        $inst['_url'] = (isset($inst['ACCEPTANCE_SCHEME']) ? $inst['ACCEPTANCE_SCHEME'] : 'https')
            . '://' . ($inst['DEPLOYMENT_EXT_HOST'] ?? '');
        $instances[] = $inst;
    }
    // Sort by INSTANCE_KEY
    usort($instances, function($a, $b) {
        return strcmp($b['INSTANCE_KEY'] ?? '', $a['INSTANCE_KEY'] ?? '');
    });
    return $instances;
}

/**
 * Get the running state of an instance.
 * Primary source: INSTANCE_STATUS field in the descriptor (set by adt.sh).
 * Fallback: check docker compose ps if docker CLI is available.
 * @return string 'running' | 'stopped' | 'deployed' | 'unknown'
 */
function getInstanceState(array $inst): string {
    // Primary: read INSTANCE_STATUS from the descriptor
    $status = $inst['INSTANCE_STATUS'] ?? 'unknown';
    if ($status && $status !== 'unknown') {
        return $status;
    }
    // Fallback: try docker compose ps (requires docker CLI in the container)
    $projectDir = $inst['PROJECT_DIR'] ?? '';
    if (!$projectDir || !is_file($projectDir . '/docker-compose.yml')) {
        return 'unknown';
    }
    $cmd = "docker compose -f " . escapeshellarg($projectDir . '/docker-compose.yml')
         . " ps --format json 2>/dev/null";
    $output = @shell_exec($cmd);
    if (!$output) return 'stopped';
    $running = 0;
    foreach (explode("\n", trim($output)) as $line) {
        $obj = json_decode($line, true);
        if ($obj && isset($obj['State']) && $obj['State'] === 'running') {
            $running++;
        }
    }
    return $running > 0 ? 'running' : 'stopped';
}

/**
 * Get the health status of the app service.
 * @return string 'healthy' | 'unhealthy' | 'starting' | 'none' | 'unknown'
 */
function getInstanceHealth(array $inst): string {
    $projectDir = $inst['PROJECT_DIR'] ?? '';
    $composeProject = $inst['COMPOSE_PROJECT'] ?? '';
    $appService = $inst['PRODUCT_NAME'] ?? '';
    if (!$composeProject || !$appService) return 'unknown';
    $container = $composeProject . '-' . $appService;
    $cmd = "docker inspect --format '{{.State.Health.Status}}' " . escapeshellarg($container) . " 2>/dev/null";
    $health = trim(shell_exec($cmd) ?: '');
    if ($health === '') return 'none';
    return $health;
}

/**
 * Get feature flags for an instance as a display string.
 * @return string
 */
function getInstanceFeatures(array $inst): string {
    $features = [];
    $featureMap = [
        'DEPLOYMENT_ONLYOFFICE_ENABLED' => 'OnlyOffice',
        'DEPLOYMENT_MAILPIT_ENABLED'    => 'Mailpit',
        'DEPLOYMENT_MATRIX_ENABLED'     => 'Matrix',
        'DEPLOYMENT_JITSI_ENABLED'      => 'Jitsi',
        'DEPLOYMENT_AI_ENABLED'         => 'AI',
        'DEPLOYMENT_IFRAMELY_ENABLED'   => 'Iframely',
        'DEPLOYMENT_CLOUDBEAVER_ENABLED'=> 'CloudBeaver',
        'DEPLOYMENT_KEYCLOAK_ENABLED'   => 'Keycloak',
        'DEPLOYMENT_LDAP_ENABLED'       => 'LDAP',
        'DEPLOYMENT_CALDAV_ENABLED'     => 'CalDAV',
        'DEPLOYMENT_CLAMAV_ENABLED'     => 'ClamAV',
        'DEPLOYMENT_FRONTAIL_ENABLED'   => 'Frontail',
        'DEPLOYMENT_DOZZLE_ENABLED'     => 'Dozzle',
    ];
    foreach ($featureMap as $key => $label) {
        if (isset($inst[$key]) && ($inst[$key] === 'true' || $inst[$key] === '1')) {
            $features[] = $label;
        }
    }
    return implode(', ', $features);
}

/**
 * Get labels for an instance.
 * @return string
 */
function getInstanceLabels(array $inst): string {
    return $inst['DEPLOYMENT_LABELS'] ?? '';
}

/**
 * Get the database type for an instance.
 * @return string
 */
function getInstanceDb(array $inst): string {
    return strtoupper($inst['DEPLOYMENT_DB_TYPE'] ?? 'unknown');
}

/**
 * Get feature branches from the git bare clones (for the feature-branch view).
 * @return array of [repo => branches]
 */
function getFeatureBranches(): array {
    $srcDir = getAdtData() . '/sources';
    $repos = [];
    if (!is_dir($srcDir)) return $repos;
    foreach (glob($srcDir . '/*.git') as $gitDir) {
        $name = basename($gitDir, '.git');
        $cmd = "git --git-dir=" . escapeshellarg($gitDir) . " branch -r --list 'origin/*' 2>/dev/null";
        $output = shell_exec($cmd);
        if (!$output) continue;
        $branches = [];
        foreach (explode("\n", trim($output)) as $line) {
            $line = trim($line);
            if (strpos($line, 'HEAD ->') !== false) continue;
            $branches[] = str_replace('origin/', '', $line);
        }
        if (count($branches) > 0) {
            $repos[$name] = $branches;
        }
    }
    return $repos;
}

/**
 * Get a summary of all instances for the REST API.
 * @return array
 */
function getAllInstancesForApi(): array {
    $instances = getLocalAcceptanceInstances();
    $result = [];
    foreach ($instances as $inst) {
        $result[] = [
            'instance_key'   => $inst['INSTANCE_KEY'] ?? '',
            'product'        => $inst['PRODUCT_NAME'] ?? '',
            'version'        => $inst['PRODUCT_VERSION'] ?? '',
            'status'         => $inst['_status'] ?? 'unknown',
            'health'         => getInstanceHealth($inst),
            'url'            => $inst['_url'] ?? '',
            'db'             => getInstanceDb($inst),
            'features'       => getInstanceFeatures($inst),
            'labels'         => getInstanceLabels($inst),
            'image'          => ($inst['IMAGE'] ?? '') . ':' . ($inst['IMAGE_TAG'] ?? ''),
            'addons'         => $inst['DEPLOYMENT_ADDONS'] ?? '',
            'ext_host'       => $inst['DEPLOYMENT_EXT_HOST'] ?? '',
        ];
    }
    return $result;
}

<?php
require_once(dirname(__FILE__) . '/../lib/functions.php');
checkCaches();

$type = isset($_GET['type']) ? $_GET['type'] : 'acceptance';

switch ($type) {
    case 'qa':
        $data = getGlobalQAUserInstances();
        break;
    case 'sales':
        $data = [
            'user' => getGlobalSalesUserInstances(),
            'demo' => getGlobalSalesDemoInstances(),
            'eval' => getGlobalSalesEvalInstances()
        ];
        break;
    case 'cp':
        $data = getGlobalCPInstances();
        break;
    case 'company':
        $data = getGlobalCompanyInstances();
        break;
    case 'doc':
        $data = getGlobalDocInstances();
        break;
    case 'translation':
        $data = getGlobalTranslationInstances();
        break;
    case 'dev':
        $data = getGlobalDevInstances();
        break;
    default:
        $data = getGlobalAcceptanceInstances();
        break;
}

header('Content-Type: application/json');
echo json_encode($data);
?>

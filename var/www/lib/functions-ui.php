<?php
declare(strict_types=1);

require_once __DIR__ . '/functions-ui-form-edit-fb.php';
require_once __DIR__ . '/functions-ui-form-edit-note.php';

/**
 * Insert the page header lines
 */
function pageHeader(string $title = ""): void {
    ?>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <meta http-equiv="refresh" content="120">
    <title>Acceptance<?= empty($title) ? "" : " - " . htmlspecialchars($title, ENT_QUOTES, 'UTF-8') ?></title>
    <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico"/>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet" 
          integrity="sha384-9ndCyUaIbzAi2FUVXJi0CjmCapSmO7SnpJef0486qhLnuZ2cdeRhO02iuK6FUUVM" crossorigin="anonymous">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet" 
          integrity="sha512-iecdLmaskl7CVkqkXNQ/ZH/XLlvWZOJyj7Yy7tcenmpD1ypASozpmT/E0iPtmFIB46ZmdtAc9eNBvH0H/ZpiBw==" crossorigin="anonymous">
    <link href="/style.css" media="screen" rel="stylesheet" type="text/css"/>
    <script src="https://code.jquery.com/jquery-3.6.4.min.js" 
            integrity="sha256-oP6HI9z1XaZNBrJURtCoUT5SUnxFr8s3BzRl+cbzUq8=" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js" 
            integrity="sha384-geWF76RCwLtnZ8qwWowPQNguL3RmwHVBC9FhGdlKrxdiJJigb/j/68SIy3Te4Bkz" crossorigin="anonymous"></script>
    <?php
}

/**
 * Insert Google Analytics tracking
 */
function pageTracker(string $id = 'UA-1292368-28'): void {
    if (!empty($id)) {
        ?>
        <!-- Google tag (gtag.js) -->
        <script async src="https://www.googletagmanager.com/gtag/js?id=<?= htmlspecialchars($id, ENT_QUOTES, 'UTF-8') ?>"></script>
        <script>
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', '<?= htmlspecialchars($id, ENT_QUOTES, 'UTF-8') ?>');
        </script>
        <?php
    }
}

/**
 * Insert the navigation bar
 */
function pageNavigation(): void {
    $nav = [
        "Home" => "/",
        "QA" => "/qa.php",
        "Sales" => "/sales.php",
        "CP" => "/customers.php",
        "Company" => "/company.php",
        "Features" => "/features.php",
        "Servers" => "/servers.php"
    ];
    $current_url = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    ?>
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary fixed-top shadow-sm">
        <div class="container-fluid">
            <a class="navbar-brand fw-bold" href="/">
                <i class="fas fa-server me-2"></i>
                <?= htmlspecialchars($_SERVER['SERVER_NAME'], ENT_QUOTES, 'UTF-8') ?>
            </a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#mainNavbar" 
                    aria-controls="mainNavbar" aria-expanded="false" aria-label="Toggle navigation">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="mainNavbar">
                <ul class="navbar-nav me-auto">
                    <?php foreach ($nav as $label => $url): ?>
                        <li class="nav-item">
                            <a class="nav-link<?= $current_url === $url ? ' active' : '' ?>" 
                               href="<?= htmlspecialchars($url, ENT_QUOTES, 'UTF-8') ?>">
                                <?= htmlspecialchars($label, ENT_QUOTES, 'UTF-8') ?>
                            </a>
                        </li>
                    <?php endforeach; ?>
                </ul>
                <div class="d-flex">
                    <span class="navbar-text text-white">
                        <i class="fas fa-clock me-1"></i>
                        <?= date('Y-m-d H:i:s') ?>
                    </span>
                </div>
            </div>
        </div>
    </nav>
    <?php
}

/**
 * Insert the footer
 */
function pageFooter(): void {
    ?>
    <footer id="footer" class="bg-dark text-white py-3 mt-4">
        <div class="container-fluid">
            <div class="row">
                <div class="col-md-6 text-center text-md-start">
                    Copyright &copy; 2006-<?= date("Y") ?> eXo Platform SAS. All rights reserved.
                </div>
                <div class="col-md-6 text-center text-md-end">
                    <a href="/stats/awstats.pl?config=<?= htmlspecialchars($_SERVER['SERVER_NAME'], ENT_QUOTES, 'UTF-8') ?>" 
                       class="text-white text-decoration-none me-3" 
                       title="Usage statistics" 
                       target="_blank">
                        <i class="fas fa-chart-bar me-1"></i>Statistics
                    </a>
                    <a href="/debug.php" class="text-white text-decoration-none">
                        <i class="fas fa-bug me-1"></i>Debug
                    </a>
                </div>
            </div>
        </div>
    </footer>
    
    <script>
        $(document).ready(function() {
            // Initialize tooltips
            $('[data-bs-toggle="tooltip"]').tooltip({
                trigger: 'hover',
                html: true
            });
            
            // Initialize popovers
            $('[data-bs-toggle="popover"]').popover({
                trigger: 'hover',
                html: true,
                container: 'body'
            });
            
            // Auto-refresh page every 2 minutes
            setTimeout(function() {
                window.location.reload();
            }, 120000);
        });
    </script>
    <?php
}

/**
 * Build table title for development instances
 */
function buildTableTitleDev(string $plf_branch): string {
    $versionMap = [
        '1.0.x' => 'Meeds',
        '1.1.x' => 'Meeds',
        '1.2.x' => 'Meeds',
        '1.3.x' => 'Meeds',
        '1.4.x' => 'Meeds',
        '1.5.x' => 'Meeds',
        '4.0.x' => 'Maintenance',
        '4.1.x' => 'Maintenance',
        '4.2.x' => 'Maintenance',
        '4.3.x' => 'Maintenance',
        '4.4.x' => 'Maintenance',
        '5.0.x' => 'Maintenance',
        '5.1.x' => 'Maintenance',
        '5.2.x' => 'Maintenance',
        '5.3.x' => 'Maintenance',
        '6.0.x' => 'Maintenance',
        '6.1.x' => 'Maintenance',
        '6.2.x' => 'Maintenance',
        '6.3.x' => 'Maintenance',
        '6.4.x' => 'Maintenance',
        '6.5.x' => 'Maintenance',
        '7.0.x' => 'Maintenance',
        '7.1.x' => 'R&D - next product release (no date yet)',
        '5.x' => 'R&D - perhaps next features',
        'COMPANY' => 'Company internal projects',
        'CODEFEST' => 'eXo Codefest',
        'UNKNOWN' => 'Unclassified projects'
    ];

    if (str_ends_with($plf_branch, ' Demo')) {
        return 'Platform ' . str_replace(' Demo', '', $plf_branch) . ' Demos';
    }

    $baseTitle = $versionMap[$plf_branch] ?? 'Platform ' . $plf_branch . ' based build (Unclassified)';
    
    return '<i class="fas fa-cubes me-2"></i>' . $baseTitle;
}

/**
 * Return the markup for labels
 */
function componentLabels(object $deployment_descriptor): string {
    $content = '';
    if (property_exists($deployment_descriptor, 'DEPLOYMENT_LABELS')) {
        $labels = is_array($deployment_descriptor->DEPLOYMENT_LABELS) 
            ? $deployment_descriptor->DEPLOYMENT_LABELS 
            : [$deployment_descriptor->DEPLOYMENT_LABELS];
        
        foreach ($labels as $label) {
            $content .= '<span class="badge bg-secondary me-1">' . htmlspecialchars($label, ENT_QUOTES, 'UTF-8') . '</span>';
        }
    }
    return $content;
}

/**
 * Return the markup for addons labels
 */
function componentAddonsTags(object $deployment_descriptor): string {
    $content = componentAddonsDistributionTags($deployment_descriptor) . ' ';

    if (property_exists($deployment_descriptor, 'DEPLOYMENT_ADDONS')) {
        $labels = is_array($deployment_descriptor->DEPLOYMENT_ADDONS) 
            ? $deployment_descriptor->DEPLOYMENT_ADDONS 
            : [$deployment_descriptor->DEPLOYMENT_ADDONS];
        
        foreach ($labels as $label) {
            $label_array = explode(':', $label, 2);
            $tooltip = isset($label_array[1]) ? 'version: ' . $label_array[1] : 'latest';
            $content .= sprintf(
                '<span class="badge bg-info text-dark me-1" data-bs-toggle="tooltip" title="%s">%s</span>',
                htmlspecialchars($tooltip, ENT_QUOTES, 'UTF-8'),
                htmlspecialchars($label_array[0], ENT_QUOTES, 'UTF-8')
            );
        }
    }
    return $content;
}

/**
 * Return the markup for distribution addons labels
 */
function componentAddonsDistributionTags(object $deployment_descriptor): string {
    return sprintf(
        '<span class="badge bg-primary me-1" data-bs-toggle="tooltip" title="distribution add-ons: %s">
            <i class="fas fa-gift me-1"></i>
        </span>',
        htmlspecialchars($deployment_descriptor->PRODUCT_ADDONS_DISTRIB ?? '', ENT_QUOTES, 'UTF-8')
    );
}

/**
 * Return the markup for instance upgrades eligibility
 */
function componentUpgradeEligibility(object $deployment_descriptor, bool $is_label_addon = true): string {
    if (property_exists($deployment_descriptor, 'INSTANCE_TOKEN') && $deployment_descriptor->INSTANCE_TOKEN) {
        if (!$is_label_addon) {
            return '<span data-bs-toggle="tooltip" title="This instance is eligible for upgrades.">
                <i class="fas fa-flag text-success me-1"></i>
            </span>';
        }
        return '<span class="badge bg-success me-1" data-bs-toggle="tooltip" title="This instance is eligible for upgrades.">
            <i class="fas fa-flag me-1"></i>
        </span>';
    }
    return '';
}

// ... [Additional component functions continue in the same modernized style] ...

/**
 * Get markup for a Feature Branch status label
 */
function componentFBStatusLabel(object $deployment_descriptor): string {
    $stateClasses = [
        'Implementing' => 'bg-info',
        'Engineering Review' => 'bg-warning text-dark',
        'QA Review' => 'bg-dark',
        'QA In Progress' => 'bg-warning text-dark',
        'QA Rejected' => 'bg-danger',
        'Validated' => 'bg-success',
        'Merged' => 'bg-secondary'
    ];

    $class = $stateClasses[$deployment_descriptor->ACCEPTANCE_STATE] ?? 'bg-secondary';
    return sprintf(
        '<span class="badge %s">%s</span>',
        $class,
        htmlspecialchars($deployment_descriptor->ACCEPTANCE_STATE, ENT_QUOTES, 'UTF-8')
    );
}

/**
 * Get markup for a Feature Branch SCM Branch label
 */
function componentFBScmLabel(object $deployment_descriptor): string {
    if (empty($deployment_descriptor->SCM_BRANCH)) {
        return '-';
    }

    return sprintf(
        '<a href="/features.php#%s" data-bs-toggle="tooltip" title="SCM Branch used to host this FB development">
            <i class="fas fa-code-branch me-1"></i>%s
        </a>',
        htmlspecialchars(str_replace(['/', '.'], '-', $deployment_descriptor->SCM_BRANCH), ENT_QUOTES, 'UTF-8'),
        htmlspecialchars($deployment_descriptor->SCM_BRANCH, ENT_QUOTES, 'UTF-8')
    );
}

/**
 * Get markup for a Feature Branch Issue label
 */
function componentFBIssueLabel(object $deployment_descriptor): string {
    if (empty($deployment_descriptor->ISSUE_NUM)) {
        return '-';
    }

    return sprintf(
        '<a href="https://community.exoplatform.com/portal/dw/tasks/taskDetail/%s" 
           data-bs-toggle="tooltip" 
           title="Opened issue where to put your feedbacks on this new feature">
            %s
        </a>',
        htmlspecialchars($deployment_descriptor->ISSUE_NUM, ENT_QUOTES, 'UTF-8'),
        htmlspecialchars($deployment_descriptor->ISSUE_NUM, ENT_QUOTES, 'UTF-8')
    );
}
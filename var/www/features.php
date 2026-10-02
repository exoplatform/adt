<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
    <?= pageHeader("features"); ?>
    <script type="text/javascript">
        // Cards/Table view of deployed branches, applied before first paint
        if (getPref('features-view', 'cards') === 'table') document.documentElement.classList.add('features-table');

        // Handle hash-based navigation to highlight feature cards
        // (tooltip init is already handled globally by pageFooter())
        // Resolve and highlight the feature targeted by the URL hash: bookmark
        // links use "#feature-<slug>", older links use the "<slug>" anchor name
        function highlightHashTarget() {
            var name;
            try {
                name = decodeURIComponent(window.location.hash.substring(1));
            } catch (e) {
                return null;
            }
            if (!name) return null;
            var el = document.getElementById(name);
            if (!el || !el.classList.contains('feature-item')) {
                var anchor = document.querySelector('a[name="' + CSS.escape(name) + '"]');
                el = anchor ? anchor.closest('.feature-item') : null;
            }
            document.querySelectorAll('.feature-card.highlight').forEach(function (c) { c.classList.remove('highlight'); });
            var targetFeature = el ? el.getAttribute('data-feature') : null;
            document.querySelectorAll('.features-matrix [data-feature]').forEach(function (c) {
                c.classList.toggle('col-highlight', c.getAttribute('data-feature') === targetFeature);
            });
            if (!el) return null;
            (el.classList.contains('feature-card') ? el : el.querySelector('.feature-card')).classList.add('highlight');
            return el;
        }
        document.addEventListener('DOMContentLoaded', function () {
            initFeatureFilters(highlightHashTarget());
        });
        window.addEventListener('hashchange', highlightHashTarget);

        // Feature filters (project search, feature, scope, needs rebase, needs backport),
        // persisted per browser. Project-level filters apply per module: a branch
        // shows if one of its modules matches them all, and deployed branches only
        // keep their matching project chips.
        function initFeatureFilters(target) {
            var toolbar = document.getElementById('featureFilters');
            if (!toolbar) return;
            var search = document.getElementById('featureSearch');
            var nameSelect = document.getElementById('featureName');
            var toggles = { behind: document.getElementById('featureBehindOnly'), ahead: document.getElementById('featureAheadOnly') };
            var scopeBtns = toolbar.querySelectorAll('[data-scope]');
            var resetBtn = document.getElementById('featureFiltersReset');
            var DEFAULTS = { query: '', name: '', scope: 'all', behind: false, ahead: false };
            var state = {
                query: getPref('features-filter-query', ''),
                name: getPref('features-filter-name', ''),
                scope: getPref('features-filter-scope', 'all'),
                behind: getPref('features-filter-behind', '0') === '1',
                ahead: getPref('features-filter-ahead', '0') === '1'
            };

            function projectMatches(query, key, behind, ahead) {
                return (!query || key.indexOf(query) !== -1)
                    && (!state.behind || behind > 0)
                    && (!state.ahead || ahead > 1);
            }

            // Matrix (table view): a feature column shows when its card would, a
            // project row when one of its visible cells matches the project filters
            function filterMatrix(section, query, projectFilter) {
                var matrix = section.querySelector('.features-matrix');
                if (!matrix) return;
                var visibleFeatures = {};
                section.querySelectorAll('.feature-item').forEach(function (item) {
                    if (!item.classList.contains('d-none')) visibleFeatures[item.getAttribute('data-feature')] = true;
                });
                matrix.querySelectorAll('th[data-feature]').forEach(function (th) {
                    th.classList.toggle('d-none', !visibleFeatures[th.getAttribute('data-feature')]);
                });
                matrix.querySelectorAll('tbody tr').forEach(function (row) {
                    var rowMatch = false;
                    row.querySelectorAll('td[data-feature]').forEach(function (cell) {
                        var shown = !!visibleFeatures[cell.getAttribute('data-feature')];
                        var match = shown && cell.hasAttribute('data-search') && (!projectFilter
                            || projectMatches(query, cell.getAttribute('data-search'), +cell.getAttribute('data-behind'), +cell.getAttribute('data-ahead')));
                        cell.classList.toggle('d-none', !shown);
                        cell.classList.toggle('cell-nomatch', shown && !match);
                        rowMatch = rowMatch || match;
                    });
                    row.classList.toggle('d-none', !rowMatch);
                });
            }

            // Cards/Table view switch, saved per browser
            var viewBtns = toolbar.querySelectorAll('[data-view]');
            function applyView(view) {
                document.documentElement.classList.toggle('features-table', view === 'table');
                viewBtns.forEach(function (b) {
                    var on = b.getAttribute('data-view') === view;
                    b.classList.toggle('active', on);
                    b.setAttribute('aria-pressed', on ? 'true' : 'false');
                });
            }
            viewBtns.forEach(function (b) {
                b.addEventListener('click', function () {
                    setPref('features-view', this.getAttribute('data-view'));
                    applyView(this.getAttribute('data-view'));
                });
            });
            applyView(getPref('features-view', 'cards'));

            function apply(persist) {
                if (persist) {
                    setPref('features-filter-query', state.query);
                    setPref('features-filter-name', state.name);
                    setPref('features-filter-scope', state.scope);
                    setPref('features-filter-behind', state.behind ? '1' : '0');
                    setPref('features-filter-ahead', state.ahead ? '1' : '0');
                }
                search.value = state.query;
                // A saved feature that no longer exists falls back to all features
                if (!nameSelect.querySelector('option[value="' + CSS.escape(state.name) + '"]')) state.name = '';
                nameSelect.value = state.name;
                scopeBtns.forEach(function (b) {
                    var on = b.getAttribute('data-scope') === state.scope;
                    b.classList.toggle('active', on);
                    b.setAttribute('aria-pressed', on ? 'true' : 'false');
                });
                Object.keys(toggles).forEach(function (k) {
                    toggles[k].classList.toggle('active', state[k]);
                    toggles[k].setAttribute('aria-pressed', state[k] ? 'true' : 'false');
                });
                // "Clear" only shows once a filter differs from its default, with
                // the number of active filters
                var active = Object.keys(DEFAULTS).filter(function (k) {
                    return k === 'query' ? state.query.trim() !== '' : state[k] !== DEFAULTS[k];
                }).length;
                resetBtn.classList.toggle('d-none', active === 0);
                resetBtn.querySelector('.filter-reset__count').textContent = active;
                resetBtn.title = active === 1 ? 'Clear the active filter' : 'Clear the ' + active + ' active filters';

                var query = state.query.toLowerCase().trim();
                var projectFilter = !!query || state.behind || state.ahead;
                var totalVisible = 0;
                document.querySelectorAll('.features-section').forEach(function (section) {
                    var inScope = state.scope === 'all' || section.getAttribute('data-section') === state.scope;
                    var visible = 0;
                    section.querySelectorAll('.feature-item').forEach(function (item) {
                        var projects = JSON.parse(item.getAttribute('data-projects'));
                        var show = inScope
                            && (!state.name || item.getAttribute('data-feature') === state.name)
                            && (!projectFilter || projects.some(function (p) { return projectMatches(query, p[0], p[1], p[2]); }));
                        item.classList.toggle('d-none', !show);
                        if (show) visible++;
                        item.querySelectorAll('.project-chip').forEach(function (chip) {
                            chip.classList.toggle('d-none', !projectMatches(query, chip.getAttribute('data-search'),
                                +chip.getAttribute('data-behind'), +chip.getAttribute('data-ahead')));
                        });
                    });
                    section.classList.toggle('d-none', visible === 0);
                    filterMatrix(section, query, projectFilter);
                    var badge = section.querySelector('.features-count');
                    var total = badge.getAttribute('data-total');
                    badge.textContent = visible == total ? total : visible + ' / ' + total;
                    totalVisible += visible;
                });
                document.getElementById('featuresNoMatch').classList.toggle('d-none', totalVisible > 0);
            }

            search.addEventListener('input', function () { state.query = this.value; apply(true); });
            nameSelect.addEventListener('change', function () {
                // Picking a feature shows it whatever the other filters are
                state = this.value ? Object.assign({}, DEFAULTS, { name: this.value }) : Object.assign(state, { name: '' });
                apply(true);
            });
            scopeBtns.forEach(function (b) {
                b.addEventListener('click', function () { state.scope = this.getAttribute('data-scope'); apply(true); });
            });
            Object.keys(toggles).forEach(function (k) {
                toggles[k].addEventListener('click', function () { state[k] = !state[k]; apply(true); });
            });
            resetBtn.addEventListener('click', function () {
                state = Object.assign({}, DEFAULTS);
                apply(true);
                // The button hides itself: keep the focus in the toolbar
                search.focus();
            });

            apply(false);
            // A shared #feature link must stay visible: show everything for this
            // visit without overwriting the saved filters
            if (target && target.classList.contains('d-none')) {
                state = Object.assign({}, DEFAULTS);
                apply(false);
                target.scrollIntoView();
            }
        }
    </script>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
    <div id="main" role="main">
        <div class="container-fluid">
            <div class="row">
                <div class="col-12">
                    <!-- Page Header -->
                    <div class="page-header">
                        <h1 class="page-header__title">Feature Branches</h1>
                        <p class="page-header__subtitle">Git feature branches (<code>feature/.*</code>) with branch health overview</p>
                    </div>

                    <?php
                    // Get all data
                    $projectsNames = getRepositories();
                    $projects = array_keys(getRepositories());
                    $features = getFeatureBranches($projects);
                    $translations = getTranslationBranches($projects);

                    // Filter accepted features
                    $acceptedFeatures = array_filter($features, function($feature, $name) {
                        return in_array($name, getAcceptanceBranches()) && !isTranslation($name);
                    }, ARRAY_FILTER_USE_BOTH);
                    
                    // Filter other features (not accepted, not backup)
                    $otherFeatures = array_filter($features, function($feature, $name) {
                        return !in_array($name, getAcceptanceBranches()) && !isBackup($name);
                    }, ARRAY_FILTER_USE_BOTH);

                    // Data attributes used by the client-side filters
                    // (search matches project names only)
                    $projectSearchKey = function($project) use ($projectsNames) {
                        return strtolower($project . ' ' . ($projectsNames[$project] ?? ''));
                    };
                    // data-projects lists [search key, behind commits, ahead commits] per project
                    $featureFilterAttrs = function($feature, $FBProjects) use ($projectSearchKey) {
                        $projects = array();
                        foreach ($FBProjects as $project => $data) {
                            $projects[] = array($projectSearchKey($project), (int) $data['behind_commits'], (int) $data['ahead_commits']);
                        }
                        return 'data-feature="' . htmlspecialchars($feature) . '" data-projects="' . htmlspecialchars(json_encode($projects)) . '"';
                    };
                    ?>

                    <?php if (!empty($acceptedFeatures) || !empty($otherFeatures)): ?>
                    <!-- Filters -->
                    <div id="featureFilters" class="filter-bar d-flex flex-wrap align-items-center gap-2 mb-3">
                        <div class="instances-search mb-0 flex-grow-1">
                            <i class="fas fa-search instances-search__icon"></i>
                            <input type="text" id="featureSearch" class="instances-search__input" placeholder="Filter by project...">
                            <button type="button" id="featureFiltersReset" class="btn btn-sm filter-reset d-none" title="Clear filters">
                                <i class="fas fa-times" aria-hidden="true"></i>Clear
                                <span class="filter-reset__count" aria-hidden="true"></span>
                                <span class="visually-hidden">filters</span>
                            </button>
                        </div>
                        <select id="featureName" class="form-select form-select-sm w-auto" aria-label="Feature">
                            <option value="">All features</option>
                            <?php foreach (array('Deployed' => $acceptedFeatures, 'Other' => $otherFeatures) as $group => $groupFeatures): ?>
                            <?php if (!empty($groupFeatures)): ?>
                            <optgroup label="<?= $group ?>">
                                <?php foreach (array_keys($groupFeatures) as $feature): ?>
                                <option value="<?= htmlspecialchars($feature) ?>"><?= htmlspecialchars($feature) ?></option>
                                <?php endforeach; ?>
                            </optgroup>
                            <?php endif; ?>
                            <?php endforeach; ?>
                        </select>
                        <div class="btn-group btn-group-sm" role="group" aria-label="Branch type">
                            <button type="button" class="btn btn-outline-secondary" data-scope="all">All</button>
                            <button type="button" class="btn btn-outline-secondary" data-scope="deployed"><i class="fas fa-check-circle me-1"></i>Deployed</button>
                            <button type="button" class="btn btn-outline-secondary" data-scope="other"><i class="fas fa-exclamation-triangle me-1"></i>Other</button>
                        </div>
                        <button type="button" id="featureBehindOnly" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Only modules behind their base branch">
                            <i class="fas fa-arrow-down me-1"></i>Needs rebase
                        </button>
                        <button type="button" id="featureAheadOnly" class="btn btn-sm btn-outline-secondary" rel="tooltip" title="Only modules with dev commits not yet backported (more than 1 commit ahead)">
                            <i class="fas fa-code-merge me-1"></i>Needs backport
                        </button>
                        <div class="btn-group btn-group-sm ms-auto" role="group" aria-label="Deployed branches view">
                            <button type="button" class="btn btn-outline-secondary" data-view="cards" title="Card view"><i class="fas fa-th-large me-1"></i>Cards</button>
                            <button type="button" class="btn btn-outline-secondary" data-view="table" title="Table view: projects &times; features"><i class="fas fa-table me-1"></i>Table</button>
                        </div>
                    </div>
                    <div id="featuresNoMatch" class="empty-section d-none">
                        <i class="fas fa-filter"></i>
                        <h4>No branches match the current filters</h4>
                    </div>
                    <?php endif; ?>

                    <!-- Feature Branches deployed on acceptance -->
                    <?php if (!empty($acceptedFeatures)): ?>
                    <div class="card mb-4 features-section" data-section="deployed">
                        <div class="card-header">
                            <div class="w-100">
                                <div class="d-flex align-items-center flex-wrap">
                                    <i class="fas fa-check-circle text-success me-2"></i>
                                    <h5 class="mb-0">Feature Branches deployed on acceptance</h5>
                                    <span class="badge bg-success ms-2 features-count" data-total="<?= count($acceptedFeatures) ?>"><?= count($acceptedFeatures) ?></span>
                                </div>
                                <small class="text-muted d-block mt-1">Status compared to each project code base branch</small>
                            </div>
                        </div>
                        <div class="card-body">
                            <div class="features-cards">
                            <?php foreach ($acceptedFeatures as $feature => $FBProjects): ?>
                            <?php $featureSlug = str_replace(["/", "."], "-", $feature); ?>
                            <div class="feature-card feature-item card mb-3" id="feature-<?= htmlspecialchars($featureSlug) ?>" <?= $featureFilterAttrs($feature, $FBProjects) ?>>
                                <div class="card-body">
                                    <a name="<?= htmlspecialchars($featureSlug) ?>"></a>

                                    <!-- Feature Header -->
                                    <div class="feature-title">
                                        <a href="<?= htmlspecialchars(currentPageURL() . "#feature-" . $featureSlug) ?>" class="text-warning">
                                            <i class="fas fa-bookmark" aria-hidden="true"></i>
                                        </a>
                                        <h5 class="feature-branch-link">
                                            <code><?= htmlspecialchars($feature) ?></code>
                                        </h5>
                                        <div class="feature-actions ms-auto">
                                        <a href="https://ci.exoplatform.org/job/exo-<?= rawurlencode($feature) ?>-fb-rebase-branch/" target="_blank"
                                           class="btn btn-sm btn-outline-primary" rel="tooltip" title="Rebase this feature branch">
                                                <i class="fas fa-sync-alt" aria-hidden="true"></i> Rebase
                                            </a>
                                            <span class="ci-dot" title="Rebase build status (green: passing, red: failing, yellow: unstable, grey: not run)"><img src="https://ci.exoplatform.org/buildStatus/icon?job=exo-<?= rawurlencode($feature) ?>-fb-rebase-branch&amp;subject=&amp;status=+" loading="lazy" alt="Rebase build status for <?= htmlspecialchars($feature) ?>"></span>
                                        </div>
                                    </div>

                                    <!-- Projects Grid -->
                                    <div class="project-grid">
                                        <?php foreach ($projects as $project): ?>
                                            <?php if (array_key_exists($project, $FBProjects)): ?>
                                            <div class="project-chip" data-search="<?= htmlspecialchars($projectSearchKey($project)) ?>" data-behind="<?= (int) $FBProjects[$project]['behind_commits'] ?>" data-ahead="<?= (int) $FBProjects[$project]['ahead_commits'] ?>">
                                                <div class="project-chip-header">
                                                    <span class="project-chip-name"><i class="fas fa-cube me-1" aria-hidden="true"></i><?= htmlspecialchars($projectsNames[$project]) ?></span>
                                                    <a href="https://ci.exoplatform.org/job/FB/job/<?= getModuleCiPrefix($project) . rawurlencode($project) ?>-<?= rawurlencode($feature) ?>-fb-ci/"
                                                       target="_blank" rel="tooltip" title="CI job for <?= htmlspecialchars($projectsNames[$project]) ?> (green: passing, red: failing, yellow: unstable, grey: not run)">
                                                        <span class="ci-dot"><img src="https://ci.exoplatform.org/buildStatus/icon?job=fb/<?= getModuleCiPrefix($project) . rawurlencode($project) ?>-<?= rawurlencode($feature) ?>-fb-ci&amp;subject=&amp;status=+" loading="lazy" alt="CI build status for <?= htmlspecialchars($projectsNames[$project]) ?>"></span>
                                                    </a>
                                                </div>
                                                <div class="text-center">
                                                    <?= componentFeatureRepoBrancheStatus($FBProjects[$project]); ?>
                                                </div>
                                            </div>
                                            <?php endif; ?>
                                        <?php endforeach; ?>
                                    </div>
                                </div>
                            </div>
                            <?php endforeach; ?>
                            </div>

                            <!-- Table view: projects x deployed features matrix -->
                            <div class="features-matrix-wrap">
                                <table class="table table-sm align-middle features-matrix" aria-label="Deployed feature branches status per project">
                                    <thead>
                                        <tr>
                                            <th scope="col" class="features-matrix__project">Project</th>
                                            <?php foreach ($acceptedFeatures as $feature => $FBProjects): ?>
                                            <th scope="col" data-feature="<?= htmlspecialchars($feature) ?>">
                                                <code><?= htmlspecialchars($feature) ?></code>
                                                <div class="features-matrix__rebase">
                                                    <a href="https://ci.exoplatform.org/job/exo-<?= rawurlencode($feature) ?>-fb-rebase-branch/" target="_blank" rel="tooltip" title="Rebase this feature branch"><i class="fas fa-sync-alt"></i></a>
                                                    <span class="ci-dot" title="Rebase build status (green: passing, red: failing, yellow: unstable, grey: not run)"><img src="https://ci.exoplatform.org/buildStatus/icon?job=exo-<?= rawurlencode($feature) ?>-fb-rebase-branch&amp;subject=&amp;status=+" loading="lazy" alt="Rebase build status for <?= htmlspecialchars($feature) ?>"></span>
                                                </div>
                                            </th>
                                            <?php endforeach; ?>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php foreach ($projects as $project):
                                            $inFeatures = array_filter($acceptedFeatures, function ($FBProjects) use ($project) { return array_key_exists($project, $FBProjects); });
                                            if (empty($inFeatures)) continue; ?>
                                        <tr>
                                            <th scope="row" class="features-matrix__project"><i class="fas fa-cube me-1" aria-hidden="true"></i><?= htmlspecialchars($projectsNames[$project]) ?></th>
                                            <?php foreach ($acceptedFeatures as $feature => $FBProjects): ?>
                                            <?php if (array_key_exists($project, $FBProjects)): ?>
                                            <td data-feature="<?= htmlspecialchars($feature) ?>" data-search="<?= htmlspecialchars($projectSearchKey($project)) ?>" data-behind="<?= (int) $FBProjects[$project]['behind_commits'] ?>" data-ahead="<?= (int) $FBProjects[$project]['ahead_commits'] ?>">
                                                <div class="features-matrix__cell">
                                                    <?= componentFeatureRepoBrancheStatus($FBProjects[$project]); ?>
                                                    <a href="https://ci.exoplatform.org/job/FB/job/<?= getModuleCiPrefix($project) . rawurlencode($project) ?>-<?= rawurlencode($feature) ?>-fb-ci/" target="_blank" rel="tooltip" title="CI job for <?= htmlspecialchars($projectsNames[$project]) ?> on <?= htmlspecialchars($feature) ?> (green: passing, red: failing, yellow: unstable, grey: not run)">
                                                        <span class="ci-dot"><img src="https://ci.exoplatform.org/buildStatus/icon?job=fb/<?= getModuleCiPrefix($project) . rawurlencode($project) ?>-<?= rawurlencode($feature) ?>-fb-ci&amp;subject=&amp;status=+" loading="lazy" alt="CI build status for <?= htmlspecialchars($projectsNames[$project]) ?>"></span>
                                                    </a>
                                                </div>
                                            </td>
                                            <?php else: ?>
                                            <td data-feature="<?= htmlspecialchars($feature) ?>" class="features-matrix__empty" aria-label="Not part of this feature">&mdash;</td>
                                            <?php endif; ?>
                                            <?php endforeach; ?>
                                        </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                    <?php endif; ?>

                    <!-- Others branches -->
                    <?php if (!empty($otherFeatures)): ?>
                    <div class="card mb-4 features-section" data-section="other">
                        <div class="card-header">
                            <div class="w-100">
                                <div class="d-flex align-items-center flex-wrap">
                                    <i class="fas fa-exclamation-triangle text-warning me-2"></i>
                                    <h5 class="mb-0">Other branches</h5>
                                    <span class="badge bg-warning ms-2 features-count" data-total="<?= count($otherFeatures) ?>"><?= count($otherFeatures) ?></span>
                                </div>
                                <small class="text-danger d-block mt-1">
                                    <i class="fas fa-broom me-1"></i>
                                    ARE YOU SURE YOU DON'T NEED TO DO SOME BRANCH CLEANUP?
                                </small>
                            </div>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <?php foreach ($otherFeatures as $feature => $FBProjects): ?>
                                <?php $featureSlug = str_replace(["/", "."], "-", $feature); ?>
                                <div class="col-md-6 col-lg-4 mb-3 feature-item" id="feature-<?= htmlspecialchars($featureSlug) ?>" <?= $featureFilterAttrs($feature, $FBProjects) ?>>
                                    <div class="feature-card card h-100">
                                        <div class="card-body">
                                            <div class="feature-title">
                                                <a href="<?= htmlspecialchars(currentPageURL() . "#feature-" . $featureSlug) ?>" class="text-warning">
                                                    <i class="fas fa-bookmark" aria-hidden="true"></i>
                                                </a>
                                                <code class="small"><?= htmlspecialchars($feature) ?></code>
                                            </div>
                                            <div class="mt-2">
                                                <?php
                                                $projectCount = count($FBProjects);
                                                $firstProjects = array_slice($FBProjects, 0, 3, true);
                                                ?>
                                                <span class="badge bg-info me-2"><?= $projectCount ?> project(s)</span>
                                                <?php if ($projectCount > 0): ?>
                                                    <small class="text-muted">
                                                        <?= htmlspecialchars(implode(', ', array_map(function($p) use ($projectsNames) {
                                                            return $projectsNames[$p];
                                                        }, array_keys($firstProjects)))) ?>
                                                        <?= $projectCount > 3 ? '...' : '' ?>
                                                    </small>
                                                <?php endif; ?>
                                            </div>
                                            <?php if (!empty($FBProjects)): ?>
                                            <div class="mt-2 d-flex gap-2 flex-wrap">
                                                <?php foreach (array_slice($FBProjects, 0, 2) as $project => $data): ?>
                                                    <span class="badge bg-light text-dark">
                                                        <?= componentFeatureRepoBrancheStatus($data) ?>
                                                    </span>
                                                <?php endforeach; ?>
                                                <?php if (count($FBProjects) > 2): ?>
                                                    <span class="badge bg-secondary">+<?= count($FBProjects) - 2 ?> more</span>
                                                <?php endif; ?>
                                            </div>
                                            <?php endif; ?>
                                        </div>
                                    </div>
                                </div>
                                <?php endforeach; ?>
                            </div>
                        </div>
                    </div>
                    <?php endif; ?>
                    <!-- Empty state -->
                    <?php if (empty($acceptedFeatures) && empty($otherFeatures)): ?>
                    <div class="empty-section">
                        <i class="fas fa-code-branch"></i>
                        <h4>No branches found</h4>
                        <p class="text-muted">There are currently no feature branches to display.</p>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </div>
        <!-- /container -->
    </div>
</div>
<?php pageFooter(); ?>
</body>
</html>
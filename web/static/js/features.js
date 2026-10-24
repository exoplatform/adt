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

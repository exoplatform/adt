document.addEventListener('DOMContentLoaded', function() {
  // the numbers of the page, written by the server as JSON
  var chartData = JSON.parse(document.getElementById('chartData').textContent);

  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[rel=tooltip]'));
  tooltipTriggerList.map(function(tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl);
  });

  // Highlight the dependency-links row jumped to via a "Depends on" badge
  // or a direct #repo-xxx link, so the target is easy to spot after the scroll.
  function highlightDependencyRow() {
    var current = document.querySelector('.dependency-row.highlight');
    if (current) current.classList.remove('highlight');
    if (location.hash.indexOf('#repo-') !== 0) return;
    var row = document.querySelector(location.hash);
    if (row) row.classList.add('highlight', 'dependency-row');
  }
  highlightDependencyRow();
  window.addEventListener('hashchange', highlightDependencyRow);

  var chartColors = {
    primary: getComputedStyle(document.documentElement).getPropertyValue('--secondary-color').trim() || '#3498db',
    success: getComputedStyle(document.documentElement).getPropertyValue('--success-color').trim() || '#27ae60',
    warning: getComputedStyle(document.documentElement).getPropertyValue('--warning-color').trim() || '#f39c12',
    danger: getComputedStyle(document.documentElement).getPropertyValue('--danger-color').trim() || '#e74c3c',
    info: getComputedStyle(document.documentElement).getPropertyValue('--info').trim() || '#54a0ff',
    accent2: getComputedStyle(document.documentElement).getPropertyValue('--accent2').trim() || '#00d2d3',
    text: getComputedStyle(document.documentElement).getPropertyValue('--text-muted').trim() || '#6c757d',
    cardBg: getComputedStyle(document.documentElement).getPropertyValue('--card-bg').trim() || '#ffffff',
    gridColor: getComputedStyle(document.documentElement).getPropertyValue('--border-color').trim() || '#dee2e6'
  };
  var trendPalette = [chartColors.primary, chartColors.accent2, chartColors.success, chartColors.warning, chartColors.danger];

  function hexToRgb(hex) {
    var r = parseInt(hex.slice(1,3), 16), g = parseInt(hex.slice(3,5), 16), b = parseInt(hex.slice(5,7), 16);
    return r+','+g+','+b;
  }

  new Chart(document.getElementById('commitsChart'), {
    type: 'bar',
    data: {
      labels: chartData.labels,
      datasets: [{
        label: 'Commits',
        data: chartData.activity,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.primary) + ', 0.6)',
        borderColor: chartColors.primary,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { maxTicksLimit: 15, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });

  var repoTrendDates = chartData.trendDates;
  var repoTrendSeries = chartData.trendSeries;
  new Chart(document.getElementById('repoTrendChart'), {
    type: 'line',
    data: {
      labels: repoTrendDates,
      datasets: Object.keys(repoTrendSeries).map(function(label, i) {
        var color = trendPalette[i % trendPalette.length];
        return {
          label: label,
          data: repoTrendSeries[label],
          borderColor: color,
          backgroundColor: 'rgba(' + hexToRgb(color) + ', 0.15)',
          borderWidth: 2,
          pointRadius: 0,
          tension: 0,
          fill: false
        };
      })
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: true, position: 'bottom', labels: { color: chartColors.text, boxWidth: 12 } } },
      scales: {
        x: { ticks: { maxTicksLimit: 15, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });

  new Chart(document.getElementById('repoChart'), {
    type: 'bar',
    data: {
      labels: chartData.repoLabels,
      datasets: [{
        label: 'Commits',
        data: chartData.repoCommits,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.success) + ', 0.6)',
        borderColor: chartColors.success,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { ticks: { font: { size: 10 }, color: chartColors.text }, grid: { display: false } }
      }
    }
  });

  new Chart(document.getElementById('authorChart'), {
    type: 'bar',
    data: {
      labels: chartData.authors,
      datasets: [{
        label: 'Commits',
        data: chartData.authorCommits,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.warning) + ', 0.6)',
        borderColor: chartColors.warning,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { ticks: { font: { size: 10 }, color: chartColors.text }, grid: { display: false } }
      }
    }
  });

  new Chart(document.getElementById('dowChart'), {
    type: 'bar',
    data: {
      labels: chartData.dowLabels,
      datasets: [{
        label: 'Commits',
        data: chartData.dowValues,
        backgroundColor: 'rgba(' + hexToRgb(chartColors.info) + ', 0.6)',
        borderColor: chartColors.info,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: chartColors.text }, grid: { color: chartColors.gridColor } },
        y: { beginAtZero: true, ticks: { stepSize: 1, color: chartColors.text }, grid: { color: chartColors.gridColor } }
      }
    }
  });
});

<?php

/**
 * Return a string representation of a variable
 *
 * @param      $var
 * @param bool $html do we return html compliant markup ? (default: false)
 *
 * @return string
 */
function debug_var($var, $html = false) {
  ob_start();
  var_export($var);
  $dump = ob_get_clean();
  if ($html) {
    return "<pre class='debug-dump'><code>" . htmlspecialchars($dump) . "</code></pre>";
  }
  return $dump;
}

function debug_var_toggle($var) {
  // An id starting with a digit is not a valid CSS selector: Bootstrap's data-bs-target would throw
  $html_id = 'debug-toggle-' . random_int(0, PHP_INT_MAX);
  $content = "";
  $content .= '<button type="button" class="btn btn-sm btn-outline-primary mb-2" data-bs-toggle="collapse" data-bs-target="#' . $html_id . '">';
  $content .= '<i class="fas fa-code me-2"></i>Toggle Details';
  $content .= '</button>';
  $content .= '<div id="' . $html_id . '" class="collapse">';
  $content .= debug_var($var, true);
  $content .= "</div>";

  return $content;
}

/**
 * Open a debug page: <html>, head, navigation, page title and the debug menu.
 * Close it with debugPageEnd(). $autoRefresh is passed to pageHeader().
 */
function debugPageBegin($title, $heading, $subtitle, $autoRefresh = false) {
  echo '<html lang="en"><head>';
  pageHeader("debug - " . $title, $autoRefresh);
  echo '</head><body>';
  pageTracker();
  pageNavigation();
  echo '<div id="wrap"><div id="main">';
  echo '<div class="page-header"><h1 class="page-header__title">' . htmlspecialchars($heading) . '</h1>';
  echo '<p class="page-header__subtitle">' . htmlspecialchars($subtitle) . '</p></div>';
  echo '<div class="container-fluid"><div class="row"><div class="col-12">';
  echo componentDebugMenu();
}

function debugPageEnd() {
  echo '</div></div></div></div></div>';
  pageFooter();
  echo '</body></html>';
}

/** Bootstrap alert, message is escaped */
function debugAlert($type, $message) {
  return '<div class="alert alert-' . $type . '">' . htmlspecialchars($message) . '</div>';
}

/** Human readable size ("1.5G") */
function debugBytes($bytes) {
  $units = ['B', 'K', 'M', 'G', 'T'];
  $i = 0;
  $bytes = (float)$bytes;
  while ($bytes >= 1024 && $i < count($units) - 1) {
    $bytes /= 1024;
    $i++;
  }
  return sprintf($i ? '%.1f%s' : '%d%s', $bytes, $units[$i]);
}

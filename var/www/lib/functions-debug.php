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
  if ($html) {
    $content = "<pre class='bg-dark text-light p-3 rounded'><code>" . ob_get_clean() . "</code></pre>";
  } else {
    $content = ob_get_clean();
  }
  return $content;
}

function debug_var_toggle($var) {
  $html_id = rand();
  $content = "";
  $content .= '<button type="button" class="btn btn-sm btn-outline-primary mb-2" data-bs-toggle="collapse" data-bs-target="#' . $html_id . '">';
  $content .= '<i class="fas fa-code me-2"></i>Toggle Details';
  $content .= '</button>';
  $content .= '<div id="' . $html_id . '" class="collapse">';
  $content .= debug_var($var, true);
  $content .= "</div>";

  return $content;
}

?>
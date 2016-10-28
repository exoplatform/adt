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
    $content = "<pre>" . ob_get_clean() . "</pre>";
  } else {
    $content = ob_get_clean();
  }
  return $content;
}

function debug_var_toggle($var) {
  $html_id = rand();
  $content = "";
  $content .= '<button type="button" class="btn btn-danger" data-toggle="collapse" data-target="#' . $html_id . '">details</button>';
  $content .= '<div id="' . $html_id . '" class="collapse out">';
  $content .= debug_var($var, true);
  $content .= "</div>";

  return $content;
}

?>

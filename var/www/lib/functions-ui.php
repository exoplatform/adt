<?php
require_once(dirname(__FILE__) . '/functions-ui-form-edit-fb.php');
require_once(dirname(__FILE__) . '/functions-ui-form-edit-note.php');

/**
 * Insert the page header lines
 *
 * @param string $title the title of the page (default: none)
 */
function pageHeader ($title="") {
  ?>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <meta http-equiv="refresh" content="120">
    <title>Acceptance<?= ( empty($title) ? "" : " - " . $title ) ?></title>
    <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico"/>
    <link href="//netdna.bootstrapcdn.com/bootswatch/2.3.2/spacelab/bootstrap.min.css" rel="stylesheet">
    <link href="//netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css" rel="stylesheet">
    <link href="./style.css" media="screen" rel="stylesheet" type="text/css"/>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js" type="text/javascript"></script>
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/js/bootstrap.min.js" type="text/javascript"></script>
  <?php
}

/**
 * Insert the script tag for Google Analytics tracking
 *
 * @param string $id the google tracker id
 */
function pageTracker ($id='UA-1292368-28') {
  ?>
  <script>
    (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
        (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
      m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
    })(window,document,'script','https://www.google-analytics.com/analytics.js','ga');

    ga('create', '<?= $id ?>', 'auto');
    ga('send', 'pageview');

  </script>
  <?php
}

/**
 * Insert the navigation bar
 */
function pageNavigation () {
  $nav=array();
  $nav["Home"]="/";
  $nav["QA"]="/qa.php";
  $nav["Sales"]="/sales.php";
  $nav["CP"]="/customers.php";
  $nav["Company"]="/company.php";
  $nav["Features"]="/features.php";
  $nav["Servers"]="/servers.php";
  ?>
<!-- navbar ================================================== -->
<div class="navbar navbar-fixed-top">
    <div class="navbar-inner">
        <div class="container-fluid">
            <a class="brand" href="/"><?=$_SERVER['SERVER_NAME'] ?></a>
            <ul class="nav">
            <?php
              foreach ($nav as $label => $url) {
                if ($url == $_SERVER['REQUEST_URI'] ){
                  echo '<li class="active"><a href='.$url.'>'.$label.'</a></li>';
                } else {
                  echo '<li><a href='.$url.'>'.$label.'</a></li>';
                }
              }
             ?>
            </ul>
        </div>
    </div>
</div>
<!-- /navbar -->
  <?php
}

/**
 * Insert the Footer
 */
function pageFooter () {
  ?>
<!-- Footer ================================================== -->
<div id="footer">
Copyright &copy; 2006-<?= date("Y") ?>. All rights Reserved, eXo Platform SAS -
<a href="/stats/awstats.pl?config=<?= $_SERVER['SERVER_NAME'] ?>" title="http://<?= $_SERVER['SERVER_NAME'] ?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="Statistics" width="16" height="16" class="left icon"/></a>
</div>
<script type="text/javascript">
    $(document).ready(function () {
        $('body').tooltip({ selector: '[rel=tooltip]'});
        $('body').popover({ selector: '[rel=popover]', trigger: 'hover'});
    });
</script>
  <?php
}

function buildTableTitleDev($plf_branch) {
  switch ($plf_branch) {
    case "1.0.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "1.1.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;  
    case "1.2.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "1.3.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "1.4.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "4.0.x":
    case "4.1.x":
    case "4.2.x":
    case "4.3.x":
    case "4.4.x":
    case "5.0.x":
    case "5.1.x":
    case "5.2.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;
    case "5.3.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;
    case "6.0.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
       break;  
    case "6.1.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "6.2.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "6.3.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "6.4.x":
      $content="Platform " . $plf_branch . " based builds (R&D) - next product release (no date yet)";
      break;  
    case "5.x":
      $content="Platform " . $plf_branch . " based builds (R&D) - perhaps next features ;-)"; 
      break;
    case "4.0.x Demo":
    case "4.1.x Demo":
    case "4.2.x Demo":
    case "4.3.x Demo":
    case "4.4.x Demo":
    case "5.0.x Demo":
    case "5.1.x Demo":
    case "5.2.x Demo":
    case "5.3.x Demo":
      $content="Platform " . $plf_branch . "s";
      break;
    case "COMPANY":
      $content="Company internal projects";
      break;
    case "CODEFEST":
      $content="eXo Codefest";
      break;
    case "UNKNOWN":
      $content="Unclassified projects";
      break;
    default:
      $content="Platform " . $plf_branch . " based build (Unclassified)";
  }
  return $content;
}

/**
 * Return the markup for labels
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentLabels ($deployment_descriptor) {
  $content="";
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_LABELS')) {
    if (is_array($deployment_descriptor->DEPLOYMENT_LABELS)) {
      $labels = $deployment_descriptor->DEPLOYMENT_LABELS;
    } else {
      $labels[] = $deployment_descriptor->DEPLOYMENT_LABELS;
    }
    foreach ($labels as $label) {
      $content.='<span class="label label-label">'.$label.'</span>&nbsp;';
    }
  }
  return $content;
}

/**
 * Return the markup for addons labels
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentAddonsTags ($deployment_descriptor) {
  $content="";

  $content.=componentAddonsDistributionTags($deployment_descriptor)."&nbsp;";

  if (property_exists($deployment_descriptor, 'DEPLOYMENT_ADDONS')) {
    if (is_array($deployment_descriptor->DEPLOYMENT_ADDONS)) {
      $labels = $deployment_descriptor->DEPLOYMENT_ADDONS;
    } else {
      $labels[] = $deployment_descriptor->DEPLOYMENT_ADDONS;
    }
    foreach ($labels as $label) {
      $label_array=explode(':',$label,2);
      $content.='<span class="label label-addon" rel="tooltip" data-original-title="version: '.(isset($label_array[1]) ? $label_array[1] : 'latest').'">'.$label_array[0].'</span>&nbsp;';
    }
  }
  return $content;
}

/**
 * Return the markup for distribution addons labels
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentAddonsDistributionTags ($deployment_descriptor) {
  $content='<span class="label label-addon" rel="tooltip" data-original-title="distribution add-ons: '.$deployment_descriptor->PRODUCT_ADDONS_DISTRIB.'"><i class="icon-gift"></i></span>';
  return $content;
}

/**
 * Return the markup for instance upgrades eligiblity
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentUpgradeEligibility($deployment_descriptor, $is_label_addon = true) {
  if (property_exists($deployment_descriptor, 'INSTANCE_TOKEN') && $deployment_descriptor->INSTANCE_TOKEN) {
    if (!$is_label_addon) {
      $content='<span rel="tooltip" data-original-title="This instance is eligible for upgrades."><i class="icon-flag"></i></span>';  
    } else {  
      $content='<span class="label label-addon" rel="tooltip" data-original-title="This instance is eligible for upgrades."><i class="icon-flag"></i></span>';
    }
      return $content;
  }
  return '';
}

/**
 * Return the markup for instance dev mode availability
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDevModeEnabled($deployment_descriptor, $is_label_addon = true) {
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_DEV_ENABLED') && $deployment_descriptor->DEPLOYMENT_DEV_ENABLED) {
    if (!$is_label_addon) {
      $content='<span rel="tooltip" data-original-title="This instance is enabled with Dev mode."><i class="icon-github"></i></span>';  
    } else {  
      $content='<span class="label label-addon" rel="tooltip" data-original-title="This instance is enabled with Dev mode."><i class="icon-github"></i></span>';
    }
      return $content;
  }
  return '';
}

/**
 * Return the markup for instance debug mode availability
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDebugModeEnabled($deployment_descriptor, $is_label_addon = true) {
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_DEBUG_ENABLED') && $deployment_descriptor->DEPLOYMENT_DEBUG_ENABLED) {
    if (!$is_label_addon) {
      $content='<span rel="tooltip" data-original-title="This instance is enabled with Debug mode."><i class="icon-stethoscope"></i></span>';  
    } else {  
      $content='<span class="label label-addon" rel="tooltip" data-original-title="This instance is enabled with Debug mode."><i class="icon-stethoscope"></i></span>';
    }
      return $content;
  }
  return '';
}

/**
 * Return the markup for the Deployment Status
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentStatusIcon ($deployment_descriptor) {
  if ($deployment_descriptor->DEPLOYMENT_STATUS == "Up") {
    $status_icon="green_ball.png";
  } else {
    $status_icon="red_ball.png";
  }
  return '<img width="16px" height="16px" src="/images/'.$status_icon.'" alt="Status: '.$deployment_descriptor->DEPLOYMENT_STATUS.'" class="icon"/>';
}

/**
 * Return markup for the Application Server type
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentAppServerIcon ($deployment_descriptor) {
  $content='<img src="/images/'.$deployment_descriptor->DEPLOYMENT_APPSRV_TYPE.'.png"';
  $content.=' width="16" height="16"';
  $content.=' alt="Application Server : '.$deployment_descriptor->DEPLOYMENT_APPSRV_TYPE.'"';
  $content.=' class="icon"/>';
  return $content;
}

/**
 * Get the markup for the Edit Note icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentEditNoteIcon ($deployment_descriptor) {
  $content='<a rel="tooltip" title="Add/Edit Instance Note"';
  $content.='href="#edit-note-'.str_replace(".", "_", $deployment_descriptor->INSTANCE_KEY).'"';
  $content.='data-toggle="modal"><i class="icon-pencil"></i></a>';
  $content.=getFormEditNote($deployment_descriptor);
  return $content;
}

/**
 * Get the markup for the Specification link icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup or empty if no specification on the deployment
 */
function componentSpecificationIcon ($deployment_descriptor) {
  $content="";
  if (!empty($deployment_descriptor->SPECIFICATIONS_LINK)) {
    $content.='<a rel="tooltip" title="Specifications link"';
    $content.='href="'.$deployment_descriptor->SPECIFICATIONS_LINK.'" target="_blank">';
    $content.='<i class="icon-book"></i></a>';
  }
  return $content;
}

/**
 * Return markup for the Database type icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDatabaseIcon ($deployment_descriptor) {
  if (stripos($deployment_descriptor->DATABASE, 'mysql') !== false) {
    $database_icon = "mysql";
  } else if (stripos($deployment_descriptor->DATABASE, 'mariadb') !== false) {
    $database_icon = "mariadb";
  } else if (stripos($deployment_descriptor->DATABASE, 'postgres') !== false) {
    $database_icon = "postgresql";
  } else if (stripos($deployment_descriptor->DATABASE, 'oracle') !== false) {
    $database_icon = "oracle";
  } else if (stripos($deployment_descriptor->DATABASE, 'sqlserver') !== false) {
    $database_icon = "sqlserver";
  } else {
    $database_icon = "none";
  }
  $content="";
  if ($database_icon != "none") {
  $content.='<img src="/images/'.$database_icon.'.png" witdh="8px" height="8px" alt="'.$database_icon.'"/>&nbsp;';
  }
  if (empty($deployment_descriptor->DEPLOYMENT_DATABASE_VERSION)) {
    $content.='<span class="label">-NC-</span>&nbsp;';
  } else {
    $content.='<span class="label">'.$deployment_descriptor->DEPLOYMENT_DATABASE_VERSION.'</span>&nbsp;';
  }
  return $content;
}

/**
 * Return markup for the Visibility icon
 *
 * @param $deployment_descriptor
 * @param $color The color for the icon (default: none)
 *
 * @return string html markup
 */
function componentVisibilityIcon ($deployment_descriptor, $color="") {
  if ($deployment_descriptor->DEPLOYMENT_APACHE_SECURITY === "public") {
      $icon = "icon-globe";
  } else if ($deployment_descriptor->DEPLOYMENT_APACHE_SECURITY === "private") {
      $icon = "icon-lock";
  } else {
      // should never occurs
      $icon = "icon-question-sign";
  }
  return '<i class="'.$icon.(empty($color) ? '' : ' '.$color ).'"></i>';
}

/**
 * Get the markup for the Product Info icon with popover
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentProductInfoIcon ($deployment_descriptor) {
  return '<a rel="popover" data-content="'.componentProductHtmlPopover($deployment_descriptor).'" data-html="true"><i class="icon-info-sign"></i></a>';
}

/**
 * Insert markup for the Artifact download icon link
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDownloadIcon ($deployment_descriptor) {
  $data_content="<strong>GroupId:</strong> ".$deployment_descriptor->ARTIFACT_GROUPID."<br/>";
  $data_content.="<strong>ArtifactId:</strong> ".$deployment_descriptor->ARTIFACT_ARTIFACTID."<br/>";
  $data_content.="<strong>Version/Timestamp:</strong> ".$deployment_descriptor->ARTIFACT_TIMESTAMP;

  $content='<a href="'.$deployment_descriptor->ARTIFACT_DL_URL .'" rel="popover" title="Download artifact from Acceptance" data-content="'.$data_content.'" data-html="true">';
  $content.='<i class="icon-download-alt"></i>';
  $content.='</a>';

  return $content;
}

/**
 * Return the markup for the Product Html Label
 *
 * @param $deployment_descriptor
 * @param bool $simple if true then ignore Branch Description and Instance Note if present (default: false)
 *
 * @return string html markup
*/
function componentProductHtmlLabel ($deployment_descriptor, $simple=false) {
  if (empty($deployment_descriptor->PRODUCT_DESCRIPTION)) {
      $content = $deployment_descriptor->PRODUCT_NAME;
  } else {
      $content = $deployment_descriptor->PRODUCT_DESCRIPTION;
  }
  if (!empty($deployment_descriptor->INSTANCE_ID)) {
      $content .= ' (' . $deployment_descriptor->INSTANCE_ID . ')';
  }
  if ($simple == false) {
    if (!empty($deployment_descriptor->BRANCH_DESC)) {
        $content = '<span class="muted">'.$content.'</span>&nbsp;&nbsp;-&nbsp;&nbsp;'.$deployment_descriptor->BRANCH_DESC;
    }
    if (!empty($deployment_descriptor->INSTANCE_NOTE)) {
        $content = "<span class=\"muted\">" . $content . "</span>&nbsp;&nbsp;-&nbsp;&nbsp;" . $deployment_descriptor->INSTANCE_NOTE;
    }
  }
  return $content;
}

/**
 * Get the markup for the link(s) to open the Product url.
 *
 * @param $deployment_descriptor
 * @param string $link_text
 * @param bool $enforce_ssl
 *
 * @return string
 */
function componentProductOpenLink ($deployment_descriptor, $link_text="", $enforce_ssl=false) {
  if ($deployment_descriptor->DEPLOYMENT_APACHE_HTTPS_ENABLED) {
    $ssl=true;
  } else {
    $ssl=false;
  }
  if ($deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS) {
    $url = "http://" . $deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS;
  } else {
    $url = $deployment_descriptor->DEPLOYMENT_URL;
  }
  // Buy page deployment specificity
  if (isInstanceBuyPage($deployment_descriptor)) {
    $url.='/buy/';
  }
  $content='<a href="';
  if ($enforce_ssl && $ssl) {
    $content.=preg_replace("/http:(.*)/", "https:$1", $url);
  } else {
    $content.=$url;
  }
  $content.='" target="_blank">';
  $content.=empty($link_text) ? componentProductHtmlLabel($deployment_descriptor) : $link_text;
  $content.='</a>';

  if (! $enforce_ssl && $ssl) {
    $content.='&nbsp;(<a rel="tooltip" title="HTTPS link available" href="';
    $content.=preg_replace("/http:(.*)/", "https:$1", $url);
    $content.='" target="_blank">&nbsp;<img src="/images/ssl.png" width="16" height="16" alt="SSL"class="icon"/></a>)';
  }
  return $content;
}

/**
 * Return the markup for the Product Version
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentProductVersion ($deployment_descriptor) {
  if (preg_match("/.*-M(LT|BL)$/", $deployment_descriptor->BASE_VERSION)) {
    $tooltipmessage=(preg_match("/.*-MBL$/", $deployment_descriptor->BASE_VERSION) ? "Before latest" : "Latest")." milestone continuous deployment enabled";
    $content=$deployment_descriptor->ARTIFACT_TIMESTAMP.' <span style="font-size: small" class="muted" rel="tooltip" data-original-title="'.$tooltipmessage.'">Auto</span>';
  } else {
    $content=$deployment_descriptor->BASE_VERSION;
    $timestamp=substr_replace($deployment_descriptor->ARTIFACT_TIMESTAMP, "", 0, strlen($deployment_descriptor->BASE_VERSION));
    if (!empty($timestamp)) {
      $content.='<span style="font-size: small" class="muted" rel="tooltip" data-original-title="'.$deployment_descriptor->ARTIFACT_TIMESTAMP.'">';
      if (!empty($deployment_descriptor->BRANCH_NAME)) {
        $content.='-'.$deployment_descriptor->BRANCH_NAME;
      }
      $content.='-SNAPSHOT</span>';
    }
  }
  return $content;
}

/**
 * Return the markup for the Product Html Popover
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentProductHtmlPopover ($deployment_descriptor) {
  $content = '<strong>Product:</strong> '.componentProductHtmlLabel($deployment_descriptor).'<br/>';
  $content .= '<strong>Version:</strong> '.$deployment_descriptor->PRODUCT_VERSION.'<br/>';
  $content .= '<strong>Packaging:</strong> '.$deployment_descriptor->DEPLOYMENT_APPSRV_TYPE.'&nbsp;'.componentAppServerIcon($deployment_descriptor).'<br/>';
  $content .= '<strong>Database:</strong> '.$deployment_descriptor->DATABASE.'<br/>';
  $content .= '<strong>Visibility:</strong> '.$deployment_descriptor->DEPLOYMENT_APACHE_SECURITY.'&nbsp;'.componentVisibilityIcon($deployment_descriptor);
  $content .= "<br/><strong>HTTPS available:</strong> " . ($deployment_descriptor->DEPLOYMENT_APACHE_HTTPS_ENABLED ? "yes" : "no");
  $content .= "<br/><strong>ES embedded:</strong> " . ($deployment_descriptor->DEPLOYMENT_ES_EMBEDDED ? "yes" : "no");
  $content .= "<br/><strong>OnlyOffice addon:</strong> " . ($deployment_descriptor->DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED ? "yes" : "no");
  $content .= "<br/><strong>CMIS Server:</strong> " . ($deployment_descriptor->DEPLOYMENT_CMISSERVER_ENABLED ? "yes" : "no");
  if ($deployment_descriptor->DEPLOYMENT_CHAT_ENABLED ) {
    $content .= "<br/><strong>Chat embedded:</strong> " . ($deployment_descriptor->DEPLOYMENT_CHAT_EMBEDDED ? "yes" : "no");
    $content .= "<br/><strong>Mongo db version:</strong> " . $deployment_descriptor->DEPLOYMENT_CHAT_MONGODB_VERSION;
  }
  //SWF-3125: Use Apache version to know if WebSocket can be enabled.
  $content .= "<br/><strong>WebSocket available:</strong> " . ((strcmp($deployment_descriptor->ACCEPTANCE_APACHE_VERSION_MINOR, "2.4") == 0 && $deployment_descriptor->DEPLOYMENT_APACHE_WEBSOCKET_ENABLED) ? "yes" : "no");
  $content .= "<br/><strong>Virtual Host:</strong> " . preg_replace("/https?:\/\/(.*)/", "$1", $deployment_descriptor->DEPLOYMENT_URL);
  if ($deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS) {
      $content .= "<br/><strong>Virtual Host Alias:</strong> " . $deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS;
  }
  if ($deployment_descriptor->DEPLOYMENT_INFO) {
      $content .= "<hr/><strong>Info:</strong> " . $deployment_descriptor->DEPLOYMENT_INFO;
  }
  $content .= "<br/>";
  return htmlentities($content);
}

/**
 * Get the markup for the available actions of the deployment
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDeploymentActions ($deployment_descriptor) {
  $deploymentURL=$deployment_descriptor->DEPLOYMENT_EXT_HOST;
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_APACHE_VHOST_ALIAS') && $deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS != "" ) {
    $deploymentURL=$deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS;
  }
  $content='<a href="'.$deployment_descriptor->DEPLOYMENT_LOG_APPSRV_URL.'" rel="tooltip" title="Instance logs" target="_blank">';
  $content.='<img src="/images/'.$deployment_descriptor->DEPLOYMENT_APPSRV_TYPE.'.png" width="16" height="16" alt="instance logs" class="icon"/>';
  $content.='</a>';
  $content.=' | <a href="'.$deployment_descriptor->DEPLOYMENT_LOG_APACHE_URL.'" rel="tooltip" title="apache logs" target="_blank">';
  $content.='<img src="/images/apache.png" width="16" height="16" alt="apache logs" class="icon"/>';
  $content.='</a>';
  if (!empty($deployment_descriptor->DEPLOYMENT_JMX_URL)) {
    $content.=' | <a href="'.$deployment_descriptor->DEPLOYMENT_JMX_URL.'" rel="tooltip" title="jmx monitoring" target="_blank">';
    $content.='<img src="/images/action_log.png" alt="JMX url" width="16" height="16" class="icon"/></a>';
  }
  if (!empty($deployment_descriptor->DEPLOYMENT_LDAP_LINK)) {
    $content.=' | <a href="'.$deployment_descriptor->DEPLOYMENT_LDAP_LINK.'" rel="tooltip" title="ldap url" target="_blank">';
    $content.='<img src="/images/ldap_link.png" alt="ldap url" width="16" height="16" class="icon"/></a>';
  }
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_CRASH_ENABLED') && $deployment_descriptor->DEPLOYMENT_CRASH_ENABLED) {
    $content.=' | <a href="ssh://root@'.$deployment_descriptor->DEPLOYMENT_EXT_HOST.':'.$deployment_descriptor->DEPLOYMENT_CRASH_SSH_PORT.'rel="tooltip" title="CRaSH SSH Access">';
    $content.='<i class="icon-laptop"></i></a>';
  }
  $content.=' | <a href="'.$deployment_descriptor->DEPLOYMENT_AWSTATS_URL.'" rel="tooltip" title="Usage statistics" target="_blank">';
  $content.='<img src="/images/server_chart.png" alt="'.$deployment_descriptor->DEPLOYMENT_URL.' usage statistics" width="16" height="16" class="icon"/>';
  $content.='</a>';
  // Elasticsearch access
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_ES_ENABLED') && $deployment_descriptor->DEPLOYMENT_ES_ENABLED) {
    $content.=' | <a href="http://'.$deploymentURL.'/elasticsearch" rel="tooltip" title="Elasticsearch">';
    $content.='<img src="/images/elastic.svg" width="16" height="16" alt="elasticsearch" class="icon"/></a>';
  }
  // Mailhog access
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_MAILHOG_ENABLED') && $deployment_descriptor->DEPLOYMENT_MAILHOG_ENABLED) {
    $content.=' | <a href="http://'.$deploymentURL.'/mailhog/" rel="tooltip" title="Mailhog">';
    $content.='<img src="/images/mailhog.svg" width="16" height="16" alt="mailhog" class="icon"/></a>';
  }
  // Admin Mongo access
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_ADMIN_MONGO_ENABLED') && $deployment_descriptor->DEPLOYMENT_ADMIN_MONGO_ENABLED) {
    $content.=' | <a href="http://'.$deploymentURL.'/adminmongo/" rel="tooltip" title="Admin Mongo">';
    $content.='<img src="/images/adminmongo.svg" width="16" height="16" alt="Admin Mongo" class="icon"/></a>';
  }
  // Keycloak admin access
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_KEYCLOAK_ENABLED') && $deployment_descriptor->DEPLOYMENT_KEYCLOAK_ENABLED) {
      $content.=' | <a href="http://'.$deploymentURL.'/auth/admin/" rel="tooltip" title="Keycloak">';
      $content.='<img src="/images/keycloak.svg" width="16" height="16" alt="keycloak" class="icon"/></a>';
  }
  // CloudBeaver access
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_CLOUDBEAVER_ENABLED') && $deployment_descriptor->DEPLOYMENT_CLOUDBEAVER_ENABLED) {
    $content.=' | <a href="http://'.$deploymentURL.'/cloudbeaver/" rel="tooltip" title="CloudBeaver">';
    $content.='<img src="/images/cloudbeaver.png" width="16" height="16" alt="CloudBeaver" class="icon"/></a>';
  }
  // PHPLDAPADMIn access
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_PHPLDAPADMIN_ENABLED') && $deployment_descriptor->DEPLOYMENT_PHPLDAPADMIN_ENABLED) {
      $content.=' | <a href="http://'.$deploymentURL.':'.$deployment_descriptor->DEPLOYMENT_PHPLDAPADMIN_HTTP_PORT.'" rel="tooltip" title="phpLDAPAdmin">';
      $content.='<img src="/images/phpldapadmin.png" width="16" height="16" alt="phpLDAPAdmin" class="icon"/></a>';
  }
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_SFTP_ENABLED') && $deployment_descriptor->DEPLOYMENT_SFTP_ENABLED) {
      $content.=' | <a href="'.$deployment_descriptor->DEPLOYMENT_SFTP_LINK.'" rel="tooltip" title="Sftp">';
      $content.='<img src="/images/lecko.svg" width="16" height="16" alt="Lecko" class="icon"/></a>';
  }
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_CMISSERVER_ENABLED') && $deployment_descriptor->DEPLOYMENT_CMISSERVER_ENABLED) {
    $content.=' | <a href="http://'.$deployment_descriptor->DEPLOYMENT_EXT_HOST.'/cmis" rel="tooltip" title="CMIS Server">';
    $content.='<img src="/images/cmis.png" width="16" height="16" alt="cmis" class="icon"/></a>';
  }

  return $content;
}

/**
 * Get markup for a Feature Branch status label
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBStatusLabel($deployment_descriptor) {
  $acceptance_state_class = "";
  if ($deployment_descriptor->ACCEPTANCE_STATE === "Implementing") {
    $acceptance_state_class = " label-info";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "Engineering Review") {
    $acceptance_state_class = " label-warning";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "QA Review") {
    $acceptance_state_class = " label-inverse";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "QA In Progress") {
    $acceptance_state_class = " label-warning";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "QA Rejected") {
    $acceptance_state_class = " label-important";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "Validated") {
    $acceptance_state_class = " label-success";
  }
  return '<span class="label'.$acceptance_state_class.'">'.$deployment_descriptor->ACCEPTANCE_STATE.'</span>';
}

/**
 * Get markup for a Feature Branch SCM Branch label
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBScmLabel($deployment_descriptor) {
  $content="-";
  if (!empty($deployment_descriptor->SCM_BRANCH)) {
    $content='<a href="/features.php#';
    $content.=str_replace(array("/", "."), "-", $deployment_descriptor->SCM_BRANCH).'"';
    $content.='rel="tooltip" title="SCM Branch used to host this FB development">';
    $content.='<img src="images/fork_icon.png" alt="SCM Branch" title="SCM Branch" class="icon"/>';
    $content.='&nbsp;'.$deployment_descriptor->SCM_BRANCH.'</a>';
  }
  return $content;
}

/**
 * Get markup for a Feature Branch Issue label
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBIssueLabel($deployment_descriptor) {
  $content="-";
  if (!empty($deployment_descriptor->ISSUE_NUM)) {
    $content='<a href="https://community.exoplatform.com/portal/dw/tasks/taskDetail/';
    $content.=$deployment_descriptor->ISSUE_NUM.'"';
    $content.='rel="tooltip" title="Opened issue where to put your feedbacks on this new feature">';
    $content.=$deployment_descriptor->ISSUE_NUM.'</a>';
  }
  return $content;
}

/**
 * Get markup for a Feature Branch Edit action icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBEditIcon($deployment_descriptor) {
  $content="";
  $content='<a href="#edit-';
  $content.=str_replace(".", "_", $deployment_descriptor->INSTANCE_KEY).'"';
  $content.='rel="tooltip" title="Edit feature branch details" data-toggle="modal">';
  $content.='<i class="icon-pencil"></i></a>';
  $content.=getFormEditFeatureBranch($deployment_descriptor);

  return $content;
}

/**
 * Get markup for a Feature Branch Deploy action icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBDeployIcon($deployment_descriptor) {
  $content="";
  if(isset($deployment_descriptor->DEPLOYMENT_BUILD_URL)) {
    $content='<a href="'.$deployment_descriptor->DEPLOYMENT_BUILD_URL.'/build?delay=0sec"';
    $content.='rel="tooltip" title="Restart your instance or reset your instance data" target="_blank">';
    $content.='<i class="icon-refresh"></i></a>';
  }
  return $content;
}

/**
 * Get markup for a Git repository branch commits status
 *
 * @param $fb_project
 *
 * @return string html markup
 */
 function componentFeatureRepoBrancheStatus($fb_project) {
  $content="";

  $content='<a href="'.$fb_project['http_url_behind'].'" target="_blank" title="[behind]">';
  $content.='<span rel="tooltip" title="'.$fb_project['behind_commits'].' commits on the base branch that do not exist on this branch [behind]">';
  if ($fb_project['behind_commits'] > 0) {
    $content.='<span class="label label-commit label-important">'.$fb_project['behind_commits'].' <i class="icon-arrow-down icon-white"></i></span>';
  } else {
    $content.='<span class="label label-commit">'.$fb_project['behind_commits'].' <i class="icon-arrow-down"></i></span>';
  }
  $content.='</span></a>';
  $content.='<a href="'.$fb_project['http_url_ahead'].'" target="_blank" title="[ahead]">';
  $content.='<span rel="tooltip" title="'.$fb_project['ahead_commits'].' commits on this branch that do not exist on the base branch [ahead]">';
  if ($fb_project['ahead_commits'] > 0) {
    $content.='<span class="label label-commit label-info "><i class="icon-arrow-up icon-white"></i> '.$fb_project['ahead_commits'].'</span>';
  } else {
    $content.='<span class="label label-commit"><i class="icon-arrow-up"></i> '.$fb_project['ahead_commits'].'</span>';
  }
  $content.='</span></a>';
  return $content;
}
?>

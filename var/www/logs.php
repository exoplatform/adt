<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<?php
$file = $_GET['file'];
$num_latest = 30; //the number of errors to show in the "Last Few Errors" section
$allow_show_source = 1; //whether to allow the ability to view the source code of your php files

//Each element in the filter array will allow you to narrow down the results by whether or not this word
//appears in the file path of the script with the error.
//$filter[] = "/website1/htdocs";
//$filter[] = "/website2/htdocs";
//$filter[] = "/website3/htdocs";

//================================================================================================
//================================================================================================
?>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<title>Acceptance Live Instances</title>
<link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
<link href="/style.css" media="screen" rel="stylesheet" type="text/css"/>
<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-1292368-28']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>
</head>
<body>
<div class="UIForgePages">
  <div class="Header ClearFix"> <a href="/" class="Logo"></a><span class="AddressWeb">acceptance.exoplatform.org</span> </div>
  <div class="MainContent">
    <div class="TitleForgePages">Acceptance Live Instances</div>
    <div>
      <?php if(empty($_GET['display_error'])) { ?>
      <div class="instructions">File : <?=$file?></div>
      <?php
	if(!empty($filter)) {
		?>
      <form action="logs.php" method="get">
        <select name='f'>
          <option value="">NONE</option>
          <?php
		foreach($filter as $f) {
			?>
          <option value="<?=$f?>">
          <?=$f?>
          </option>
          <?php
		}
		?>
        </select>
        <input type="submit" value="Filter" />
      </form>
      <?php
	}
	
	function mysort($a,$b) {
		if($a[0] == $b[0]) {
		   return 0;
		}
		return ($a[0] > $b[0]) ? -1 : 1;
	}
	
	$handle = @fopen($file,"r");
	if($handle) {
	   $linenumber = 0;
	   while(!feof($handle)) {
			$line = fgets($handle, 4096); //get line
			
			if(empty($_GET['f']) || stristr($line,$_GET['f'])) {
				//stores the last few errors reported
				$latest[] = $line;
				if(sizeof($latest)>1+$num_latest) array_shift($latest);
				
				$linenumber = $linenumber + 1;

				//figures out severity of error
				$severity=1; 
				// Tomcat/eXo warnings
				if(strstr($line,"WARNING")!==FALSE) $severity=2;
				if(strstr($line,"WARN")!==FALSE) $severity=2;
				// Tomcat/eXo errors
				if(strstr($line,"ERROR")!==FALSE) $severity=3;
				if(strstr($line,"SEVERE")!==FALSE) $severity=3;
				// Apache warnings 40x
				if(preg_match("/^(\S+) (\S+) (\S+) \[([^:]+):(\d+:\d+:\d+) ([^\]]+)\] \"(\S+) (.*?) (\S+)\" 40[0-9] (\S+) (\".*?\") (\".*?\")$/", $line)>0) $severity=2;
				// Apache errors 50x
                if(preg_match("/^(\S+) (\S+) (\S+) \[([^:]+):(\d+:\d+:\d+) ([^\]]+)\] \"(\S+) (.*?) (\S+)\" 50[0-9] (\S+) (\".*?\") (\".*?\")$/", $line)>0) $severity=3;

				$line = ereg_replace("[0-9]*-[a-zA-Z]*-[0-9]* [0-9]*:[0-9]*:[0-9]*","",$line); //gets rid of timestamp
				$line = str_replace("INFO: ","",$line);
				$line = str_replace("WARNING: ","",$line);
				$line = str_replace("ERROR: ","",$line);
				$line = str_replace("SEVERE: ","",$line);
				$line = str_replace("[INFO] ","",$line);
				$line = str_replace("[WARNING] ","",$line);
				$line = str_replace("[WARN] ","",$line);
				$line = str_replace("[ERROR] ","",$line);

				$hash = md5($line); //make a unique id for this error
				

				if(!empty($line)) {
					if(empty($res[$severity][$hash])) { //stuff this error into an array or increment counter for existing error
						$res[$severity][$hash][0]=1;
						$res[$severity][$hash][1]=$line;
						if(empty($allow_show_source)) 
						  $res[$severity][$hash][2]=$linenumber;
						else 
						  $res[$severity][$hash][2]="<a href='logs.php?file=".urlencode($file)."#".$linenumber."'>".$linenumber."</a>";
						$res[$severity][$hash][3]=$file;
						
					} else {
						$res[$severity][$hash][0]++; //repeat error, so increment the existsing value
						if(empty($allow_show_source)) 
						  $res[$severity][$hash][2].=" ".$linenumber;
						else 
						  $res[$severity][$hash][2].=" <a href='logs.php?file=".urlencode($file)."#".$linenumber."'>".$linenumber."</a>";
					}
				}
			}
		}
		fclose($handle);
		
		asort($res); //sort errors
		
		if(!empty($num_latest)) { 
			echo "<div class='latest'><b>Last Few</b><br />";
			if(!empty($latest) && is_array($latest)) {
				foreach($latest as $error) {
					echo "<p>".$error."</p>";
				}
			} else {
				echo "none<br />";
			}
			echo "</div><br />";
		}
		?>
        <b>Key:</b> The first number is the frequency count (bigger number=worse error).  This is followed by the error.  The numbers at the ends are the line numbers at which the errors have occurred in your file. <br />
        <?php
		echo "<div class='errors'><b>Errors</b><br />";
		if(!empty($res[3]) && is_array($res[3])) {
			usort($res[3],"mysort");
			foreach($res[3] as $error) {
				echo "<p><b>".$error[0]."</b> ".$error[1]." ".$error[2]."</p>";
			}
		} else {
			echo "none<br />";
		}
		echo "</div><br />";
		
		echo "<div class='warnings'><b>Warnings</b><br />";
		if(!empty($res[2]) && is_array($res[2])) {
			usort($res[2],"mysort");
			foreach($res[2] as $error) {
				echo "<p><b>".$error[0]."</b> ".$error[1]." ".$error[2]."</p>";
			}
		} else {
			echo "none<br />";
		}
		echo "</div><br />";
		
	} else {
		echo "Couldn't read error file.";
	}
	?>
      <br />
      <br />
      <?php } 
	  if(!empty($allow_show_source)) { ?>
      <div class="code">
        <?php
		$output = highlight_file($_GET['file'], true);
	
		//Line breaks are a little strange
		// dos = \r\n
		// unix = \n
		// mac = \r
		$output = str_replace("\r<br />","<br />", $output); //dos line breaks
		$output = str_replace("\r","<br />", $output); //mac line breaks
		$lines = explode("<br />",$output);
		
		for($i=0;$i<count($lines);$i++) {
			?>
        <p><a name="<?=($i+1)?>"></a>&nbsp;<?=$i+1?>&nbsp;&nbsp;&nbsp;<?=$lines[$i]?></p>
        <?php
		}	
	?>
      </div>
      <? } ?>
    </div>
  </div>
  <div class="Footer">eXo Platform SAS</div>
</div>
</body>
</html>
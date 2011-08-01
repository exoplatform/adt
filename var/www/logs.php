<?php

$file = $_GET['file'];
$num_latest = 5; //the number of errors to show in the "Last Few Errors" section
$allow_show_source = 1; //whether to allow the ability to view the source code of your php files

//Each element in the filter array will allow you to narrow down the results by whether or not this word
//appears in the file path of the script with the error.
//$filter[] = "/website1/htdocs";
//$filter[] = "/website2/htdocs";
//$filter[] = "/website3/htdocs";

//================================================================================================
//================================================================================================
?>
<html>
<body>
<head>
<title>PHP Error Log Digested</title>
</head>
<body>
<style type="text/css">
html,body,div,p {margin:0px;padding:0px;}
p { white-space: nowrap }
.instructions { padding: 5px; margin-bottom: 10px; }
.instructions p { font-size: 0.8em;}
.latest { border-top: 1px solid #666; border-bottom: 1px solid #666; background-color: #eee; padding: 5px;}
.latest p { font-size: 0.8em; }
.errors { border-top: 1px solid #600; border-bottom: 1px solid #600; background-color: #fee; padding: 5px;}
.errors b { color: #600; } 
.errors p { font-size: 1.1em; } 
.warnings { border-top: 1px solid #660; border-bottom: 1px solid #660; background-color: #ffe; padding: 5px;}
.warnings b { color: #660; } 
.notices { border-top: 1px solid #666; border-bottom: 1px solid #666; background-color: #eee; padding: 5px;}
.notices p { font-size: 0.9em; }
.code { font-size: 0.8em; background-color: #eee; border-top: 1px solid #666; border-bottom: 1px solid #666; padding: 5px; font-family: Courier,monospace; }
code {font-family: Courier,monospace; }
input,select { margin-left: 5px; }
a { color: #000; }
a:hover { color: #009; }
</style>
<?php if(empty($_GET['display_error'])) { ?>
<div class="instructions"> <b><a href="http://www.jakeo.com/software/logdigester/index.php">Log Digester</a> Output</b> from
  <?=$file?>
</div>
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
	   while(!feof($handle)) {
			$line = fgets($handle, 4096); //get line
			
			if(empty($_GET['f']) || stristr($line,$_GET['f'])) {
				//stores the last few errors reported
				$latest[] = $line;
				if(sizeof($latest)>1+$num_latest) array_shift($latest);
				
				$line = ereg_replace(".* PHP ","",$line); //gets rid of timestamp
				
				//gets line number of error		
				ereg(" on line ([0-9]*)",$line,$linenumber); 
				$linenumber = $linenumber[1];
				if(empty($linenumber)) $linenumber=" ";
				$line = ereg_replace(" on line [0-9]*","",$line);
				
				$hash = md5($line); //make a unique id for this error
				
				//gets filepath
				ereg(" in ([^ ]*)",$line,$filepath); 
				$filepath = trim($filepath[1]);
				if(empty($filepath)) $filepath="";
				$line = ereg_replace(" in [^ ]*","",$line);
				
				//figures out severity of error
				$severity=3; 
				if(strstr($line,"WARNING")!==FALSE) $severity=2;
				if(strstr($line,"INFO")!==FALSE) $severity=1;
				$line = ereg_replace("INFO: ","",$line);
				$line = ereg_replace("WARNING: ","",$line);
				$line = ereg_replace("ERROR: ","",$line);
		
				if(!empty($line)) {
					if(empty($res[$severity][$hash])) { //stuff this error into an array or increment counter for existing error
						$res[$severity][$hash][0]=1;
						$res[$severity][$hash][1]=$line;
						if(empty($allow_show_source)) $res[$severity][$hash][2]=$linenumber;
						else $res[$severity][$hash][2]="<a href='logs.php?display_error=".urlencode($filepath)."&amp;line=".$linenumber."#jump'>".$linenumber."</a>";
						$res[$severity][$hash][3]=$filepath;
						
					} else {
						$res[$severity][$hash][0]++; //repeat error, so increment the existsing value
						if(strstr($res[$severity][$hash][2],$linenumber)==FALSE) {
							if(empty($allow_show_source)) $res[$severity][$hash][2].=" ".$linenumber;
							else $res[$severity][$hash][2].=" <a href='logs.php?display_error=".urlencode($filepath)."&amp;line=".$linenumber."#jump'>".$linenumber."</a>";
						}
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
		echo "<div class='errors'><b>Errors</b><br />";
		if(!empty($res[3]) && is_array($res[3])) {
			usort($res[3],"mysort");
			foreach($res[3] as $error) {
				echo "<p>".$error[0]." ".$error[1]." ".$error[3]." ".$error[2]."</p>";
			}
		} else {
			echo "none<br />";
		}
		echo "</div><br />";
		
		echo "<div class='warnings'><b>Warnings</b><br />";
		if(!empty($res[2]) && is_array($res[2])) {
			usort($res[2],"mysort");
			foreach($res[2] as $error) {
				echo "<p>".$error[0]." ".$error[1]." ".$error[3]." ".$error[2]."</p>";
			}
		} else {
			echo "none<br />";
		}
		echo "</div><br />";
		
		echo "<div class='notices'><b>Notices</b><br />";
		if(!empty($res[1]) && is_array($res[1])) {
			usort($res[1],"mysort");
			foreach($res[1] as $error) {
				echo "<p>".$error[0]." ".$error[1]." ".$error[3]." ".$error[2]."</p>";
			}
		} else {
			echo "none<br />";
		}
		echo "</div>";
	
	} else {
		echo "Couldn't read error file.";
	}
	?>
<br />
<br />
<b>Key:</b> The first number is the frequency count (bigger number=worse error).  This is followed by the error.  The numbers at the ends are the line numbers at which the errors have occurred in your php file. <br />
<?php } else if(!empty($allow_show_source)) { ?>
<div class="instructions"> <b><a href="http://www.jakeo.com/software/logdigester/index.php">Log Digester</a> Output</b> from <a href="logs.php">
  <?=$file?>
  </a><br />
  Showing errors from:
  <?=$_GET['display_error']?>
</div>
<div class="code">
  <?php
		$output = highlight_file($_GET['display_error'], true);
	
		//Line breaks are a little strange
		// dos = \r\n
		// unix = \n
		// mac = \r
		$output = str_replace("\r<br />","<br />", $output); //dos line breaks
		$output = str_replace("\r","<br />", $output); //mac line breaks
		$lines = explode("<br />",$output);
		
		for($i=0;$i<count($lines);$i++) {
			if($i+1==$_GET['line']) echo "<a name='jump'></a><font color='black'>***</font>&nbsp;";
			else echo "&nbsp;&nbsp;&nbsp;&nbsp;";
			?>
  <font color="black">
  <?=$i+1?>
  </font>&nbsp;&nbsp;&nbsp;
  <?=$lines[$i]?>
  <br />
  <?php
		}
		
	?>
</div>
<? } ?>
</body>
</html>
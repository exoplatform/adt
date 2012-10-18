<?php
  file_put_contents($_SERVER['ADT_DATA']."/conf/features/".$_POST['product']."-".$_POST['version'].".".$_POST['server'].".spec", $_POST['specifications']);
  file_put_contents($_SERVER['ADT_DATA']."/conf/features/".$_POST['product']."-".$_POST['version'].".".$_POST['server'].".status", $_POST['status']);
  file_put_contents($_SERVER['ADT_DATA']."/conf/features/".$_POST['product']."-".$_POST['version'].".".$_POST['server'].".issue", $_POST['issue']);
	header("Location: ".$_POST['from']); /* Redirect browser */
	/* Make sure that code below does not get executed when we redirect. */
	exit;	
?>
<?php

if($wjid >=10000000){	
//写入数据库
include("./sql/mysql.php");//调用数据库连接 
$q2="all_cz";
$sql = "insert into $q2 (czid,czje,cztime,czfl)  values('$cz01','$cz02','$cz03','$cz04')";
 if (!mysql_query($sql,$conn)){
   die('Error: ' . mysql_error());
 }
} else{

}








?>
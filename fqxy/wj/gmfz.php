<?php



if($npcc==1){
include("./ini/yl_ini.php");
$yl=($iniFile->getItem('背包仓库银两','背包银两'));	
$fz01=10000000;//民宅价格1000万
if($yl>=$fz01){

include("./ini/zt_ini.php");
$wjname=($iniFile->getItem('玩家信息','玩家名字'));	
include("./sql/mysql.php");//调用数据库连接 
$q2="all_houres";
mysql_query("set names utf8");
$fzname="民宅";//房子名字
$fzfl=1;//房子类型
$fzgm=0;//房子改名
mysql_query("set names utf8");
$sql = "insert into $q2 (wjid,wjmz,fzmz,fzfl,fzgm)  values('$wjid','$wjname','$fzname','$fzfl','$fzgm')";
 if (!mysql_query($sql,$conn))
 {
   die('Error: ' . mysql_error());
 }
$fziidd = mysql_insert_id();
mysql_query("update $q2 set fzid=$fziidd where id=$fziidd");
$q2="all_zt";
mysql_query("set names utf8");
$strsql = "update $q2 set zzid=$fziidd,zzmz='$fzname',zzfl=$fzfl where wjid=$wjid";//物品id号必改值
$result = mysql_query($strsql);
$q2="all_yl";
$yll=$yl-$fz01;
$strsql = "update $q2 set bbyl=$yll where wjid=$wjid";//物品id号必改值
$result = mysql_query($strsql);


include("./ini/zt_ini.php");
$iniFile->updItem('玩家信息', ['住宅id'=> $fziidd]);
$iniFile->updItem('玩家信息', ['住宅分类'=> $fzfl]);
$iniFile->updItem('玩家信息', ['住宅名字'=> $fzname]);
include("./ini/yl_ini.php");
$iniFile->updItem('背包仓库银两', ['背包银两'=> $yll]);
echo "<font color=black>恭喜你,成功购买到了民宅</font>"."<br>";
echo "<font color=black>失去银两1000万</font>"."<br>";
} else{
echo "<font color=black>对不起,你的银两不足</font>"."<br>";

}

} elseif($npcc==2){  
include("./ini/sc_ini.php");
$jd=($iniFile->getItem('商城数量','127'));	
$fz02=188;//豪宅价格188金豆
if($jd>=$fz02){
$kcjd=$jd-$fz02;
$iniFile->updItem('商城数量', ['127'=> $kcjd]);



include("./ini/zt_ini.php");
$wjname=($iniFile->getItem('玩家信息','玩家名字'));	
include("./sql/mysql.php");//调用数据库连接 
$q2="all_houres";
mysql_query("set names utf8");
$fzname="豪宅";//房子名字
$fzfl=2;//房子类型
$fzgm=1;//房子改名
mysql_query("set names utf8");
$sql = "insert into $q2 (wjid,wjmz,fzmz,fzfl,fzgm)  values('$wjid','$wjname','$fzname','$fzfl','$fzgm')";
 if (!mysql_query($sql,$conn))
 {
   die('Error: ' . mysql_error());
 }
$fziidd = mysql_insert_id();
mysql_query("update $q2 set fzid=$fziidd where id=$fziidd");
$q2="all_zt";
$strsql = "update $q2 set zzid=$fziidd,zzmz='$fzname',zzfl=$fzfl where wjid=$wjid";//物品id号必改值
$result = mysql_query($strsql);
$q2="wp";
$strsql = "update $q2 set wpsl=$kcjd where wjid=$wjid and wpid=127";//物品id号必改值
$result = mysql_query($strsql);
include("./ini/zt_ini.php");
$iniFile->updItem('玩家信息', ['住宅id'=> $fziidd]);
$iniFile->updItem('玩家信息', ['住宅分类'=> $fzfl]);
$iniFile->updItem('玩家信息', ['住宅名字'=> $fzname]);
echo "<font color=black>恭喜你,成功购买到了豪宅</font>"."<br>";
echo "<font color=black>失去金豆x188</font>"."<br>";



} else{
echo "<font color=black>对不起,你的金豆不足</font>"."<br>";

}
} elseif($npcc==3){  
include("./ini/sc_ini.php");
$jd=($iniFile->getItem('商城数量','127'));
$yhj=($iniFile->getItem('商城数量','396'));
$fz03=88;//豪宅价格88金豆+豪宅优惠券
if($jd>=$fz03&&$yhj>=1){
	$kcjd=$jd-$fz03;
	$kcyhj=$yhj-1;
$iniFile->updItem('商城数量', ['127'=> $kcjd]);
$iniFile->updItem('商城数量', ['396'=> $kcyhj]);



include("./ini/zt_ini.php");
$wjname=($iniFile->getItem('玩家信息','玩家名字'));	
include("./sql/mysql.php");//调用数据库连接 
$q2="all_houres";
mysql_query("set names utf8");
$fzname="豪宅";//房子名字
$fzfl=2;//房子类型
$fzgm=1;//房子改名
$sql = "insert into $q2 (wjid,wjmz,fzmz,fzfl,fzgm)  values('$wjid','$wjname','$fzname','$fzfl','$fzgm')";
 if (!mysql_query($sql,$conn))
 {
   die('Error: ' . mysql_error());
 }
$fziidd = mysql_insert_id();
mysql_query("update $q2 set fzid=$fziidd where id=$fziidd");
$q2="all_zt";
$strsql = "update $q2 set zzid=$fziidd,zzmz='$fzname',zzfl=$fzfl where wjid=$wjid";//物品id号必改值
$result = mysql_query($strsql);
$q2="wp";
$strsql = "update $q2 set wpsl=$kcjd where wjid=$wjid and wpid=127";//物品id号必改值
$result = mysql_query($strsql);
$strsql = "update $q2 set wpsl=$kcyhj where wjid=$wjid and wpid=396";//物品id号必改值
$result = mysql_query($strsql);

include("./ini/zt_ini.php");
$iniFile->updItem('玩家信息', ['住宅id'=> $fziidd]);
$iniFile->updItem('玩家信息', ['住宅分类'=> $fzfl]);
$iniFile->updItem('玩家信息', ['住宅名字'=> $fzname]);
echo "<font color=black>恭喜你,成功购买到了豪宅</font>"."<br>";
echo "<font color=black>失去金豆x88,豪宅优惠券x1</font>"."<br>";



} else{
echo "<font color=black>对不起,你的金豆不足或者缺少豪宅优惠卷</font>"."<br>";

}


} else{

echo "<font color=black>购买住宅出现未知错误请联系购买解决</font>"."<br>";


}
















?>



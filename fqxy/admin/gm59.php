<?php

$sdkmz="拉人SDK码";
$sdkfl=2;//1宣传2拉人3福利4新区
$addtime=1;//有效天数

echo "<font color=red>【提取".$sdkmz."成功】</font>"."<br>";
$a1=str_rand(10);
$a2="【".$sdkmz."[".$a1."]"."】";	

$q2="all_sdk";

$q2="all_sdk";
if (isset($viptime)) {
    $viptime1 = date("Y-m-d H:i:s", strtotime("$viptime   $addtime   day"));   //日期天数相加函数
} else {
    $viptime1 = date('Y-m-d H:i:s', strtotime("+$addtime day"));
}
$sql = "insert into $q2 (sdk,sdktime,sdkfl,sdksy)  values('$a2','$viptime1','$sdkfl','1')";
 if (!mysql_query($sql)) {
   die('Error: ' . mysql_error());
 }

echo "<font color=red>【".$sdkmz."】</font>"."<br>";



echo "<font color=red>恭喜你成功提取到一条".$sdkmz."</font>"."<br>";
?>

<article id="article">
<?php
echo "<font color=black>$a2</font>"."<br>";
?>
</article>


<?php

echo "<br>";
echo "<font color=black>---------------------</font>"."<br>";



echo "<br>";
echo "<font color=black>---------------------</font>"."<br>";
echo "<a href='gm.php?gid=1'><font color=blue>【返回GM管理首页】</font></a>"."<br>";


?>







<script>
function copyArticle(event){
const range = document.createRange();
range.selectNode(document.getElementById('article'));
const selection = window.getSelection();
if(selection.rangeCount > 0) selection.removeAllRanges();
selection.addRange(range);
document.execCommand('copy');
}
document.getElementById('copy').addEventListener('click', copyArticle, false);
</script>
<?php

/**
 * 删除文件前检查文件是否存在
 *
 * @param $path
 */
function _unlink($path)
{
    if (file_exists($path)) {
        unlink($path);
    }
}

/**
 * 数据库兼容性代码
 * 定义 mysql_* 兼容常量（避免 mysqli 扩展未加载时 undefined constant 警告）
 */
if (!defined('MYSQLI_BOTH')) {
    define('MYSQLI_BOTH', 3);      // MYSQLI_BOTH = 3
}
if (!defined('MYSQLI_ASSOC')) {
    define('MYSQLI_ASSOC', 1);     // MYSQLI_ASSOC = 1
}
if (!defined('MYSQLI_NUM')) {
    define('MYSQLI_NUM', 2);       // MYSQLI_NUM = 2
}

if (!function_exists('mysql_query')) {
    function mysql_query($sql, $conn = null)
    {
        $conn = get_mysql_conn();
        return $conn->query($sql);
    }
}

if (!function_exists('mysql_fetch_array')) {

    function mysql_fetch_array($result, $result_type = MYSQLI_BOTH)
    {
        /** @var \PDOStatement $result */
        return $result->fetch(PDO::FETCH_ASSOC);
    }
}

if (!function_exists('mysql_num_rows')) {

    function mysql_num_rows($result)
    {
        /** @var \PDOStatement $result */
        return $result->rowCount();
    }
}

if (!function_exists('mysql_error')) {
    function mysql_error()
    {
        $conn = get_mysql_conn();
        return $conn->error;
    }
}

if (!function_exists('mysql_insert_id')) {
    /**
     * 获取最后插入的AUTO_INCREMENT ID
     * 使用 Medoo::id() 包装 PDO::lastInsertId()，连接级安全，无并发问题
     *
     * @return int 最后插入的自增ID
     */
    function mysql_insert_id()
    {
        return (int) get_mysql_conn()->id();  // Medoo::id() → PDO::lastInsertId()
    }
}

function get_mysql_conn()
{
    if (!class_exists('DB')) {
        throw new RuntimeException('缺少依赖：DB::class');
    }
    $conn = DB::instance();
    if (is_null($conn)) {
        throw new RuntimeException('数据库链接未找到');
    }
    return $conn;
}

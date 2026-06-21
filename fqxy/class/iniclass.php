<?php
/**
 * INI 文件缓存类 (v2.0)
 * 底层从文件 INI 升级为 Redis Hash，API 完全兼容。
 * 
 * Redis 数据模型：
 *   文件 ache/{wjid}/user.ini → Redis 前缀 ini:{wjid}:user:
 *   每个 INI section 对应一个 Redis Hash：ini:{wjid}:user:status
 * 
 * 读写策略：Redis 优先，文件回退。
 * 类型处理：parse_ini_file 自动转 int，Redis hGetAll 返回 string，
 *           加载时归一化为 int（纯数字）以对齐行为。
 */
class iniFile
{
    public $iniFilePath;
    public $iniFileHandle = [];

    /** @var bool fake 为真时不进行任何文件操作 */
    public $fake;

    /** @var Redis|null 全局 Redis 连接 */
    private static $redis = null;

    /** @var bool|null null=未检测, true=可用, false=不可用 */
    private static $redisAvailable = null;

    /** @var string Redis Hash Key 前缀（不含 section 名） */
    private $redisKey;

    function __construct($iniFilePath, bool $fake = false)
    {
        $this->iniFilePath = $iniFilePath;
        $this->fake = $fake;
        if ($this->fake) {
            return;
        }

        $this->redisKey = $this->fileToRedisKey($iniFilePath);

        // 尝试从 Redis 加载
        $data = $this->loadFromRedis();
        if ($data !== false && !empty($data)) {
            $this->iniFileHandle = $data;
            return;
        }

        // 文件回退：加载 INI 文件
        if (file_exists($this->iniFilePath)) {
            $this->iniFileHandle = parse_ini_file($this->iniFilePath, true);

            if (empty($this->iniFileHandle)) {
                unlink($this->iniFilePath);
            } else {
                // 将文件数据写入 Redis 缓存（首次迁移）
                $this->saveToRedis();
            }
        } else {
            die($this->iniFilePath . ' file cannot be opened');
        }
    }

    public function addCategory($category_name, array $item = [])
    {
        if (!isset($this->iniFileHandle[$category_name])) {
            $this->iniFileHandle[$category_name] = [];
        }
        if (!empty($item)) {
            foreach ($item as $key => $value) {
                $this->iniFileHandle[$category_name][$key] = $value;
            }
        }
        $this->save();
    }

    public function addItem($category_name, array $item)
    {
        foreach ($item as $key => $value) {
            $this->iniFileHandle[$category_name][$key] = $value;
        }
        $this->save();
    }

    public function getAll()
    {
        return $this->iniFileHandle;
    }

    public function getCategory($category_name)
    {
        return $this->iniFileHandle[$category_name] ?? [];
    }

    public function getItem($category_name, $item_name)
    {
        if (is_array($item_name)) {
            $arr = array();
            foreach ($item_name as $value) {
                $arr[$value] = $this->iniFileHandle[$category_name][$value];
            }
            return $arr;
        } else {
            return $this->iniFileHandle[$category_name][$item_name] ?? null;
        }
    }

    public function updItem($category_name, array $item)
    {
        foreach ($item as $key => $value) {
            $this->iniFileHandle[$category_name][$key] = $value;
        }
        $this->save();
    }

    public function delCategory($category_name)
    {
        unset($this->iniFileHandle[$category_name]);
        $this->save();
    }

    public function delItem($category_name, $item_name)
    {
        unset($this->iniFileHandle[$category_name][$item_name]);
        $this->save();
    }

    /**
     * 持久化：Redis 优先，不可用时回退文件写入
     */
    public function save()
    {
        if ($this->fake) {
            return true;
        }

        // 优先写 Redis
        if ($this->saveToRedis()) {
            return true;
        }

        // Redis 不可用时回退文件写入
        return $this->saveToFile();
    }

    // ==================== 私有辅助方法 ====================

    /**
     * 获取 Redis 连接（单例，自动重连）
     */
    private static function getRedis(): ?\Redis
    {
        if (self::$redisAvailable === false) {
            return null;
        }

        if (self::$redis === null) {
            if (!class_exists('Redis')) {
                self::$redisAvailable = false;
                return null;
            }

            try {
                self::$redis = new Redis();
                $host = getenv('REDIS_HOST') ?: 'redis';
                $port = (int)(getenv('REDIS_PORT') ?: 6379);
                self::$redis->connect($host, $port, 2.0);
                self::$redisAvailable = true;
            } catch (\RedisException $e) {
                self::$redisAvailable = false;
                self::$redis = null;
                return null;
            }
        } elseif (!self::$redis->isConnected()) {
            try {
                self::$redis->connect('redis', 6379, 2.0);
            } catch (\RedisException $e) {
                self::$redisAvailable = false;
                return null;
            }
        }

        return self::$redis;
    }

    /**
     * 文件路径 → Redis Key 前缀
     * ache/12345/user.ini → ini:12345:user
     */
    private function fileToRedisKey(string $filePath): string
    {
        $path = str_replace('\\', '/', $filePath);

        // 提取 ache/ 之后的部分（仅限 ache/ 后跟数字 wjid，排除 acher/）
        if (preg_match('#(?:^|/)ache/(\d.+)$#', $path, $m)) {
            $key = $m[1];
        } else {
            // 兜底：仅取文件名
            $key = basename($path);
        }

        // 去除 .ini 后缀，路径分隔符替换为冒号
        $key = preg_replace('#\.ini$#i', '', $key);
        $key = str_replace('/', ':', $key);

        return 'ini:' . $key;
    }

    /**
     * 从 Redis 加载所有 section 数据
     * @return array|false 加载成功返回数据，失败返回 false
     */
    private function loadFromRedis()
    {
        $redis = self::getRedis();
        if ($redis === null) return false;

        try {
            $pattern = $this->redisKey . ':*';
            $keys = $redis->keys($pattern);
            if (empty($keys)) return false;

            $data = [];
            $prefix = $this->redisKey . ':';
            $prefixLen = strlen($prefix);

            foreach ($keys as $key) {
                $section = substr($key, $prefixLen);
                // 过滤内部索引 key
                if ($section === '_sections') continue;
                $fields = $redis->hGetAll($key);
                if (!empty($fields)) {
                    $data[$section] = $this->normalizeArray($fields);
                }
            }

            return !empty($data) ? $data : false;
        } catch (\RedisException $e) {
            self::$redisAvailable = false;
            return false;
        }
    }

    /**
     * 保存所有 section 到 Redis
     */
    private function saveToRedis(): bool
    {
        $redis = self::getRedis();
        if ($redis === null) return false;

        try {
            // 清理旧 section Hash
            $pattern = $this->redisKey . ':*';
            $oldKeys = $redis->keys($pattern);
            if ($oldKeys) {
                $redis->del($oldKeys);
            }

            // 写入当前所有 section
            foreach ($this->iniFileHandle as $cat => $items) {
                if (!empty($items)) {
                    $hashKey = $this->redisKey . ':' . $cat;
                    $redis->hMSet($hashKey, array_map('strval', $items));
                }
            }
            return true;
        } catch (\RedisException $e) {
            self::$redisAvailable = false;
            return false;
        }
    }

    /**
     * 文件写入回退（保留原有逻辑）
     */
    private function saveToFile(): bool
    {
        $string = '';
        foreach ($this->iniFileHandle as $key => $value) {
            $string .= '[' . $key . ']' . "\r\n";
            foreach ($value as $k => $v) {
                $string .= "$k = $v\r\n";
            }
        }
        $iniFileHandle = fopen($this->iniFilePath, 'w+');
        $isfwrite = fwrite($iniFileHandle, $string);
        if ($isfwrite) {
            fclose($iniFileHandle);
            return true;
        } else {
            fclose($iniFileHandle);
            return false;
        }
    }

    /**
     * 归一化 Redis 返回值，对齐 parse_ini_file 的类型行为：
     * - 纯数字字符串 → int（例 "100" → 100）
     * - 其余保持 string
     */
    private function normalizeValue($v)
    {
        if ($v === false || $v === null) return $v;
        if (is_numeric($v) && (string)(int)$v === (string)$v) {
            return (int)$v;
        }
        return (string)$v;
    }

    private function normalizeArray(array $arr): array
    {
        return array_map([$this, 'normalizeValue'], $arr);
    }
}

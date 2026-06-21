<?php
/**
 * 🎯 TODO #10 PHP 8.2 Warning 探测 Bot v2
 *
 * v2 优化:
 *   - 文件内变量定义追踪，排除明显安全的访问
 *   - 置信度评分，只展示高/中风险
 *   - 按风险排序，Top N + 按文件分组
 *   - --diff 模式：对比上次扫描看进度
 *   - --exclude 排除文件/目录
 *
 * 用法:
 *   docker exec xiyou-app php tests/warn_scanner.php           # 高+中风险
 *   docker exec xiyou-app php tests/warn_scanner.php --all     # 全部
 *   docker exec xiyou-app php tests/warn_scanner.php --top 50  # Top 50
 *   docker exec xiyou-app php tests/warn_scanner.php --diff    # 对比上次
 *   docker exec xiyou-app php tests/warn_scanner.php --exclude template
 */

define('ROOT_DIR', dirname(__DIR__));
define('SCAN_DIR', ROOT_DIR . '/fqxy');
define('STATE_FILE', ROOT_DIR . '/tests/.warn_state.json');

$opts = getopt('', ['dir::', 'json', 'help', 'all', 'top::', 'diff', 'exclude::']);
$scanDir  = $opts['dir'] ?? SCAN_DIR;
$jsonOut  = isset($opts['json']);
$showAll  = isset($opts['all']);
$doDiff   = isset($opts['diff']);
$topN     = (int)($opts['top'] ?? 200);
$exclude  = isset($opts['exclude']) ? explode(',', $opts['exclude']) : [];

if (isset($opts['help'])) {
    echo <<<HELP
🎯 PHP 8.2 Warning 探测 Bot v2

用法: php tests/warn_scanner.php [选项]

选项:
  --all              显示所有等级（默认仅高+中风险）
  --top N            只展示 Top N 条（默认 200）
  --diff             对比上次运行，显示新增/修复
  --exclude DIRS     排除目录，逗号分隔（如 template,tests）
  --dir PATH         指定扫描目录
  --json             JSON 输出
  --help             帮助

置信度:
  🔴 HIGH   (>80)  极大概率触发 Warning，优先修复
  🟡 MEDIUM (50-80) 可能触发，建议验证
  🟢 LOW    (<50)  风格建议，非紧急

HELP;
    exit(0);
}

// ─── 文件收集 ─────────────────────────────────────
function findPhpFiles(string $dir, array $exclude): array {
    $files = [];
    $it = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS)
    );
    foreach ($it as $file) {
        if ($file->getExtension() !== 'php') continue;
        $path = $file->getRealPath();
        foreach ($exclude as $ex) {
            if (str_contains($path, "/$ex/") || str_contains($path, "\\$ex\\")) continue 2;
        }
        $files[] = $path;
    }
    sort($files);
    return $files;
}

// ─── 辅助函数 ─────────────────────────────────────
function isCommentLine(string $line): bool {
    $t = ltrim($line);
    return str_starts_with($t, '//') || str_starts_with($t, '#')
        || str_starts_with($t, '/*') || str_starts_with($t, '*');
}
function hasAnyGuard(string $line): bool {
    return (bool) preg_match('/(\?\?|\?\?=)/', $line);
}

// ─── 文件内变量定义追踪 ───────────────────────────

/**
 * 扫描一个文件，收集所有"确定性赋值"的变量名。
 * 确定性赋值：函数参数、foreach() as、明确的 $var = expr，排除 include 后的变量。
 */
function collectDefinedVars(array $lines): array {
    $defined = [];
    foreach ($lines as $idx => $line) {
        $lineNo = $idx + 1;
        if (isCommentLine($line)) continue;

        // 函数/方法参数
        if (preg_match_all('/function\s+\w+\s*\(([^)]*)\)/', $line, $ms)) {
            foreach ($ms[1] as $params) {
                preg_match_all('/\$(\w+)/', $params, $vs);
                foreach ($vs[1] as $v) $defined[$v] = "param:{$lineNo}";
            }
        }
        // foreach ($arr as $k => $v)
        if (preg_match_all('/foreach\s*\([^)]*\s+as\s+\$(\w+)(?:\s*=>\s*\$(\w+))?/', $line, $ms)) {
            foreach ([$ms[1], $ms[2]] as $grp) {
                foreach ($grp as $v) {
                    if ($v) $defined[$v] = "foreach:{$lineNo}";
                }
            }
        }
        // list($a, $b) = expr
        if (preg_match_all('/list\s*\(([^)]*)\)\s*=/', $line, $ms)) {
            foreach ($ms[1] as $lst) {
                preg_match_all('/\$(\w+)/', $lst, $vs);
                foreach ($vs[1] as $v) $defined[$v] = "list:{$lineNo}";
            }
        }
        // $var = expr （排除 $var['k'] = 和 $var->p =）
        if (preg_match_all('/\$(\w+)\s*=(?![=>])/', $line, $ms)) {
            foreach ($ms[1] as $v) {
                if (!str_contains($v, 'this') && $v !== 'GLOBALS') {
                    $defined[$v] = "assign:{$lineNo}";
                }
            }
        }
        // $$var 动态变量 → 其指向的任何变量都视为已定义
        if (preg_match_all('/\$\$(\w+)\s*=/', $line, $ms)) {
            // 无法静态追踪，保守处理
        }
    }
    return $defined;
}

// ─── 风险评估 ─────────────────────────────────────

/**
 * 为一条发现计算置信度 (0-100)。
 * 分数越高 = 越可能触发真实 Warning。
 */
function calcConfidence(array $issue, array $definedVars): int {
    $score = 30; // 基础分
    $rid = $issue['rule_id'];

    // ── 加分项（增加风险）──
    if ($rid === 'M001') $score += 40;          // 超全局数组读取 → 非常高
    if ($rid === 'M005' && !$issue['defined'])  $score += 35;  // echo 未定义变量 → 高
    if ($issue['no_guard_nearby'] ?? false)      $score += 20;  // 附近无 isset/??/empty
    if ($issue['in_loop'] ?? false)              $score += 10;  // 在循环内 → 重复触发
    if ($issue['after_include'] ?? false)        $score += 15;  // include 后的变量 → 高风险

    // ── 减分项（降低风险）──
    if ($issue['defined'])                       $score -= 30;  // 文件中已赋值 → 大概率安全
    if ($issue['has_nearby_isset'] ?? false)     $score -= 25;  // 附近有 isset 检查
    if ($issue['has_nearby_empty'] ?? false)     $score -= 20;  // 附近有 empty 检查
    if ($rid === 'M003')                         $score -= 10;  // iniFile 返回值可能已在外层判空

    return max(0, min(100, $score));
}

function confidenceLabel(int $score): string {
    return $score >= 80 ? 'HIGH' : ($score >= 50 ? 'MEDIUM' : 'LOW');
}

// ─── 检测规则（返回标准化 issue 结构）─────────────

function detectIssues(array $lines, array $definedVars, string $relPath): array {
    $issues = [];
    $total = count($lines);

    for ($i = 0; $i < $total; $i++) {
        $line = $lines[$i];
        $lineNo = $i + 1;
        if (isCommentLine($line)) continue;

        // ── 检查附近是否有保护（前后 3 行内）──
        $nearby = [];
        for ($j = max(0, $i - 3); $j <= min($total - 1, $i + 3); $j++) {
            $nearby[] = $lines[$j];
        }
        $nearbyText = implode("\n", $nearby);
        $hasNearbyIsset = (bool) preg_match('/isset\s*\(/', $nearbyText);
        $hasNearbyEmpty = (bool) preg_match('/\bempty\s*\(/', $nearbyText);
        $inLoop = (bool) preg_match('/(foreach|for|while)\s*\(/', ($lines[$i - 1] ?? '') . $line);

        // 检查是否在 include 之后（前 10 行内有 include）
        $afterInclude = false;
        for ($j = max(0, $i - 10); $j < $i; $j++) {
            if (preg_match('/(?:include|require)(?:_once)?\s*\(/', $lines[$j])) {
                $afterInclude = true;
                break;
            }
        }

        // ── M001: 超全局数组读取 ──
        if (preg_match('/\$_(?:GET|POST|REQUEST|COOKIE|SERVER|FILES)\s*\[[\'"]\w+[\'"]\](?!\s*\?\?)/', $line, $m)) {
            if (!hasAnyGuard($line) && !preg_match('/^\s*\$_(?:GET|POST|REQUEST|COOKIE|SERVER|FILES)\s*\[[\'"]\w+[\'"]\s*\]\s*=/', $line)) {
                // 解析变量名
                $varname = '';
                if (preg_match('/\$(\w+)\s*=\s*\$_(?:GET|POST|REQUEST|COOKIE|SERVER|FILES)\s*\[/', $line, $vm)) {
                    $varname = $vm[1];
                }
                $issues[] = [
                    'file'       => $relPath,
                    'line'       => $lineNo,
                    'rule_id'    => 'M001',
                    'message'    => '超全局数组读取缺少 ?? 守卫',
                    'code'       => trim(mb_substr($line, 0, 120)),
                    'varname'    => $varname,
                    'defined'    => isset($definedVars[$varname]) && $definedVars[$varname] !== "assign:{$lineNo}",
                    'no_guard_nearby' => !$hasNearbyIsset && !$hasNearbyEmpty,
                    'has_nearby_isset' => $hasNearbyIsset,
                    'has_nearby_empty' => $hasNearbyEmpty,
                    'in_loop'    => $inLoop,
                    'after_include' => $afterInclude,
                ];
            }
        }

        // ── M002: 普通数组键读取 ──
        if (preg_match('/\$(?!_GET|_POST|_REQUEST|_COOKIE|_SERVER|_FILES|GLOBALS|this\b)(\w+)\s*\[[\'"]/', $line, $m)) {
            $varname = $m[1];
            // 排除写操作 $arr['k'] = xxx
            if (!preg_match('/^\s*\$' . preg_quote($varname, '/') . '\s*\[[\'"]\w+[\'"]\s*\]\s*=/', $line)
                && !hasAnyGuard($line)) {
                $issues[] = [
                    'file'       => $relPath,
                    'line'       => $lineNo,
                    'rule_id'    => 'M002',
                    'message'    => "数组键读取缺少 ?? 守卫: \${$varname}[...]",
                    'code'       => trim(mb_substr($line, 0, 120)),
                    'varname'    => $varname,
                    'defined'    => isset($definedVars[$varname]),
                    'no_guard_nearby' => !$hasNearbyIsset && !$hasNearbyEmpty,
                    'has_nearby_isset' => $hasNearbyIsset,
                    'has_nearby_empty' => $hasNearbyEmpty,
                    'in_loop'    => $inLoop,
                    'after_include' => $afterInclude,
                ];
            }
        }

        // ── M003: iniFile 返回值 ──
        if (preg_match('/\$iniFile\s*->\s*(?:getCategory|getItem)\s*\(/', $line)) {
            $varname = '';
            if (preg_match('/\$(\w+)\s*=\s*\(?\s*\$iniFile\s*->/', $line, $vm)) {
                $varname = $vm[1];
            }
            $issues[] = [
                'file'       => $relPath,
                'line'       => $lineNo,
                'rule_id'    => 'M003',
                'message'    => 'iniFile 返回值建议加 ?? 守卫',
                'code'       => trim(mb_substr($line, 0, 120)),
                'varname'    => $varname,
                'defined'    => isset($definedVars[$varname]),
                'no_guard_nearby' => !$hasNearbyIsset && !$hasNearbyEmpty,
                'has_nearby_isset' => $hasNearbyIsset,
                'has_nearby_empty' => $hasNearbyEmpty,
                'in_loop'    => $inLoop,
                'after_include' => $afterInclude,
            ];
        }

        // ── M004: in_array 参数可能为 null ──
        if (preg_match('/(?:in_array|array_key_exists|array_search)\s*\([^,]+\s*,\s*\$[a-zA-Z_]\w+/', $line)) {
            $issues[] = [
                'file'       => $relPath,
                'line'       => $lineNo,
                'rule_id'    => 'M004',
                'message'    => 'in_array/array_key_exists 第二参数可能为 null',
                'code'       => trim(mb_substr($line, 0, 120)),
                'varname'    => '',
                'defined'    => false,
                'no_guard_nearby' => false,
                'has_nearby_isset' => false,
                'has_nearby_empty' => false,
                'in_loop'    => $inLoop,
                'after_include' => false,
            ];
        }

        // ── M005: echo/print 未检查变量 ──
        if (preg_match('/(?:echo|print|printf)\s+\$([a-zA-Z_]\w+)(?!\s*\?\?)/', $line, $m)) {
            $varname = $m[1];
            // 排除 superglobals 和 $this
            if (in_array($varname, ['this', 'GLOBALS', '_GET', '_POST', '_REQUEST', '_SERVER', '_SESSION', '_COOKIE', '_FILES', '_ENV'])) {
                continue;
            }
            if (!hasAnyGuard($line) && !$hasNearbyIsset && !$hasNearbyEmpty) {
                $issues[] = [
                    'file'       => $relPath,
                    'line'       => $lineNo,
                    'rule_id'    => 'M005',
                    'message'    => "echo/print 变量可能未定义: \${$varname}",
                    'code'       => trim(mb_substr($line, 0, 120)),
                    'varname'    => $varname,
                    'defined'    => isset($definedVars[$varname]),
                    'no_guard_nearby' => true,
                    'has_nearby_isset' => false,
                    'has_nearby_empty' => false,
                    'in_loop'    => $inLoop,
                    'after_include' => $afterInclude,
                ];
            }
        }
    }

    return $issues;
}

// ─── 主流程 ───────────────────────────────────────

$files = findPhpFiles($scanDir, $exclude);
$totalFiles = count($files);
$allIssues = [];
$startTime = microtime(true);

foreach ($files as $file) {
    $lines = @file($file, FILE_IGNORE_NEW_LINES);
    if ($lines === false) continue;

    $relPath = str_replace(ROOT_DIR . '/', '', $file);
    $definedVars = collectDefinedVars($lines);
    $fileIssues = detectIssues($lines, $definedVars, $relPath);

    foreach ($fileIssues as $issue) {
        $score = calcConfidence($issue, $definedVars);
        $issue['confidence'] = $score;
        $issue['level'] = confidenceLabel($score);
        $allIssues[] = $issue;
    }
}

// ─── 按置信度排序 ─────────────────────────────────
usort($allIssues, fn($a, $b) => $b['confidence'] <=> $a['confidence']);

if (!$showAll) {
    $allIssues = array_filter($allIssues, fn($i) => $i['level'] !== 'LOW');
}

// 截取 Top N
$allIssues = array_values($allIssues);
$totalIssues = count($allIssues);
if ($topN > 0 && $totalIssues > $topN) {
    $allIssues = array_slice($allIssues, 0, $topN);
}

$elapsed = round(microtime(true) - $startTime, 2);

// 统计
$byLevel = ['HIGH' => 0, 'MEDIUM' => 0, 'LOW' => 0];
$byRule = [];
foreach ($allIssues as $i) {
    $byLevel[$i['level']] = ($byLevel[$i['level']] ?? 0) + 1;
    $byRule[$i['rule_id']] = ($byRule[$i['rule_id']] ?? 0) + 1;
}

// ─── Diff 模式 ────────────────────────────────────
$diffNew = $diffFixed = 0;
if ($doDiff && file_exists(STATE_FILE)) {
    $prev = json_decode(file_get_contents(STATE_FILE), true) ?: [];
    $prevKeys = [];
    foreach ($prev as $p) {
        $prevKeys["{$p['file']}:{$p['line']}:{$p['rule_id']}"] = true;
    }
    $currKeys = [];
    foreach ($allIssues as $i) {
        $currKeys["{$i['file']}:{$i['line']}:{$i['rule_id']}"] = true;
    }
    $diffNew = count(array_diff_key($currKeys, $prevKeys));
    $diffFixed = count(array_diff_key($prevKeys, $currKeys));
}

// 保存状态
file_put_contents(STATE_FILE, json_encode($allIssues, JSON_UNESCAPED_UNICODE));

// ─── 输出 ─────────────────────────────────────────

if ($jsonOut) {
    echo json_encode([
        'summary' => [
            'files_scanned' => $totalFiles,
            'issues_shown'  => count($allIssues),
            'by_level'      => $byLevel,
            'by_rule'       => $byRule,
            'elapsed_sec'   => $elapsed,
            'diff_new'      => $diffNew,
            'diff_fixed'    => $diffFixed,
        ],
        'issues' => $allIssues,
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . PHP_EOL;
    exit(0);
}

// ── 终端输出 ─────────────────────────────────────

echo "🎯 PHP 8.2 Warning 探测 Bot v2 — TODO #10\n";
echo str_repeat('─', 70) . "\n";
echo "文件: {$totalFiles}  |  耗时: {$elapsed}s";
if (!$showAll) echo "  |  模式: 仅高+中风险";
echo "\n";

echo sprintf("发现: 🔴HIGH:%d  🟡MEDIUM:%d  🟢LOW:%d（已过滤）",
    $byLevel['HIGH'], $byLevel['MEDIUM'], $byLevel['LOW']);
if ($topN > 0) echo "  |  Top {$topN}";
echo "\n";

if ($doDiff && ($diffNew || $diffFixed)) {
    echo "📊 对比上次:  ➕新增 {$diffNew} 处  ✅修复 {$diffFixed} 处\n";
}

echo str_repeat('─', 70) . "\n\n";

if (count($allIssues) === 0) {
    echo "✅ 未发现高风险问题！\n";
    exit(0);
}

// 按规则统计
echo "📊 按规则统计:\n";
foreach ($byRule as $rule => $c) {
    $desc = match($rule) {
        'M001' => '超全局数组缺守卫',
        'M002' => '数组键缺守卫',
        'M003' => 'iniFile 返回值',
        'M004' => 'in_array null',
        'M005' => 'echo 未定义变量',
        default => '?',
    };
    echo "  [{$rule}] {$c} 处 — {$desc}\n";
}
echo "\n";

// Top 20 高危文件
$byFile = [];
foreach ($allIssues as $i) {
    if ($i['level'] === 'HIGH') {
        $byFile[$i['file']] = ($byFile[$i['file']] ?? 0) + 1;
    }
}
arsort($byFile);
if (count($byFile) > 0) {
    echo "📁 Top 高危文件 (HIGH only):\n";
    $shown = 0;
    foreach ($byFile as $f => $c) {
        echo sprintf("  %4d  %s\n", $c, $f);
        if (++$shown >= 15) break;
    }
    echo "\n";
}

// 详情：每规则展示前几条最高置信度
echo "🔍 高风险样例 (置信度 ≥ 80):\n";
$shown = 0;
foreach ($allIssues as $issue) {
    if ($issue['level'] !== 'HIGH') continue;
    if (++$shown > 20) break;

    $conf = $issue['confidence'];
    echo "  [{$issue['rule_id']}] 置信度:{$conf}%  {$issue['file']}:{$issue['line']}\n";
    echo "    → {$issue['message']}\n";
    echo "    → " . htmlspecialchars($issue['code'], ENT_QUOTES, 'UTF-8') . "\n\n";
}

echo str_repeat('─', 70) . "\n";
echo "💡 查看全部: 加 --all\n";
echo "💡 对比进度: 加 --diff\n";
echo "💡 排除目录: 加 --exclude template,admin (大量模板文件干扰)\n";
echo "💡 运行时验证: .\\tests\\warn_monitor.ps1 -Watch\n";

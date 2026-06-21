# TODO #10: PHP 8.2 Warning 探测 Bot

## 概览

| 工具 | 文件 | 用途 | 运行环境 |
|------|------|------|:--:|
| 静态扫描器 | `warn_scanner.php` | 扫源码查潜在 Warning 模式 | Docker 容器内 |
| 运行时监控 (PS) | `warn_monitor.ps1` | 抓 Docker 日志实时 Warning | Windows PowerShell |
| 运行时监控 (SH) | `warn_monitor.sh` | 同上，Linux/macOS 用 | Bash |
| 🆕 自动探索器 | `auto_explore.ps1` | 遍历游戏所有页面，自动触发 Warning | Windows PowerShell |

---

## 前置条件

```powershell
docker compose -f docker/docker-compose.yml up -d
```

确保 `xiyou-app` 容器在运行，扫描器和网站共享同一份代码。

---

## 一、静态扫描器 (`warn_scanner.php`)

### 基本用法

```powershell
# 默认：仅展示高+中风险，Top 200 条
docker exec xiyou-app php tests/warn_scanner.php

# 查看全部（含低风险）
docker exec xiyou-app php tests/warn_scanner.php --all

# 只看 Top 50
docker exec xiyou-app php tests/warn_scanner.php --top 50

# JSON 输出（供脚本消费）
docker exec xiyou-app php tests/warn_scanner.php --json
```

### 进阶用法

```powershell
# 排除干扰目录（template 下有大量模板文件）
docker exec xiyou-app php tests/warn_scanner.php --exclude template

# 排除多个目录
docker exec xiyou-app php tests/warn_scanner.php --exclude template,admin

# 只扫某个子目录
docker exec xiyou-app php tests/warn_scanner.php --dir fqxy/wj

# 对比上次运行，看修复进度
docker exec xiyou-app php tests/warn_scanner.php --diff
```

### 检测规则

| 规则 | 说明 | 典型场景 |
|------|------|----------|
| **M001** | 超全局数组缺 `??` 守卫 | `$_POST['key']` 直接读取 |
| **M002** | 普通数组键缺 `??` 守卫 | `$arr['key']` 且变量可能未定义 |
| **M003** | `iniFile` 返回值未判空 | `$iniFile->getItem(...)` 直接使用 |
| **M004** | `in_array` 参数可能为 null | `in_array($x, $maybeUndefined)` |
| **M005** | `echo/print` 变量未定义 | `echo $var` 变量可能未赋值 |

### 置信度说明

```
🔴 HIGH   (≥80)  极大概率触发 Warning，建议优先修复
🟡 MEDIUM (50-79) 可能触发，运行时验证后决定
🟢 LOW    (<50)  风格建议，非紧急（默认不显示）
```

评分维度：变量是否文件中已赋值(±30)、附近有无 isset/empty 保护(±25)、是否超全局数组(+40)、是否在循环中(+10) 等。

### 输出解读

```
🎯 PHP 8.2 Warning 探测 Bot v2 — TODO #10
──────────────────────────────────────────────────────────────────────
文件: 1739  |  耗时: 6.76s  |  模式: 仅高+中风险
发现: 🔴HIGH:164  🟡MEDIUM:36
──────────────────────────────────────────────────────────────────────

📊 按规则统计:
  [M001] 101 处 — 超全局数组缺守卫        ← 数量最多的类别
  [M005] 64 处  — echo 未定义变量
  [M002] 35 处  — 数组键缺守卫

📁 Top 高危文件 (HIGH only):              ← 优先修这些文件
     6  fqxy/map/cwd.php
     3  fqxy/admin/gm06.php
     ...

📊 对比上次: ➕新增 3 处  ✅修复 12 处    ← --diff 模式才有
```

---

## 二、运行时监控 (`warn_monitor.ps1`)

### 基本用法

```powershell
# 一次性抓取最近 500 条 Warning
.\tests\warn_monitor.ps1

# 实时监控（操作网站时同步看）
.\tests\warn_monitor.ps1 -Watch

# 生成汇总报告
.\tests\warn_monitor.ps1 -Report

# 导出 CSV
.\tests\warn_monitor.ps1 -Export warn_log.csv
```

### 实时监控示例

```powershell
PS> .\tests\warn_monitor.ps1 -Watch
🔍 实时监控 PHP 8.2 Warning ... (Ctrl+C 退出)
容器: xiyou-app

[21:45:01] [Warning] Undefined array key "wjtoke"
  📁 /var/www/html/fqxy/template/seach.php:7
[21:45:03] [Warning] Trying to access array offset on value of type null
  📁 /var/www/html/fqxy/map/cwd.php:42
```

---

## 三、典型修复流程

```
  ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
  │ 1. 扫描  │ ──→ │ 2. 监控  │ ──→ │ 3. 修复  │ ──→ │ 4. 验证  │
  │ 找候选   │     │ 真报Warning│     │ 加??守卫  │     │ --diff   │
  └──────────┘     └──────────┘     └──────────┘     └──────────┘
```

### 步骤详解

**第 1 步：扫描找候选**

```powershell
docker exec xiyou-app php tests/warn_scanner.php --top 50
```

从 Top 文件列表找下手目标，优先 M001（超全局数组）类。

**第 2 步：运行时验证**

```powershell
# 终端 1：开启监控
.\tests\warn_monitor.ps1 -Watch

# 终端 2：浏览器访问网站对应功能页面
# 观察日志里是否真有 Warning
```

**第 3 步：只修真报错的**

```php
// ❌ 错误：扫描报了就加守卫
// （可能掩盖真 Bug —— 把"本应存在的值"悄悄改成默认值）

// ✅ 正确：日志确认报 Warning 后才修
// 修复前
$name = $_POST['name'];
// 修复后
$name = $_POST['name'] ?? '';
```

**第 4 步：验证修复效果**

```powershell
docker exec xiyou-app php tests/warn_scanner.php --diff
# 输出: 📊 对比上次: ✅修复 47 处
```

---

## 四、注意事项

### Bot vs IDE 提示

| | Bot (warn_scanner) | IDE (Intelephense) |
|------|-------------------|---------------------|
| 分析方式 | 正则模式匹配 + 变量追踪 | 静态类型推断 |
| 误报类型 | 多报（宁可多报不愿漏） | 海量误报（include 链路断裂） |
| 适用场景 | TODO #10 专项，定位真实 Warning | 写代码时的实时提示 |

### 防止引入 Bug

- **不要扫出来就修**：扫描结果是"候选"，不是"Bug 清单"
- **必须运行时验证**：只有 `warn_monitor.ps1 -Watch` 日志里真正出现的行才动手
- **加守卫时注意语义**：`?? 0` 和 `?? null` 和 `?? []` 选择正确的默认值
- **修完跑 `--diff`**：确认数量下降，没有引入新问题

### 常见误报场景

```php
// 场景 1：变量在 include 文件中定义
include("config.php");
echo $CONFIG['db_host'];  // Bot: M005 报未定义
// → 实际：config.php 定义了 $CONFIG，运行时安全

// 场景 2：$_SERVER 在 CLI 下缺失
$ip = $_SERVER['REMOTE_ADDR'];  // Bot: M001 报缺守卫
// → Web 环境永远存在，但加 ?? '' 无害

// 场景 3：前置代码保证变量存在
$user = getUserById($uid);      // 函数保证返回数组
echo $user['name'];             // Bot: M002 报缺守卫
// → 如果 getUserById 永远返回数组，安全
```

---

## 四.五、自动探索器 (auto_explore.ps1)

自动遍历游戏所有 cmd 页面，结合 `warn_monitor.ps1 -Watch` 捕获 Warning，**无需手动点击**。

### 使用方法

```powershell
# 1. 终端1: 启动监控
.	ests\warn_monitor.ps1 -Watch

# 2. 从浏览器地址栏复制 uid 和 sid 参数
#    例如: xy.php?uid=10000002&cmd=1&sid=mpWnxuxmhTOrHBh1gIOdxLDNNOvwqD
#    则 uid=10000002, sid=mpWnxuxmhTOrHBh1gIOdxLDNNOvwqD

# 3. 终端2: 启动探索器
.	ests\auto_explore.ps1 -Uid 10000002 -Sid "mpWnxuxmhTOrHBh1gIOdxLDNNOvwqD"
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|:--:|
| `-Uid` | 游戏玩家ID (必填) | — |
| `-Sid` | 玩家游戏码 (必填) | — |
| `-Delay` | 请求间隔(秒) | 0.25 |
| `-Quick` | 快速模式，只扫上次爆 Warning 的 cmd | off |
| `-NoSkipSafe` | 不跳过安全 cmd，全量扫描 | off |

### 安全跳过规则

探索器自动跳过：
- **有副作用**: 丢弃物品、使用物品、银两操作、改名、PK 等 (~80 个 cmd)
- **需 POST 数据**: 拍卖、赠送、仓库存储等 (~60 个 cmd)
- 约扫描 **550 个 GET-only 安全 cmd**，范围 1..685

### 快速重扫模式

修完一批 Warning 后，可以只重扫之前报错的 cmd：

```powershell
.	ests\auto_explore.ps1 -Uid 10000002 -Sid "..." -Quick
```

---

## 五、快捷脚本

将以下内容加入工作流：

```powershell
# 修前快照
docker exec xiyou-app php tests/warn_scanner.php --json > tests/before.json

# ... 修复若干文件 ...

# 修后对比
docker exec xiyou-app php tests/warn_scanner.php --diff

# 全量 JSON 导出分析
docker exec xiyou-app php tests/warn_scanner.php --json --all > tests/full_report.json
```

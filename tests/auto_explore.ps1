# TODO #10 Auto-Explorer Bot
# 借助已有 session 遍历游戏所有 cmd 页面，触发 PHP Warning
#
# Usage:
#   1. 终端1: .\tests\warn_monitor.ps1 -Watch
#   2. 浏览器打开游戏，F12 → Application → Cookies → 复制 PHPSESSID 值
#   3. 终端2: .\tests\auto_explore.ps1 -Cookie "PHPSESSID的值"
#   4. 终端1 会实时捕获 Warning
#
# 获取 PHPSESSID 方法:
#   Chrome/Edge: F12 → Application → Cookies → http://localhost:8080 → PHPSESSID
#   Firefox:     F12 → Storage → Cookies → http://localhost:8080 → PHPSESSID
#
# 模式:
#   -Range         扫描 cmd 范围 (默认: 1..685)
#   -Delay         请求间隔秒数 (默认: 0.2)
#   -Quick         快速模式 — 只扫上次爆 Warning 的 cmd (默认所有)
#   -SkipSafe      跳过已知安全的 cmd (默认开启)

param(
    [string]$Cookie,                 # PHPSESSID 值 (从浏览器 F12 → Cookies 获取) ★推荐★

    [int]$Delay = 0.25,             # 请求间隔(秒), 最低0.15避免被封
    [switch]$Quick,                  # 快速模式: 只扫历史爆过的cmd
    [switch]$NoSkipSafe,             # 不跳过安全cmd, 全量扫描
    [string]$StateFile = "$PSScriptRoot/.explore_state.json"
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

$BaseUrl = "http://localhost:8080/fqxy"
$Total = 0
$Tested = 0
$Warned = 0
$Errored = 0
$Results = @()
$Cwd = Split-Path -Parent $PSCommandPath

# ── PID 文件锁 (防止重复启动) ───────────────
$PidFile = "$env:TEMP\explore_bot.pid"
if (Test-Path $PidFile) {
    $old = Get-Content $PidFile -Raw
    try {
        $p = Get-Process -Id ([int]$old) -ErrorAction SilentlyContinue
        if ($p -and $p.ProcessName -match 'powershell') {
            Write-Host "[ERROR] Another explorer is running (PID: $old). Stop it first." -ForegroundColor Red
            exit 1
        }
    } catch { }
}
$PID | Out-File -FilePath $PidFile -Force

# ── 构建 cmd 列表 ──────────────────────────
$allCmds = 1..685

# 有副作用的 cmd — 会消耗物品/银两/经验/改变状态, 跳过
$dangerCmds = @(
    3,4,5,6,7,      # 移动 (改变地图位置)
    37,             # 使用物品
    82,84,          # 穿装备/卸装备
    69,73,74,75,    # 宝石操作
    77,79,          # 装备升星
    90,91,          # 装备升级/打造
    122,123,124,126,127,246, # 买东西/丢弃
    185,            # 国家捐献
    213,            # 玄铁令兑换
    248,            # 药品恢复
    249,            # 宠物捕捉
    257,258,259,    # 存取银两
    295,            # 选择门派
    297,            # 选择性别
    298,            # 输入名字 (会改名!)
    310,            # 制作宝石
    328,329,        # 改名 法宝经验
    330,331,332,333,# 批量使用物品
    344,345,346,347,# 装备操作
    348,            # 打怪 (会触发战斗消耗)
    349,350,        # 死亡
    360,361,        # 宠物捕捉
    401,402,403,    # 挑战/擂台/娱乐
    413,            # 答题
    450,            # 挑战面板
    451,452,        # 十八层地狱
    453,            # 宠物初始
    520,521,        # 领取金豆
    522,523,524,525,526,534, # PK
    535,536,537,    # 银两转换/赠银
    538,539,540,541,542,543,544,545,546,547,548, # 赠送
    609,610,        # 中秋抢榜
    611,612,        # 改性别
    658,659,660,661,662,663,664,665, # 农场
    667,            # 提交课本
    675,676,677,678,679,680, # SDK码兑换
    682,683,684,685 # 竞猜购买
)

# 需要 POST 数据的 cmd (跳过)
$postCmds = @(
    14,15,16,17,    # 技能设置
    24,25,          # 私聊
    109,110,        # 组队同意/拒绝
    214,215,216,    # 结婚相关
    254,255,        # 留言
    275,276,277,278,279,280,281,282,283,284, # 仓库存储
    305,            # 重置快捷键
    313,            # 快速任务
    315,316,        # 重置副本
    413,            # 答题提交
    467,468,469,470,471,472, # 金豆泡泡
    482,483,        # 宝石熔炼
    484,485,486,487,# 宠物升星
    501,502,503,504,505,506,507,508,509,510,511,512,513,514,515,516, # 拍卖
    529,530,531,532, # 升星魂/图纸
    613,            # 天降密宝领取
    620,621,622,623,624,625, # 擂台提交
    631,632,633,    # 熔炼/奖励
    641,642,        # 诛仙台
    643,644,645,646, # 采花大盗
    652,653,654,    # 愿望/伏羲
    670,671,672     # 猜糖果
)

# 组合跳过列表
$skipCmds = $dangerCmds + $postCmds | Sort-Object -Unique

# 快速模式: 只扫上次爆过 Warning 的历史 cmd
if ($Quick) {
    $knownWarn = @()
    if (Test-Path $StateFile) {
        $state = Get-Content $StateFile -Raw | ConvertFrom-Json
        $knownWarn = $state.warned_cmds
        Write-Host "Quick mode: replaying $($knownWarn.Count) previously warned cmds" -ForegroundColor Cyan
    }
    if ($knownWarn.Count -eq 0) {
        Write-Host "No previous warn state found. Run without -Quick first." -ForegroundColor Yellow
        exit 0
    }
    $allCmds = $knownWarn
} else {
    if (-not $NoSkipSafe) {
        $allCmds = $allCmds | Where-Object { $_ -notin $skipCmds }
    }
}

# ── Cookie 验证 ──────────────────────────
if (-not $Cookie) {
    Write-Host "[ERROR] -Cookie is required!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  xy.php uses PHP Sessions, not URL params." -ForegroundColor Yellow
    Write-Host "  To get your PHPSESSID:"
    Write-Host "    1. Open the game in Chrome/Edge"
    Write-Host "    2. Press F12 → Application tab → Cookies → localhost:8080"
    Write-Host "    3. Copy the Value of PHPSESSID"
    Write-Host ""
    Write-Host "  Then: .\tests\auto_explore.ps1 -Cookie 'PHPSESSID_value'" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

$Total = $allCmds.Count
Write-Host ("=" * 60)
Write-Host "  TODO #10 Auto-Explorer Bot" -ForegroundColor Cyan
Write-Host ("=" * 60)
Write-Host "  Cookie  : PHPSESSID=$($Cookie.Substring(0, [Math]::Min(8,$Cookie.Length)))..."
Write-Host "  Target  : $Total cmds (range 1..685)"
Write-Host "  Delay   : ${Delay}s"
Write-Host "  Skip    : $($dangerCmds.Count)danger + $($postCmds.Count)post"
Write-Host "  Mode    : $(if ($Quick) {'Quick (replay)'} else {'Full scan'})"
Write-Host ""

# ── 前置验证: Cookie 是否有效 ─────────────
Write-Host "  Verifying cookie..." -NoNewline
$probe = curl.exe -s -o NUL -w "%{http_code};%{size_download}" -b "PHPSESSID=$Cookie" --max-time 10 "$BaseUrl/xy.php?cmd=1" 2>&1
$pParts = $probe -split ';'
$pCode = ($pParts[0] -replace '\s+', '')
$pSize = if ($pParts.Count -gt 1) { ($pParts[1] -replace '\s+', '') } else { '?' }
if ($pCode -eq '200' -and $pSize -match '^\d+$' -and [int]$pSize -lt 1500) {
    Write-Host " INVALID (body=$pSize bytes → session expired)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Your PHPSESSID has expired. Please:" -ForegroundColor Yellow
    Write-Host "    1. Refresh the game page in your browser"
    Write-Host "    2. Copy the NEW PHPSESSID from F12 → Cookies"
    Write-Host "    3. Re-run with: .\tests\auto_explore.ps1 -Cookie 'NEW_PHPSESSID'"
    Write-Host ""
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    exit 1
}
Write-Host " OK (code=$pCode size=$pSize bytes)" -ForegroundColor Green
Write-Host ""

$startTime = Get-Date
$TempBody = "$env:TEMP\_explore_body.tmp"

# ── 主循环 ─────────────────────────────────
foreach ($cmd in $allCmds) {
    $Tested++
    $url = "$BaseUrl/xy.php?cmd=$cmd"

    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        # 下载到临时文件并拿到 HTTP 状态码
        $resp = curl.exe -s -o "$TempBody" -w "%{http_code};%{size_download}" -b "PHPSESSID=$Cookie" --max-time 10 "$url" 2>&1
        $elapsed = $sw.ElapsedMilliseconds
        $sw.Stop()

        $parts = $resp -split ';'
        $statusCode = ($parts[0] -replace '\s+', '')
        $bodySize = if ($parts.Count -gt 1) { ($parts[1] -replace '\s+', '') } else { '?' }
        if (-not $statusCode) { $statusCode = 'err' }

        # ── 扫描响应体中的 PHP 错误 ──────────
        if ($statusCode -eq '200' -and (Test-Path $TempBody)) {
            $body = Get-Content $TempBody -Raw -ErrorAction SilentlyContinue
            if ($body -match 'Warning|Notice|Deprecated|Fatal error|Parse error') {
                # 提取所有匹配行
                $warnLines = ([regex]::Matches($body, '<b>(Warning|Notice|Deprecated|Fatal|Parse)[^<]*</b>[^<]*'))
                foreach ($m in $warnLines) {
                    $Warned++
                    $msg = $m.Value -replace '<[^>]+>', '' -replace '\s+', ' '
                    $msg = if ($msg.Length -gt 100) { $msg.Substring(0,97) + '...' } else { $msg }
                    $Results += [PSCustomObject]@{ cmd=$cmd; type='PHP_WARN'; msg=$msg; status=$statusCode; ms=$elapsed }
                    # 换行打印（不盖掉进度条）
                    Write-Host "`r  ⚠ $(if($Warned -le 999){' '})$Warned | cmd=$cmd $msg" -ForegroundColor Yellow
                }
            }
        }

        if ($statusCode -match '^[345]') {
            $Errored++
            $Results += [PSCustomObject]@{ cmd=$cmd; type='HTTP_ERR'; msg=$statusCode; status=$statusCode; ms=$elapsed }
        } elseif ($statusCode -ne '200') {
            $Errored++
            $Results += [PSCustomObject]@{ cmd=$cmd; type='UNKNOWN'; msg=$statusCode; status=$statusCode; ms=$elapsed }
        }
    } catch {
        $Errored++
        $Results += [PSCustomObject]@{ cmd=$cmd; type='EXCEPTION'; msg=$_.Exception.Message; status='err'; ms=0 }
    }

    # ── 内联进度条 ──────────────────────────
    $pct = [math]::Round($Tested / $Total * 100, 1)
    $eta = ''
    if ($Tested -gt 0) {
        $elapsed = ([DateTime]::Now - $startTime).TotalSeconds
        $rate = $elapsed / $Tested                     # 平均每请求秒数
        $remaining = [int]($rate * ($Total - $Tested))
        if ($remaining -gt 120) { $eta = " ETA $([math]::Floor($remaining/60))m" }
        elseif ($remaining -gt 0) { $eta = " ETA ${remaining}s" }
    }
    # 绘制进度条 30 格
    $barW = 30
    $done = [math]::Floor($Tested / $Total * $barW)
    $bar  = ("█" * $done) + ("░" * ($barW - $done))
    # 速率（请求/秒）
    $rpsStr = ''
    if ($Tested -gt 5) {
        $rps = ($Tested / ([DateTime]::Now - $startTime).TotalSeconds).ToString('0.0')
        $rpsStr = " ${rps}/s"
    }
    Write-Host -NoNewline "`r  [$bar] ${Tested}/${Total} (${pct}%)${rpsStr} err:${Errored} warn:${Warned}${eta}    "
    Write-Progress -Activity "Auto-Explorer" -Status "cmd $cmd / $Total" -PercentComplete $pct

    Start-Sleep -Milliseconds ([int]($Delay * 1000))
}

# 清理临时文件
Remove-Item $TempBody -Force -ErrorAction SilentlyContinue

Write-Progress -Completed

# ── 换行结束进度条 ─────────────────────────
Write-Host ""

$duration = [DateTime]::Now - $startTime
Write-Host ("=" * 60)
Write-Host "  Explore Complete" -ForegroundColor Green
Write-Host ("=" * 60)
Write-Host "  Duration : $($duration.TotalSeconds.ToString('0.0'))s"
Write-Host "  Tested   : $Tested / $Total"
Write-Host "  Warn     : $Warned" -ForegroundColor $(if($Warned -gt 0){'Yellow'}else{'DarkGray'})
Write-Host "  HTTP Err : $Errored"
Write-Host ""

# ── 输出 Warning 汇总 ──────────────────────
if ($Results.Count -gt 0) {
    Write-Host "  --- PHP Warnings Found ---" -ForegroundColor Yellow
    $Results | Where-Object { $_.type -eq 'PHP_WARN' } | Format-Table cmd, msg -AutoSize -Wrap | Out-String | Write-Host
    # 导出到文件
    $reportFile = "$Cwd\.warn_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $Results | Export-Csv -Path ($reportFile -replace '\.txt$','.csv') -NoTypeInformation -Encoding UTF8
    Write-Host "  Report saved to: $reportFile" -ForegroundColor Cyan
} else {
    Write-Host "  No PHP warnings detected across all $Tested pages." -ForegroundColor DarkGray
}
Write-Host ""

# 清理
Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
Remove-Item $TempBody -Force -ErrorAction SilentlyContinue

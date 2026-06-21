# TODO #10 Auto-Explorer Bot
# 借助已有 session 遍历游戏所有 cmd 页面，触发 PHP Warning
#
# Usage:
#   1. 终端1: .\tests\warn_monitor.ps1 -Watch
#   2. 从浏览器复制 uid 和 sid
#   3. 终端2: .\tests\auto_explore.ps1 -Uid 10000002 -Sid "your_sid_value"
#   4. 终端1 会实时捕获 Warning
#
# 模式:
#   -Range         扫描 cmd 范围 (默认: 1..685)
#   -Delay         请求间隔秒数 (默认: 0.2)
#   -Quick         快速模式 — 只扫上次爆 Warning 的 cmd (默认所有)
#   -SkipSafe      跳过已知安全的 cmd (默认开启)

param(
    [Parameter(Mandatory=$true)]
    [string]$Uid,                    # 游戏玩家ID (8位数字)

    [Parameter(Mandatory=$true)]
    [string]$Sid,                    # 玩家游戏码 (30位字符串)

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

$Total = $allCmds.Count
Write-Host ("=" * 60)
Write-Host "  TODO #10 Auto-Explorer Bot" -ForegroundColor Cyan
Write-Host ("=" * 60)
Write-Host "  UID     : $Uid"
Write-Host "  SID     : $Sid"
Write-Host "  Target  : $Total cmds (range 1..685)"
Write-Host "  Delay   : ${Delay}s"
Write-Host "  Skip    : $($dangerCmds.Count)danger + $($postCmds.Count)post"
Write-Host "  Mode    : $(if ($Quick) {'Quick (replay)'} else {'Full scan'})"
Write-Host ""

$startTime = Get-Date

# ── 主循环 ─────────────────────────────────
foreach ($cmd in $allCmds) {
    $Tested++
    $url = "$BaseUrl/xy.php?uid=$Uid&cmd=$cmd&sid=$Sid"

    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        # 用 curl 发请求（更轻量）, 只检查 HTTP 状态码和 PHP 错误
        $resp = curl.exe -s -o NUL -w "%{http_code}" --max-time 10 "$url" 2>&1
        $elapsed = $sw.ElapsedMilliseconds
        $sw.Stop()

        $statusCode = $resp -replace '\s+', ''

        # curl 报错但状态码被吞的情况
        if (-not $statusCode) { $statusCode = 'err' }

        if ($statusCode -eq '200') {
            # OK — 需要等 monitor 确认是否有 Warning
        } elseif ($statusCode -match '^[345]') {
            $Errored++
            $Results += [PSCustomObject]@{ cmd=$cmd; status=$statusCode; ms=$elapsed }
        } else {
            $Errored++
            $Results += [PSCustomObject]@{ cmd=$cmd; status=$statusCode; ms=$elapsed }
        }
    } catch {
        $Errored++
        $Results += [PSCustomObject]@{ cmd=$cmd; status='exception'; ms=0 }
    }

    # 进度条
    $pct = [math]::Round($Tested / $Total * 100, 1)
    $eta = ''
    if ($Tested -gt 0) {
        $secs = [int](([DateTime]::Now - $startTime).TotalSeconds / $Tested * ($Total - $Tested))
        if ($secs -gt 60) { $eta = " ~$([math]::Floor($secs/60))m" }
        elseif ($secs -gt 0) { $eta = " ~${secs}s" }
    }
    Write-Progress -Activity "Exploring cmd..." -Status "${cmd}/${Total} ($pct%) errors:$Errored$eta" -PercentComplete $pct

    Start-Sleep -Milliseconds ([int]($Delay * 1000))
}

Write-Progress -Completed

$duration = [DateTime]::Now - $startTime
Write-Host ""
Write-Host ("=" * 60)
Write-Host "  Explore Complete" -ForegroundColor Green
Write-Host ("=" * 60)
Write-Host "  Duration : $($duration.TotalSeconds.ToString('0.0'))s"
Write-Host "  Tested   : $Tested / $Total"
Write-Host "  HTTP Err : $Errored"
Write-Host ""
Write-Host "  Monitor output above this line ---^" -ForegroundColor DarkGray
Write-Host "  Run '.\tests\warn_monitor.ps1 -Report' for summary" -ForegroundColor Yellow

# 清理
Remove-Item $PidFile -Force -ErrorAction SilentlyContinue

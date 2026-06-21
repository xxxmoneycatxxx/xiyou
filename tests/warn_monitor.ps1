# TODO #10 PHP 8.2 Warning Runtime Monitor (PowerShell)
#
# PHP Warning 在 Docker 容器中输出到 stdout/stderr,
# 因此通过 docker logs 获取，而非读日志文件。
#
# Usage:
#   .\tests\warn_monitor.ps1                  # One-shot: fetch recent warnings
#   .\tests\warn_monitor.ps1 -Watch            # Real-time tail
#   .\tests\warn_monitor.ps1 -Report           # Summary report
#   .\tests\warn_monitor.ps1 -Export out.csv   # Export CSV

param(
    [switch]$Watch,
    [switch]$Report,
    [string]$Export
)

# Fix UTF-8 display in PowerShell 5.x
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8
chcp 65001 >$null 2>&1

$Container = "xiyou-app"

# ── Helpers ──────────────────────────────────────

function Assert-Container {
    $running = docker ps --format '{{.Names}}' 2>$null | Select-String "^$Container$"
    if (-not $running) {
        Write-Host "[ERROR] Container '$Container' not running" -ForegroundColor Red
        Write-Host "  Run: docker compose -f docker/docker-compose.yml up -d"
        exit 1
    }
}

function Get-RawLogs {
    # PHP Warning/Notice/Deprecated go to container stdout/stderr via Apache
    docker logs $Container 2>&1 | Select-String -Pattern 'PHP (Warning|Notice|Deprecated):' | ForEach-Object { $_.Line }
}

function Get-LogsStream {
    # Stream new logs in real-time
    docker logs -f --tail 0 $Container 2>&1 | ForEach-Object {
        $line = if ($_ -is [string]) { $_ } else { $_.Line }
        if ($line -match 'PHP (Warning|Notice|Deprecated):') {
            Write-Output $line
        }
    }
}

# ── Decode PHP hex escapes (\xe8\xa1\x80 → 血) ────
function Decode-HexEscapes {
    param([string]$Text)
    # PHP logs non-ASCII chars as \xNN sequences in apache error output
    $bytes = [byte[]]@()
    $i = 0
    while ($i -lt $Text.Length) {
        if ($i + 3 -lt $Text.Length -and $Text[$i] -eq '\' -and $Text[$i+1] -eq 'x') {
            $hex = $Text.Substring($i+2, 2)
            $bytes += [Convert]::ToByte($hex, 16)
            $i += 4
        } else {
            $bytes += [byte][char]$Text[$i]
            $i++
        }
    }
    try { return [Text.Encoding]::UTF8.GetString($bytes) }
    catch { return $Text }
}

# ── Parse Helpers ─────────────────────────────────

function Parse-LogLine {
    param([string]$Line)
    $result = @{ Type = ''; Message = ''; File = ''; Lineno = '' }
    if ($Line -match 'PHP\s+(Warning|Notice|Deprecated):\s*(.+?)(?:\s+in\s+(/\S+\.php)(?:\s+on\s+line\s+(\d+))?)?$') {
        $result.Type = $Matches[1]
        $result.Message = Decode-HexEscapes -Text $Matches[2]
        $result.File = if ($Matches[3]) { $Matches[3] } else { '?' }
        $result.Lineno = if ($Matches[4]) { $Matches[4] } else { '?' }
    }
    return $result
}

# ── Main ─────────────────────────────────────────

Assert-Container

# ── -Watch: real-time (polling mode, works in PS 5/7) ──
if ($Watch) {
    Write-Host "Watching PHP 8.2 Warnings... (Ctrl+C to stop)" -ForegroundColor Cyan
    Write-Host "Container: $Container" -ForegroundColor DarkGray
    Write-Host "Open http://localhost:8080 and browse pages to trigger warnings.`n"

    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $firstRun = $true

    while ($true) {
        # Fetch last N lines of PHP warnings from docker logs
        $lines = docker logs $Container --tail 300 2>&1 | Where-Object { $_ -match 'PHP (Warning|Notice|Deprecated):' }
        $newCount = 0

        foreach ($line in $lines) {
            $lineStr = if ($line -is [string]) { $line } else { $line.ToString() }
            # Skip dupes using hash
            if (-not $seen.Add($lineStr)) { continue }

            if ($firstRun) { continue }  # Skip historical on first poll

            $ts = Get-Date -Format 'HH:mm:ss'
            $parsed = Parse-LogLine -Line $lineStr

            $color = 'Gray'
            if ($parsed.Type -eq 'Warning') { $color = 'Yellow' }
            elseif ($parsed.Type -eq 'Deprecated') { $color = 'Magenta' }

            Write-Host "[$ts] " -NoNewline -ForegroundColor DarkGray
            Write-Host "[$($parsed.Type)] " -NoNewline -ForegroundColor $color
            Write-Host $parsed.Message
            if ($parsed.File -ne '?') {
                Write-Host "        $($parsed.File):$($parsed.Lineno)" -ForegroundColor DarkGray
            }
            $newCount++
        }

        if ($firstRun) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Monitor ready, waiting for warnings... (Ctrl+C to stop)`n" -ForegroundColor Green
            $firstRun = $false
        }

        Start-Sleep -Seconds 2
    }
    exit 0
}

# ── Collect raw lines ────────────────────────────
$rawLines = @(Get-RawLogs)
$parsedLines = $rawLines | ForEach-Object { Parse-LogLine -Line $_ } | Where-Object { $_.Message }

# ── -Export ──────────────────────────────────────
if ($Export) {
    if ($parsedLines.Count -eq 0) {
        Write-Host "No warnings to export." -ForegroundColor Green
        exit 0
    }
    $parsedLines | Select-Object Type, Message, File, Lineno |
        Export-Csv -Path $Export -NoTypeInformation -Encoding UTF8
    Write-Host "Exported $($parsedLines.Count) warnings to $Export" -ForegroundColor Green
    exit 0
}

# ── -Report ──────────────────────────────────────
if ($Report) {
    if ($parsedLines.Count -eq 0) {
        Write-Host "No PHP 8.2 warnings detected." -ForegroundColor Green
        exit 0
    }

    $total = $parsedLines.Count
    Write-Host ("=" * 60)
    Write-Host "  TODO #10 Warning Report" -ForegroundColor Cyan
    Write-Host ("=" * 60)
    Write-Host "  Time : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "  Total: $total warnings"
    Write-Host ""

    # By type
    $byType = @{}
    foreach ($p in $parsedLines) {
        if (-not $byType.ContainsKey($p.Type)) { $byType[$p.Type] = 0 }
        $byType[$p.Type]++
    }
    Write-Host "  -- By Type --"
    foreach ($t in ($byType.Keys | Sort-Object)) {
        $tag = if ($t -eq 'Warning') { '[!]' } elseif ($t -eq 'Deprecated') { '[D]' } else { '[i]' }
        Write-Host "    $tag $t : $($byType[$t])"
    }
    Write-Host ""

    # By file
    $byFile = @{}
    foreach ($p in $parsedLines) {
        $f = if ($p.File -ne '?') { $p.File } else { '(unknown)' }
        if (-not $byFile.ContainsKey($f)) { $byFile[$f] = 0 }
        $byFile[$f]++
    }
    Write-Host "  -- By File (Top 15) --"
    $byFile.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15 | ForEach-Object {
        Write-Host "    $($_.Value.ToString().PadLeft(5))  $($_.Key)"
    }
    Write-Host ""

    # Recent 10 details
    Write-Host "  -- Recent 10 --"
    $parsedLines | Select-Object -Last 10 | ForEach-Object {
        $short = $_.Message
        if ($short.Length -gt 100) { $short = $short.Substring(0, 100) + "..." }
        Write-Host "    [$($_.Type)] $short" -ForegroundColor Yellow
        if ($_.File -ne '?') {
            Write-Host "      $($_.File):$($_.Lineno)" -ForegroundColor DarkGray
        }
    }
    Write-Host ("=" * 60)
    exit 0
}

# ── Default: one-shot ────────────────────────────
if ($parsedLines.Count -eq 0) {
    Write-Host "No PHP 8.2 warnings found." -ForegroundColor Green
    Write-Host "Tip: Visit the website to trigger PHP pages, then re-run."
    Write-Host "      Or use -Watch for real-time monitoring."
} else {
    Write-Host "Recent warnings ($($parsedLines.Count)):`n" -ForegroundColor Cyan
    $parsedLines | Select-Object -Last 30 | ForEach-Object {
        $short = $_.Message
        if ($short.Length -gt 120) { $short = $short.Substring(0, 120) + "..." }
        Write-Host "  [$($_.Type)] $short" -ForegroundColor Yellow
        if ($_.File -ne '?') {
            Write-Host "    $($_.File):$($_.Lineno)" -ForegroundColor DarkGray
        }
    }
}

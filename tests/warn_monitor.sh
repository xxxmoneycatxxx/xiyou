#!/bin/bash
# 🎯 TODO #10 PHP 8.2 Warning 运行时监控 Bot
# 
# 从 Docker 容器抓取 Apache + PHP 日志并过滤 Warning。
# 
# 用法:
#   bash tests/warn_monitor.sh               # 一次性抓取最近 100 条 Warning
#   bash tests/warn_monitor.sh --watch         # 实时 tail 模式
#   bash tests/warn_monitor.sh --report        # 生成汇总报告
#   bash tests/warn_monitor.sh --export report.csv  # 导出 CSV
# 
# 前置条件: docker compose -f docker/docker-compose.yml up -d

set -euo pipefail

CONTAINER="xiyou-app"
DOCKER_COMPOSE_DIR="docker"

# ─── 确保容器运行 ─────────────────────────────────

check_container() {
    if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
        echo "❌ 容器 $CONTAINER 未运行"
        echo "   请先执行: docker compose -f docker/docker-compose.yml up -d"
        exit 1
    fi
}

# ─── 抓取 Warning ─────────────────────────────────

fetch_warnings() {
    local limit="${1:-100}"
    # 从 Apache error log 和 PHP-FPM log 抓 Warning
    docker exec "$CONTAINER" sh -c "
        (tail -n $limit /var/log/apache2/error.log 2>/dev/null || true;
         tail -n $limit /usr/local/etc/php/error.log 2>/dev/null || true) \
        | grep -i 'warn\|notice\|deprecated' \
        | grep -v 'child process\|AH0\|core:notice' \
        | tail -n $limit
    " 2>/dev/null || echo ""
}

# ─── 实时监控模式 ─────────────────────────────────

watch_mode() {
    echo "🔍 实时监控 PHP 8.2 Warning ... (Ctrl+C 退出)"
    echo "容器: $CONTAINER"
    echo ""
    
    docker exec "$CONTAINER" sh -c "
        tail -F /var/log/apache2/error.log 2>/dev/null &
        tail -F /usr/local/etc/php/error.log 2>/dev/null &
        wait
    " 2>/dev/null | grep --line-buffered -i 'warn\|notice\|deprecated\|error' \
        | grep -v 'child process\|AH0\|core:notice' \
        | while IFS= read -r line; do
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            echo "[$timestamp] $line"
        done
}

# ─── 生成报告 ─────────────────────────────────────

report_mode() {
    local warnings
    warnings=$(fetch_warnings 9999)
    
    if [ -z "$warnings" ]; then
        echo "✅ 未检测到 PHP 8.2 Warning"
        exit 0
    fi
    
    local total
    total=$(echo "$warnings" | wc -l)
    
    echo "══════════════════════════════════════════════"
    echo "  🎯 TODO #10 Warning 监控报告"
    echo "══════════════════════════════════════════════"
    echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  容器: $CONTAINER"
    echo "  总计: $total 条 Warning"
    echo ""
    
    # 按文件分组统计
    echo "  ── 按文件统计 ──"
    echo "$warnings" | grep -oP '(?<=in\s)/\S+\.php' | sort | uniq -c | sort -rn | head -20 \
        | awk '{printf "    %-5s %s\n", $1, $2}'
    echo ""
    
    # 按类型分组统计
    echo "  ── 按 Warning 类型统计 ──"
    echo "$warnings" \
        | sed 's/.*PHP *\(Warning\|Notice\|Deprecated\): *//' \
        | sed 's/ in .*//' \
        | sort | uniq -c | sort -rn | head -20 \
        | awk '{printf "    %-5s %s\n", $1, substr($0, index($0,$2))}'
    echo ""
    
    # 最近 20 条详情
    echo "  ── 最近 20 条 ──"
    echo "$warnings" | tail -20 | while IFS= read -r line; do
        # 提取关键信息
        local file=$(echo "$line" | grep -oP '/\S+\.php' | head -1)
        local msg=$(echo "$line" | sed 's/.*PHP *\(Warning\|Notice\|Deprecated\): */\1: /' | sed 's/ in .*//')
        echo "    $msg"
        [ -n "$file" ] && echo "       📁 $file"
    done
    echo "══════════════════════════════════════════════"
}

# ─── 导出 CSV ─────────────────────────────────────

export_csv() {
    local outfile="${1:-warn_report.csv}"
    local warnings
    warnings=$(fetch_warnings 9999)
    
    echo "file,line,type,message" > "$outfile"
    
    echo "$warnings" | while IFS= read -r line; do
        local file=$(echo "$line" | grep -oP '/\S+\.php' | head -1)
        local lineno=$(echo "$line" | grep -oP 'on line \K\d+' | head -1)
        local type=$(echo "$line" | grep -oP 'PHP \K\w+' | head -1)
        local msg=$(echo "$line" | sed 's/.*PHP *\w*: *//' | sed 's/ in .*//' | sed 's/"/""/g')
        echo "\"$file\",\"$lineno\",\"$type\",\"$msg\"" >> "$outfile"
    done
    
    echo "✅ 导出完成: $outfile"
}

# ─── 主入口 ───────────────────────────────────────

check_container

case "${1:-}" in
    --watch|-w)
        watch_mode
        ;;
    --report|-r)
        report_mode
        ;;
    --export)
        export_csv "${2:-warn_report.csv}"
        ;;
    *)
        # 默认：一次性抓取
        fetch_warnings 200
        ;;
esac

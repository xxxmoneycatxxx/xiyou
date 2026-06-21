#!/bin/bash
# #5 InnoDB 迁移模拟测试
# 用法：docker exec xiyou-app bash /var/www/html/simulate_innodb.sh
set +e

MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-root}"
APP_URL="${APP_URL:-http://localhost:8080}"
PASS=0
FAIL=0

mysql_cmd() {
    mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "$1" 2>/dev/null
}

check() {
    local desc="$1"
    if [ "$2" -eq 0 ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "╔══════════════════════════════════════════╗"
echo "║   #5 MyISAM → InnoDB 模拟测试           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ──── 1. 迁移前状态 ────
echo "[1/5] 迁移前引擎分布..."
echo "  数据库: xyy"
mysql_cmd "SELECT ENGINE, COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='xyy' GROUP BY ENGINE;"
echo "  数据库: xxjyuser"
mysql_cmd "SELECT ENGINE, COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='xxjyuser' GROUP BY ENGINE;"
echo ""

MYISAM_BEFORE=$(mysql_cmd "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA IN ('xyy','xxjyuser') AND ENGINE='MyISAM';")
echo "  MyISAM 表总数: $MYISAM_BEFORE"
echo ""

# ──── 2. 备份关键表（可选） ────
echo "[2/5] 创建回滚备份..."
mysql_cmd "
SELECT CONCAT('ALTER TABLE \`', TABLE_SCHEMA, '\`.\`', TABLE_NAME, '\` ENGINE=MyISAM;')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA IN ('xxjyuser', 'xyy') AND ENGINE = 'MyISAM';
" > /tmp/innodb_rollback.sql 2>/dev/null

ROLLBACK_COUNT=$(wc -l < /tmp/innodb_rollback.sql)
echo "  回滚脚本: /tmp/innodb_rollback.sql ($ROLLBACK_COUNT 条)"
echo ""

# ──── 3. 执行迁移 ────
echo "[3/5] 执行 ALTER TABLE ... ENGINE=InnoDB ..."
START_TIME=$(date +%s)
mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" < /var/www/html/data/migrate_to_innodb.sql 2>&1
RC=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "  耗时: ${DURATION}s"
echo ""

# ──── 4. 验证 ────
echo "[4/5] 验证迁移结果..."
INNODB_AFTER=$(mysql_cmd "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA IN ('xyy','xxjyuser') AND ENGINE='InnoDB';")
MYISAM_AFTER=$(mysql_cmd "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA IN ('xyy','xxjyuser') AND ENGINE='MyISAM';")

echo "  InnoDB 表: $INNODB_AFTER"
echo "  MyISAM 表: $MYISAM_AFTER"

check "全部表已切 InnoDB" "$MYISAM_AFTER"

# 验证 AUTO_INCREMENT 完好
echo ""
echo "  AUTO_INCREMENT 抽样检查..."
AI_UID=$(mysql_cmd "SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='xyy' AND TABLE_NAME='o_user_list';")
AI_ZT=$(mysql_cmd "SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='xyy' AND TABLE_NAME='all_zt';")
AI_UG=$(mysql_cmd "SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='xxjyuser' AND TABLE_NAME='o_user_list';")
echo "    xyy.o_user_list      AUTO_INCREMENT = $AI_UID"
echo "    xyy.all_zt           AUTO_INCREMENT = $AI_ZT"
echo "    xxjyuser.o_user_list AUTO_INCREMENT = $AI_UG"

# ──── 5. 应用层冒烟测试 ────
echo ""
echo "[5/5] 应用层冒烟..."
echo "  (通过 HTTP 访问关键页面，验证 PHP+InnoDB 协同正常)"

# 5a. 登录页
HTTP_LOGIN=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/xxjy/index.php" 2>/dev/null || echo "000")
check "登录页 HTTP $HTTP_LOGIN" "$([ "$HTTP_LOGIN" = "200" ] && echo 0 || echo 1)"

# 5b. 注册页
HTTP_REG=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/xxjy/register.php" 2>/dev/null || echo "000")
check "注册页 HTTP $HTTP_REG" "$([ "$HTTP_REG" = "200" ] && echo 0 || echo 1)"

# 5c. 选区页（未登录时 302 重定向也是正常）
HTTP_SEL=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/xxjy/xywap.php" 2>/dev/null || echo "000")
check "选区页 HTTP $HTTP_SEL" "$([ "$HTTP_SEL" = "200" ] || [ "$HTTP_SEL" = "302" ] && echo 0 || echo 1)"

# 5d. 游戏入口（需要 token，只需确认无 DB 错误）
HTTP_GAME=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/fqxy/xyy.php" 2>/dev/null || echo "000")
check "游戏入口 HTTP $HTTP_GAME (预期 302/200)" "$([ "$HTTP_GAME" = "302" ] || [ "$HTTP_GAME" = "200" ] && echo 0 || echo 1)"

# 5e. 检查 PHP 错误日志中无 InnoDB 相关错误
echo ""
echo "  PHP 错误检查 (最近 20 条)..."
if [ -f /var/log/apache2/error.log ]; then
    INNODB_ERR=$(tail -20 /var/log/apache2/error.log 2>/dev/null | grep -ci "InnoDB\|ENGINE\|mysql error" || echo "0")
    # strip trailing newline
    INNODB_ERR=$(echo "$INNODB_ERR" | tr -d '\r')
else
    INNODB_ERR=0
fi
check "无 InnoDB 相关错误" "$([ "$INNODB_ERR" = "0" ] && echo 0 || echo 1)"

# ──── 汇总 ────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  测试结果: ✅ $PASS 通过  ❌ $FAIL 失败          ║"
echo "╚══════════════════════════════════════════╝"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "⚠️  有测试失败！建议执行回滚："
    echo "   docker exec -i xiyou-mysql mysql -uroot -proot < /tmp/innodb_rollback.sql"
    exit 1
else
    echo ""
    echo "🎉 全部通过！InnoDB 迁移成功。"
    echo ""
    echo "如需回滚:"
    echo "   docker exec -i xiyou-mysql mysql -uroot -proot < /tmp/innodb_rollback.sql"
fi

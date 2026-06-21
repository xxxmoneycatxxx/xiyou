#!/bin/bash
set -e

MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-root}"

echo "=== 幻想西游 · Docker 容器初始化 ==="

# 1. 等待 MySQL
echo "[1/3] 等待 MySQL..."
until mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1" &>/dev/null; do
    sleep 2
done
echo "  MySQL 就绪"

# 2. 建库 + 导入 SQL（仅首次）
echo "[2/3] 数据库初始化..."
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS xxjyuser DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS xyy     DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_general_ci;
SQL

# 仅表不存在时才导入
if [ "$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='xxjyuser' AND table_name='gmuser'")" -eq 0 ]; then
    echo "  导入 xxjyuser ..."
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" xxjyuser < /var/www/html/data/xxjyuser.sql
fi

if [ "$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='xyy' AND table_name='all_zt'")" -eq 0 ]; then
    echo "  导入 xyy ..."
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" xyy < /var/www/html/data/xyy.sql
    echo "  添加关键索引..."
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" xyy < /var/www/html/data/add_indexes.sql
fi
echo "  数据库完成"

# 3. 权限
echo "[3/3] 设置目录权限..."
mkdir -p /var/www/html/fqxy/ache
mkdir -p /var/www/html/fqxy/acher
chown -R www-data:www-data /var/www/html/fqxy/ache 2>/dev/null || true
chown -R www-data:www-data /var/www/html/fqxy/acher 2>/dev/null || true

echo "=== 初始化完成，启动 Apache ==="
exec "$@"

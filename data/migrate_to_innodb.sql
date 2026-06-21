-- #5 MyISAM → InnoDB 全量迁移脚本
-- 前置：确保 add_indexes.sql 已执行，auto_increment.sql 已对齐
-- 用法：docker exec -i xiyou-mysql mysql -uroot -proot < data/migrate_to_innodb.sql
-- 回滚：将下方 ENGINE=InnoDB 改为 ENGINE=MyISAM 重新执行即可

-- 显示迁移前状态
SELECT '=== 迁移前引擎分布 ===' AS '';
SELECT TABLE_SCHEMA, ENGINE, COUNT(*) AS cnt
FROM information_schema.TABLES
WHERE TABLE_SCHEMA IN ('xxjyuser', 'xyy')
GROUP BY TABLE_SCHEMA, ENGINE
ORDER BY TABLE_SCHEMA, ENGINE;

-- ═══════════════════════════════════════════
-- xyy 库 (60 张 MyISAM → InnoDB)
-- ═══════════════════════════════════════════
USE xyy;

-- 核心玩家表（高频读写）
ALTER TABLE `all_zt`          ENGINE=InnoDB;   -- 玩家主状态
ALTER TABLE `o_user_list`     ENGINE=InnoDB;   -- 分区用户列表
ALTER TABLE `all_yl`          ENGINE=InnoDB;   -- 背包银两
ALTER TABLE `all_ylck`        ENGINE=InnoDB;   -- 仓库银两
ALTER TABLE `all_money`       ENGINE=InnoDB;   -- 金豆
ALTER TABLE `all_phb`         ENGINE=InnoDB;   -- 排行榜
ALTER TABLE `all_user`        ENGINE=InnoDB;   -- 用户信息
ALTER TABLE `all_ip`          ENGINE=InnoDB;   -- IP 绑定

-- 装备/武器（高频读写）
ALTER TABLE `zb`              ENGINE=InnoDB;   -- 身上装备
ALTER TABLE `wp`              ENGINE=InnoDB;   -- 身上物品
ALTER TABLE `zbb`             ENGINE=InnoDB;   -- 装备宝石
ALTER TABLE `ckwp`            ENGINE=InnoDB;   -- 仓库物品
ALTER TABLE `ckzb`            ENGINE=InnoDB;   -- 仓库装备
ALTER TABLE `gswp`            ENGINE=InnoDB;   -- 交易所物品
ALTER TABLE `gszb`            ENGINE=InnoDB;   -- 交易所装备
ALTER TABLE `gsqt`            ENGINE=InnoDB;   -- 交易所其他

-- 宠物
ALTER TABLE `cw`              ENGINE=InnoDB;   -- 宠物
ALTER TABLE `cwzbb`           ENGINE=InnoDB;   -- 宠物装备

-- 技能/修炼/社交
ALTER TABLE `jnn`             ENGINE=InnoDB;   -- 技能
ALTER TABLE `xl`              ENGINE=InnoDB;   -- 修炼
ALTER TABLE `hy`              ENGINE=InnoDB;   -- 好友
ALTER TABLE `sw`              ENGINE=InnoDB;   -- 声望

-- 拍卖/交易
ALTER TABLE `all_pm`          ENGINE=InnoDB;   -- 拍卖行
ALTER TABLE `all_pay`         ENGINE=InnoDB;   -- 充值订单

-- 副本/任务/活动
ALTER TABLE `fb`              ENGINE=InnoDB;   -- 副本
ALTER TABLE `hd`              ENGINE=InnoDB;   -- 活动
ALTER TABLE `yxrw`            ENGINE=InnoDB;   -- 任务
ALTER TABLE `all_qd`          ENGINE=InnoDB;   -- 签到
ALTER TABLE `all_qggz`        ENGINE=InnoDB;   -- 抢购规则
ALTER TABLE `all_boss`        ENGINE=InnoDB;   -- Boss

-- 住宅/国家
ALTER TABLE `all_houres`      ENGINE=InnoDB;   -- 住宅
ALTER TABLE `all_gzhoures`    ENGINE=InnoDB;   -- 官宅
ALTER TABLE `all_bp`          ENGINE=InnoDB;   -- 帮派（xxsql 注：已有 bp 表是 InnoDB）

-- VIP/称号/时装/星盘
ALTER TABLE `tx`              ENGINE=InnoDB;   -- 头衔
ALTER TABLE `xp`              ENGINE=InnoDB;   -- 星盘
ALTER TABLE `zgvip`           ENGINE=InnoDB;   -- VIP
ALTER TABLE `jfdj`            ENGINE=InnoDB;   -- 积分等级
ALTER TABLE `jj`              ENGINE=InnoDB;   -- 家具
ALTER TABLE `dyxx`            ENGINE=InnoDB;   -- 丹药信息
ALTER TABLE `wpp`             ENGINE=InnoDB;   -- 物品皮肤
ALTER TABLE `zf`              ENGINE=InnoDB;   -- 阵法

-- 运营活动表
ALTER TABLE `all_cz`          ENGINE=InnoDB;   -- 充值记录
ALTER TABLE `all_hbmoney`     ENGINE=InnoDB;   -- 红包金额
ALTER TABLE `all_hbmoneyjc`   ENGINE=InnoDB;   -- 红包奖池
ALTER TABLE `all_moneyjc`     ENGINE=InnoDB;   -- 金豆奖池
ALTER TABLE `all_sdk`         ENGINE=InnoDB;   -- 兑换码
ALTER TABLE `all_xjhb`        ENGINE=InnoDB;   -- 现金红包
ALTER TABLE `all_jc`          ENGINE=InnoDB;   -- 竞技场

-- 活动排行/记录
ALTER TABLE `all_hdph01`      ENGINE=InnoDB;
ALTER TABLE `all_hdph02`      ENGINE=InnoDB;
ALTER TABLE `all_hdph03`      ENGINE=InnoDB;
ALTER TABLE `all_yd01`        ENGINE=InnoDB;
ALTER TABLE `all_yd02`        ENGINE=InnoDB;
ALTER TABLE `all_yd03`        ENGINE=InnoDB;
ALTER TABLE `all_yd04`        ENGINE=InnoDB;

-- 怪物/宠物（gz06 已是 InnoDB）
ALTER TABLE `gz01`            ENGINE=InnoDB;
ALTER TABLE `gz03`            ENGINE=InnoDB;
ALTER TABLE `gz04`            ENGINE=InnoDB;
ALTER TABLE `gz05`            ENGINE=InnoDB;

-- 其他业务表（低风险）
ALTER TABLE `xtbl`            ENGINE=InnoDB;   -- 系统表

-- ═══════════════════════════════════════════
-- xxjyuser 库 (3 张 MyISAM → InnoDB)
-- ═══════════════════════════════════════════
ALTER TABLE `xxjyuser`.`gmuser`       ENGINE=InnoDB;
ALTER TABLE `xxjyuser`.`o_user_list`  ENGINE=InnoDB;
ALTER TABLE `xxjyuser`.`zem`          ENGINE=InnoDB;

-- 显示迁移后状态
SELECT '' AS '';
SELECT '=== 迁移后引擎分布 ===' AS '';
SELECT TABLE_SCHEMA, ENGINE, COUNT(*) AS cnt
FROM information_schema.TABLES
WHERE TABLE_SCHEMA IN ('xxjyuser', 'xyy')
GROUP BY TABLE_SCHEMA, ENGINE
ORDER BY TABLE_SCHEMA, ENGINE;

SELECT '' AS '';
SELECT '=== 迁移完成！如仍有 MyISAM 表，请检查上方输出 ===' AS '';

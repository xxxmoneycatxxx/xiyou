-- ============================================
-- 西游游戏 数据库索引优化脚本
-- 全部 ADD INDEX，不改代码，不丢数据
-- 建议低峰期执行，MyISAM 大表加索引会锁表（秒级）
-- ============================================
-- 数据库: xyy
-- 执行: mysql -u root -p xyy < data/add_indexes.sql
-- ============================================

-- ========================
-- 玩家主状态（最高频查询）
-- ========================
ALTER TABLE `all_zt` ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_zt` ADD INDEX `idx_dj` (`dj`);

-- ========================
-- 装备 / 物品 / 宠物（高频查询）
-- ========================
ALTER TABLE `zb`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `wp`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `cw`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `zbb`    ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `cwzbb`  ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 仓库
-- ========================
ALTER TABLE `ckwp`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `ckzb`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `ckqt`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `qt`       ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `zzck`     ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 挂售（交易所）
-- ========================
ALTER TABLE `gswp`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `gszb`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `gsqt`     ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 技能 / 好友 / 修炼
-- ========================
ALTER TABLE `jnn`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `hy`      ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `xl`      ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 活动 / 副本
-- ========================
ALTER TABLE `hd`      ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `fb`      ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 称号 / 头衔 / 声望 / 星盘
-- ========================
ALTER TABLE `tx`      ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `sw`      ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `xp`      ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 家具 / 解封 / 尊贵VIP / 丹药
-- ========================
ALTER TABLE `jj`      ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `jfdj`    ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `zgvip`   ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `dyxx`    ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `wpp`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `zf`      ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 玩家数据（银两/金豆/红包）
-- ========================
ALTER TABLE `all_yl`       ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_ylck`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_money`    ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_hbmoney`  ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 拍卖行（wjid + 分类过滤）
-- ========================
ALTER TABLE `all_pm`       ADD INDEX `idx_wjid`   (`wjid`);
ALTER TABLE `all_pm`       ADD INDEX `idx_pmwpfl` (`pmwpfl`);

-- ========================
-- 排行榜 / 帮派 / 用户 / 住宅
-- ========================
ALTER TABLE `all_phb`      ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_user`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_houres`   ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_gzhoures` ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 帮派成员
-- ========================
ALTER TABLE `bp`           ADD INDEX `idx_userid` (`userid`);

-- ========================
-- 任务 / 签到 / 限购公告
-- ========================
ALTER TABLE `yxrw`    ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_qd`  ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_qggz` ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_xjhb` ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 活动记录（运营活动 01~04）
-- ========================
ALTER TABLE `all_yd01`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_yd02`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_yd03`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_yd04`     ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 活动排行榜 01~03
-- ========================
ALTER TABLE `all_hdph01`   ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_hdph02`   ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_hdph03`   ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 擂台 / 竞猜（InnoDB 表也加）
-- ========================
ALTER TABLE `all_ltbw`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_jdjc`     ADD INDEX `idx_wjid` (`wjid`);
ALTER TABLE `all_qtjc`     ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 在线状态（user 表高频读写）
-- ========================
ALTER TABLE `user`         ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 战场（gz04 玩家级记录）
-- ========================
ALTER TABLE `gz04`         ADD INDEX `idx_wjid` (`wjid`);

-- ========================
-- 共计 47 条 ADD INDEX，覆盖 47 张表
-- ========================
-- zz 表已有 idx_wjid，跳过
-- all_zt 额外加了 dj (等级排行)
-- all_pm 额外加了 pmwpfl (拍卖分类)
-- ========================

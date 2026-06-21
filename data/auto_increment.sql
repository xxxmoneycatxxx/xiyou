-- ============================================
-- 西游游戏 AUTO_INCREMENT 计数器重置脚本
-- 确保自增值 >= MAX(id)+1，消除主键冲突风险
-- 对应 #4.5 MAX(id)+1 → AUTO_INCREMENT 优化
-- 执行: mysql -u root -p < data/auto_increment.sql
-- ============================================

-- xxjyuser 数据库
ALTER TABLE `xxjyuser`.`o_user_list` AUTO_INCREMENT = (SELECT COALESCE(MAX(uid)+1, 1) FROM (SELECT MAX(uid) AS uid FROM `xxjyuser`.`o_user_list`) AS t);
ALTER TABLE `xxjyuser`.`gmuser` AUTO_INCREMENT = (SELECT COALESCE(MAX(uid)+1, 1) FROM (SELECT MAX(uid) AS uid FROM `xxjyuser`.`gmuser`) AS t);

-- xyy 数据库
ALTER TABLE `xyy`.`o_user_list` AUTO_INCREMENT = (SELECT COALESCE(MAX(uid)+1, 1) FROM (SELECT MAX(uid) AS uid FROM `xyy`.`o_user_list`) AS t);
ALTER TABLE `xyy`.`all_bp` AUTO_INCREMENT = (SELECT COALESCE(MAX(bpid)+1, 1) FROM (SELECT MAX(bpid) AS bpid FROM `xyy`.`all_bp`) AS t);
ALTER TABLE `xyy`.`all_houres` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_houres`) AS t);
ALTER TABLE `xyy`.`all_gzhoures` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_gzhoures`) AS t);
ALTER TABLE `xyy`.`all_user` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_user`) AS t);
ALTER TABLE `xyy`.`all_sdk` AUTO_INCREMENT = (SELECT COALESCE(MAX(sdkid)+1, 1) FROM (SELECT MAX(sdkid) AS sdkid FROM `xyy`.`all_sdk`) AS t);
ALTER TABLE `xyy`.`all_qggz` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_qggz`) AS t);
ALTER TABLE `xyy`.`all_pay` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_pay`) AS t);
ALTER TABLE `xyy`.`all_hdph01` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_hdph01`) AS t);
ALTER TABLE `xyy`.`all_hdph02` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_hdph02`) AS t);
ALTER TABLE `xyy`.`all_hdph03` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_hdph03`) AS t);
ALTER TABLE `xyy`.`all_yd01` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_yd01`) AS t);
ALTER TABLE `xyy`.`all_yd02` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_yd02`) AS t);
ALTER TABLE `xyy`.`all_yd03` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_yd03`) AS t);
ALTER TABLE `xyy`.`all_yd04` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_yd04`) AS t);
ALTER TABLE `xyy`.`all_xjhb` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_xjhb`) AS t);
ALTER TABLE `xyy`.`all_moneyjc` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_moneyjc`) AS t);
ALTER TABLE `xyy`.`all_hbmoneyjc` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_hbmoneyjc`) AS t);
ALTER TABLE `xyy`.`all_cz` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_cz`) AS t);
ALTER TABLE `xyy`.`all_qd` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_qd`) AS t);
ALTER TABLE `xyy`.`all_jc` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_jc`) AS t);
ALTER TABLE `xyy`.`all_jdjc` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_jdjc`) AS t);
ALTER TABLE `xyy`.`all_ltbw` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_ltbw`) AS t);
ALTER TABLE `xyy`.`all_pm` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_pm`) AS t);
ALTER TABLE `xyy`.`all_qtjc` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`all_qtjc`) AS t);
ALTER TABLE `xyy`.`bl` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`bl`) AS t);
ALTER TABLE `xyy`.`gz04` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`gz04`) AS t);
ALTER TABLE `xyy`.`gz06` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`gz06`) AS t);
ALTER TABLE `xyy`.`hddl` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`hddl`) AS t);
ALTER TABLE `xyy`.`map` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`map`) AS t);
ALTER TABLE `xyy`.`user` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`user`) AS t);
ALTER TABLE `xyy`.`wpxx` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`wpxx`) AS t);
ALTER TABLE `xyy`.`zz` AUTO_INCREMENT = (SELECT COALESCE(MAX(id)+1, 1) FROM (SELECT MAX(id) AS id FROM `xyy`.`zz`) AS t);

-- ============================================
-- 共计 33 条 ALTER，确保所有自增计数器正确
-- ============================================

-- ============================================
-- 西游游戏 AUTO_INCREMENT 计数器重置脚本
-- 确保自增值 >= MAX(id)+1，消除主键冲突风险
-- 对应 #4.5 MAX(id)+1 → AUTO_INCREMENT 优化
-- 执行: mysql -u root -p < data/auto_increment.sql
-- ============================================

-- xxjyuser 数据库
SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xxjyuser`.`o_user_list` AUTO_INCREMENT = ', COALESCE(MAX(uid)+1, 1)) INTO @sql FROM `xxjyuser`.`o_user_list`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xxjyuser`.`gmuser` AUTO_INCREMENT = ', COALESCE(MAX(uid)+1, 1)) INTO @sql FROM `xxjyuser`.`gmuser`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- xyy 数据库
SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`o_user_list` AUTO_INCREMENT = ', COALESCE(MAX(uid)+1, 1)) INTO @sql FROM `xyy`.`o_user_list`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_bp` AUTO_INCREMENT = ', COALESCE(MAX(bpid)+1, 1)) INTO @sql FROM `xyy`.`all_bp`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_houres` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_houres`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_gzhoures` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_gzhoures`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_user` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_user`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_sdk` AUTO_INCREMENT = ', COALESCE(MAX(sdkid)+1, 1)) INTO @sql FROM `xyy`.`all_sdk`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_qggz` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_qggz`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_pay` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_pay`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_hdph01` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_hdph01`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_hdph02` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_hdph02`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_hdph03` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_hdph03`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_yd01` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_yd01`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_yd02` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_yd02`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_yd03` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_yd03`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_yd04` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_yd04`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_xjhb` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_xjhb`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_moneyjc` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_moneyjc`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_hbmoneyjc` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_hbmoneyjc`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_cz` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_cz`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_qd` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_qd`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_jc` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_jc`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_jdjc` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_jdjc`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_ltbw` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_ltbw`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_pm` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_pm`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`all_qtjc` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`all_qtjc`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`bl` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`bl`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`gz04` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`gz04`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`gz06` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`gz06`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`hddl` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`hddl`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`map` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`map`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`user` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`user`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`wpxx` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`wpxx`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = NULL;
SELECT CONCAT('ALTER TABLE `xyy`.`zz` AUTO_INCREMENT = ', COALESCE(MAX(id)+1, 1)) INTO @sql FROM `xyy`.`zz`;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================
-- 共计 33 条，确保所有自增计数器正确
-- ============================================

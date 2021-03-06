-- MySQL dump 10.13  Distrib 5.6.34, for Linux (x86_64)
--
-- Host: rr-2zeap9jp480wx4j12.mysql.rds.aliyuncs.com    Database: jiudouyu_module_db
-- ------------------------------------------------------
-- Server version   5.6.29

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

DROP TABLE IF EXISTS `module_picture`;

CREATE TABLE `module_picture` (
      `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '图片管理',
      `path` char(255) COLLATE utf8_unicode_ci NOT NULL COMMENT '图片存储路径',
      `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

LOCK TABLES `module_picture` WRITE;
/*!40000 ALTER TABLE `module_picture` DISABLE KEYS */;

INSERT INTO `module_picture` (`id`, `path`, `created_at`, `updated_at`)
VALUES
    (1,'image/20161230/1481528031Yqf68qwLqp.jpeg','2016-09-21 23:23:00','2016-09-21 23:23:00'),
    (2,'image/20161230/148240326699518o5qA1.png','2016-09-21 23:23:00','2016-09-21 23:23:00'),
    (3,'image/20161230/1483099768UlSpqL3nw2.png','2016-09-21 23:23:00','2016-09-21 23:23:00');

/*!40000 ALTER TABLE `module_picture` ENABLE KEYS */;
UNLOCK TABLES;



/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

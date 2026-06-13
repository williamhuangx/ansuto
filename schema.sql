-- ============================================================
-- 安速通物流 官网后台数据库表结构
-- 执行顺序:直接复制到MySQL客户端执行即可
-- 编码: utf8 / utf8_general_ci
-- 统一字段规范: id / 标题 / 添加时间 / 内容 (+分类/排序/状态)
-- ============================================================

SET NAMES utf8;
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
-- 表 0 : 管理员账号表 (admins)
-- 说明:用于后台登录,默认账号 admin / admin123
-- ------------------------------------------------------------
DROP TABLE IF EXISTS `admins`;
CREATE TABLE `admins` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `username`    VARCHAR(50)   NOT NULL                  COMMENT '登录账号',
    `password`    VARCHAR(255)  NOT NULL                  COMMENT '登录密码(加密)',
    `real_name`   VARCHAR(50)   DEFAULT NULL              COMMENT '真实姓名',
    `role`        VARCHAR(20)   DEFAULT 'editor'          COMMENT '角色: super / editor',
    `status`      TINYINT(1)    DEFAULT 1                 COMMENT '状态: 1启用 0禁用',
    `last_login`  DATETIME      DEFAULT NULL              COMMENT '最后登录时间',
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='管理员账号表';

-- 默认管理员(首次启动后请立即修改密码)
INSERT INTO `admins` (`username`, `password`, `real_name`, `role`) VALUES
('admin', 'pbkdf2:sha256:600000$placeholder$placeholder', '超级管理员', 'super');

-- ============================================================
-- 表 1 : 业务介绍 (business_intros)
-- 含: 主营产品 / 增值服务 / 市场活动
-- category = main | value_added | marketing
-- ============================================================
DROP TABLE IF EXISTS `business_intros`;
CREATE TABLE `business_intros` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `category`    VARCHAR(30)   NOT NULL                  COMMENT '分类:main/value_added/marketing',
    `title`       VARCHAR(200)  NOT NULL                  COMMENT '标题',
    `content`     TEXT          NOT NULL                  COMMENT '详细内容',
    `sort_order`  INT(11)       DEFAULT 0                 COMMENT '排序(小在前)',
    `status`      TINYINT(1)    DEFAULT 1                 COMMENT '状态:1启用 0禁用',
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP COMMENT '添加时间',
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='业务介绍表';

-- ============================================================
-- 表 2 : 网上营业厅 (online_halls)
-- 含: 价格与时效 / 微信服务 / 禁运品
-- category = price | wechat | forbidden
-- ============================================================
DROP TABLE IF EXISTS `online_halls`;
CREATE TABLE `online_halls` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `category`    VARCHAR(30)   NOT NULL                  COMMENT '分类:price/wechat/forbidden',
    `title`       VARCHAR(200)  NOT NULL                  COMMENT '标题',
    `content`     TEXT          NOT NULL                  COMMENT '详细内容',
    `sort_order`  INT(11)       DEFAULT 0,
    `status`      TINYINT(1)    DEFAULT 1,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP COMMENT '添加时间',
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='网上营业厅表';

-- ============================================================
-- 表 3 : 货物追踪 (trackings) + 节点明细 (tracking_details)
-- 客户通过运单号查询;后台可录入追踪节点
-- ============================================================
DROP TABLE IF EXISTS `trackings`;
CREATE TABLE `trackings` (
    `id`            INT(11)       NOT NULL AUTO_INCREMENT,
    `tracking_no`   VARCHAR(50)   NOT NULL                  COMMENT '快递单号',
    `shipping_time` DATETIME      DEFAULT NULL              COMMENT '托运时间',
    `origin`        VARCHAR(100)  DEFAULT NULL              COMMENT '始发地',
    `destination`   VARCHAR(100)  DEFAULT NULL              COMMENT '目的地',
    `sender_company` VARCHAR(150) DEFAULT NULL              COMMENT '寄件公司',
    `sender`        VARCHAR(100)  DEFAULT NULL              COMMENT '发件人',
    `sender_phone`  VARCHAR(30)   DEFAULT NULL              COMMENT '发件人电话',
    `receiver_company` VARCHAR(150) DEFAULT NULL            COMMENT '收件公司',
    `receiver`      VARCHAR(100)  DEFAULT NULL              COMMENT '收件人',
    `receiver_phone` VARCHAR(30)  DEFAULT NULL              COMMENT '收件人电话',
    `transport_type` VARCHAR(50)  DEFAULT NULL              COMMENT '运输类型',
    `goods_name`    VARCHAR(200)  DEFAULT NULL              COMMENT '品名',
    `weight`        DECIMAL(10,2) DEFAULT 0                 COMMENT '重量(kg)',
    `volume`        DECIMAL(10,2) DEFAULT 0                 COMMENT '体积(m3)',
    `pieces`        INT(11)       DEFAULT 0                 COMMENT '件数',
    `package`       VARCHAR(100)  DEFAULT NULL              COMMENT '包装',
    `delivery_method` VARCHAR(50) DEFAULT NULL              COMMENT '送货方式',
    `need_receipt`  VARCHAR(10)   DEFAULT '否'             COMMENT '签回单(是/否)',
    `receipt_remark` VARCHAR(200) DEFAULT NULL              COMMENT '回单备注',
    `receipt_status` VARCHAR(50)  DEFAULT NULL              COMMENT '回单情况',
    `remark`        TEXT          DEFAULT NULL              COMMENT '备注',
    `charge_weight` DECIMAL(10,2) DEFAULT 0                 COMMENT '计费重量(kg)',
    `package_fee`   DECIMAL(10,2) DEFAULT 0                 COMMENT '包装费',
    `pickup_request` VARCHAR(200) DEFAULT NULL              COMMENT '提货要求',
    `unload_fee`    DECIMAL(10,2) DEFAULT 0                 COMMENT '卸货费',
    `other_fee`     DECIMAL(10,2) DEFAULT 0                 COMMENT '其它费用',
    `insurance`     DECIMAL(10,2) DEFAULT 0                 COMMENT '保险费',
    `freight`       DECIMAL(10,2) DEFAULT 0                 COMMENT '运费',
    `cod_amount`    DECIMAL(10,2) DEFAULT 0                 COMMENT '到付金额',
    `payment_method` VARCHAR(30)  DEFAULT NULL              COMMENT '付款方式',
    `status`        VARCHAR(30)   DEFAULT 'transit'         COMMENT '目前状态: pending/transit/delivered/lost',
    `created_at`    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_tracking_no` (`tracking_no`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='货物追踪表';

DROP TABLE IF EXISTS `tracking_details`;
CREATE TABLE `tracking_details` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `tracking_id` INT(11)       NOT NULL                  COMMENT '主表ID',
    `tracking_no` VARCHAR(50)   NOT NULL                  COMMENT '运单号(冗余便于查询)',
    `node_time`   DATETIME      NOT NULL                  COMMENT '节点时间',
    `location`    VARCHAR(200)  NOT NULL                  COMMENT '所在地点/网点',
    `status_text` VARCHAR(200)  NOT NULL                  COMMENT '状态描述',
    `operator`    VARCHAR(100)  DEFAULT NULL              COMMENT '操作人员',
    `sort_order`  INT(11)       DEFAULT 0,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_tracking_id` (`tracking_id`),
    KEY `idx_tracking_no` (`tracking_no`),
    KEY `idx_node_time` (`node_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='货物追踪明细表';

-- 测试数据: 安速通标准运单
INSERT INTO `trackings` (
    `tracking_no`, `shipping_time`, `origin`, `destination`,
    `sender_company`, `sender`, `sender_phone`,
    `receiver_company`, `receiver`, `receiver_phone`,
    `transport_type`, `goods_name`, `weight`, `volume`, `pieces`, `package`,
    `delivery_method`, `need_receipt`, `receipt_remark`, `receipt_status`,
    `remark`, `charge_weight`, `package_fee`, `pickup_request`,
    `unload_fee`, `other_fee`, `insurance`, `freight`, `cod_amount`,
    `payment_method`, `status`
) VALUES (
    'AST20240615001', '2024-06-15 09:30:00', '浙江 杭州 西湖区', '美国 纽约 New York',
    '杭州安速通电子科技有限公司', '张建国', '13800138000',
    'USA Electronics Trading Co., Ltd.', 'John Smith', '+1-555-010-0200',
    '空运', '智能手机 / 电子配件 / 充电设备', 15.50, 0.12, 5, '纸箱+气泡膜',
    '送货上门', '是', '收件方签字回传', '待签',
    '易碎品, 请轻拿轻放; 外包装完好后签收',
    18.00, 50.00, '请提前1小时电话通知', 30.00, 20.00, 100.00, 1580.00, 0.00,
    '月结', 'transit'
);

-- 测试数据: 物流节点(与上面运单关联, id=1 时)
-- 使用 LAST_INSERT_ID 确保与上一条主单关联
SET @last_tid = LAST_INSERT_ID();
INSERT INTO `tracking_details` (`tracking_id`, `tracking_no`, `node_time`, `location`, `status_text`, `operator`, `sort_order`) VALUES
(@last_tid, 'AST20240615001', '2024-06-15 09:30:00', '杭州西湖区揽收点', '【揽收】快递员已揽收,货物已入库', '李快递', 1),
(@last_tid, 'AST20240615001', '2024-06-15 14:20:00', '杭州萧山转运中心', '【运输中】货物已到达杭州转运中心,正在分拣', '转运员', 2),
(@last_tid, 'AST20240615001', '2024-06-15 22:10:00', '上海浦东国际机场', '【报关】国际货物已到达上海浦东机场,等待清关', '报关员', 3),
(@last_tid, 'AST20240615001', '2024-06-16 08:45:00', '上海浦东国际机场', '【已起飞】航班 JL087 已起飞,预计当地时间 6月16日 下午到达纽约', '国际部', 4);

-- ============================================================
-- 表 4 : 帮助与支持 (helps)
-- 含: 基本常识 / 下载中心
-- category = knowledge | download
-- ============================================================
DROP TABLE IF EXISTS `helps`;
CREATE TABLE `helps` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `category`    VARCHAR(30)   NOT NULL                  COMMENT '分类:knowledge/download',
    `title`       VARCHAR(200)  NOT NULL                  COMMENT '标题',
    `content`     TEXT          NOT NULL                  COMMENT '详细内容',
    `sort_order`  INT(11)       DEFAULT 0,
    `status`      TINYINT(1)    DEFAULT 1,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP COMMENT '添加时间',
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='帮助与支持表';

-- ============================================================
-- 表 5 : 公司新闻 (news)
-- 含: 新闻中心 / 行业资讯
-- category = company | industry
-- ============================================================
DROP TABLE IF EXISTS `news`;
CREATE TABLE `news` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `category`    VARCHAR(30)   NOT NULL                  COMMENT '分类:company/industry',
    `title`       VARCHAR(200)  NOT NULL                  COMMENT '标题',
    `content`     TEXT          NOT NULL                  COMMENT '详细内容',
    `sort_order`  INT(11)       DEFAULT 0,
    `status`      TINYINT(1)    DEFAULT 1,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP COMMENT '添加时间',
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='公司新闻表';

-- ============================================================
-- 表 6 : 网点分布 (branches) - 独立复杂业务表,保留完整字段
-- ============================================================
DROP TABLE IF EXISTS `branches`;
CREATE TABLE `branches` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `branch_name` VARCHAR(200)  NOT NULL                  COMMENT '网点名称',
    `province`    VARCHAR(50)   DEFAULT NULL              COMMENT '省份',
    `city`        VARCHAR(50)   DEFAULT NULL              COMMENT '城市',
    `district`    VARCHAR(50)   DEFAULT NULL              COMMENT '区/县',
    `address`     VARCHAR(500)  NOT NULL                  COMMENT '详细地址',
    `phone`       VARCHAR(100)  DEFAULT NULL              COMMENT '联系电话',
    `mobile`      VARCHAR(30)   DEFAULT NULL              COMMENT '手机',
    `manager`     VARCHAR(50)   DEFAULT NULL              COMMENT '负责人',
    `business_scope` VARCHAR(300) DEFAULT NULL            COMMENT '业务范围',
    `work_time`   VARCHAR(200)  DEFAULT NULL              COMMENT '工作时间',
    `longitude`   DECIMAL(12,8) DEFAULT NULL              COMMENT '经度',
    `latitude`    DECIMAL(12,8) DEFAULT NULL              COMMENT '纬度',
    `description` TEXT          COMMENT '网点描述',
    `sort_order`  INT(11)       DEFAULT 0,
    `status`      TINYINT(1)    DEFAULT 1,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_province` (`province`),
    KEY `idx_city` (`city`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='网点分布表';

-- ============================================================
-- 表 7 : 关于安速通 (abouts)
-- 含: 公司简介 / 发展历程 / 人才招聘 / 走进安速通 / 公司公告 / 组织架构 / 企业文化
-- category = profile / history / recruit / video / notice / structure / culture
-- ============================================================
DROP TABLE IF EXISTS `abouts`;
CREATE TABLE `abouts` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `category`    VARCHAR(30)   NOT NULL                  COMMENT '分类:profile/history/recruit/video/notice/structure/culture',
    `title`       VARCHAR(200)  NOT NULL                  COMMENT '标题',
    `content`     TEXT          NOT NULL                  COMMENT '详细内容',
    `sort_order`  INT(11)       DEFAULT 0,
    `status`      TINYINT(1)    DEFAULT 1,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP COMMENT '添加时间',
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='关于安速通表';

-- ============================================================
-- 表 8 : 联系我们 (contacts) - 独立业务表,保留完整字段
-- ============================================================
DROP TABLE IF EXISTS `contacts`;
CREATE TABLE `contacts` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `type`        VARCHAR(30)   DEFAULT 'inquiry'         COMMENT '类型: company(公司信息) / inquiry(客户咨询)',
    `name`        VARCHAR(100)  DEFAULT NULL              COMMENT '姓名/联系人',
    `company`     VARCHAR(200)  DEFAULT NULL              COMMENT '公司名',
    `phone`       VARCHAR(30)   DEFAULT NULL              COMMENT '电话',
    `email`       VARCHAR(100)  DEFAULT NULL              COMMENT '邮箱',
    `subject`     VARCHAR(200)  DEFAULT NULL              COMMENT '主题',
    `message`     TEXT          COMMENT '留言内容',
    `address`     VARCHAR(500)  DEFAULT NULL              COMMENT '公司地址',
    `service_hotline` VARCHAR(100) DEFAULT NULL           COMMENT '服务热线',
    `business_phone` VARCHAR(100) DEFAULT NULL            COMMENT '业务电话',
    `fax`         VARCHAR(50)   DEFAULT NULL              COMMENT '传真',
    `qq`          VARCHAR(50)   DEFAULT NULL              COMMENT 'QQ',
    `wechat`      VARCHAR(100)  DEFAULT NULL              COMMENT '微信号',
    `work_time`   VARCHAR(200)  DEFAULT NULL              COMMENT '工作时间',
    `longitude`   DECIMAL(12,8) DEFAULT NULL,
    `latitude`    DECIMAL(12,8) DEFAULT NULL,
    `is_read`     TINYINT(1)    DEFAULT 0                 COMMENT '是否已读(咨询类)',
    `is_replied`  TINYINT(1)    DEFAULT 0                 COMMENT '是否已回复',
    `reply_note`  TEXT          COMMENT '回复备注',
    `sort_order`  INT(11)       DEFAULT 0,
    `status`      TINYINT(1)    DEFAULT 1,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_type` (`type`),
    KEY `idx_is_read` (`is_read`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='联系我们表';

-- ============================================================
-- 表 9 : Banner / 首页轮播图 (banners) - 独立业务表,保留完整字段
-- ============================================================
DROP TABLE IF EXISTS `banners`;
CREATE TABLE `banners` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `title`       VARCHAR(200)  DEFAULT NULL              COMMENT '标题',
    `subtitle`    VARCHAR(300)  DEFAULT NULL              COMMENT '副标题',
    `image_url`   VARCHAR(500)  NOT NULL                  COMMENT '图片地址',
    `link_url`    VARCHAR(500)  DEFAULT NULL              COMMENT '跳转链接',
    `position`    VARCHAR(30)   DEFAULT 'home'            COMMENT '位置: home / about / ...',
    `sort_order`  INT(11)       DEFAULT 0,
    `status`      TINYINT(1)    DEFAULT 1,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_position` (`position`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Banner轮播图表';

-- ============================================================
-- 表 10 : 站点配置 / SEO信息 (site_configs)
-- ============================================================
DROP TABLE IF EXISTS `site_configs`;
CREATE TABLE `site_configs` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `config_key`  VARCHAR(100)  NOT NULL                  COMMENT '配置键名',
    `config_value` TEXT         COMMENT '配置值',
    `description` VARCHAR(300)  DEFAULT NULL              COMMENT '说明',
    `updated_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='站点配置表';

-- 默认站点配置
INSERT INTO `site_configs` (`config_key`, `config_value`, `description`) VALUES
('site_name', '安速通物流', '网站名称'),
('site_title', '安速通物流 - 专业的国际国内物流服务提供商', 'SEO标题'),
('site_keywords', '安速通,物流,快递,国际物流,货运,运输,供应链', 'SEO关键词'),
('site_description', '安速通物流专注于国际国内物流运输服务,为客户提供高效、安全、专业的物流解决方案。', 'SEO描述'),
('site_copyright', '© 2024 安速通物流 版权所有', '版权信息'),
('service_hotline', '400-888-8888', '服务热线'),
('company_address', '浙江省杭州市西湖区某某路88号', '公司地址');

-- ============================================================
-- 表 11 : 系统操作日志 (logs)
-- ============================================================
DROP TABLE IF EXISTS `logs`;
CREATE TABLE `logs` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `admin_id`    INT(11)       DEFAULT NULL              COMMENT '管理员ID',
    `username`    VARCHAR(50)   DEFAULT NULL              COMMENT '账号',
    `action`      VARCHAR(100)  DEFAULT NULL              COMMENT '操作动作',
    `module`      VARCHAR(50)   DEFAULT NULL              COMMENT '所属模块',
    `target_id`   INT(11)       DEFAULT NULL              COMMENT '目标ID',
    `ip`          VARCHAR(50)   DEFAULT NULL              COMMENT 'IP地址',
    `user_agent`  VARCHAR(500)  DEFAULT NULL,
    `created_at`  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_admin_id` (`admin_id`),
    KEY `idx_module` (`module`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='系统操作日志表';

-- ============================================================
-- 默认测试数据 (首次执行插入,正式环境可删除)
-- ============================================================

-- 表1 业务介绍
INSERT INTO `business_intros` (`category`, `title`, `content`, `sort_order`, `status`) VALUES
('main', '国际空运专线', '覆盖全球180+国家和地区的国际空运专线服务,7天内送达全球主要城市,支持上门取件,保价运输,安全可靠,为您的业务提供快速、稳定的国际物流解决方案。', 1, 1),
('main', '国际海运整柜', '提供FCL整柜与LCL拼箱服务,全球200+港口直达,整柜价格透明,舱位充足,专业清关团队支持,为您制定最优海运方案,节省成本。', 2, 1),
('main', '国际快递小包', '中邮小包、香港小包、新加坡小包多渠道选择,时效稳定,价格实惠,全程可追踪,适合2kg以下轻小件物品的跨境发货。', 3, 1),
('main', '国内零担物流', '覆盖全国34个省市区的零担运输服务,网络齐全,门到门、站到站、站到门多种服务模式,价格公道,时效可承诺。', 4, 1),
('main', '整车运输服务', '专业整车调度,覆盖全国的3.5-17.5米各类车型资源,冷链车、高栏车、平板车、飞翼车按需匹配,全程GPS追踪,专业司机团队。', 5, 1),
('value_added', '保价运输服务', '按货值0.2%-0.5%收取保价费用,低至1元起保,破损丢失100%赔付,3-7个工作日内完成理赔流程,让您发件更安心。', 1, 1),
('value_added', '代收货款服务', '支持现金代收、扫码代收,次日到账,手续费低至0.3%,提供专业代收对账服务,适合中小电商批量发货。', 2, 1),
('value_added', '仓储配送一体化', '全国5大仓储中心,总面积超过10万平米,支持SKU管理、分拣打包、一件代发、退换货处理,系统对接主流电商平台。', 3, 1),
('value_added', '清关服务', '专业报关团队,平均清关时间1-2个工作日,支持一般贸易、跨境电商9610/9710/9810模式,提供关税咨询与方案优化。', 4, 1),
('marketing', '双11特惠活动', '双11期间所有线路8.5折,新注册客户首单立减100元,大客户享VIP专属折扣,活动时间11月1日-11月15日,详询400热线。', 1, 1),
('marketing', '618年中大促', '年中大促期间空运专线9折,免费升级包装服务,发货满5000元赠送500元代金券,活动时间6月1日-6月20日。', 2, 1),
('marketing', '新客户专享礼包', '首次合作客户赠送:免费纸箱包装服务、首单8折优惠、价值200元VIP会员、专属客服对接、物流方案咨询服务。', 3, 1);

-- 表2 网上营业厅
INSERT INTO `online_halls` (`category`, `title`, `content`, `sort_order`, `status`) VALUES
('price', '国内时效报价表', '国内标准快递: 首重12元/公斤,续重3元/公斤,2-3天送达。\n\n国内次晨达: 首重18元/公斤,续重4元/公斤,次日12点前送达。\n\n国内当日达: 首重35元/公斤,续重8元/公斤,当日22点前送达(仅限开通城市)。\n\n大宗货物优惠: 20公斤以上享折扣,50公斤以上专享大客户价。', 1, 1),
('price', '国际空运报价表', '欧美线路: 首重80元/0.5kg,续重35元/0.5kg,5-7天送达。\n\n东南亚线路: 首重65元/0.5kg,续重28元/0.5kg,3-5天送达。\n\n日韩线路: 首重70元/0.5kg,续重30元/0.5kg,4-6天送达。\n\n澳洲新西兰: 首重90元/0.5kg,续重40元/0.5kg,7-10天送达。\n\n中东非洲: 首重120元/0.5kg,续重55元/0.5kg,10-15天送达。\n\n以上为参考价格,具体以实际计费为准,量大价优。', 2, 1),
('price', '海运报价表', '美西LAX: 整柜40GP $1800起,拼箱$35/CBM,14-18天到港。\n\n美东NYC: 整柜40GP $2800起,拼箱$55/CBM,22-28天到港。\n\n欧洲基本港: 整柜40GP $1600起,拼箱$30/CBM,25-30天到港。\n\n东南亚: 整柜40GP $800起,拼箱$18/CBM,5-7天到港。\n\n中东: 整柜40GP $1500起,拼箱$32/CBM,15-20天到港。', 3, 1),
('wechat', '关注官方微信', '请使用微信搜索公众号「安速通物流」或扫描官网首页二维码关注我们。关注后可享: 1.实时查询运单状态 2.在线下单 3.获取最新活动信息 4.联系在线客服 5.接收电子发票推送。', 1, 1),
('wechat', '微信客服服务时间', '在线客服服务时间: 工作日 08:30-21:00,周六 09:00-18:00,周日及节假日 10:00-16:00。\n\n400客服热线: 7×24小时全天候服务。\n\n非工作时间紧急事宜:可通过微信公众号留言,值班人员将第一时间响应。', 2, 1),
('wechat', '微信下单指南', '1.关注公众号「安速通物流」\n2.点击菜单「我要下单」\n3.填写收发货信息与货物信息\n4.选择取件方式(上门/自送)\n5.提交订单,系统自动分配快递员\n6.快递员1小时内联系您确认取件时间\n7.完成取件,您可在公众号内全程追踪', 3, 1),
('forbidden', '违禁品清单(总览)', '一、绝对禁止寄送:\n1.易燃易爆品:汽油、酒精、液化气、烟花、爆竹、雷管、炸药等\n2.剧毒化学品:农药、氰化物、砒霜等\n3.放射性物品:各类放射性同位素及容器\n4.腐蚀性物品:强酸强碱、水银、双氧水等\n5.枪支弹药、管制刀具、仿真武器\n6.毒品及麻醉品:海洛因、大麻、冰毒、摇头丸等\n7.盗版及淫秽物品:盗版光盘、黄色书刊、成人用品\n8.国家明文禁止的其他物品', 1, 1),
('forbidden', '限制品清单', '以下物品需特殊渠道或限制数量寄送,请提前咨询客服:\n1.锂电池及含锂电池产品:需符合UN38.3标准,单件不超100Wh\n2.液体类:化妆品、食用油等,需密封完好,单件不超500ml\n3.粉末类:食品粉末、保健品粉末,需原包装,单件不超1kg\n4.电子产品:手机、平板、笔记本,需单独申报\n5.食品类:需保质期6个月以上,提供食品生产许可\n6.药品类:仅限非处方药品,需符合目的地国家规定', 2, 1),
('forbidden', '包装要求规范', '1.外包装:使用标准纸箱或木箱,边角加固,禁止使用再生纸箱\n2.内包装:气泡膜、珍珠棉、泡沫板等缓冲材料,避免运输中晃动\n3.重货:使用木架或托盘,单件重量超过50kg建议打托\n4.易碎品:贴易碎标签,建议木架加固,注明「小心轻放」\n5.液体:使用密封容器,外加塑料膜,贴「向上」标签\n6.超长件:超过1.5米的货物需提前报备,部分渠道可能拒收\n7.所有货物必须正确填写申报品名与实际价值', 3, 1);

-- 表4 帮助与支持
INSERT INTO `helps` (`category`, `title`, `content`, `sort_order`, `status`) VALUES
('knowledge', '如何查询运单状态', '方法一:打开官网首页,在右上角「运单查询」框中输入运单号,点击查询即可查看实时状态。\n\n方法二:关注官方微信公众号,点击菜单「运单查询」,输入运单号查询。\n\n方法三:拨打400-888-8888热线,按提示输入运单号或转人工查询。\n\n方法四:登录会员中心,在「我的运单」可查看历史运单与当前状态。', 1, 1),
('knowledge', '发货前需要准备什么', '1.准备好货物,确保包装完好,贵重物品建议保价\n2.准备收件人完整信息:姓名、电话、详细地址(省市区街道门牌)\n3.准备发件人联系电话,方便快递员联系\n4.如是出口货物,请准备商业发票、装箱单、合同等报关资料\n5.如实填写货物名称与价值,避免因申报不实导致清关问题\n6.特殊货物(液体/粉末/电池)请提前咨询客服,确认可走渠道', 2, 1),
('knowledge', '运费是如何计算的', '运费计算规则:\n1.实际重量:以公斤为单位,不足1公斤按1公斤计算\n2.体积重量:长(cm)×宽(cm)×高(cm)÷5000或÷6000(不同渠道略有差异)\n3.计费重量:实际重量与体积重量两者取较大值\n4.偏远地区附加费:部分偏远地址可能收取偏远费\n5.特殊处理费:超长、超重、异形货物可能加收费用\n6.关税与增值税:国际件由目的地海关收取,收件人支付\n\n您可在官网「价格查询」输入具体信息预估运费。', 3, 1),
('knowledge', '货物破损或丢失如何处理', '如遇货物破损或丢失,请按以下步骤处理:\n1.收到货物时当场验货,发现问题立即在签收单上注明情况并拍照存证\n2.签收后24小时内联系我司客服热线400-888-8888报案\n3.提供:运单号、破损/丢失物品清单、价值证明、现场照片\n4.我司将在3个工作日内完成调查并回复处理方案\n5.如已购买保价服务,将按保价金额100%赔付\n6.未保价货物按《邮政法》相关规定进行赔付\n\n温馨提示:高价值货物强烈建议购买保价服务。', 4, 1),
('knowledge', '国际件关税是怎么回事', '关税是货物进入目的地国家时,当地海关根据货物类别与申报价值征收的税费。\n\n关税的决定因素:\n1.货物的HS编码(商品编码)\n2.货物申报价值\n3.目的地国家的关税政策\n4.货物原产地(可能影响贸易协定税率)\n\n一般情况下:\n- 个人用品:多数国家对低于一定金额的个人物品免税(如美国$800以下)\n- 商业货物:一般都会产生关税与增值税/GST\n- 具体税率:可通过我司关税查询工具预估或咨询客服\n\n支付方式:关税一般由收件人在收件时支付(到付),也可选择由发件人预付。', 5, 1),
('knowledge', '如何注册企业账号', '企业账号注册流程:\n1.官网首页点击「企业注册」,填写企业基本信息\n2.上传营业执照扫描件、法人身份证正反面\n3.填写企业联系人信息与开票资料\n4.提交审核,我司将在1-2个工作日内完成审核\n5.审核通过后,即可享受:月结服务、企业专属价格、批量下单、API对接、专属客户经理\n\n大客户专线:400-888-8888转8号线\n合作邮箱:business@ansuto.com', 6, 1),
('download', '安速通物流服务价目表(2024版).pdf', '国内与国际各线路详细价目表,包含首重/续重价格、时效说明、偏远地区附加费等信息。', 1, 1),
('download', '商业发票模板.docx', '国际件出口报关所需的标准商业发票模板,填写示例与注意事项。', 2, 1),
('download', '装箱单模板.xlsx', '货物出口装箱单标准模板,含中英文对照版本。', 3, 1),
('download', '企业合作协议书.pdf', '企业客户与我司签订物流服务协议的标准版本,可下载参考。', 4, 1),
('download', '危险货物申报单.pdf', '特殊货物(含电池/液体/粉末等)申报单模板。', 5, 1);

-- 表5 公司新闻
INSERT INTO `news` (`category`, `title`, `content`, `sort_order`, `status`) VALUES
('company', '安速通物流荣获2024年度「最佳跨境物流服务商」', '近日,在由中国电子商务协会主办的2024年中国跨境电商大会上,安速通物流凭借出色的服务质量与创新的物流解决方案,荣获「最佳跨境物流服务商」称号。这是对安速通成立以来深耕跨境物流领域的肯定,也是对全体员工辛勤付出的最高褒奖。未来,安速通将继续加大基础设施投入,优化全球网络布局,为客户提供更优质的服务。', 1, 1),
('company', '安速通新增5条欧洲专线,时效大幅提升', '为满足客户日益增长的欧洲市场需求,安速通物流即日起正式开通英国、德国、法国、意大利、西班牙5条欧洲专线服务。新专线采用直飞航班与本地清关相结合的模式,平均时效由原来的10-15天缩短至5-8天,价格也较市场平均水平低约15%。客户可通过官网或微信公众号在线下单,享受全新的欧洲物流体验。', 2, 1),
('company', '安速通深圳宝安智能仓正式启用', '安速通物流在深圳宝安新建的智能仓储中心于今日正式投入使用。该仓储中心占地面积3万平方米,配备了先进的自动化分拣系统、AGV机器人搬运、电子标签拣货系统,日处理订单能力达20万件。智能仓的启用将大幅提升华南地区的仓储配送效率,为客户提供更优质的一件代发服务。', 3, 1),
('company', '与阿里国际站达成战略合作,共建跨境物流生态', '安速通物流今日与阿里国际站正式签署战略合作协议,双方将在跨境物流、数据互通、联合营销等方面开展深度合作。合作后,阿里国际站商家可直接在后台选择安速通物流作为发货渠道,享受一键下单、运单同步、状态实时回传的便利。双方还将联合推出「超级物流保障计划」,为商户提供更有保障的物流服务。', 4, 1),
('company', '安速通物流2023年年终总结表彰大会隆重举行', '2024年1月18日,安速通物流2023年年终总结表彰大会在深圳总部隆重举行。公司领导与全体员工齐聚一堂,共同回顾过去一年的辉煌成就,展望新一年的发展目标。会议表彰了一批在2023年表现突出的优秀员工与先进集体,颁发了金牌业务员、最佳服务奖、创新奖等奖项。公司总经理在发言中表示,2024年将是公司的「服务升级年」,将以更高的标准服务客户。', 5, 1),
('company', '安速通通过ISO9001质量管理体系认证', '经过为期三个月的严格审核,安速通物流顺利通过了国际权威认证机构的ISO9001:2015质量管理体系认证。这标志着公司在服务流程标准化、质量管控体系化方面达到了国际先进水平。认证的取得将为公司拓展国际市场、服务全球客户提供更有力的保障。', 6, 1),
('industry', '2024年跨境电商市场规模预计突破2.5万亿', '据权威机构预测,2024年中国跨境电商市场规模将达2.5万亿元,同比增长约22%。其中出口跨境电商占比约75%,进口跨境电商占比约25%。北美、欧洲、东南亚仍是三大主力市场,合计占出口总额的60%以上。从品类来看,3C数码、服装鞋帽、家居园艺、美妆个护、运动户外仍是最受欢迎的五大品类。安速通物流将持续优化各线路服务,助力中国商家出海。', 1, 1),
('industry', '东南亚跨境物流迎来新一轮增长期', '随着东南亚各国经济持续增长与互联网渗透率提升,东南亚跨境电商迎来新一轮高速增长。印度尼西亚、越南、泰国、菲律宾、马来西亚成为最具潜力的五大市场。安速通物流已在东南亚布局多年,在雅加达、胡志明、曼谷设有本地运营团队,能为客户提供本地化的跨境物流解决方案。', 2, 1),
('industry', '人工智能在物流行业的应用前景分析', '人工智能技术正在深刻改变物流行业。在智能仓储领域,AGV机器人、自动分拣系统大幅提升了作业效率;在路径优化方面,AI算法能实时计算最优配送路线,降低运输成本;在客户服务方面,智能客服已能处理80%以上的标准咨询问题。未来3-5年,AI将继续在需求预测、库存优化、动态定价等方面发挥更大作用,推动整个物流行业向智能化转型升级。', 3, 1),
('industry', '中欧班列运行十周年,年开行量突破1.7万列', '截至2023年底,中欧班列累计开行已突破7.7万列,通达欧洲25个国家的217个城市。中欧班列作为「一带一路」倡议的旗舰项目,为中欧贸易提供了新的物流通道,时效比海运快、价格比空运低,特别适合高附加值、对时效有一定要求的货物。安速通物流开通了中欧班列专线服务,每周固定发班,全程15-20天送达欧洲主要城市。', 4, 1);

-- 表7 关于安速通
INSERT INTO `abouts` (`category`, `title`, `content`, `sort_order`, `status`) VALUES
('profile', '公司简介', '安速通物流有限公司成立于2010年,总部位于深圳,是一家专注于国际国内综合物流服务的现代化企业。经过十余年的稳健发展,公司现已成为中国物流行业的领先企业之一。\n\n公司现有员工3000余人,在全国拥有5大区域仓储中心、23个分公司、200+服务网点,国际网络覆盖全球180+国家和地区。2023年全年处理货物超过500万吨,服务企业客户超过2万家。\n\n公司始终秉承「安全、快速、通达」的服务理念,以技术创新与服务升级为双轮驱动,致力于为客户提供「一站式」的综合物流解决方案,让全球贸易更简单。', 1, 1),
('profile', '企业使命与愿景', '【我们的使命】\n让全球贸易更简单,让物流服务更高效\n\n【我们的愿景】\n成为最受信赖的综合物流服务商\n\n【核心价值观】\n客户至上:一切以客户价值为依归\n诚信经营:坚守商业道德,言出必行\n团队协作:开放包容,共同成长\n持续创新:拥抱变化,不断突破\n务实进取:脚踏实地,追求卓越', 2, 1),
('history', '发展历程', '2010年: 公司在深圳成立,聚焦国内快递业务\n2012年: 开通国际业务,首条香港-深圳专线正式运营\n2014年: 完成A轮融资,全国网点突破50个\n2016年: 深圳总部新办公大楼启用,员工突破1000人\n2018年: 正式进军东南亚市场,在越南、泰国设立分公司\n2020年: 疫情期间全力保障国际供应链,获得行业高度认可\n2021年: 完成B轮融资,估值突破10亿\n2022年: 欧洲、美洲海外仓陆续启用\n2023年: 深圳宝安智能仓储中心正式启用,服务企业客户突破2万家\n2024年: 全面启动数字化升级,打造智慧物流平台', 1, 1),
('recruit', '诚聘英才-国际业务经理', '岗位名称: 国际业务经理\n工作地点: 深圳总部\n招聘人数: 5人\n薪资范围: 15K-30K + 业绩提成\n\n岗位职责:\n1.负责国际业务客户开发与维护\n2.制定销售策略,完成销售目标\n3.跟进客户需求,提供物流方案\n4.维护客户关系,提升客户满意度\n\n任职要求:\n1.本科以上学历,3年以上国际物流销售经验\n2.熟悉国际快递、空运、海运业务流程\n3.英语流利,可作为工作语言\n4.具备客户资源者优先\n\n简历投递: hr@ansuto.com\n邮件标题格式: 应聘岗位-姓名-工作年限', 1, 1),
('recruit', '诚聘英才-软件开发工程师', '岗位名称: 高级Java开发工程师\n工作地点: 深圳总部\n招聘人数: 3人\n薪资范围: 20K-40K\n\n岗位职责:\n1.负责物流管理系统后端开发\n2.系统架构设计与性能优化\n3.新技术调研与应用\n\n任职要求:\n1.本科以上学历,5年以上Java开发经验\n2.熟悉Spring Boot、MySQL、Redis、Kafka\n3.有大型分布式系统开发经验\n4.有物流/供应链行业经验者优先', 2, 1),
('recruit', '诚聘英才-仓储运营经理', '岗位名称: 仓储运营经理\n工作地点: 深圳/东莞/杭州\n招聘人数: 3人\n薪资范围: 12K-20K\n\n岗位职责:\n1.负责仓储中心整体运营管理\n2.优化仓内作业流程,提升效率降低成本\n3.团队管理与培训\n4.客户对接与异常处理\n\n任职要求:\n1.大专以上学历,3年以上仓储管理经验\n2.熟悉WMS系统操作\n3.具备团队管理能力,能承受工作压力', 3, 1),
('video', '走进安速通-企业宣传片', '安速通物流官方企业宣传片,带您走进安速通的全国运营网络与智能仓储中心,全方位了解公司的发展历程、服务能力与企业文化。宣传片时长5分钟,包含深圳总部办公环境、智能仓储中心作业现场、全国主要网点实拍、国际航班装卸等精彩画面。(视频内容请以富文本方式展示或嵌入视频链接)', 1, 1),
('video', '安速通一天24小时', '通过跟拍方式,真实记录安速通一线员工一天的工作日常:从早班分拣员清晨5点到岗、快递员8点派件、客服9点到岗接听客户咨询、仓储中心全天24小时运营、国际航班深夜装卸...展现安速通24小时不间断为客户提供服务的日常。(视频内容)', 2, 1),
('notice', '春节期间服务安排通知', '尊敬的客户:\n\n2024年春节临近,根据国务院假期安排,结合我司实际运营情况,现将春节期间服务安排通知如下:\n\n一、国内业务: 2月8日(除夕)至2月12日(初四)暂停国内揽收服务,2月13日(初五)起全面恢复正常。\n\n二、国际业务: 2月10日(初一)至2月12日(初四)暂停国际件揽收,其余时间正常服务,但部分渠道时效略有延迟。\n\n三、客服热线: 400-888-8888 节日期间正常服务(人工服务时间 10:00-16:00)。\n\n四、仓储服务: 各仓储中心2月10日-2月12日暂停入库,出库正常但时效顺延1天。\n\n请您提前安排好发货计划,对给您带来的不便深表歉意。感谢您一直以来对安速通物流的支持与信任!\n\n祝您春节愉快,阖家幸福!\n\n安速通物流有限公司\n2024年1月25日', 1, 1),
('notice', '关于部分渠道价格调整的通知', '尊敬的客户:\n\n因国际航空燃油价格持续上涨及部分渠道成本增加,经公司研究决定,自2024年2月1日起,对以下线路的公布价格进行小幅调整:\n\n1. 欧美空运专线:首重及续重价格上调5%\n2. 中东非洲线路:首重及续重价格上调8%\n3. 国内空运次日达:燃油附加费上调2元/公斤\n\n其他线路及海运、陆运价格保持不变。\n\n已签订合作协议的企业客户,将按协议约定价格执行,不受本次调整影响。\n\n感谢您的理解与支持,我们将继续为您提供优质服务。\n\n安速通物流有限公司\n2024年1月15日', 2, 1),
('notice', '系统升级维护通知', '尊敬的客户:\n\n为提升系统性能,为您提供更好的服务体验,我司将于2024年2月20日凌晨02:00-05:00进行系统升级维护。\n\n维护期间影响:\n1.官网在线下单功能暂停\n2.微信公众号查询功能可能延迟\n3.运单状态更新可能延迟2-3小时\n4.400热线正常服务\n\n维护完成后,系统将自动恢复所有功能。如有紧急需求,请拨打400-888-8888联系人工客服。\n\n感谢您的支持与理解!', 3, 1),
('structure', '组织架构', '安速通物流采用「总部-区域-网点」三级管理架构:\n\n【总部职能部门】\n- 总裁办:公司战略规划与重大决策\n- 国际业务部:国际空运、国际快递、海外仓\n- 国内业务部:国内快递、零担、整车运输\n- 仓储事业部:全国5大仓储中心运营管理\n- 市场部:品牌推广、市场活动、媒体关系\n- 客服中心:400热线、在线客服、客户投诉处理\n- 技术研发中心:系统开发与运维\n- 人力资源部:人才招聘、培训、绩效管理\n- 财务部:财务核算、预算、资金管理\n- 法务与合规部:合同、知识产权、合规管理\n\n【五大区域中心】\n- 华南区:深圳(总部)\n- 华东区:上海\n- 华北区:北京\n- 华中区:武汉\n- 西南区:成都\n\n【地方网点】\n- 全国200+直属网点,深入地市级城市', 1, 1),
('culture', '企业文化理念', '【服务理念】\n安全(Safe): 保障每一件货物安全送达\n快速(Swift): 承诺的时效一定达成\n通达(Smooth): 网络覆盖全球,畅通无阻\n\n【团队文化】\n- 简单:人与人之间坦诚沟通,简单直接\n- 专业:在各自领域做到专业,持续学习\n- 协作:跨部门通力合作,以客户价值为依归\n- 进取:不安于现状,持续突破自我\n\n【客户服务承诺】\n1. 400热线15秒内响应\n2. 客户投诉24小时内闭环处理\n3. 运单异常主动通知,不推诿责任\n4. 大客户专属客户经理,1对1服务', 1, 1),
('culture', '员工关怀与成长', '安速通物流始终将员工视为公司最宝贵的财富。我们为员工提供:\n\n【完善的薪酬福利】\n- 行业内具有竞争力的薪资\n- 五险一金、补充商业保险\n- 年终奖金、业绩提成\n- 带薪年假、法定假期\n- 节日礼品、生日关怀\n\n【完善的培训体系】\n- 新员工入职培训(30天)\n- 岗位技能培训(持续进行)\n- 管理者领导力培训\n- 外派学习机会\n\n【清晰的职业发展路径】\n- 专业序列:初级-中级-高级-资深-专家\n- 管理序列:主管-经理-高级经理-总监\n\n【丰富的企业文化活动】\n- 每年一次全员旅游\n- 季度团建活动\n- 周年庆典\n- 各类文体俱乐部(篮球、羽毛球、瑜伽等)', 2, 1),
('culture', '社会责任与公益行动', '安速通物流在业务发展的同时,始终积极履行企业社会责任:\n\n【绿色物流】\n- 在全国网点推广使用环保包装\n- 新能源电动车辆使用率逐年提升\n- 无纸化办公,电子面单普及率100%\n\n【公益行动】\n- 支援偏远山区:连续5年向云南、贵州山区学校捐赠图书与物资\n- 灾害救援:2021年河南水灾、2023年甘肃地震,均第一时间组织运力运送救灾物资\n- 爱心助学:公司设立「安速通爱心基金」,已资助200+名贫困学生完成学业\n\n【行业贡献】\n- 参与制定多项行业服务标准\n- 为中小物流企业提供技术与管理咨询服务\n- 与高校合作,设立奖学金与实习基地', 3, 1);

SET FOREIGN_KEY_CHECKS = 1;
-- ============================================================
-- 数据库表结构创建完成!
-- 说明: 表1/表2/表4/表5/表7统一精简为基础字段,方便管理
-- 初始登录账号: admin / admin123 (请在首次登录后立即修改密码)
-- ============================================================

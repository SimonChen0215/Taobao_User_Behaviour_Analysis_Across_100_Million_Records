-- - 关于人 ---
-- 获客情况 --
-- 创建临时表来测试
CREATE TEMPORARY TABLE temp_behavior AS
SELECT * FROM user_behavior_new2 LIMIT 100000;

SELECT * FROM temp_behavior LIMIT 5;

-- pv(pageview) & uv (Unique Visitor) 
-- Testing
SELECT dates, count(*) pv, count(DISTINCT user_id) uv, round(count(*)/count(DISTINCT user_id),1) 'pv/uv'
FROM temp_behavior
WHERE behavior_type = 'pv'
GROUP BY dates
ORDER BY dates;

-- Real data processing
CREATE TABLE pv_uv_puv AS
SELECT dates, count(*) pv, count(DISTINCT user_id) uv, round(count(*)/count(DISTINCT user_id),1) 'pv/uv'
FROM user_behavior_new2
WHERE behavior_type = 'pv'
GROUP BY dates
ORDER BY dates;

SELECT * FROM pv_uv_puv;

-- 留存情况 --
-- 留存率
SELECT user_id,dates FROM temp_behavior GROUP BY user_id,dates

-- 自关联 & 留存率 --
-- Retention rate of test data
CREATE TABLE test_behavior AS
SELECT user_id, dates
    FROM temp_behavior
    GROUP BY user_id, dates;

SELECT a.dates
, COUNT(IF(DATEDIFF(b.dates,a.dates) = 0, b.user_id, NULL)) rentention_0
, COUNT(IF(DATEDIFF(b.dates,a.dates) = 1, b.user_id, NULL)) retention_1
, COUNT(IF(DATEDIFF(b.dates,a.dates) = 1, b.user_id, NULL))/COUNT(IF(DATEDIFF(b.dates,a.dates) = 0, b.user_id, NULL)) retention_rate
FROM test_behavior a
LEFT JOIN test_behavior b ON a.user_id = b.user_id
WHERE a.dates <= b.dates
GROUP BY a.dates;

-- Retention rate of Real data
CREATE TABLE IF NOT EXISTS retention_rate AS
SELECT
    a.dates,
    COUNT(IF(DATEDIFF(b.dates, a.dates) = 0, b.user_id, NULL)) AS retention_0,
    COUNT(IF(DATEDIFF(b.dates, a.dates) = 1, b.user_id, NULL)) AS retention_1,
    COUNT(IF(DATEDIFF(b.dates, a.dates) = 1, b.user_id, NULL)) / COUNT(IF(DATEDIFF(b.dates, a.dates) = 0, b.user_id, NULL)) AS retention_rate
FROM
    (SELECT user_id, dates
     FROM user_behavior_new2
     GROUP BY user_id, dates) a
LEFT JOIN
    (SELECT user_id, dates
     FROM user_behavior_new2
     GROUP BY user_id, dates) b ON a.user_id = b.user_id AND a.dates <= b.dates
GROUP BY
    a.dates;

-- 跳失率 -- 51
SELECT COUNT(*) Lost_number FROM
(
SELECT user_id FROM user_behavior_new2
GROUP BY user_id
HAVING COUNT(behavior_type) = 1
) a;

SELECT sum(pv) FROM pv_uv_puv -- 9838354
-- 51/9839354

-- 行为情况——事件序列分析 --
-- 周内行为 日期，小时 --
-- test data
SELECT dates, hours, 
COUNT(IF (behavior_type = 'pv', behavior_type, NULL)) AS pv,
COUNT(IF (behavior_type = 'cart', behavior_type, NULL)) AS cart,
COUNT(IF (behavior_type = 'fav', behavior_type, NULL)) AS fav,
COUNT(IF (behavior_type = 'buy', behavior_type, NULL)) AS buy
FROM temp_behavior
GROUP BY dates,hours
ORDER BY dates,hours

-- real data
CREATE TABLE date_hour_behavior AS 
SELECT dates, hours, 
COUNT(IF (behavior_type = 'pv', behavior_type, NULL)) AS pv,
COUNT(IF (behavior_type = 'cart', behavior_type, NULL)) AS cart,
COUNT(IF (behavior_type = 'fav', behavior_type, NULL)) AS fav,
COUNT(IF (behavior_type = 'buy', behavior_type, NULL)) AS buy
FROM user_behavior_new2
GROUP BY dates,hours
ORDER BY dates,hours

SELECT * FROM date_hour_behavior

-- 行为分析——用户转化率分析——基于用户数量-- 
CREATE TABLE behavior_user_num AS
SELECT behavior_type, COUNT(DISTINCT user_id) user_num FROM user_behavior_new2
GROUP BY behavior_type
ORDER BY behavior_type DESC
SELECT * FROM behavior_user_num
-- buy rate based on user perspective 0.6786
SELECT (SELECT user_num FROM behavior_user_num WHERE behavior_type = 'buy')/(SELECT user_num FROM behavior_user_num WHERE behavior_type = 'pv') buy_rate 

-- 行为分析——用户浏览转化率分析——基于行为数量 --
CREATE TABLE behavior_num AS
SELECT behavior_type, COUNT(*) AS behavior_num FROM user_behavior_new2 GROUP BY behavior_type ORDER BY behavior_type DESC;
SELECT * FROM behavior_num

-- buy rate based on behavior perspective 0.0223
SELECT (SELECT behavior_num FROM behavior_num WHERE behavior_type = 'buy')/(SELECT behavior_num FROM behavior_num WHERE behavior_type = 'pv') buy_rate 
-- fav/cart rate based on behavior perspective 0.0952
SELECT ((SELECT behavior_num FROM behavior_num WHERE behavior_type = 'fav')+(SELECT behavior_num FROM behavior_num WHERE behavior_type = 'cart')) /(SELECT behavior_num FROM behavior_num WHERE behavior_type = 'pv') cart_fav_rate

-- 行为分析——行为路径分析 --
CREATE VIEW user_item_behavior AS
SELECT user_id, item_id, 
COUNT(IF(behavior_type = 'pv', behavior_type, NULL)) AS pv,
COUNT(IF(behavior_type = 'fav', behavior_type, NULL)) AS fav,
COUNT(IF(behavior_type = 'cart', behavior_type, NULL)) AS cart,
COUNT(IF(behavior_type = 'buy', behavior_type, NULL)) AS buy
FROM user_behavior_new2
GROUP BY user_id, item_id
ORDER BY user_id, item_id;

CREATE VIEW user_behavior_standard AS
SELECT user_id, item_id,
(CASE WHEN pv>0 THEN 1 ELSE 0 END) viewed,
(CASE WHEN fav>0 THEN 1 ELSE 0 END) favorited,
(CASE WHEN cart>0 THEN 1 ELSE 0 END) in_cart,
(CASE WHEN buy>0 THEN 1 ELSE 0 END) bought
FROM user_item_behavior
ORDER BY user_id, item_id


-- 创建路径类型
SELECT *, CONCAT(viewed, favorited, in_cart, bought) AS behavior_path
FROM user_behavior_standard
WHERE bought>0

-- 各路径数量
CREATE VIEW path_count AS
SELECT behavior_path, COUNT(*) num FROM 
(SELECT *, CONCAT(viewed, favorited, in_cart, bought) AS behavior_path
FROM user_behavior_standard
WHERE bought>0) AS a
GROUP BY a.behavior_path
SELECT * FROM path_count

-- path explaination table
CREATE TABLE path_explaination(
path_type char(4),
description varchar(60));
INSERT INTO path_explaination
VALUES
('0001', 'Direct Purchase'),
('1001', 'Purchase After Browsing'),
('0011', 'Purchase After Adding to Cart'),
('1011', 'Purchase After Browsing and Adding to Cart'),
('0101', 'Purchase After Favoriting'),
('1101', 'Purchase After Browsing and Favoriting'),
('0111', 'Purchase After Favoriting and Adding to Car'),
('1111', 'Purchase After Browsing, Favoriting, and Adding to Cart')

CREATE TABLE path_result AS
SELECT pc.behavior_path, pe.description, pc.num FROM path_explaination pe
JOIN path_count pc
ON pc.behavior_path = pe.path_type
ORDER BY pc.num DESC
SELECT * FROM path_result

-- 用户购买转化率
-- 浏览后直接购买的数量 165072
SELECT sum(buy) FROM user_item_behavior
WHERE buy > 0 AND fav =0 AND cart = 0
-- 总购买量 218984
SELECT behavior_num FROM behavior_num WHERE behavior_type = 'buy'
-- 收藏/加购后购买的购买量 53912
SELECT (SELECT behavior_num FROM behavior_num WHERE behavior_type = 'buy') - 165072 
-- 收藏加购后的购买转化率 0.0576
SELECT 53912/ ((SELECT behavior_num FROM behavior_num WHERE behavior_type = 'fav')+(SELECT behavior_num FROM behavior_num WHERE behavior_type = 'cart'))

-- 用户定位——rfm model
CREATE TABLE rfm_model AS
SELECT user_id
,COUNT(user_id) 'Frequency'
,MAX(dates) 'Recent'
FROM user_behavior_new2
WHERE behavior_type='buy'
GROUP BY user_id
ORDER BY 2 DESC,3 DESC;
ALTER TABLE rfm_model MODIFY `Purchase Frequency` INT;

ALTER TABLE rfm_model ADD fscore INT;
ALTER TABLE rfm_model ADD rscore INT;

UPDATE rfm_model
SET rscore = CASE
WHEN Recent = '2017-12-03' THEN 5
WHEN Recent IN ('2017-12-01','2017-12-02') THEN 4
WHEN Recent in ('2017-11-29','2017-11-30') THEN 3
WHEN recent in ('2017-11-27','2017-11-28') THEN 2
ELSE 1
END

UPDATE rfm_model
SET fscore = CASE
WHEN Frequency BETWEEN 76 AND 100 THEN 5
WHEN Frequency BETWEEN 51 AND 75 THEN 4
WHEN Frequency BETWEEN 26 AND 50 THEN 3
WHEN Frequency BETWEEN 5 AND 25 THEN 2
ELSE 1
END

-- Average score
SET @f_avg=NULL;
SET @r_avg=NULL;
SELECT AVG(fscore) INTO @f_avg FROM rfm_model;
SELECT AVG(rscore) INTO @r_avg FROM rfm_model;

-- Set class based on different scores & Number Counts on Different Classes
ALTER TABLE rfm_model ADD class VARCHAR(60);
UPDATE rfm_model
SET class = CASE
WHEN fscore > @f_avg AND rscore > @r_avg THEN 'Best Customer'
WHEN fscore > @f_avg AND rscore < @r_avg THEN 'Churned Best Customer'
WHEN fscore < @f_avg AND rscore > @r_avg THEN 'Low-Spenidng Active Loyal Customer'
WHEN fscore < @f_avg AND rscore < @r_avg THEN 'Needs Retention'
END

-- Products Category -- 统计商品的热门品类、热门商品、热门品类热门商品
-- Most popular product category
CREATE TABLE popular_categories AS
SELECT category_id, COUNT(behavior_type) pv FROM user_behavior_new2
WHERE behavior_type = 'pv'
GROUP BY category_id
ORDER BY pv DESC

-- Most popular items
CREATE TABLE popular_items AS
SELECT item_id, COUNT(behavior_type) pv FROM user_behavior_new2
WHERE behavior_type = 'pv'
GROUP BY item_id
ORDER BY pv DESC

-- Most popular products in different categories
CREATE TABLE popular_cateitems AS
SELECT category_id,item_id,
pageview_category FROM
(
SELECT category_id,item_id
,COUNT(IF(behavior_type='pv',behavior_type,NULL)) 'pageview_category'
,RANK()over(PARTITION BY category_id ORDER BY count(if(behavior_type='pv',behavior_type,NULL)) DESC) r
FROM user_behavior_new2
GROUP BY category_id,item_id
ORDER BY 3 DESC
) a
WHERE a.r = 1
ORDER BY a.pageview_category DESC

SELECT * FROM popular_cateitems
-- 商品转化率分析 -- 
-- 特定商品转化率 Conversion rate of different items--
CREATE TABLE item_conversion_rate AS
SELECT item_id
, COUNT(IF(behavior_type = 'pv',behavior_type,NULL)) 'pv'
, COUNT(IF(behavior_type = 'fav',behavior_type,NULL)) 'fav'
, COUNT(IF(behavior_type = 'cart',behavior_type,NULL)) 'cart'
, COUNT(IF(behavior_type = 'buy',behavior_type,NULL)) 'buy'
, COUNT(DISTINCT IF(behavior_type = 'buy',user_id,NULL))/COUNT(DISTINCT user_id) user_buy_rate
FROM user_behavior_new2
GROUP BY item_id
ORDER BY 6 DESC

-- Conversion rate of different categories
CREATE TABLE category_conversion_rate AS
SELECT category_id
, COUNT(IF(behavior_type = 'pv',behavior_type,NULL)) 'pv'
, COUNT(IF(behavior_type = 'fav',behavior_type,NULL)) 'fav'
, COUNT(IF(behavior_type = 'cart',behavior_type,NULL)) 'cart'
, COUNT(IF(behavior_type = 'buy',behavior_type,NULL)) 'buy'
, COUNT(DISTINCT IF(behavior_type = 'buy',user_id,NULL))/COUNT(DISTINCT user_id) user_buy_rate
FROM user_behavior_new2
GROUP BY category_id
ORDER BY 6 DESC

SELECT * FROM retention_rate
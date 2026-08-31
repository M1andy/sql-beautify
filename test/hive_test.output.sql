-- ============================================================
-- Hive SQL 格式化测试文件 (故意混乱，用于测试格式化能力)
-- 覆盖常见 Hive SQL 场景
-- ============================================================

-- ============================================================
-- 1. 基础查询 Basic Query
-- ============================================================
SELECT  user_id
       ,COUNT(DISTINCT order_id) AS order_cnt
       ,SUM(amount)              AS total_amt
       ,AVG(amount)              AS avg_amt
FROM dws.orders
WHERE dt = '2024-01-01'
AND amount >= 100
AND amount < 5000
AND status IN ('paid', 'refunded')
AND pay_channel RLIKE '^(ali|wechat)'
GROUP BY  user_id
HAVING COUNT(DISTINCT order_id) > 2
ORDER BY  total_amt DESC
         ,user_id ASC
LIMIT 100
;

SELECT  id
       ,name
FROM ods.users
WHERE created_date BETWEEN '2023-01-01' AND '2023-12-31'
AND email LIKE '%@company.com'
AND name NOT LIKE 'test%'
LIMIT 10
;

SELECT  DISTINCT channel
       ,COUNT(*) cnt
FROM dws.orders
WHERE dt = '2024-01-01'
GROUP BY  channel
;

-- 行注释测试
SELECT  1; -- 尾部注释

/* 块注释
   跨行 */
SELECT  2;

-- ============================================================
-- 2. JOIN 连接
-- ============================================================
SELECT  a.id
       ,a.name
       ,b.order_id
       ,b.amount
FROM dim.user a
INNER JOIN dws.orders b
ON a.id = b.user_id
WHERE b.dt = '2024-01-01'
;

SELECT  *
FROM table_a a
LEFT JOIN table_b b
ON a.key = b.key
LEFT JOIN table_c c
ON b.key = c.key
WHERE c.flag = 1
;

SELECT  a.*
       ,b.*
FROM table_a a
RIGHT OUTER JOIN table_b b
ON a.id = b.id
;

SELECT  a.x
       ,b.y
FROM table_a a
FULL OUTER JOIN table_b b
ON a.id = b.id
WHERE b.id IS NOT NULL
;

SELECT  a.id
       ,b.id
FROM table_a a
CROSS JOIN table_b b
;

SELECT  a.id
       ,b.id
FROM table_a a
JOIN table_b b
ON a.id = b.id
JOIN table_c c
ON b.id = c.id
;

-- ============================================================
-- 3. CTE 公共表表达式
-- ============================================================
WITH base AS
(
    SELECT  id
           ,amount
    FROM ods.orders
    WHERE dt = '2024-01-01'
), agg AS
(
    SELECT  id
           ,SUM(amount) AS amt
    FROM base
    GROUP BY  id
)
SELECT  id
       ,amt
FROM agg
WHERE amt > 100
;

WITH cte1 AS
(
    SELECT  id
    FROM table_a
), cte2 AS
(
    SELECT  id
    FROM cte1
    WHERE id > 0
), cte3 AS
(
    SELECT  id
    FROM cte2
    WHERE id < 100
)
SELECT  COUNT(*)
FROM cte3
;

-- ============================================================
-- 4. CASE WHEN 条件表达式
-- ============================================================
SELECT  id
       ,CASE WHEN amount >= 10000 THEN 'high'
             WHEN amount >= 1000 THEN 'mid'
        ELSE 'low' END AS level
       ,CASE gender WHEN 'M' THEN 'male'
                    WHEN 'F' THEN 'female'
        ELSE 'unknown' END AS g
FROM dws.orders
;

SELECT  CASE WHEN a > 0 THEN (CASE WHEN b > 0 THEN 'ab' ELSE 'a' END) ELSE 'none' END AS flag
FROM table_a
;

-- ============================================================
-- 5. 窗口函数 Window Function
-- ============================================================
SELECT  id
       ,user_id
       ,amount
       ,ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY amount DESC) AS rn
FROM dws.orders
WHERE dt = '2024-01-01'
;

SELECT  id
       ,RANK() OVER(PARTITION BY user_id ORDER BY amount DESC) AS rk
       ,DENSE_RANK() OVER(PARTITION BY user_id ORDER BY amount DESC) AS drk
FROM dws.orders
;

SELECT  id
       ,SUM(amount) OVER(PARTITION BY user_id ORDER BY dt ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_sum
FROM dws.orders
;

SELECT  id
       ,LAG(amount,1) OVER(PARTITION BY user_id ORDER BY dt) AS prev_amt
       ,LEAD(amount,1) OVER(PARTITION BY user_id ORDER BY dt) AS next_amt
       ,NTILE(4) OVER(ORDER BY amount DESC) AS bucket
FROM dws.orders
;

SELECT  id
       ,COUNT(*) OVER() AS total_cnt
FROM dws.orders
;

-- ============================================================
-- 6. LATERAL VIEW 与 UDTF
-- ============================================================
SELECT  user_id
       ,tag
FROM dws.user_tags
LATERAL VIEW EXPLODE(SPLIT(tags, ',')) t AS tag
WHERE tag != ''
GROUP BY  user_id
         ,tag
;

SELECT  a.id
       ,b.col
FROM table_a a
LATERAL VIEW EXPLODE(MAP_KEYS(a.kv)) b AS col
;

SELECT  id
       ,EXPLODE(ARRAY('a','b'))
FROM table_a
;

-- ============================================================
-- 7. GROUPING SETS / ROLLUP / CUBE
-- ============================================================
SELECT  dt
       ,channel
       ,SUM(amount) AS amt
FROM dws.orders
GROUP BY  dt
         ,channel
GROUPING SETS((dt), (channel), (dt, channel), ())
;

SELECT  dt
       ,channel
       ,SUM(amount) AS amt
FROM dws.orders
GROUP BY  ROLLUP(dt,channel)
;

SELECT  dt
       ,channel
       ,SUM(amount) AS amt
FROM dws.orders
GROUP BY  CUBE(dt,channel)
;

-- ============================================================
-- 8. UNION / INTERSECT / EXCEPT
-- ============================================================
SELECT  id
FROM table_a

UNION ALL

SELECT  id
FROM table_b

UNION

SELECT  id
FROM table_c
;

SELECT  id
FROM table_a

INTERSECT

SELECT  id
FROM table_b
;

SELECT  id
FROM table_a

EXCEPT

SELECT  id
FROM table_b
;

-- ============================================================
-- 9. INSERT 写入 (含多表插入与动态分区)
-- ============================================================
INSERT OVERWRITE TABLE dws.orders_snapshot PARTITION(dt = '2024-01-01')
SELECT  id
       ,user_id
       ,amount
FROM ods.orders
WHERE dt = '2024-01-01'
;

INSERT INTO TABLE dws.orders VALUES(1, 100, 100.0, '2024-01-01'), (2, 200, 200.0, '2024-01-01');

INSERT INTO TABLE dws.orders PARTITION(dt)
SELECT  id
       ,user_id
       ,amount
       ,dt
FROM ods.orders
WHERE dt >= '2024-01-01'
;

INSERT OVERWRITE TABLE dws.stat
SELECT  'total'  AS k
       ,COUNT(*) AS v
FROM dws.orders

UNION ALL

SELECT  'paid'   AS k
       ,COUNT(*) AS v
FROM dws.orders
WHERE status = 'paid'
;

FROM ods.orders
INSERT OVERWRITE TABLE dws.a PARTITION(dt = '2024-01-01')
SELECT  id
WHERE amount > 100
INSERT OVERWRITE TABLE dws.b PARTITION(dt = '2024-01-01')
SELECT  id
WHERE amount <= 100
;

-- ============================================================
-- 10. DDL 建表与表操作
-- ============================================================
CREATE TABLE IF NOT EXISTS dws.orders_detail (
    id       BIGINT        COMMENT '订单id'
    ,user_id BIGINT        COMMENT '用户id'
    ,amount  DECIMAL(10,2) COMMENT '金额'
    ,status  STRING        COMMENT '状态'
    ,dt      STRING        COMMENT '日期'
)
COMMENT '订单明细表'
PARTITIONED BY (dt STRING)
CLUSTERED BY (id)
SORTED BY (amount DESC) INTO 16 BUCKETS
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'snappy', 'auto.purge' = 'true')
LOCATION '/warehouse/dws/orders_detail'
;

CREATE TABLE dws.dim_date (
    d      DATE   COMMENT '日期'
    ,year  STRING COMMENT '年'
    ,month STRING COMMENT '月'
)
COMMENT '日期维表'
PARTITIONED BY (dt STRING)
STORED AS PARQUET
;

CREATE VIEW v_orders AS
SELECT  id
       ,user_id
       ,amount
FROM dws.orders
WHERE amount > 100
;

ALTER TABLE dws.orders ADD COLUMNS (
    new_col STRING COMMENT '新列'
)
;

ALTER TABLE dws.orders DROP COLUMNS (
    old_col
)
;

ALTER TABLE dws.orders CHANGE COLUMN old_col new_col BIGINT COMMENT '改名列';

DROP TABLE IF EXISTS dws.tmp_table;

TRUNCATE TABLE dws.tmp_table;

-- ============================================================
-- 11. SET / Hint / 常用函数
-- ============================================================
SET hive.exec.dynamic.partition = true;

SET hive.exec.dynamic.partition.mode = nonstrict;

SELECT  /*+ MAPJOIN(dim) */ a.id
       ,b.name
FROM dws.orders a
JOIN dim.user b
ON a.user_id = b.id
;

SELECT  CONCAT(a,'_',b)                          AS ab
       ,SPLIT(s,',')                             AS arr
       ,GET_JSON_OBJECT(js,'$.name')             AS nm
       ,REGEXP_REPLACE(s,'\\d','')               AS cleaned
       ,DATEDIFF('2024-01-02','2024-01-01')      AS diff
       ,NVL(a,0)                                 AS a1
       ,COALESCE(a,b,0)                          AS a2
       ,CAST(a AS STRING)                        AS a3
       ,IF(flag = 1,'y','n')                     AS f
       ,FLOOR(1.9)                               AS fl
       ,CEIL(1.1)                                AS ce
       ,ROUND(1.234,2)                           AS rd
       ,DATE_FORMAT(dt,'yyyy-MM-dd')             AS df
       ,TO_DATE(dt)                              AS td
       ,UNIX_TIMESTAMP(dt,'yyyy-MM-dd HH:mm:ss') AS ts
       ,FROM_UNIXTIME(ts)                        AS fu
FROM ods.tmp
;

-- ============================================================
-- 12. 注释 Comment
-- ============================================================
SELECT  a
FROM t -- 这里 SELECT 和 WHERE 是注释
WHERE b = 1
;

SELECT  a
       ,b
FROM t -- a,b,c (内容) 注释
WHERE b = 1
;

SELECT  a -- 注释
       ,b
FROM t
;

SELECT  a -- 注释
       ,b
FROM t
;

SELECT  a
FROM t; -- 注释;分号

SELECT  a
FROM t; -- it's done, ok

/* select * from x where y=1 */
SELECT  a
FROM t
;

-- 注释
INSERT INTO TABLE t VALUES(1);

-- ============================================================
-- 13. IN 列表换行 IN list wrapping
-- ============================================================
SELECT  id
       ,status
FROM dws.orders
WHERE status IN
    (
        'paid'
        ,'refunded'
        ,'chargeback'
        ,'failed'
        ,'pending'
        ,'cancelled'
        ,'processing'
        ,'shipped'
        ,'returned'
        ,'expired'
        ,'unknown'
        ,'reversed'
    )
AND id > 100
;

SELECT  id
FROM dws.orders
WHERE id NOT IN
    (
        10001
        ,10002
        ,10003
        ,10004
        ,10005
        ,10006
        ,10007
        ,10008
        ,10009
        ,10010
        ,10011
        ,10012
        ,10013
        ,10014
        ,10015
        ,10016
        ,10017
        ,10018
        ,10019
        ,10020
    )
;

SELECT  a
FROM t
WHERE x IN
    (
        1
        ,2
        ,3
        ,CASE WHEN y = 1 THEN 4 WHEN y = 2 THEN 5 ELSE 6 END
        ,7
        ,8
        ,9
        ,10
        ,11
        ,12
        ,13
        ,14
        ,15
        ,16
        ,17
        ,18
        ,19
        ,20
        ,21
        ,22
        ,23
        ,24
        ,25
        ,26
        ,27
        ,28
        ,29
        ,30
    )
;

SELECT  a
FROM t
WHERE x IN ( SELECT id FROM dim_user WHERE dt = '2024-01-01' AND type IN ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't') AND status = 1)
;

SELECT  a
FROM t
WHERE (type IN
    (
        'aa'
        ,'bb'
        ,'cc'
        ,'dd'
        ,'ee'
        ,'ff'
        ,'gg'
        ,'hh'
        ,'ii'
        ,'jj'
        ,'kk'
        ,'ll'
        ,'mm'
        ,'nn'
        ,'oo'
        ,'pp'
        ,'qq'
        ,'rr'
        ,'ss'
        ,'tt'
    )
OR level IN
    (
        1
        ,2
        ,3
        ,4
        ,5
        ,6
        ,7
        ,8
        ,9
        ,10
        ,11
        ,12
        ,13
        ,14
        ,15
        ,16
        ,17
        ,18
        ,19
        ,20
    )
)
AND b = 1
;

SELECT  a
FROM t
WHERE tag IN
    (
        'beijing,chaoyang'
        ,'shanghai,pudong'
        ,'guangzhou,tianhe'
        ,'shenzhen,nanshan'
        ,'hangzhou,xihu'
        ,'chengdu,wuhou'
        ,'wuhan,hongshan'
        ,'xian,yanta'
        ,'nanjing,jianye'
        ,'suzhou,gusu'
        ,'chongqing,yubei'
        ,'tianjin,hexi'
        ,'jinan,lixia'
        ,'fuzhou,cangshan'
        ,'changsha,yuelu'
        ,'zhengzhou,jinshui'
        ,'hefei,baohe'
        ,'kunming,panlong'
        ,'guiyang,nanshan'
        ,'haikou,meilan'
    )
;

SELECT  a
FROM t
WHERE x IN (1, 2, 3)
AND y NOT IN (4, 5)
;

-- ============================================================
-- SQL Beautify 人工验证样例 第 2 轮（修复后回归 + 新能力覆盖）
-- 用法: node test/generate-result.js -> 仓库根目录 test_result.sql
-- 说明: 每个用例前用 @case/@expect 标记，生成结果时转为勾选框头
-- ============================================================

-- @case 多层嵌套子查询 + NOT IN 子查询展开
-- @expect FROM 子查询逐层缩进；NOT IN (SELECT...) 展开为多行块；子查询内值列表保持单行
select t1.uid,t1.cnt from (select uid,count(*) as cnt from (select uid,dt from ods.login where dt='2024-07-01' and platform in ('ios','android')) tmp group by uid) t1 where t1.uid not in (select uid from dim.black_list where dt='2024-07-01' and level in (1,2,3)) and t1.cnt >= 5 order by t1.cnt desc;

-- @case CTE 链 + 多表 JOIN + 窗口函数去重（回归）
-- @expect 每个 CTE 单独成块缩进，JOIN/ON 分行，GROUP BY 前导逗号对齐
with pay_ord as (select order_id,uid,amt,pay_time from ods.pay_order where dt='2024-07-01' and pay_status=90),dedup as (select order_id,uid,amt,row_number() over (partition by order_id order by pay_time desc) as rn from pay_ord) select ui.city,count(distinct d.uid) as uv,sum(d.amt) as amt from dedup d join dim.user_info ui on d.uid=ui.id and ui.dt='2024-07-01' where d.rn=1 group by ui.city order by amt desc limit 20;

-- @case 嵌套 CASE WHEN + 聚合 + 多条件 HAVING（新：AND 拆行）
-- @expect HAVING 的多个 AND 条件逐行拆分，与 WHERE 风格一致；CASE WHEN 分支对齐
select province,city,sum(amt) as total,count(*) as cnt,case when sum(amt)>=100000 then 'S' when sum(amt)>=50000 then 'A' else 'B' end as grade from dws.city_pay_day where dt between '2024-07-01' and '2024-07-31' group by province,city having count(*)>10 and sum(amt)>5000 and province!='test' order by total desc;

-- @case is null / is not null 关键字大写（新）
-- @expect 普通与否定形式均大写为 IS NULL / IS NOT NULL，出现在 CASE WHEN 与 WHERE 中都生效
select uid,case when ref_order_id is null then 0 else 1 end as is_paid,case when coupon_id is not null then 1 else 0 end as used_coupon from dws.order_ext where remark is null or channel is not null;

-- @case 超长多子句 OVER 块状展开（新：整行超 150 触发）
-- @expect OVER ( 后换行，PARTITION BY / ORDER BY / ROWS 各占一行，) 回到语句缩进并携带 AS 别名
select id,sum(amount) over (partition by user_id_first_col, second_partition_col, third_partition_col order by dt_long_col_name, amount_col_name rows between unbounded preceding and current row) as running_sum from t;

-- @case 短 OVER 不展开（新规则回归）
-- @expect 未超长的 OVER 子句保持单行；COUNT(*) OVER() 空子句永不展开
select id,row_number() over (partition by uid order by amt desc) as rn,count(*) over() as total from t;

-- @case 超长 IN 值列表新缩进 + 短 IN 保持单行（回归）
-- @expect 超长列表: ( 与语句对齐、条目 4 空格缩进、首条目与后续逗号后的值对齐；短列表与含 CASE 的列表保持原样
select order_id,city_id,status from dws.order_detail where dt='2024-07-01' and city_id in (110000,310000,440100,440300,330100,510100,420100,610100,320100,320500,500100,120000,370100,350100,430100,410100,340100,530100,520100,460100) and status in ('paid','refunded') limit 100;

-- @case UNION ALL + EXISTS/NOT EXISTS 关联子查询（回归）
-- @expect union all 两侧各自成块，exists 子查询不被拆坏
select 'app' as src,uid from dws.app_login where dt='2024-07-01' and exists (select 1 from dws.vip_user v where v.uid=dws.app_login.uid) union all select 'web' as src,uid from dws.web_login where dt='2024-07-01' and not exists (select 1 from dws.black_list b where b.uid=dws.web_login.uid) limit 200;

-- @case INSERT OVERWRITE 动态分区 + LATERAL VIEW explode（回归）
-- @expect partition 子句与 select 部分正确分行，lateral view 语法不被拆坏
insert overwrite table dws.user_tag_stat partition (dt) select uid,tag,count(*) as cnt,dt from ods.user_tag_log lateral view explode(split(tag_list,',')) t as tag where dt='2024-07-01' and tag<>'' group by uid,tag,dt;

-- @case EXTERNAL TABLE DDL：混合注释列 + 分区列注释 + 桶/存储（新）
-- @expect CREATE EXTERNAL TABLE 正常走 DDL 通道；无注释列不补空 COMMENT ''；分区列注释不换行；表级子句逐段换行
create external table if not exists dws.order_pay_detail (order_id bigint comment '订单ID',user_id bigint comment '用户ID',pay_amount decimal(16,2) comment '支付金额',pay_channel string,pay_time string) comment '订单支付明细表' partitioned by (dt string comment '业务日期') clustered by (user_id) sorted by (pay_time desc) into 8 buckets stored as orc location '/warehouse/dws/db/order_pay_detail' tblproperties ('orc.compress'='SNAPPY');

-- @case 行注释/块注释/含分号字符串混排（回归）
-- @expect 注释保留在原语义位置，字符串中的分号不导致语句被截断
select order_id, -- 订单编号
user_name,remark /* 备注块注释 */ from dws.order_info where dt='2024-07-01' and remark not like '%半角分号;测试%' and status=1;

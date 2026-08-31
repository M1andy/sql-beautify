-- ============================================================
-- Hive SQL 格式化测试文件 (故意混乱，用于测试格式化能力)
-- 覆盖常见 Hive SQL 场景
-- ============================================================

-- ============================================================
-- 1. 基础查询 Basic Query
-- ============================================================
select user_id,count(distinct order_id) as order_cnt,sum(amount) as total_amt,avg(amount) as avg_amt from dws.orders where dt='2024-01-01' and amount>=100 and amount<5000 and status in('paid','refunded') and pay_channel rlike '^(ali|wechat)' group by user_id having count(distinct order_id)>2 order by total_amt desc,user_id asc limit 100;

select id,name from ods.users where created_date between '2023-01-01' and '2023-12-31' and email like '%@company.com' and name not like 'test%' limit 10;

SELECT DISTINCT channel,count(*) cnt FROM dws.orders WHERE dt='2024-01-01' GROUP BY channel;

-- 行注释测试
select 1; -- 尾部注释
/* 块注释
   跨行 */
select 2;

-- ============================================================
-- 2. JOIN 连接
-- ============================================================
select a.id,a.name,b.order_id,b.amount from dim.user a inner join dws.orders b on a.id=b.user_id where b.dt='2024-01-01';

select * from table_a a left join table_b b on a.key=b.key left join table_c c on b.key=c.key where c.flag=1;

select a.*,b.* from table_a a right outer join table_b b on a.id=b.id;

select a.x,b.y from table_a a full outer join table_b b on a.id=b.id where b.id is not null;

select a.id,b.id from table_a a cross join table_b b;

select a.id,b.id from table_a a join table_b b on a.id=b.id join table_c c on b.id=c.id;

-- ============================================================
-- 3. CTE 公共表表达式
-- ============================================================
with base as(select id,amount from ods.orders where dt='2024-01-01'),agg as(select id,sum(amount) as amt from base group by id) select id,amt from agg where amt>100;

with cte1 as(select id from table_a),cte2 as(select id from cte1 where id>0),cte3 as(select id from cte2 where id<100) select count(*) from cte3;

-- ============================================================
-- 4. CASE WHEN 条件表达式
-- ============================================================
select id,case when amount>=10000 then 'high' when amount>=1000 then 'mid' else 'low' end as level,case gender when 'M' then 'male' when 'F' then 'female' else 'unknown' end as g from dws.orders;

select case when a>0 then(case when b>0 then 'ab' else 'a' end) else 'none' end as flag from table_a;

-- ============================================================
-- 5. 窗口函数 Window Function
-- ============================================================
select id,user_id,amount,row_number() over(partition by user_id order by amount desc) as rn from dws.orders where dt='2024-01-01';

select id,rank() over(partition by user_id order by amount desc) as rk,dense_rank() over(partition by user_id order by amount desc) as drk from dws.orders;

select id,sum(amount) over(partition by user_id order by dt rows between unbounded preceding and current row) as running_sum from dws.orders;

select id,lag(amount,1) over(partition by user_id order by dt) as prev_amt,lead(amount,1) over(partition by user_id order by dt) as next_amt,ntile(4) over(order by amount desc) as bucket from dws.orders;

select id,count(*) over() as total_cnt from dws.orders;

-- ============================================================
-- 6. LATERAL VIEW 与 UDTF
-- ============================================================
select user_id,tag from dws.user_tags lateral view explode(split(tags,',')) t as tag where tag!='' group by user_id,tag;

select a.id,b.col from table_a a lateral view explode(map_keys(a.kv)) b as col;

select id,explode(array('a','b')) from table_a;

-- ============================================================
-- 7. GROUPING SETS / ROLLUP / CUBE
-- ============================================================
select dt,channel,sum(amount) as amt from dws.orders group by dt,channel grouping sets((dt),(channel),(dt,channel),());

select dt,channel,sum(amount) as amt from dws.orders group by rollup(dt,channel);

select dt,channel,sum(amount) as amt from dws.orders group by cube(dt,channel);

-- ============================================================
-- 8. UNION / INTERSECT / EXCEPT
-- ============================================================
select id from table_a union all select id from table_b union select id from table_c;

select id from table_a intersect select id from table_b;

select id from table_a except select id from table_b;

-- ============================================================
-- 9. INSERT 写入 (含多表插入与动态分区)
-- ============================================================
insert overwrite table dws.orders_snapshot partition(dt='2024-01-01') select id,user_id,amount from ods.orders where dt='2024-01-01';

insert into table dws.orders values(1,100,100.0,'2024-01-01'),(2,200,200.0,'2024-01-01');

insert into table dws.orders partition(dt) select id,user_id,amount,dt from ods.orders where dt>='2024-01-01';

insert overwrite table dws.stat select 'total' as k,count(*) as v from dws.orders union all select 'paid' as k,count(*) as v from dws.orders where status='paid';

from ods.orders insert overwrite table dws.a partition(dt='2024-01-01') select id where amount>100 insert overwrite table dws.b partition(dt='2024-01-01') select id where amount<=100;

-- ============================================================
-- 10. DDL 建表与表操作
-- ============================================================
create table if not exists dws.orders_detail(id bigint comment '订单id',user_id bigint comment '用户id',amount decimal(10,2) comment '金额',status string comment '状态',dt string comment '日期') comment '订单明细表' partitioned by(dt string) clustered by(id) sorted by(amount desc) into 16 buckets row format delimited fields terminated by '\t' stored as orc tblproperties('orc.compress'='snappy','auto.purge'='true') location '/warehouse/dws/orders_detail';

create table dws.dim_date(d date comment '日期',year string comment '年',month string comment '月') comment '日期维表' partitioned by(dt string) stored as parquet;

create view v_orders as select id,user_id,amount from dws.orders where amount>100;

alter table dws.orders add columns(new_col string comment '新列');

alter table dws.orders drop columns(old_col);

alter table dws.orders change column old_col new_col bigint comment '改名列';

drop table if exists dws.tmp_table;

truncate table dws.tmp_table;

-- ============================================================
-- 11. SET / Hint / 常用函数
-- ============================================================
set hive.exec.dynamic.partition=true;

set hive.exec.dynamic.partition.mode=nonstrict;

select /*+ mapjoin(dim) */ a.id,b.name from dws.orders a join dim.user b on a.user_id=b.id;

select concat(a,'_',b) as ab,split(s,',') as arr,get_json_object(js,'$.name') as nm,regexp_replace(s,'\\d','') as cleaned,datediff('2024-01-02','2024-01-01') as diff,nvl(a,0) as a1,coalesce(a,b,0) as a2,cast(a as string) as a3,if(flag=1,'y','n') as f,floor(1.9) as fl,ceil(1.1) as ce,round(1.234,2) as rd,date_format(dt,'yyyy-MM-dd') as df,to_date(dt) as td,unix_timestamp(dt,'yyyy-MM-dd HH:mm:ss') as ts,from_unixtime(ts) as fu from ods.tmp;

-- ============================================================
-- 12. 注释 Comment
-- ============================================================
select a from t -- 这里 SELECT 和 WHERE 是注释
where b=1;

select a,b from t -- a,b,c (内容) 注释
where b=1;

select a -- 注释
,b from t;

select a, -- 注释
b from t;

select a from t; -- 注释;分号

select a from t; -- it's done, ok

/* select * from x where y=1 */
select a from t;

-- 注释
insert into table t values(1);

-- ============================================================
-- 13. IN 列表换行 IN list wrapping
-- ============================================================
select id,status from dws.orders where status in('paid','refunded','chargeback','failed','pending','cancelled','processing','shipped','returned','expired','unknown','reversed') and id>100;

select id from dws.orders where id not in(10001,10002,10003,10004,10005,10006,10007,10008,10009,10010,10011,10012,10013,10014,10015,10016,10017,10018,10019,10020);

select a from t where x in(1,2,3,case when y=1 then 4 when y=2 then 5 else 6 END,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30);

select a from t where x in(select id from dim_user where dt='2024-01-01' and type in('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t') and status=1);

select a from t where (type in('aa','bb','cc','dd','ee','ff','gg','hh','ii','jj','kk','ll','mm','nn','oo','pp','qq','rr','ss','tt') OR level in(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20)) and b=1;

select a from t where tag in('beijing,chaoyang','shanghai,pudong','guangzhou,tianhe','shenzhen,nanshan','hangzhou,xihu','chengdu,wuhou','wuhan,hongshan','xian,yanta','nanjing,jianye','suzhou,gusu','chongqing,yubei','tianjin,hexi','jinan,lixia','fuzhou,cangshan','changsha,yuelu','zhengzhou,jinshui','hefei,baohe','kunming,panlong','guiyang,nanshan','haikou,meilan');

select a from t where x in(1,2,3) and y not in(4,5);

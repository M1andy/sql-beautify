-- ============================================================
-- SQL Beautify 人工验证样例 第 3 轮（括号条件组换行 condition_wrap 专项）
-- 用法: node test/generate-result.js -> 仓库根目录 test_result.sql
-- 说明: 每个用例前用 @case/@expect 标记，生成结果时转为勾选框头
-- ============================================================

-- @case 纯 OR 超长组（WHERE 直挂）
-- @expect WHERE 独行，( 与 ) 独立成行与语句对齐，各条件 +4 缩进且 OR 前缀与首条件同列
select order_id from dws.order_detail where (channel_id = 10000001 or channel_id = 20000002 or channel_id = 30000003 or channel_id = 40000004 or channel_id = 50000005 or channel_id = 60000006) and dt='2024-08-01' limit 100;

-- @case AND 后超长组（多条件 WHERE 中段）
-- @expect 前面的条件各自成行；AND 独行，条件组按块状展开
select order_id from dws.order_detail where dt='2024-08-01' and status in ('paid','refunded') and (province_code = 110000 or province_code = 310000 or province_code = 440100 or province_code = 440300 or province_code = 330100 or province_code = 510100) limit 100;

-- @case NOT + 超长组
-- @expect 关键词行为 WHERE NOT，( 仍独立成行，条件组正常展开
select order_id from t where not (black_channel_level = 1 or black_channel_level = 2 or black_channel_level = 3 or black_channel_level = 4 or black_channel_level = 5 or black_channel_level = 6) limit 10;

-- @case 括号内 OR/AND 混合：只拆顶层 OR
-- @expect 顶层 OR 逐条换行，AND 子句整体作为一项不拆
select id from t where (city_id = 110000 and channel_name = 'app_channel' or city_id = 310000 and channel_name = 'web_channel' or city_id = 440100 and channel_name = 'mini_program' or city_id = 440300 and channel_name = 'h5_page') and dt='2024-08-01';

-- @case 纯 AND 组超长（无 OR 时拆 AND）
-- @expect 无顶层 OR 时按 AND 拆行，样式与 OR 拆分一致（AND 前缀对齐首条件）
select id from t where (first_col_name_aaa = 10000001 and second_col_name_bbb = 20000002 and third_col_name_ccc = 30000003 and fourth_col_name_ddd = 40000004 and fifth_col_name_eee = 50000005) and dt='2024-08-01';

-- @case 嵌套括号组：外层拆、内层保持整体
-- @expect 外层组按顶层 AND 拆行，内层 (a OR b OR c) 子组整体作为一项不被二次拆分
select id from t where ((first_col_name_aaa = 1 or second_col_name_bbb = 2 or third_col_name_ccc = 3) and fourth_col_name_ddd = 4 and fifth_col_name_eee = 5 and sixth_col_name_fff = 6 and seventh_col_ggg = 7) limit 10;

-- @case 闭括号后有尾随内容
-- @expect 组展开后，) 后的顶层 OR 条件另起一行与语句对齐
select id from t where (first_col_name_aaa = 10000001 or second_col_name_bbb = 20000002 or third_col_name_ccc = 30000003 or fourth_col_name_ddd = 40000004 or fifth_col_name_eee = 50000005) or fallback_flag = 1 limit 10;

-- @case CTE 内的超长组（嵌套缩进语境）
-- @expect 子查询内的条件组同样块状展开，缩进随所在层级（tab 折算 4 空格）
with base as (select id from dws.order_detail where dt='2024-08-01' and (first_channel_code = 10000001 or second_channel_code = 20000002 or third_channel_code = 30000003 or fourth_channel_code = 40000004 or fifth_channel_code = 50000005)) select count(*) as cnt from base;

-- @case 超长条件组与 IN 列表共存
-- @expect 括号条件组按连接词块状展开，IN 列表按逗号展开，二者互不干扰
select id from t where (first_col_name_aaa = 10000001 or second_col_name_bbb = 20000002 or third_col_name_ccc = 30000003 or fourth_col_name_ddd = 40000004 or fifth_col_name_eee = 50000005) and city_id in (110000,310000,440100,440300,330100,510100,420100,610100,320100,320500,500100,120000,370100,350100,430100,410100,340100,530100,520100,460100,450100,230100,220100,210100) limit 10;

-- @case 短括号组不拆（阈值边界）
-- @expect 行长未超 150 时括号组保持单行
select id from t where (a = 1 or b = 2 or c = 3) and dt='2024-08-01';

-- @case 守卫：函数参数括号不拆
-- @expect IF(...) 参数内的 AND 不触发拆分，列保持单行；条件组守卫不误伤函数调用
select id,if(flag_long_name_aaa = 1 and flag_long_name_bbb = 2 and flag_long_name_ccc = 3 and flag_long_name_ddd = 4,'aaaaaaaaaaaaaaaaaa','bbbbbbbbbbbbbbbbbb') as flag_desc from t where dt='2024-08-01';

-- @case 回归抽查：IN 子查询与 EXISTS 展开
-- @expect IN (SELECT...) 与 EXISTS (SELECT...) 均块状展开，) 独立成行
select id from t where uid in (select uid from dim.vip where level >= 3) and exists (select 1 from t2 where t2.id = t.id) and dt='2024-08-01';

-- @case 回归抽查：超长 OVER 块状相对缩进
-- @expect OVER ( 后换行，窗口子句相对表达式列 +4 缩进，) 对齐表达式起始列
select id,sum(amount) over (partition by user_id_first_col, second_partition_col, third_partition_col order by dt_long_col_name, amount_col_name rows between unbounded preceding and current row) as running_sum from t;

-- @case 回归抽查：EXTERNAL DDL 格式化
-- @expect EXTERNAL 表走 DDL 通道，列定义对齐、分区注释不断行、表级子句逐段换行
create external table if not exists dws.order_pay_detail (order_id bigint comment '订单ID',user_id bigint comment '用户ID',pay_amount decimal(16,2) comment '支付金额',pay_channel string,pay_time string) comment '订单支付明细表' partitioned by (dt string comment '业务日期') clustered by (user_id) sorted by (pay_time desc) into 8 buckets stored as orc location '/warehouse/dws/db/order_pay_detail' tblproperties ('orc.compress'='SNAPPY');

-- ============================================================
-- SQL Beautify 人工验证样例 第 4 轮（Velocity #set 指令专项）
-- ============================================================

-- @case #set 指令归一：大小写、括号空格、= 收紧、独立成行
-- @expect #set 小写，括号内侧各一空格，= 两侧无空格，每条指令独占一行且行间无空行
#SET(a='123') #set( b = '456' ) #Set(c=789)
select order_id from dws.order_detail where dt='2024-08-01' limit 100;

-- @case #set 指令：字面量为字符串或常数
-- @expect 字符串与常数原样保留；撞关键字的变量名（date）不被大写；字面量内的 = 不受影响
#set( date = '2024-08-01' )
#set( x = 'a=b' )
#set( limit_days = 30 )
select order_id from dws.order_detail where dt='2024-08-01' limit 100;

-- @case #set 指令：字符串与注释中的 #set 不受影响
-- @expect 字面量与 -- 注释里的 #set(...) 文本原样保留，不拆行不改写
select a from t where c = '#set(x=1)'; -- #set(y=2)

/* 
 * MoM Growth % = ((current month - previous month) / previous month) * 100
 * YoY Growth % = ((current month - previous year same month) / previous year same month) * 100
 * */

SELECT * FROM sales_orders WHERE order_status = 'Delivered';

SELECT *, date_trunc('month', order_date)
FROM sales_orders;

-- Monthly Revenue by order date
SELECT 
	date_trunc('month', order_date)::date month_start,
	SUM(total_amount) Revenue
FROM sales_orders
GROUP BY month_start
ORDER BY month_start;

-- Month Spine
SELECT 
	generate_series(
		(SELECT min(order_date)::date FROM sales_orders),
		(SELECT max(order_date)::date FROM sales_orders),
		INTERVAL '1 month'
		)::date ;

-- monthly revenue using month spine
WITH month_spine AS (
SELECT 
	generate_series(
		(SELECT min(order_date)::date FROM sales_orders),
		(SELECT max(order_date)::date FROM sales_orders),
		INTERVAL '1 month'
	)::date AS month_start
), revenue_date AS (
SELECT 
	date_trunc('month', order_date)::date month_start,
	SUM(total_amount) revenue
	FROM sales_orders
	GROUP BY month_start
	ORDER BY month_start
)
SELECT ms.month_start, rd.revenue
FROM month_spine ms
LEFT JOIN revenue_date rd
ON ms.month_start = rd.month_start;


-- MoM Growth % and YoY Growth %
WITH month_spine AS (
SELECT 
	generate_series(
		(SELECT min(order_date)::date FROM sales_orders),
		(SELECT max(order_date)::date FROM sales_orders),
		INTERVAL '1 month'
	)::date AS month_start
), revenue_data AS (
SELECT 
	date_trunc('month', order_date)::date month_start,
	SUM(total_amount) revenue
	FROM sales_orders
	WHERE order_status = 'Delivered'
	GROUP BY month_start
	ORDER BY month_start
)
SELECT 
	ms.month_start, 
	rd.revenue,
	round(COALESCE(((rd.revenue - lag(rd.revenue) OVER(ORDER BY ms.month_start)) / 
	lag(rd.revenue) OVER(ORDER BY ms.month_start)) * 100, 0), 2) AS "MoM_Growth_%" ,
	round(COALESCE(((rd.revenue - lag(rd.revenue, 12) OVER(ORDER BY ms.month_start)) / 
	lag(rd.revenue, 12) OVER(ORDER BY ms.month_start)) * 100, 0), 2) AS "YoY_Growth_%"
	FROM month_spine ms
	LEFT JOIN revenue_data rd
	ON ms.month_start = rd.month_start
;



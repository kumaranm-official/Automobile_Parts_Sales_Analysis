/*
FR-1  Revenue & Sales Trend Analysis   
	Establish the top-line revenue baseline and show how it moves across channel, region and
	time — the number every other module gets checked against.
*/

-- BQ01 -- Total recognised revenue by year and month, with MoM and YoY growth.
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


-- BQ02 - Average order value and order volume BY channel — Dealer vs. Retail vs. Online.
SELECT 
	channel,  
	round(avg(so.total_amount), 2) Average_order_Value,
	count(so.order_id) total_order_volume
FROM sales_orders so 
WHERE order_status = 'Delivered'
GROUP BY channel;


-- BQ03 - Revenue leaders and laggards by region.
WITH regional_data AS (
	SELECT 
		so.channel,
		coalesce(d.region, rc.region) region,
		so.total_amount 
	FROM sales_orders so
		LEFT JOIN dealers d 
			ON so.dealer_id = d.dealer_id 	
		LEFT JOIN retail_customers rc 
			ON so.customer_id = rc.customer_id 
)
SELECT
	COALESCE(region, 'Grand Total') Region,
	sum(total_amount) FILTER (WHERE channel = 'DEALER') "Dealer",
	sum(total_amount) FILTER (WHERE channel = 'RETAIL') "Retail",
	sum(total_amount) FILTER (WHERE channel = 'ONLINE') "online",
	sum(total_amount) revenue
FROM regional_data
	GROUP BY rollup(region) 
		ORDER BY grouping(region),
		revenue DESC ;


-- BQ04 - Revenue lost to cancellations, and discount rate as a % of gross.
WITH calc_table AS (
	SELECT 
		date_trunc('month', so.order_date) ::date AS month_start,
		sum(so.total_amount) FILTER (WHERE so.order_status = 'Delivered') booked_revenue,
		sum(so.total_amount) FILTER (WHERE so.order_status = 'Cancelled') cancelled_revenue,
		sum(so.discount_amount) FILTER (WHERE so.order_status = 'Delivered') discounted_amount,
		sum(so.subtotal) FILTER (WHERE so.order_status = 'Delivered') gross_amount
	FROM sales_orders so
		GROUP BY 
			month_start  
)
SELECT 
	month_start,
	booked_revenue,
	cancelled_revenue,
	round((cancelled_revenue / (booked_revenue + cancelled_revenue)) * 100, 2) cancelled_pct,
	discounted_amount,
	round((discounted_amount / gross_amount) * 100, 2) discounted_pct
FROM calc_table 
	ORDER BY month_start;

	

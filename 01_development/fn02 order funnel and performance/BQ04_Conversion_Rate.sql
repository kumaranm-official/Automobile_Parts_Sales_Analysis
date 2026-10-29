SELECT DISTINCT order_status FROM sales_orders so ;

SELECT 
	channel,
	count(*) FILTER (WHERE order_status IN ('Confirmed', 'Shipped', 'Delivered')) converted_orders,
	round(count(*) FILTER (WHERE order_status IN ('Confirmed', 'Shipped', 'Delivered')) * 100.0 / count(*),2) conversion_rate,
	count(*) FILTER (WHERE order_status = 'Cancelled') cancelled_orders,
	round(count(*) FILTER (WHERE order_status = 'Cancelled') * 100.0 / count(*),2) cancelled_rate
FROM sales_orders so 
GROUP BY channel;
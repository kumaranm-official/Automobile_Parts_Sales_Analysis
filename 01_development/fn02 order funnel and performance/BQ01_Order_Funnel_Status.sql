SELECT * FROM sales_orders so ; 

WITH order_counts AS (
SELECT 
	count(*) total_orders, 
	count(order_id) FILTER(WHERE order_status IN ('Confirmed', 'Shipped', 'Delivered')) confirmed_orders, 
	count(order_id) FILTER(WHERE order_status IN ('Shipped', 'Delivered')) shipped_orders, 
	count(order_id) FILTER(WHERE order_status = 'Delivered') delivered_orders,
	count(order_id) FILTER(WHERE order_status = 'Cancelled') cancelled_orders
FROM sales_orders so
) 
SELECT
	metrics.total_orders ,
	metrics.order_count ,
	metrics.share_percentage 
FROM order_counts oc
CROSS JOIN LATERAL (
	VALUES
		('Total Orders', total_orders, 100.0),
		('Confirmed Orders', confirmed_orders, round(confirmed_orders * 100.0 / total_orders ,2)),
		('Shipped Orders', shipped_orders, round(shipped_orders * 100.0 / total_orders , 2)),
		('Delivered Orders', delivered_orders, round(delivered_orders * 100.0 / total_orders , 2)),
		('Cancelled Orders', cancelled_orders, round(cancelled_orders * 100.0 / total_orders , 2))
	)
	AS metrics (total_orders, order_count, share_percentage)	
;


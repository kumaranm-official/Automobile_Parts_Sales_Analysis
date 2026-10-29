SELECT * FROM sales_orders so ;

-- Average Order Value and total order Volume by channels

SELECT 
	channel,  
	round(avg(so.total_amount), 2) Average_order_Value,
	count(so.order_id) total_order_volume
FROM sales_orders so 
WHERE order_status = 'Delivered'
GROUP BY channel;
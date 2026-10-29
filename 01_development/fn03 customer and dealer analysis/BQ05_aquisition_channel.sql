SELECT * FROM retail_customers rc ;

SELECT
	rc.acquisition_channel ,
	count(DISTINCT rc.customer_id ) total_orders,
	sum(so.total_amount ) FILTER (WHERE order_status = 'Delivered') total_revenue,
	round(sum(so.total_amount ) FILTER (WHERE order_status = 'Delivered') * 1.0 / 
		nullif(count(DISTINCT rc.customer_id ), 0) ,2) revenue_per_customer
FROM retail_customers rc 
	LEFT JOIN sales_orders so 
		ON so.customer_id = rc.customer_id 
			GROUP BY acquisition_channel 	
				ORDER BY revenue_per_customer DESC 
;

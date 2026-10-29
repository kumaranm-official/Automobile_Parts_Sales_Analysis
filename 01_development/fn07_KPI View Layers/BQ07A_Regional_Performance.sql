CREATE OR REPLACE VIEW vw_regional_performance AS 
	WITH regional_orders AS (
	SELECT
		w.region ,
		sum(so.total_amount ) revenue ,
		count(*) delivered_orders ,
		round(sum(so.total_amount ) * 100.0 / NULLIF(count(*), 0) ,2) avg_order_value
	FROM 
		warehouses w 
	JOIN 
		sales_orders so ON so.warehouse_id = w.warehouse_id AND so.order_status = 'Delivered'
	GROUP BY 
		w.region
	)
	SELECT 
		*,
		row_number() over(ORDER BY avg_order_value desc) AS rn
	FROM regional_orders
	LIMIT 3
	
	;
	
	
	SELECT * FROM vw_regional_performance vrp ;
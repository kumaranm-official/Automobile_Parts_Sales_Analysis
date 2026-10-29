CREATE OR REPLACE VIEW vw_warehouse_performance AS 
	WITH warehouse_utilization AS (
	SELECT 
		w.warehouse_id ,
		w.warehouse_name ,
		w.capacity_units ,
		count(so.order_id) total_orders ,
		round(count(so.order_id) * 100.0 / w.capacity_units ,2) utilization_rate
	FROM 
		warehouses w
	JOIN 
		sales_orders so ON so.warehouse_id = w.warehouse_id 
	GROUP BY 
		w.warehouse_id , w.warehouse_name , w.capacity_units 
	)
	SELECT 
		* ,
		row_number() over(ORDER BY utilization_rate DESC ) rnk
	FROM 
		warehouse_utilization 
;

SELECT * FROM vw_warehouse_performance vwp ;

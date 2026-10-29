SELECT * FROM sales_order_lines sol ;

SELECT * FROM part_vehicle_compatibility pvc ;

SELECT * FROM vehicle_model_years vmy ;

SELECT * FROM vehicle_models vm ;

-- --------------------------------

SELECT 
	vmk.make_name ,
	vm.model_name ,
	sum(sol.line_total ) revenue
FROM 
	sales_order_lines sol 
JOIN 
	sales_orders so ON so.order_id = sol.order_id AND so.order_status = 'Delivered'
JOIN	
	part_vehicle_compatibility pvc ON pvc.part_id = sol.part_id 
JOIN 
	vehicle_model_years vmy ON vmy.model_year_id = pvc.model_year_id 
JOIN 
	vehicle_models vm ON vm.model_id = vmy.model_id 
JOIN 
	vehicle_makes vmk ON vmk.make_id = vm.make_id
GROUP BY
	vmk.make_name , vm.model_name 
ORDER BY
	revenue DESC 
LIMIT 25
	




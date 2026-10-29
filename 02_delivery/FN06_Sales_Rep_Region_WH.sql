/*
FR-6  Sales Performance - Representative, Regions and Warehouses       

	Rank internal sales performance by employee and warehouse to identify who is driving — or dragging on — revenue.
*/

-- BQ01 - List the top 10 sales representatives ranked by realised revenue.
WITH employees_revenue AS (
SELECT
	e.employee_id ,
	e.first_name || ' ' || e.last_name AS full_name , 
	sum(so.total_amount ) revenue
FROM 
	employees e 
JOIN 	
	sales_orders so ON so.employee_id = e.employee_id AND so.order_status = 'Delivered'
GROUP BY 
	e.employee_id ,
	full_name
),
employees_rank AS (
	SELECT 
		*,
		dense_rank() over(ORDER BY revenue DESC) rnk
	FROM
		employees_revenue 
)
SELECT 
	*
FROM 
	employees_rank 
WHERE 
	rnk <= 10
ORDER BY 
	rnk
	
	
	
-- BQ02 - Rank top 3 regions based on average order value.

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



-- BQ03 - List all warehouses ranked by utilization rate (highest first).
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
FROM warehouse_utilization 



-- BQ04 - Find and list out warehouses by return rate.
WITH warehouse_returns AS (
SELECT 
	w.warehouse_id ,
	w.warehouse_name ,
	so.order_id ,
	r.return_id ,
	CASE WHEN r.status IN ('Approved', 'Refunded') THEN TRUE ELSE FALSE END AS return_status
FROM 
	warehouses w 
JOIN 
	sales_orders so ON so.warehouse_id = w.warehouse_id AND so.order_status = 'Delivered'
LEFT JOIN 
	"returns" r ON r.order_id = so.order_id 
)
SELECT 
	warehouse_id,
	warehouse_name ,
	count(order_id) delivered_orders ,
	count(return_id ) FILTER (WHERE return_status ) returned_orders ,
	round(count(return_id ) FILTER (WHERE return_status ) * 100.0 / nullif(count(order_id) ,0) ,2) return_rate
FROM warehouse_returns 
GROUP BY 
	warehouse_id , warehouse_name 
ORDER BY 
	return_rate DESC 
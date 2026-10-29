SELECT * FROM sales_orders so ;
SELECT * FROM employees e ;

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
	
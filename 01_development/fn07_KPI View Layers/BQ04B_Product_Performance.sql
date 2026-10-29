CREATE OR REPLACE VIEW vw_product_performance AS 
	WITH part_revenue AS (
		SELECT 
			p.part_id ,
			p.part_name ,
			sum(sol.line_total ) revenue
		FROM 
			parts p 
		JOIN 
			sales_order_lines sol ON sol.part_id = p.part_id 
		JOIN 
			sales_orders so ON so.order_id = sol.order_id AND so.order_status = 'Delivered'
		GROUP BY
			p.part_id , p.part_name 
		) , 
		ranked AS (
		SELECT 
			*,
			sum(revenue ) over(ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) running_revenue ,
			sum(revenue ) OVER () total_revenue , 
			ROW_NUMBER() over(ORDER BY revenue DESC ) revenue_rank
		FROM 
			part_revenue 
		)
		SELECT 
			r.part_id ,
			r.part_name ,
			r.running_revenue ,
			round(r.running_revenue * 100.0 / NULLIF(r.total_revenue, 0) ,2) AS cumulative_pct
		FROM 
			ranked r
		LIMIT 100
;



SELECT * FROM vw_product_performance vpp ;
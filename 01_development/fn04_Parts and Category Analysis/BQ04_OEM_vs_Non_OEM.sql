SELECT * FROM manufacturers m ;

WITH line_economy AS (
SELECT 
	sol.order_id ,
	sol.part_id ,
	p.category_id ,
	p.manufacturer_id ,
	sol.line_total ,
	sol.quantity * ph.cost_price cost_on_sale
FROM sales_order_lines sol 
	JOIN parts p ON p.part_id  = sol.part_id 
	JOIN sales_orders so ON sol.order_id = so.order_id AND so.order_status = 'Delivered'
	JOIN LATERAL (
			SELECT 
				ph.cost_price 
			FROM 
				price_history ph	
			WHERE 
				ph.part_id = sol.part_id AND ph.effective_date <= so.order_date 
			ORDER BY 
				ph.effective_date DESC 
			LIMIT 1
	) ph ON TRUE 
),
oem_table AS (
	SELECT 
		le.* ,
		CASE WHEN m.is_oem = TRUE THEN 'OEM' ELSE 'Non-OEM' END as oem_category
	FROM 
		line_economy le
	JOIN 
		manufacturers m ON m.manufacturer_id = le.manufacturer_id 
)
SELECT 
	oem_category ,
	count(DISTINCT part_id) total_parts ,
	sum(line_total ) revenue,
	sum(line_total - cost_on_sale ) gross_margin ,
	round(sum(line_total - cost_on_sale ) * 100.0 / sum(line_total ) ,2) gross_margin_pct 
FROM
	oem_table 
GROUP BY
	oem_category ;
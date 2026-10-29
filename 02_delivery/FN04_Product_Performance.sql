/*
FN-4    Product & Category Sales Performance
	Identify what sells, what's actually profitable once cost is accounted for, and how pricing
	decisions have moved either.
 */


-- BQ01 - Analyze revenue and gross margin by category and sub-category using the part category hierarchy.
WITH RECURSIVE category_tree AS (
	SELECT 
		pc.category_id ,
		pc.parent_category_id ,
		pc.category_name ,
		pc.category_id AS parent_id,
		pc.category_name AS parent_name
	FROM 
		part_categories pc 	
	WHERE 
		pc.category_level = 1
	UNION ALL
	SELECT 
		pc2.category_id ,
		pc2.parent_category_id ,
		pc2.category_name ,
		ct.parent_id,
		ct.parent_name
	FROM 
		part_categories pc2 
	JOIN 
		category_tree ct ON pc2.parent_category_id = ct.category_id 
),
line_economy AS (
	SELECT 
		sol.order_id ,
		sol.part_id ,
		p.category_id ,
		sol.line_total ,
		sol.quantity * ph.cost_price cost_on_sale 
	FROM 
		sales_order_lines sol 
	JOIN 
		parts p ON p.part_id  = sol.part_id 
	JOIN 
		sales_orders so ON sol.order_id = so.order_id AND so.order_status = 'Delivered'
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
)
SELECT
	ct.parent_name AS parent_category ,
	ct.category_name AS sub_category ,
	round(sum(le.line_total ) ,2) revenue ,
	round(sum(le.line_total - le.cost_on_sale) ,2) profit ,
	round(sum(le.line_total - le.cost_on_sale) * 100.0 / sum(le.line_total) ,2) profit_margin_pct
FROM 
	category_tree ct
JOIN 
	line_economy le ON le.category_id = ct.category_id 
GROUP BY 
	ct.parent_name , ct.category_name 
ORDER BY 
	profit_margin_pct DESC ;


-- BQ02 - Rank parts by revenue and calculate their cumulative contribution to total revenue, showing the top 100 parts by revenue.
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
FROM part_revenue 
)
SELECT 
	r.part_id ,
	r.part_name ,
	r.running_revenue ,
	round(r.running_revenue * 100.0 / NULLIF(r.total_revenue, 0) ,2) AS cumulative_pct
FROM ranked r
LIMIT 100
;


--BQ03 - Identify the number and percentage of parts that collectively generate 80% of total revenue.
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
FROM part_revenue 
),
cumulative_revenue AS (
SELECT 
	r.part_id ,
	r.part_name ,
	r.running_revenue ,
	round(r.running_revenue * 100.0 / NULLIF(r.total_revenue, 0) ,2) AS cumulative_pct
FROM ranked r
)
SELECT 
	count(*) FILTER (WHERE cumulative_pct <= 80 ) AS total_parts ,
	round(count(*) FILTER (WHERE cumulative_pct <= 80 ) * 100.0 / count(*) ,2) AS share_pct
FROM cumulative_revenue 
;


-- BQ04 - Compare OEM vs non-OEM manufacturers BY distinct parts sold, revenue, gross margin, and margin percentage.
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

-- BQ05 - Identify the top 25 vehicle makes AND models by revenue generated FROM compatible parts.
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
	




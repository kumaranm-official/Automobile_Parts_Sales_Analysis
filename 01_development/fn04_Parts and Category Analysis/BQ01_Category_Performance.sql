SELECT * FROM parts p ;
SELECT * FROM part_categories pc ;

-- Anchor Query
WITH RECURSIVE category_tree AS (
SELECT 
	pc.category_id ,
	pc.parent_category_id ,
	pc.category_name ,
	pc.category_id AS parent_id,
	pc.category_name AS parent_name
	FROM part_categories pc 	
		WHERE pc.category_level = 1
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
)
SELECT * FROM category_tree ct ;

-- Line Items Economy

SELECT * FROM sales_order_lines sol ;

SELECT * FROM parts p ;

SELECT * FROM price_history ph ;


SELECT 
	sol.order_id ,
	sol.part_id ,
	p.category_id ,
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

			
-- combining category tree and line economy
			
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

		




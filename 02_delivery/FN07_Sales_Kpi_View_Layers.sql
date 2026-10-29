/*
FR-7  Executive Sales KPI View Layer                                      MUST

Consolidate FR-1 through FR-6 into a small, reusable set of SQL views a Sales Operations leadership 
audience could be handed directly — the deliverable the rest of this document builds toward.
*/


--BQ01 - Monthly Sales Performance Growth
CREATE OR REPLACE VIEW vw_monthly_sales_performance AS 
	WITH month_spine AS (
		SELECT 
			generate_series(
				(SELECT min(order_date)::date FROM sales_orders),
				(SELECT max(order_date)::date FROM sales_orders),
				INTERVAL '1 month'
			)::date AS month_start
	), 
	revenue_data AS (
		SELECT 
			date_trunc('month', order_date)::date month_start,
			SUM(total_amount) revenue
		FROM 
			sales_orders
		WHERE 
			order_status = 'Delivered'
		GROUP BY 
			month_start
		ORDER BY 
			month_start
	)
		SELECT 
			ms.month_start, 
			rd.revenue,
			round(COALESCE(((rd.revenue - lag(rd.revenue) OVER(ORDER BY ms.month_start)) / 
				lag(rd.revenue) OVER(ORDER BY ms.month_start)) * 100, 0), 2) AS "MoM_Growth_%" ,
			round(COALESCE(((rd.revenue - lag(rd.revenue, 12) OVER(ORDER BY ms.month_start)) / 
				lag(rd.revenue, 12) OVER(ORDER BY ms.month_start)) * 100, 0), 2) AS "YoY_Growth_%"
		FROM 
			month_spine ms
		LEFT JOIN 
			revenue_data rd ON ms.month_start = rd.month_start
;

SELECT * FROM vw_monthly_sales_performance ;


-- BQ02 - Customer Segments
CREATE OR REPLACE VIEW vw_customer_segments AS 
	WITH business_latest_order AS (
		SELECT 
			max(order_date)::date business_latest_order_date
		FROM 
			sales_orders
	), 
	customer_data AS (
		SELECT 
			so.customer_id,
			max(so.order_date)::date AS customer_latest_order_date,
			count(*) frequency,
			sum(so.total_amount) monetary
	FROM 
		sales_orders so 
	WHERE 
		so.customer_id IS NOT NULL 
	GROUP BY 
		customer_id 
	), 
	rfm_values AS (
		SELECT 
			cd.customer_id ,
			blo.business_latest_order_date - cd.customer_latest_order_date AS recency,
			cd.frequency ,
			cd.monetary 
		FROM 
			customer_data cd
		CROSS JOIN 
			business_latest_order blo
	), 
	rfm_scores AS (
		SELECT *,
			ntile(5) over(ORDER BY recency DESC) recency_score,
			ntile(5) over(ORDER BY frequency ASC) frequency_score,
			ntile(5) OVER(ORDER BY monetary ASC) monetary_score,
			ntile(10) OVER(ORDER BY monetary ASC) AS decile_value
		FROM 
			rfm_values 
	)
	SELECT 
		rs.customer_id ,
		rs.recency_score + rs.frequency_score + rs.monetary_score AS rfm_score,
		CASE 
			WHEN rs.recency_score = 5 AND rs.frequency_score = 5 AND rs.monetary_score = 5 THEN 'Champion'
			WHEN rs.recency_score >= 4 AND rs.frequency_score >= 3 THEN 'Loyal'
			WHEN rs.recency_score >= 2 AND rs.frequency_score <= 2 THEN 'Risk'
			WHEN rs.recency_score = 1 AND rs.frequency_score = 1 THEN 'Risk'
			ELSE 'Intermediate'
		END AS rfm_segments
	FROM 
		rfm_scores rs
	WHERE 
		rs.decile_value = 10
	ORDER BY 
		rfm_score DESC
;

SELECT * FROM vw_customer_segments ;

-- BQ03 - Dealers Performance by Credit Utilization
CREATE OR REPLACE VIEW vw_dealers_performance AS 
	WITH dealers_data AS (
		SELECT 
			d.dealer_tier ,
			d.dealer_id ,
			d.credit_limit ,
			sum(so.total_amount ) total_revenue
		FROM 
			dealers d 
		LEFT JOIN 
			sales_orders so ON so.dealer_id = d.dealer_id 
		WHERE 
			so.dealer_id IS NOT NULL AND so.order_status = 'Delivered'
		GROUP BY 
			d.dealer_tier ,
			d.dealer_id ,
			d.credit_limit 
		)
		SELECT 
			dealer_tier ,
			round(avg(credit_limit ) ,2) avg_credit_limit,
			round(avg(total_revenue ) ,2) avg_revenue,
			round(avg(total_revenue ) * 100.0 / nullif(avg(credit_limit), 0) ,2) credit_usage
		FROM 
			dealers_data 
		GROUP BY 
			dealer_tier
;

SELECT * FROM vw_dealers_performance ;

-- BQ04 - Product & Category Performance
CREATE MATERIALIZED VIEW mvw_category_performance AS 
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
		profit_margin_pct DESC 
;

SELECT * FROM mvw_category_performance mcp ;

--

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



-- BQ05 - Sales Order Funnel Performance
CREATE OR REPLACE VIEW vw_order_funnel_performance AS 
	WITH order_counts AS (
		SELECT 
			count(*) total_orders, 
			count(order_id) FILTER(WHERE order_status IN ('Confirmed', 'Shipped', 'Delivered')) confirmed_orders, 
			count(order_id) FILTER(WHERE order_status IN ('Shipped', 'Delivered')) shipped_orders, 
			count(order_id) FILTER(WHERE order_status = 'Delivered') delivered_orders,
			count(order_id) FILTER(WHERE order_status = 'Cancelled') cancelled_orders
		FROM 
			sales_orders so
	) 
		SELECT
			metrics.total_orders ,
			metrics.order_count ,
			metrics.share_percentage 
		FROM 
			order_counts oc
		CROSS JOIN LATERAL (
			VALUES
				('Total Orders', total_orders, 100.0),
				('Confirmed Orders', confirmed_orders, round(confirmed_orders * 100.0 / total_orders ,2)),
				('Shipped Orders', shipped_orders, round(shipped_orders * 100.0 / total_orders , 2)),
				('Delivered Orders', delivered_orders, round(delivered_orders * 100.0 / total_orders , 2)),
				('Cancelled Orders', cancelled_orders, round(cancelled_orders * 100.0 / total_orders , 2))
			)
			AS metrics (total_orders, order_count, share_percentage)	
;

SELECT * FROM vw_order_funnel_performance vofp  ;


-- BQ06 - Sales Representatives Performance
CREATE OR REPLACE VIEW vw_sales_rep_performance AS 
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
;


SELECT * FROM vw_sales_rep_performance vsrp  ;




-- BQ07 - Regional & Warehouse Performance
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
	
--

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





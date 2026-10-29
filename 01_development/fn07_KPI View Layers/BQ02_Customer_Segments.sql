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
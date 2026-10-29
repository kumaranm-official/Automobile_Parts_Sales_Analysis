/*
 * customer lifetime value = average order value * purchase frequency * life span
 * aov = revenue / total orders
 * pf = total orders / time period
 * ls = latest order date - first order date
 * */

----------------------------------------------------------------------------------------------------------------------
-- creating rfm segment table as view.
CREATE VIEW rfm_segment_table AS (
	WITH business_latest_order AS (
		SELECT max(order_date)::date business_latest_order_date
		FROM sales_orders
	), customer_data AS (
		SELECT 
		so.customer_id,
		max(so.order_date)::date AS customer_latest_order_date,
		count(*) frequency,
		sum(so.total_amount) monetary
	FROM sales_orders so 
	WHERE so.customer_id IS NOT NULL 
	GROUP BY customer_id 
	), rfm_values AS (
	SELECT 
		cd.customer_id ,
		blo.business_latest_order_date - cd.customer_latest_order_date AS recency,
		cd.frequency ,
		cd.monetary 
	FROM customer_data cd
	CROSS JOIN business_latest_order blo
	), rfm_scores AS (
	SELECT *,
		ntile(5) over(ORDER BY recency DESC) recency_score,
		ntile(5) over(ORDER BY frequency ASC) frequency_score,
		ntile(5) OVER(ORDER BY monetary ASC) monetary_score,
		ntile(10) OVER(ORDER BY monetary ASC) AS decile_value
	FROM rfm_values 
	)
	SELECT 
		rs.customer_id ,
		rs.recency_score + rs.frequency_score + rs.monetary_score AS rfm_score,
		CASE 
			WHEN rs.recency_score = 5 AND rs.frequency_score = 5 AND rs.monetary_score = 5 THEN 'Champion'
			WHEN rs.recency_score >= 4 AND rs.frequency_score >= 3 THEN 'Loyal'
			WHEN rs.recency_score >= 2 AND rs.frequency_score <= 2 THEN 'Risk'
			WHEN rs.recency_score = 1 AND rs.frequency_score = 1 THEN 'Lost'
			ELSE 'Intermediate'
		END AS rfm_segments
	FROM rfm_scores rs
);


 ---------------------------------------------------------------------------------------------------------------------

CREATE VIEW customer_clv AS (
WITH metrics AS ( 
	SELECT 
		so.customer_id ,
		sum(so.total_amount ) AS revenue,
		count(*) AS total_orders,
		round((max(so.order_date ::date) - min(so.order_date ::date)) * 1.0 / 365.25, 2) life_span
	FROM sales_orders so 
	GROUP BY customer_id 
), customer_clv AS (
SELECT 
	customer_id ,
	round(revenue / NULLIF(total_orders, 0), 2) AS AoV,
	round(total_orders / NULLIF(life_span, 0), 2) AS purchase_frequency,
	life_span ,
	round((revenue / NULLIF(total_orders, 0)) * (total_orders / NULLIF(life_span, 0)) * life_span , 2) CLV
FROM metrics
)
SELECT customer_id, clv FROM customer_clv
) ;

-----------------------------------------------------------------------------------------------------------------------
-- CLV by rfm segments

SELECT 
	rst.rfm_segments ,
	round(avg(CLV), 2) AS clv
FROM rfm_segment_table rst 
LEFT JOIN customer_clv cc 
ON cc.customer_id = rst.customer_id 
GROUP BY rfm_segments ;

-- CLV by customer
SELECT * FROM customer_clv;

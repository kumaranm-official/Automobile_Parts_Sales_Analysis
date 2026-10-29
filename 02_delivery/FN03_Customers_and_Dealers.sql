/*FR-3  Customer & Dealer Sales Analytics                           

	Turn the two customer masters — dealers and retail customers — into a segmentation the
	business can actually act on.
*/

-- BQ01 - RFM segments for retail customers — who sits in the top decile?
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
		WHEN rs.recency_score = 1 AND rs.frequency_score = 1 THEN 'Risk'
		ELSE 'Intermediate'
	END AS rfm_segments
FROM rfm_scores rs
WHERE rs.decile_value = 10
ORDER BY rfm_score desc;


--BQ02 - An approximate CLV per customer and per segment.
SELECT 
	rst.rfm_segments ,
	round(avg(CLV), 2) AS clv
FROM rfm_segment_table rst 
LEFT JOIN customer_clv cc 
ON cc.customer_id = rst.customer_id 
GROUP BY rfm_segments ;

-- BQ03 - Cohort retention by signup month — what share of a cohort is still ordering N months on?
WITH dates AS (
    SELECT
        (SELECT MIN(signup_date) FROM retail_customers) AS min_signup_date,
        (SELECT MAX(order_date) FROM sales_orders) AS max_order_date
),
cohort_months AS (
    SELECT
        generate_series(
            date_trunc('month', min_signup_date),
            date_trunc('month', max_order_date),
            INTERVAL '1 month'
        )::date AS cohort_month,
        date_trunc('month', max_order_date)::date AS last_order_month
    FROM dates
),
signup_months AS (
    SELECT
        *,
        (
            EXTRACT(YEAR FROM last_order_month)
            - EXTRACT(YEAR FROM cohort_month)
        ) * 12
        +
        (
            EXTRACT(MONTH FROM last_order_month)
            - EXTRACT(MONTH FROM cohort_month)
        ) AS signup_since_months
    FROM cohort_months
), 
signup_months_table AS (
	SELECT *, 
		generate_series(1, signup_since_months) AS signup_since
	FROM signup_months
), 
cohort_customers_table AS (
	SELECT 
		smt.cohort_month, 
		smt.signup_since,
		rc.customer_id 
	FROM signup_months_table smt
		LEFT JOIN 
			retail_customers rc 
				ON smt.cohort_month = date_trunc('month', rc.signup_date)
), 
total_customers_cohort AS (
	SELECT *,
		count(customer_id) over(PARTITION BY cohort_month , signup_since) cohort_customers
	FROM cohort_customers_table
), customer_orders AS (
	SELECT 
		tcc.*,
		count(so.*) total_orders
	FROM total_customers_cohort tcc 
		LEFT JOIN sales_orders so 
			ON date_trunc('month', so.order_date) = tcc.cohort_month + INTERVAL '1 month' * (signup_since - 1)
				GROUP BY 
					tcc.cohort_month , 
					tcc.signup_since,  
					tcc.customer_id , 
					tcc.cohort_customers 
), cohort_retention AS (
SELECT 
	co.cohort_month ,
	co.signup_since ,
	co.cohort_customers ,
	count(co.customer_id ) retained_customers
FROM customer_orders co
	WHERE co.total_orders != 0
		GROUP BY
			co.cohort_month ,
			co.signup_since ,
			co.cohort_customers
)
SELECT 
	cohort_month ,
	signup_since ,
	round(retained_customers * 100.0 / NULLIF (cohort_customers , 0) ,2) retained_pct
FROM cohort_retention
;


-- BQ04 - How does dealer tier performance differ in terms of average credit limit, average delivered revenue per dealer, and credit utilisation?
WITH dealers_data AS (
SELECT 
	d.dealer_tier ,
	d.dealer_id ,
	d.credit_limit ,
	sum(so.total_amount ) total_revenue
FROM dealers d 
	LEFT JOIN sales_orders so 
		ON so.dealer_id = d.dealer_id 
			WHERE so.dealer_id IS NOT NULL AND so.order_status = 'Delivered'
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
FROM dealers_data 
	GROUP BY 
		dealer_tier
;


-- BQ05 - Which acquisition_channel produces the highest-value customers?
SELECT
	rc.acquisition_channel ,
	count(DISTINCT rc.customer_id ) total_orders,
	sum(so.total_amount ) FILTER (WHERE order_status = 'Delivered') total_revenue,
	round(sum(so.total_amount ) FILTER (WHERE order_status = 'Delivered') * 1.0 / 
		nullif(count(DISTINCT rc.customer_id ), 0) ,2) revenue_per_customer
FROM retail_customers rc 
	LEFT JOIN sales_orders so 
		ON so.customer_id = rc.customer_id 
			GROUP BY acquisition_channel 	
				ORDER BY revenue_per_customer DESC 
;


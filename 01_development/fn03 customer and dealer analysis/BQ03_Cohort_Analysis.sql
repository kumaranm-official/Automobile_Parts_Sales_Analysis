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
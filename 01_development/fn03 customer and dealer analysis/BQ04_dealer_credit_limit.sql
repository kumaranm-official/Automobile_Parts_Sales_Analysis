SELECT * FROM dealers d ;

SELECT * FROM sales_orders so ;

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
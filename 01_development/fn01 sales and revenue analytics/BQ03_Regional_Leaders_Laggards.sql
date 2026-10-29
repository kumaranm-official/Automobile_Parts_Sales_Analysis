SELECT * FROM sales_orders so;

SELECT * FROM dealers d ;

SELECT * FROM retail_customers rc ;

-- Regional Leaders and Laggards

SELECT 
	so.channel,
	coalesce(d.region, rc.region),
	so.total_amount 
FROM sales_orders so
	LEFT JOIN dealers d 
		ON so.dealer_id = d.dealer_id 
	LEFT JOIN retail_customers rc 
		ON so.customer_id = rc.customer_id;

-- results in channel x region matrix
WITH regional_data AS (
	SELECT 
		so.channel,
		coalesce(d.region, rc.region) region,
		so.total_amount 
	FROM sales_orders so
		LEFT JOIN dealers d 
			ON so.dealer_id = d.dealer_id 	
		LEFT JOIN retail_customers rc 
			ON so.customer_id = rc.customer_id 
)
SELECT
	COALESCE(region, 'Grand Total') Region,
	sum(total_amount) FILTER (WHERE channel = 'DEALER') "Dealer",
	sum(total_amount) FILTER (WHERE channel = 'RETAIL') "Retail",
	sum(total_amount) FILTER (WHERE channel = 'ONLINE') "online",
	sum(total_amount) revenue
FROM regional_data
	GROUP BY rollup(region) 
		ORDER BY grouping(region),
		revenue DESC ;


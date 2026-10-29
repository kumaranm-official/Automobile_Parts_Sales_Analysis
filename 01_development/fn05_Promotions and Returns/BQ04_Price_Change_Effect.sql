SELECT * FROM price_history ph ;

select * FROM sales_order_lines sol;

WITH previous_price_table AS (
SELECT 
	ph.part_id ,
	ph.effective_date change_date,
	ph.list_price current_price,
	lag(ph.list_price ) over( PARTITION BY part_id ORDER BY ph.effective_date ) previous_price
FROM 
	price_history ph 
) ,
price_change_table AS (
	SELECT 
	*
	FROM 
		previous_price_table
	WHERE 
		previous_price IS NOT NULL AND previous_price != current_price
)
SELECT 
	pct.* ,
	round((pct.current_price - pct.previous_price ) * 100.0 / pct.previous_price ,2) price_change_pct , 
	COALESCE(sum(sol.quantity ) FILTER 
		(
			WHERE 
				so.order_date < pct.change_date AND 
				so.order_date >= pct.change_date - INTERVAL '30days'
		) , 0)
		AS 
			volume_before_30days ,
	COALESCE(sum(sol.quantity ) FILTER 
		(
			WHERE 
				so.order_date > pct.change_date AND 
				so.order_date <= pct.change_date + INTERVAL '30days'
		) , 0)
		AS 
			volume_after_30days
FROM 
	price_change_table pct
JOIN 
	sales_order_lines sol ON sol.part_id = pct.part_id
JOIN 
	sales_orders so ON so.order_id = sol.order_id AND so.order_status = 'Delivered'
GROUP BY 
	pct.part_id , pct.change_date , pct.current_price , pct.previous_price 
ORDER BY 	
	pct.part_id , pct.change_date 
	
/*
FR-5  Promotions & Returns Impact on Sales                              SHOULD

Quantify what promotional discounting is actually buying the business in incremental sales,
and how much return activity is eroding net revenue.
*/


-- BQ01 - Promo-code redemption rate and average discount depth (discount_amount ÷ subtotal) by promotion.
WITH total_orders AS (
	SELECT 
		count(so.*) delivered_orders
	FROM
		sales_orders so 
	WHERE 
		so.order_status = 'Delivered'
)
SELECT 
	pr.promotion_id ,
	pr.promo_code ,
	pr.discount_type ,
	pr.discount_value ,
	count(so.order_id ) redemption_count ,
	round(count(so.order_id ) * 100.0 / NULLIF(tot.delivered_orders, 0) ,2) AS redemption_rate ,
	round(sum(so.discount_amount ) * 100 / NULLIF(sum(so.subtotal) , 0), 2) AS avg_discount_depth
FROM
	promotions pr
LEFT JOIN 
	sales_orders so ON pr.promotion_id = so.promotion_id AND so.order_status = 'Delivered'
CROSS JOIN
	total_orders tot	
GROUP BY 
	pr.promotion_id , pr.promo_code , pr.discount_type , pr.discount_value , tot.delivered_orders 
ORDER BY 
	redemption_rate DESC , avg_discount_depth ASC 
	
-- BQ02 - Does promoted order value/volume outperform non-promoted, net of the discount given?
SELECT 
	CASE 
		WHEN so.promotion_id IS NOT NULL THEN 'Promoted' ELSE 'Not Promoted'
	END AS promo_flag ,
	count(*) order_volume ,
	round(avg(so.subtotal ) ,2) avg_gross_value , 
	round(avg(so.discount_amount ) ,2) avg_discount_value , 
	round(avg(so.total_amount ) ,2) avg_net_value
FROM 
	sales_orders so 
WHERE 
	so.order_status = 'Delivered'
GROUP BY 
	promo_flag 
	
	
-- BQ03 - Return rate by category and channel, and its dollar impact on net sales (refund_amount).
WITH return_orders AS (
SELECT 
	sol.* ,
	so.channel ,
	pc.category_name ,
	CASE WHEN r.status IN ('Approved', 'Refunded') THEN TRUE ELSE FALSE END AS refund_status ,
	CASE WHEN r.status IN ('Approved', 'Refunded') THEN rl.refund_amount ELSE 0 END AS refund_amount
FROM sales_order_lines sol 
JOIN sales_orders so ON so.order_id = sol.order_id AND so.order_status = 'Delivered'
JOIN parts p ON p.part_id = sol.part_id 
JOIN part_categories pc ON pc.category_id = p.category_id 
LEFT JOIN 
	return_lines rl ON rl.order_line_id = sol.order_line_id 
LEFT JOIN 
	"returns" r ON r.return_id = rl.return_id 
)
SELECT
	COALESCE(ro.channel , 'All Channels') channel ,
	coalesce(ro.category_name , 'All Categories') category_name ,
	count(*) delivered_orders ,
	count(*) FILTER (WHERE refund_status) AS returned_orders ,
	round(count(*) FILTER (WHERE refund_status) * 100.0 / count(*) ,2) return_rate ,
	sum(refund_amount) total_refund_amount , 
	round(sum(refund_amount) * 100.0 / NULLIF(sum(line_total) , 0) ,2) refund_rate
FROM 
	return_orders ro 
GROUP BY 
	GROUPING SETS (
	(channel , category_name ) ,
	(channel) ,
	(category_name)
	)
ORDER BY 
	ro.channel , ro.category_name
	
	
	
--  PRICE CHANGE EFFECT
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
	
	
	
-- BQ04 Most common return reasons, and which products or channels concentrate them.
SELECT 
	r.reason ,
	so.channel ,
	count(*) total_reason
FROM "returns" r 
JOIN 
	sales_orders so ON so.order_id = r.order_id 
GROUP BY
	r.reason , so.channel
ORDER BY 
	total_reason DESC 
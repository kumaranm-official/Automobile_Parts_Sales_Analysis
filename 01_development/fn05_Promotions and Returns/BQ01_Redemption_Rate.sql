SELECT * FROM promotions p ;
SELECT * FROM sales_orders so ;

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
	
	
/*
	High redemption rate , Low discount depth  --> high preference
	high redemption rate , high discount depth --> 2nd preference 
	Low redemption rate , low discount depth --> 3rd preference 
	low redemption rate , high discount depth --> not preferred.
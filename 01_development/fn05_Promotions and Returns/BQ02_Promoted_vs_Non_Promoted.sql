SELECT * FROM sales_orders so ;

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
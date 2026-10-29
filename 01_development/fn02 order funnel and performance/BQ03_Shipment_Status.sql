SELECT * FROM shipments;

-- order status x shipment status
SELECT 
	DISTINCT so.order_status ,
	s.shipment_status 
FROM sales_orders so 
LEFT JOIN shipments s
	ON so.order_id = s.order_id ;

-- =================================================

WITH shipping_table AS (
	SELECT 
		so.channel ,
		coalesce(d.region, rc.region) region,
		s.shipment_status 
	FROM sales_orders so
	LEFT JOIN dealers d 
		ON so.dealer_id = d.dealer_id 
	LEFT JOIN retail_customers rc 
		ON so.customer_id  = rc.customer_id
	LEFT JOIN shipments s
		ON s.order_id = so.order_id 
	WHERE so.order_status IN ('Delivered', 'Shipped')
) 
SELECT
	channel,
	region,
	count(*) qualified_orders,
	count(*) FILTER (WHERE shipment_status = 'Delayed') delayed_orders,
	round(count(*) FILTER (WHERE shipment_status = 'Delayed') * 100.0 / count(*) ,2) delayed_pct,
	count(*) FILTER (WHERE shipment_status = 'Returned') Returned_orders,
	round(count(*) FILTER (WHERE shipment_status = 'Returned') * 100.0 / count(*) ,2) Returned_pct
FROM shipping_table 
GROUP BY channel, region;
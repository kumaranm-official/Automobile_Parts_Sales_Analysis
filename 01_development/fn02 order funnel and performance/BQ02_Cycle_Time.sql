SELECT * FROM sales_orders so;
SELECT * FROM shipments s ;

-- Ensuring no duplicate order details.
SELECT 
	order_id,
	count(*)
FROM sales_orders so 
GROUP BY order_id 
HAVING count(*) > 1;

-- Calculating Shipping Cycle
SELECT 
	so.order_id,
	so.channel, 
	so.order_date ::date,
	s.ship_date ::date,
	s.ship_date - so.order_date ::date no_of_days_to_ship 
FROM sales_orders so 
LEFT JOIN shipments s 
ON so.order_id = s.order_id
WHERE s.ship_date IS NOT NULL 
ORDER BY order_id ;
	

-- Calculating delivery Cycle
SELECT 
	so.order_id,
	so.channel, 
	so.order_date ::date,
	s.delivery_date ::date,
	s.delivery_date - so.order_date ::date no_of_days_to_deliver 
FROM sales_orders so 
LEFT JOIN shipments s 
ON so.order_id = s.order_id
WHERE s.delivery_date IS NOT NULL 
ORDER BY order_id ;



WITH ship_cycle AS (
	SELECT 
		so.order_id,
		so.channel, 
		so.order_date ::date,
		s.ship_date ::date,
		s.ship_date - so.order_date ::date no_of_days_to_ship 
	FROM sales_orders so 
	LEFT JOIN shipments s 
	ON so.order_id = s.order_id
	WHERE s.ship_date IS NOT NULL 
	ORDER BY order_id 
), 
delivery_cycle AS (
	SELECT 
		so.order_id,
		so.channel, 
		so.order_date ::date,
		s.delivery_date ::date,
		s.delivery_date - so.order_date ::date no_of_days_to_deliver 
	FROM sales_orders so 
	LEFT JOIN shipments s 
	ON so.order_id = s.order_id
	WHERE s.delivery_date IS NOT NULL 
)
SELECT 
	sc.channel,
	round(avg(sc.no_of_days_to_ship), 2) avg_shipping_cycle,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY sc.no_of_days_to_ship) median_shipping_cycle,
	round(avg(dc.no_of_days_to_deliver),2) avg_delivery_cycle,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY dc.no_of_days_to_deliver) median_delivery_cycle
FROM ship_cycle sc 
LEFT JOIN delivery_cycle dc
ON sc.order_id = dc.order_id 
GROUP BY sc.channel ;